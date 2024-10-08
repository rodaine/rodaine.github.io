---
layout: x-files
title: "The X-Files: Avoiding Concurrency Boilerplate With golang.org/­​x/​sync"
description: Or abstracting common synchronization patterns in Go
keywords: go, golang, x-files, sub-repositories, sync, semaphore, errgroup, singleflight, concurrent map, syncmap
---

Go makes concurrent programming dead simple with the `go` keyword. And, with its ["share memory by communicating"][share] mantra, channels perform as a thread-safe mechanism for IO between threads. These primitives more than meet the demands of most parallel tasks.

But sometimes workloads need extra coordination, particularly around error propagation or synchronization. For example, goroutines often need access to a shared yet thread-<em>unsafe</em> resource. Enter the standard library's [`sync`][sync] package with `WaitGroup`, `Once`, and `Mutex`. For the brave of heart, `sync/atomic` beckons. These utilities along with channels annihilate data races, but can result in a lot of nuanced boilerplate. Wouldn't it makes sense to lift this code into portable abstractions?

Unfortunately, the `sync` package doesn't provide for many higher-level patterns. But where the standard library is lacking, [`golang.org/x/sync`][xsync] picks up the slack. In this episode of _The X-Files_, I'll cover the four tools provided by this subrepo and how they can fit into any project's concurrent workflow.

### The Action/Executor Pattern

The _Action/Executor_ pattern from the Gang of Four, also known as the [Command][executor] pattern, is pretty powerful. It abstracts a behavior (the action) from how it's actually run (the executor). Here's the basic interface for the two components:

```go
// An Action performs a single arbitrary task.
type Action interface {
	// Execute performs the work of an Action. This method should make a best
	// effort to be cancelled if the provided ctx is cancelled.
	Execute(ctx context.Context) error
}

// An Executor performs a set of Actions. It is up to the implementing type
// to define the concurrency and open/closed failure behavior of the actions.
type Executor interface {
	// Execute performs all provided actions by calling their Execute method.
	// This method should make a best-effort to cancel outstanding actions if the
	// provided ctx is cancelled.
	Execute(ctx context.Context, actions []Action) error
}

// ActionFunc permits using a standalone function as an Action.
type ActionFunc func(context.Context) error

// Execute satisfies the Action interface, delegating the call to the
// underlying function.
func (fn ActionFunc) Execute(ctx context.Context) error { return fn(ctx) }
```

The `Action` interface type performs some arbitrary task; an `Executor` handles running a set of `Actions` together. It would be a nominal effort to create a [sequential `Executor`][sequential]. A concurrent implementation would be more useful, but requires more finesse. Namely, it's imperative that this `Executor` handles errors well and synchronizes the `Action` lifecycles.

### Error Propagation & Cancellation with `errgroup`

When I first started writing Go, I sought any excuse to use the concurrency features. It even led me towards writing a post about [tee-ing an `io.Reader`][async] for multiple goroutines to simultaneously consume. In my excitement, though, I failed to consider what happens if more than one goroutine errors out. Spoiler alert: the program would panic, as [noticed][async-errata] two years after publication.

Capturing the first error and cancelling outstanding goroutines is an incredibly common pattern. A parallel `Executor` could be plumbed together with a mess of `WaitGroups` and channels to achieve this behavior. Or, it could use the [`errgroup`][errgroup] subpackage, which abstracts this in an elegant way.

```go
// Parallel is a concurrent implementation of Executor
type Parallel struct{}

// Execute performs all provided actions in concurrently, failing closed on the
// first error or if ctx is cancelled.
func (p Parallel) Execute(ctx context.Context, actions []Action) error {
	grp, ctx := errgroup.WithContext(ctx)

	for _, a := range actions {
		grp.Go(p.execFn(ctx, a))
	}

	return grp.Wait()
}

// execFn binds the Context and Action to the proper function signature for the
// errgroup.Group.
func (p Parallel) execFn(ctx context.Context, a Action) func() error {
	return func() error { return a.Execute(ctx) }
}
```

When first calling `Parallel.Execute`, an instance of `errgroup.Group` is created from the provided `context.Context`.[^execFn] This permits the caller to stop the whole shebang at any time. Then, instead of starting vanilla goroutines, each `Action` runs via `grp.Go`. The `Group` spawns goroutines with the boilerplate to capture errors from each.

[^execFn]: Note that `Parallel.execFn` morphs the `Action.Execute` method to the expected signature of `Group.Go`.

Finally, `grp.Wait()` blocks until all the scheduled `Actions` complete. The method returns either the first error it receives from the `Actions` or `nil`. If any of the `Actions` produce an error, the `ctx` is cancelled and propagated through to the others. This allows them to short-circuit and return early.

One limitation hinted at above, however, is that `errgroup.Group` _fails closed_. Meaning if a single `Action` returns an error, the `Group` cancels all others, swallowing any additional errors. This may not be desirable, in which case a different pattern is necessary to _fail open_.

Looking at this code, it should be plain that `errgroup` cuts down on a lot of error-prone boilerplate. At the time of writing, there are just over [100 public packages importing `Group`][errgroup-importers] to synchronize their goroutines. Notably, `containerd` leverages it for [dispatching handlers][containerd-dispatch] and [diff-ing directories.][containerd-diff]

### Controlling Concurrent Access with `semaphore`

`Parallel` can create an unbounded quantity of goroutines for each call to `Execute`. This could have dangerous consequences if the `Executor` happens to be resource constrained or if an `Action` is reentrant. To prevent this, limiting in-flight calls and `Actions` will keep the system predictable.

In the [previous X-Files post][rate], I covered a usecase for the `rate` package to control access to a resource. While  `rate.Limiter` is good at managing _temporal_ access to something, it's not always appropriate for limiting _concurrent_ use. In other words, a `rate.Limiter` permits some number of actions in a given time window, but cannot control if they all happen at the same instant. A mutex or weighted semaphore, alternatively, ignores time and concerns itself only with simultaneous actions. And, as it were, the [`semaphore`][semaphore] subrepo has this usecase covered!

Before diving in, it's worth mentioning `semaphore.Weighted` and `sync.RWMutex` from the standard library share some characteristics, but solve different problems. The two are often confused, and sometimes treated (incorrectly) as interchangeable. The following points should help clarify their differences in Go:

* Ownership
  * **Mutex:** Only one caller can take a lock at a time. Because of this, mutexes can control ownership of a resource.
  * **Semaphore**: Multiple callers up to a specified weight can take a lock. This behaves like `RWMutex.RLock`, but enforces an upper bound. Since many callers could access the resource(s), semaphores do not control ownership. Instead, they act as a signal between tasks or regulate flow.
* Blocking
  * **Mutex:** Obtaining a lock blocks forever until an unlock occurs in another thread. This has the potential to cause hard-to-debug deadlocks or goroutine leaks.
  * **Semaphore**: Like `rate.Limiter`, `semaphore.Weighted` permits cancellation via `context.Context`. It also supports a `TryAcquire` method which immediately returns if the desired weight is unavailable.

Since the goal here is to control the flow of actions through an `Executor`, a semaphore is more appropriate. Below demonstrates using a `semaphore.Weighted` to decorate any `Executor`.[^decorator]

[^decorator]: This `Executor` and the following two use the [Decorator](https://en.wikipedia.org/wiki/Decorator_pattern) pattern. Two-for-one Gang of Four!

```go
type flow struct {
	maxActions int64
	actions    *semaphore.Weighted
	calls      *semaphore.Weighted
	ex         Executor
}

// ControlFlow decorates an Executor, limiting it to a maximum concurrent
// number of calls and actions.
func ControlFlow(e Executor, maxCalls, maxActions int64) Executor {
	return &flow{
		maxActions: maxActions,
		calls:      semaphore.NewWeighted(maxCalls),
		actions:    semaphore.NewWeighted(maxActions),
		ex:         e,
	}
}

// Execute attempts to acquire the semaphores for the concurrent calls and
// actions before delegating to the decorated Executor. If Execute is called
// with more actions than maxActions, an error is returned.
func (f *flow) Execute(ctx context.Context, actions []Action) error {
	qty := int64(len(actions))

	if qty > f.maxActions {
		return fmt.Errorf("maximum %d actions allowed", f.maxActions)
	}

	// limit concurrent calls to Executor.Execute
	if err := f.calls.Acquire(ctx, 1); err != nil {
		return err
	}
	defer f.calls.Release(1)

	// limit total in-flight Actions, independent of Execute calls
	if err := f.actions.Acquire(ctx, qty); err != nil {
		return err
	}
	defer f.actions.Release(qty)

	// delegate Actions to decorated Executor
	return f.ex.Execute(ctx, actions)
}
```

The `ControlFlow` function composes around an existing `Executor`. It constructs the unexported `flow` struct with two semaphores: one for calls to `Execute`, the other for total `Actions`. As calls come in, `flow` checks if the number of `Actions` exceeds the max, erroring early if necessary. It then attempts to acquire the semaphores for 1 call and _n_ `Actions`. This not only maintains an upper limit on concurrent `Executes` but also simultaneous `Actions`. Assuming there were no errors acquiring, the weights are released in `defers`. Finally, `flow` delegates the `Actions` to the underlying `Executor`.

It's arguable whether the `semaphore` package is necessary or not. For instance, buffered channels can behave like `Weighted`; the [Effective Go][effective] document even demonstrates utilizing one in this way. Yet, creating the max `Actions` semaphore would not be possible to do atomically with a channel. A different and more robust solution for limiting `Actions` would be a [worker pool][worker-pool] `Executor`. That said, there's value in having the flow control independent of the `Executor`.

`semaphore` is nonexistent in the standard library and sees almost no use in open-sourced packages. Google Cloud's [PubSub SDK][pubsub] mirrors the same use of semaphores as in the above example, controlling the number of in-flight messages as well as their cumulative size. Besides this use case, I'd suggest passing on this package in favor of the worker pool.

### Deduping Actions with `singleflight`

While `ControlFlow` limits concurrency, it has no concept of duplicates. Executing multiple expensive actions that are idempotent is a waste of resources and avoidable. An example of this occurs on the front-end, where browsers emit scroll or resize events for every frame that action is taking place. To prevent janky behavior, developers typically [debounce][debounce] their event handlers by limiting how often it triggers within the same period.

Having a similar functionality in an Executor would be a nice addition. And, as might be expected, the [`singleflight`][singleflight] package provides this facility. Like `errgroup`, a `singleflight.Group` encapsulates work occurring across goroutines. It doesn't spawn the goroutines itself; instead, goroutines should share a `singleflight.Group`. If two goroutines execute the same action, the `Group` blocks one call while the other runs. Once finished, both receive the same result, error, and a flag indicating if the result is shared. Mechanically, this is similar to `sync.Once`, but it permits subsequent operations with the same identifier to occur.

Right now, the `Action` interface has no notion of identification nor are interfaces comparable.  Creating a `NamedAction` is the first step in supporting `singleflight`:

```go
// A NamedAction describes an Action that also has a unique
// identifier. This interface is used by the Debounce Executor
// to prevent duplicate actions from running concurrently.
type NamedAction interface {
	Action

	// ID returns the name for this Action. Identical actions
	// should return the same ID value.
	ID() string
}

type namedAction struct {
	ActionFunc
	name string
}

func (a namedAction) ID() string { return a.name }

// Named creates a NamedAction from fn, with n as its name. This
// function is just a helper to simplify creating NamedActions.
func Named(n string, fn ActionFunc) NamedAction {
	return namedAction{
		ActionFunc: fn,
		name:       n,
	}
}
```

Here, the `NamedAction` interface composes around an `Action` and attaches the `ID` method. `ID` should return a string uniquely identifying the `Action`. The `Named` function provides a handy helper to construct a `NamedAction` from an `ActionFunc`. Now, a debounce `Executor` can detect when an `Action` has a name and execute it within a `singleflight.Group`:

```go
// Debounce wraps e, preventing duplicate NamedActions from running
// concurrently, even from separate calls to Execute.
func Debounce(e Executor) Executor {
	return debouncer{
		ex: e,
		sf: new(singleflight.Group),
	}
}

type debouncer struct {
	ex Executor
	sf *singleflight.Group
}

// Execute attaches a singleflight.Group to any NamedActions, effectively debouncing
// identical Actions if ran concurrently.
func (d debouncer) Execute(ctx context.Context, actions []Action) error {
	wrapped := make([]Action, len(actions))

	for i, a := range actions {
		if na, ok := a.(NamedAction); ok {
			// compose the NamedAction with the singleflight.Group
			wrapped[i] = debouncedAction{
				NamedAction: na,
				sf:          d.sf,
			}
		} else {
			// otherwise, pass it through untouched
			wrapped[i] = actions[i]
		}
	}

	// delegate wrapped Actions to decorated Executor
	return d.ex.Execute(ctx, wrapped)
}

type debouncedAction struct {
	NamedAction
	sf *singleflight.Group
}

func (da debouncedAction) Execute(ctx context.Context) error {
	// map the composed Action's Execute function with the expected signature
	// for singleflight.Group.Do.
	fn := func() (interface{}, error) {
		return nil, da.NamedAction.Execute(ctx)
	}

	_, err, _ := da.sf.Do(da.ID(), fn)

	return err
}
```

When `Debounce` receives a set of `Actions`, it checks for any `NamedAction`, wrapping them with a shared `singleflight.Group`. This new `debounceAction` delegates execution through to the group's `Do` method. Now, any concurrent identical `Actions` are only run once. Note that this only prevents the **same `Action` occurring at the same time;** later events with the same name will still occur. For this to be effective, the underlying `Executor` must operate in parallel.

Honestly, this is a pretty limited application of `singleflight.Group`, considering the `Actions` only return errors. A more common use case is to have a group front reads to a database. Without `singleflight`, this would result in one query per request. With singleflight, any concurrent calls for the same record could be shared, significantly reducing load on the underlying store. If the result is a pointer, however, users of that value must be careful not to mutate it without creating a copy.

The `singleflight` package originally supported [deduping of key fetches in `groupcache`][groupcache]. Today, it's used for [DNS lookups][dns] in the `net` stdlib package. The Docker builder also uses it in its [`FSCache`][docker] implementation.

### Avoiding the Mutex Dance with `sync.Map` (né `syncmap`)

While `Action` authors can attach logging and metrics ad hoc, doing it globally for all would be a way better approach. Another decorator that emits metrics for each operation performed by an `Executor` can achieve this, including name-scoped stats for each `NamedAction`. But first, the decorator needs a way to provide this data:

```go
// StatSource creates metrics with the given name. The returned metrics should be
// concurrency-safe.
type StatSource interface {
	Timer(name string) Timer
	Counter(name string) Counter
}

// Timer emits the duration of a particular event. The duration value is
// typically used to measure latencies and create histograms thereof.
type Timer func(duration time.Duration)

// Counter emits any number of events happening at a given time. For example,
// Counters are often used to measure RPS.
type Counter func(delta int)

// A StatSet is the cached value.
type statSet struct {
	// Latency measures how long an Action takes
	Latency Timer
	// Success is incremented when an Action does not return an error
	Success Counter
	// Error is incremented when an Action results in an error
	Error Counter
}

// Cache describes a read-through cache to obtain
type statCache interface {
	// get returns a shared statSet for the given name, either from the cache or
	// a provided StatSource.
	get(name string) *statSet
}
```

The stats library, abstracted behind a `StatSource` interface, will return `Timers` and `Counters`. These metric types are cacheable for reuse between `Actions`. For each `Action` name, the `statCache` will hold a `statSet`, containing the metrics of interest. If the `statCache.get` encounters a name it hasn't seen, it will create a new `statSet` from `StatSource`.

Now with the boilerplate out of the way, the metrics `Executor` will have more-or-less the same structure as `Debounce`:

```go
type metrics struct {
	ex Executor
	stats statCache
}

// Execute emits latency, success, and error metrics for every action delegated to the
// decorated Executor. For NamedActions, additional name-scoped stats are also emitted.
func (m *metrics) Execute(ctx context.Context, actions []Action) error {
	wrapped := make([]Action, len(actions))
	global := m.stats.get("all_actions")

	for i, a := range actions {
		if na, ok := a.(NamedAction); ok {
			// composed the NamedAction with global and name-scoped stats
			wrapped[i] = namedStatAction{
				NamedAction: na,
				global:      global,
				stats:       m.stats.get(na.ID()),
			}
		} else {
			// otherwise, just compose with global stats
			wrapped[i] = statAction{
				Action: a,
				global: global,
			}
		}
	}

	// delegate wrapped Actions to decorated Executor
	return m.ex.Execute(ctx, wrapped)
}

type namedStatAction struct {
	NamedAction
	global *statSet
	stats  *statSet
}

func (a namedStatAction) Execute(ctx context.Context) error {
	return captureMetrics(ctx, a.NamedAction, a.global, a.stats)
}

type statAction struct {
	Action
	global *statSet
}

func (a statAction) Execute(ctx context.Context) error {
	return captureMetrics(ctx, a.Action, a.global, nil)
}

func captureMetrics(ctx context.Context, a Action, global, stats *statSet) error {
	// execute the action, timing its latency
	start := time.Now()
	err := a.Execute(ctx)
	lat := time.Now().Sub(start)

	// create our counter values for error/success
	var errored, succeeded int
	if err != nil {
		errored = 1
	} else {
		succeeded = 1
	}

	// emit the global stats
	global.Latency(lat)
	global.Success(succeeded)
	global.Error(errored)

	// if there are name-scoped stats, emit those, too
	if stats != nil {
		stats.Latency(lat)
		stats.Success(succeeded)
		stats.Error(errored)
	}

	return err
}
```

So, how should `statCache` be implemented? At face value, this seems like a perfect usecase for a map–easy enough! However, this is one of Go's most common gotchas: **maps are not safe for concurrent use**. With just a map, concurrent calls to the Executor would result in data races reading and writing to the cache. All's not lost, though. Developers can synchronize access to their fields with the careful use of a `sync.RWMutex`. Below is a `statCache` implementation that leverages these two together with what I call the _mutex dance_.

```go
// mutexCache implements statCache, backed by a map and sync.RWMutex
type mutexCache struct {
	src    StatSource
	mtx    sync.RWMutex
	lookup map[string]*statSet
}

func (mc *mutexCache) get(name string) *statSet {
	// take a read lock to see if the set already exists
	mc.mtx.RLock()
	set, ok := mc.lookup[name]
	mc.mtx.RUnlock()

	if ok { // the set exists, return it
		return set
	}

	// need to take a write lock to update the map
	mc.mtx.Lock()
	// While waiting for the write lock, another goroutine may have created the
	// set. Here, we check again after obtaining the lock before making a new one
	if set, ok = mc.lookup[name]; !ok {
		set = newStatSet(mc.src, name)
		mc.lookup[name] = set
	}
	mc.mtx.Unlock()

	return set
}
```

First, the cache obtains a read lock on its mutex to see if the set already exists in its map. Multiple callers to `get` can share a read lock so there is no steady-state contention to access the map. However, if the set does not exist, the caller must obtain a write lock to make changes to the underlying map. Only one write lock can exist concurrently, so execution stops until all read locks (or another write lock) are unlocked.

With the write lock in hand, it needs to check the map again for the set. This is because, while waiting for the lock, another goroutine may have added the set to the map. If it still does not exist, the set is added, the lock is released, and the value is returned from the cache.

This nuanced dance of locking and unlocking mutexes is error prone. One false step and incredibly hard to debug deadlocks will creep into the program. Without generics, code generation or some nasty reflection, generalizing this for any arbitrary map is also just not possible. Is there a better way?

Well, kind of: [`sync.Map`][sync.map]. Originally a part of the sub-repository as [`syncmap.Map`][syncmap], this concurrency-safe map implementation was added to the standard library in Go 1.9\. It was first proposed to address [scaling issues with sync.RWMutex protected maps on machines with many (_many_) CPU cores][map-issue]. Since then, `sync.Map` has replaced map-based caches throughout the standard library. Check out its use in `encoding/json`, `mime`, and `reflect`.[^internals]

[^internals]: The internals of `sync.Map` are fascinating. It possesses separate fast and slow paths via an atomically accessed read-only map and a mutex protected dirty copy. Heuristics driven by fast path misses control when the dirty map is persisted onto the read-only map. I recommend giving the [implementation](https://golang.org/src/sync/map.go) a read.

Below, is a reimplementation of `statCache` using `sync.Map`:

```go
// syncMapCache implements statCache, backed by a sync.Map
type syncMapCache struct {
	src    StatSource
	lookup sync.Map
}

func (smc *syncMapCache) get(name string) *statSet {
	val, _ := smc.lookup.Load(name)
	if set, ok := val.(*statSet); ok {
		return set
	}

	// create a new statSet, but don't store it if one was added since the last
	// load. This is not ideal since we can't atomically create the set and
	// write it.
	set, _ := smc.lookup.LoadOrStore(name, newStatSet(smc.src, name))
	return set.(*statSet)
}
```

A few things should stick out from this new implementation. First, `sync.Map` abstracts away all the synchronization boilerplate. While it gains readability and reliability, though, it also loses compiler-time type safety. `sync.Map` deals solely with `interface{}` as it's not a builtin. Also, as the comment implies, this version cannot atomically create the set and commit it to the map. While `LoadOrStore` does not insert the new set if it already exists, it still pays the cost of calling `newStatSet`, which could be expensive.

So which is "better?" Depends on the goal. If readability and maintainability is the primary concern, use `sync.Map`. If it's type-safety, I would recommend the mutex-based cache. If it's performance, measure. And be sure to benchmark on hardware that is or resembles a production environment. Supposing this Mid-2015 MacBook Pro (4 cores, 8 threads) is close enough, here's some [benchmarks][benchmarks] comparing the two implementations:

<aside>The benchmark names have the following form: <code>Benchmark<b>CACHE_NAME</b>&#8203;/<b>CORPUS_SIZE</b>-8</code>. The trailing 8 indicates the number of CPU threads used in the test.</aside>

```txt
BenchmarkMutexCache/10-8            10000000	       180 ns/op	       0 B/op	       0 allocs/op
BenchmarkMutexCache/100-8           10000000	       187 ns/op	       0 B/op	       0 allocs/op
BenchmarkMutexCache/1000-8          10000000	       214 ns/op	       0 B/op	       0 allocs/op
BenchmarkMutexCache/10000-8         10000000	       231 ns/op	       0 B/op	       0 allocs/op
BenchmarkMutexCache/100000-8         5000000	       254 ns/op	       2 B/op	       0 allocs/op
BenchmarkMutexCache/1000000-8        1000000	      1159 ns/op	     102 B/op	       1 allocs/op
BenchmarkMutexCache/10000000-8       1000000	      1481 ns/op	     184 B/op	       2 allocs/op
BenchmarkMutexCache/100000000-8      1000000	      1655 ns/op	     187 B/op	       3 allocs/op

BenchmarkSyncMapCache/10-8           5000000	       221 ns/op	       0 B/op	       0 allocs/op
BenchmarkSyncMapCache/100-8         10000000	       235 ns/op	       0 B/op	       0 allocs/op
BenchmarkSyncMapCache/1000-8        10000000	       235 ns/op	       0 B/op	       0 allocs/op
BenchmarkSyncMapCache/10000-8       10000000	       246 ns/op	       0 B/op	       0 allocs/op
BenchmarkSyncMapCache/100000-8       5000000	       264 ns/op	       5 B/op	       0 allocs/op
BenchmarkSyncMapCache/1000000-8      1000000	      1378 ns/op	     146 B/op	       3 allocs/op
BenchmarkSyncMapCache/10000000-8     1000000	      1939 ns/op	     237 B/op	       5 allocs/op
BenchmarkSyncMapCache/100000000-8    1000000	      2090 ns/op	     241 B/op	       6 allocs/op
```

The benchmark takes a corpus of _N_ names (ranging from 10 to 100 million), chooses one at random, fetches the set with that name from the cache, and emits a stat. It also runs in parallel, simulating the contention of  multiple goroutines executing actions. As the population of names grows, the read:write ratio shrinks, going from ~100% reads (_N_ = 10) to far more writes (_N_ = 100 million).

 The results show the `sync.Map` implementation is systematically ~20% slower than the mutex solution. This should be expected, given the use of interface{} and the extra internal bookkeeping. I'd likely choose to use the mutex-based solution as library code should provide as little overhead as possible.

### Wrapping Up

The sync subrepository has a ton of utility, but I'm surprised to see it shows up in very few open source projects. Hopefully these examples will conjure some ideas where it could be useful. The code for this article is both available in the inlined [gist][gist] snippets, as well as an importable [executor][repo] package. Let me know how it goes!

[share]: https://blog.golang.org/share-memory-by-communicating
[sync]: https://golang.org/pkg/sync/
[xsync]: https://godoc.org/golang.org/x/sync
[executor]: https://en.wikipedia.org/wiki/Command_pattern
[sequential]: https://gist.github.com/rodaine/d627e4b67285eb5aaa72f3df2b344ad2#file-sequential-go
[errgroup]: https://godoc.org/golang.org/x/sync/errgroup
[errgroup-importers]: https://godoc.org/golang.org/x/sync/errgroup?importers
[containerd-dispatch]: https://github.com/containerd/containerd/blob/4ae34cccc5b496c6547ff28dbeed1bde4773fa7a/images/handlers.go#L95
[containerd-diff]: https://github.com/containerd/containerd/blob/4ae34cccc5b496c6547ff28dbeed1bde4773fa7a/fs/diff.go#L281
[worker-pool]: https://gist.github.com/rodaine/d627e4b67285eb5aaa72f3df2b344ad2#file-pool-go
[effective]: https://golang.org/doc/effective_go.html#channels
[pubsub]: https://github.com/GoogleCloudPlatform/google-cloud-go/blob/357e551/pubsub/flow_controller.go
[debounce]: https://davidwalsh.name/javascript-debounce-function
[groupcache]: https://github.com/golang/groupcache/blob/6dad98a783706eed16bd2f90356daa33bbc925b2/singleflight/singleflight.go
[dns]: https://golang.org/pkg/net/#Resolver.LookupIPAddr
[docker]: https://github.com/docker/docker-ce/blob/7f78f7f/components/engine/builder/fscache/fscache.go
[map-issue]: https://github.com/golang/go/issues/18177
[semaphore]: https://godoc.org/golang.org/x/sync/semaphore
[singleflight]: https://godoc.org/golang.org/x/sync/singleflight
[benchmarks]: https://github.com/rodaine/executor/blob/master/statcache_benchmark_test.go
[gist]: https://gist.github.com/rodaine/d627e4b67285eb5aaa72f3df2b344ad2
[repo]: https://github.com/rodaine/executor
[syncmap]: https://godoc.org/golang.org/x/sync/syncmap
[sync.map]: https://golang.org/pkg/sync/#Map
[async]: {{< ref 2015-04-25-async-split-io-reader-in-golang.md >}}
[async-errata]: {{< ref 2015-04-25-async-split-io-reader-in-golang.md >}}#errata-updated-2017-05-22
[rate]: {{< ref 2017-05-22-x-files-time-rate-golang.md >}}
