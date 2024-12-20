---
layout: x-files
title: "The X-Files: Controlling Throughput with rate.Limiter"
description: Or how to fail fast and avoid catastrophe
keywords: go, golang, x-files, sub-repositories, token bucket, rate limit, time.Ticker, rate.Limiter
---

In this first _X-Files_ post, I'll cover the simple yet powerful [golang.org/x/time/rate][rate]. This package provides a `Limiter` that controls throughput to an arbitrary resource. There’s a ton of utility in `rate`, and to show its virtues, I will use it to enforce an SLA on an HTTP service.[^credits]

[^credits]: The service and test-harness code in this example lives on [GitHub](https://github.com/rodaine/x-files-rate). Load testing utilizes Tomás Senart's awesome [vegeta](https://github.com/tsenart/vegeta) library, with plots generated by [gnuplot](http://www.gnuplot.info/).

### SLAs and Rate Limiting

When creating a new service, it is prudent to specify a service level agreement, or SLA. This promises an expected availability given some throughput from consumers. The benefits of an SLA are twofold. First, it provides [a metric][nines] by which the success of a service is measurable. Is it exceeding expecations, or are changes necessary to achieve the SLA? Second, it is enforceable as a means to protect upstream dependencies (like a database) from a [cascading failure][cascade]. One of the simplest ways to impose such an SLA is rate limiting incoming requests.

#### The "Hello, World!" Microservice

The nascent _Hello, World!_ microservice exposes one HTTP endpoint that makes a call to an upstream service and writes (ahem) "Hello, World!" to the response. The `http.HandlerFunc` might look something like this:

```go
func HelloWorld(w http.ResponseWriter, r *http.Request) {
	switch err := upstream.Call(); err.(type) {
	case nil: // no error
		fmt.Fprintln(w, "Hello, World!")
	case upstream.ErrTimeout: // known timeout error
		w.WriteHeader(http.StatusGatewayTimeout)
	default: // unknown error
		w.WriteHeader(http.StatusBadGateway)
	}
}
```

The upstream dependency has some interesting characteristics. First, it takes an average of about 25ms to complete `upstream.Call()`. Next, it concurrently handles up to 10 calls before queueing them. Finally, if a call takes longer than 500ms to complete, the method returns a timeout error.

To protect itself from drowning in traffic, the service should conform to an SLA. As an initial step, performing load tests will help derive the right thresholds.

{{<figure id="hello" src="hello.svg" alt="Performance graphs of unlimited throughput to the service over RPS. Success rate drops below 100% rapidly and logarithmically starting about 450rps, with essentially all failures happening due to the upstream service timeout of 500ms. Successful requests are steady at <50ms (P50 & P95) until approximately 415rps, ramping up quickly to take anywhere from 275ms (P50) to 500ms (P95) at 450rps and onward." caption="Initial load testing with no rate limiting. Success Rate (**top left**) measures the ratio of requests that were successful (200 response codes) at a given RPS. Total P50 and P95 (**top right**) indicates the median and 95th-percentile latencies respectively over all requests. These are split out by successful (**bottom left**) and failed (**bottom right**) requests, additionally.">}}

Woof… At approximately 415rps, the upstream service is unable to handle the volume and begins queueing. As the RPS increases, the amount of calls enqueued must wait longer and longer to complete. When the service reaches about 450rps, the upstream calls start exceeding the 500ms threshold and failing at a logarithmic rate as the throughput continues to grow. Those requests that are lucky enough to make it through have a median latency (P50) of ~275ms and a 95th-percentile (P95) just under 500ms.

This behavior is not ideal and usually indicative of a critical failure upstream. But now there is enough information to make an SLA! While the service may be showing signs of degradation at 425rps, the success rate holds steady at 100%. Likewise, the P95 latency at this rate is ~165ms. For this example, it is safe to assume consumers will tolerate up to a P95 of 275ms. Given these limits, a target SLA can be defined:

> The _Hello, World!_ service guarantees at least 99.99% availability up to 425rps. The P95 for all requests will not exceed 275ms.

#### Trickle Through with `time.Ticker`

With SLA in hand, preventing a flood against the upstream service is the first order of business. The service remains stable at 425rps and should limit throughput heading upstream. To throttle the `http.HandlerFunc`, the channel exposed by a `time.Ticker` acts as a semaphore:

```go
func TickerLimiter(rps, burst int) (c <-chan time.Time, cancel func()) {  
	// create the buffered channel and prefill it
	c = make(chan time.Time, burst)
	for i := 0; i < burst; i++ {
		c <- time.Now()
	}

	// create a ticker with the interval 1/rps
	t := time.NewTicker(time.Second / time.Duration(rps))
	
	// add to the channel with each tick
	go func() {
		for t := range t.C {
			select {
			case c <- t: // add the tick to channel
			default:     // channel already full, drop the tick
			}
		}
		close(c) // close channel when the ticker is stopped
	}()

	return c, t.Stop
}

func RateLimit(rps, burst int, h http.HandlerFunc) http.HandlerFunc {
	l, _ := TickerLimiter(rps, burst)
	
	return func(w http.ResponseWriter, r *http.Request) {
		<-l // h is blocked by the TickerLimiter
		h(w, r)
	}
}
```

Why not outright use `time.Ticker`? The channel returned from the ticker is unbuffered and would enforce serial access to the endpoint. This is not the desired behavior for any web service, especially when the upstream service handles up to 10 concurrent requests. So, a buffered channel fronts the ticker, prefilled to the specified burst. A `cancel` function is returned in the event the limiter is no longer used. If `cancel` is not called, the `time.Ticker`, buffered channel, and goroutine would all end up leaking! Since this handler is going to live on for the life of the process, though, it can be ignored.

The `RateLimit` function itself decorates any `http.HandlerFunc` with the limiter logic. This is a common middleware pattern in Go. Applying this to the existing handler and registering it with the mux:

```go
const (
	rps   = 425 // the SLA maximum
	burst = 10  // matches the upstream services concurrency
)

http.HandleFunc("/", RateLimit(rps, burst, HelloWorld))
```
 Now that everything's all squared away, running the tests again reveals an improved availability:

{{<figure src="ticker.svg" alt="Performance graphs of time.Ticker limited service. While the success rate remains at 100% for all RPS values, the latencies scale linearly up from ~25rps at 415rps to between 1250ms (P50) to 2250ms (P95) at 600rps." caption="Load testing of service limited by `time.Ticker`." >}}

Whelp, since only a safe amount of requests are making it through to the upstream service at a time, the service achieves 100% availability through 600rps. This satisfies the 4-nines part of the SLA. Yet, starting at 425rps, latencies show linear growth as requests pile up behind the limiter, exceeding _two seconds_ at 600rps.

Not only does this violate the 275ms P95 stipulation, but it also has the potential to wreak havoc on the service itself. If it's memory-bound or has limited resources (eg, file descriptors or threads), the service would soon refuse new connections or die. In fact, for reproducibility, the test harness boosts file descriptors from the default 1,024 (on Mac OS) to a million! Regardless, as long as the SLA holds at 425rps, the limiter should drop requests exceeding the deadline beyond that.

#### `time.Ticker` with `select` Timeout

To cancel the read on the limiter, a `select` statement can short circuit the request with a timeout:

```go
func RateLimit(rps, burst int, wait time.Duration, h http.HandlerFunc) http.HandlerFunc {
	l, _ := TickerLimiter(rps, burst)

	return func(w http.ResponseWriter, r *http.Request) {
		t := time.NewTimer(wait)
		select {
		case <-l:
			t.Stop()
		case <-t.C: // wait deadline reached, cancel request
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}

		h(w, r)
	}
}
```

The middleware's signature now adds a `wait` parameter . This specifies how long the `time.Timer` should run before terminating an enqueued request. If the limiter lets the request through, the middleware calls `t.Stop()`. While this isn't required, it frees up the timer's resources immediately.

Using the same `rate` and `burst` as before, the handler now needs a deadline. Given that the P95 at 425rps is ~165ms, a timeout of 75ms should bring it up to about 240ms, safely below the 275ms rule. Running load tests again, this resolves the unbounded latencies:

{{<figure src="fast.svg" alt="Performance graphs of time.Ticker with select timeout at 75ms. While the success rate falls linearly starting at approximately 435rps (with a SR of 72% at 600rps), failure latencies originate from the select timeout instead of the upstream service. Better still, success latencies remain steady between 175ms (P50) and 260ms (P95)." caption="Load testing of service limited by `time.Ticker` with a timeout of 75ms" >}}

Sweet! The success rate remains at 100% through 435rps before falling, and the P95 latencies stay below 275ms. All the failures are exactly 75ms, indicating the rate limiter timeout is effective.

Still, 75ms is an eternity for a computer to be waiting, and a traffic spike could yet overwhelm the process. Knowing the limiter's queue depth, it could determine if a request will even make it through. If there's no chance, the limiter should cancel the request without waiting for the deadline.

#### Smarter queueing with the `rate.Limiter` token bucket

Alright, hold up. Before implementing this strategy on top of the limiter, there are a couple of things to note. First, the Go wiki suggests [avoiding `time.Ticker` if the rate exceeds tens per second][wiki]. This is likely a fidelity issue with either the clock, the performance of channels, or both. At 425rps, the limiter exceeds this heuristic by an order of magnitude. Instead, a [token bucket][bucket] solution is preferable … like [`rate.Limiter`][rate]!

Second, the `rate` package already implements this extrapolation strategy. `rate.Limiter` uses `Reservations`: promised access to a resource after some time, like getting a table at a restaurant. Since the `Reservation` encodes the time in which it can be fulfilled, the limiter can jettison requests from the start.

For the purposes of this service, [`rate.Limiter#Wait`][wait] achieves this desired behavior:

```go
func RateLimit(rps, burst int, wait time.Duration, h http.HandlerFunc) http.HandlerFunc {
	l := rate.NewLimiter(rate.Limit(rps), burst)

	return func(w http.ResponseWriter, r *http.Request) {
		// create a new context from the request with the wait timeout
		ctx, cancel := context.WithTimeout(r.Context(), wait)
		defer cancel() // always cancel the context!

		// Wait errors out if the request cannot be processed within
		// the deadline. This is preemptive, instead of waiting the
		// entire duration.
		if err := l.Wait(ctx); err != nil {
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}

		h(w, r)
	}
}
```

This version is the same as the previous, albeit trading channels and selects for `context.Context` and error handling. Running the tests, though, shows the benefit of this package:


{{<figure src="rate.svg" alt="Performance graphs of rate.Limiter with a deadline of 75ms. While the SR and overall latency characteristics of these graphs match the previous, failure latencies are now sub millisecond instead of the entire timeout duration." caption="Load testing of service limited with `rate.Limiter`" >}}

While the latencies of these graphs match the previous almost exactly, the failures are now sub-millisecond! This indicates requests doomed to fail are terminated early, preventing a potential pileup on the service. It would be prudent, of course, to provide a retry policy and return back off information to the consumers.

The service now conforms to its SLA, protecting itself, its dependencies and its consumers by shedding excess load. Though a contrived example, this strategy is useful in determining boundaries for a real-world service. Adjusting the parameters driving the limiter (`rps`, `burst`, and `wait`) will eke out as much availability and performance as desired.

### More Features and Uses of `rate.Limiter`

The `rate` package is not limited to gating HTTP endpoints. Here are some other interesting uses to consider:

* **Fine-Grained Limitations.** The example laid out above treats all requests as equal. But, the middleware can be setup to limit by arbitrary properties on the request, such as header values. The [`tollbooth`][tollbooth] package abstracts a lot of this behavior.

* **Runtime Configurable.** One powerful feature not covered here is that the `rate.Limiter` can be adjusted on the fly to have different fill rates or burst. Controlled with a distributed feature flag tool like [`dcdr`][dcdr], these values can be modified on-the-fly without a deployment by calling `SetLimit`. This is a powerful way of scaling features, or responding to environmental changes of the system.

* **Load Testing.** [`vegeta`][vegeta] is a powerful tool for load testing HTTP services, but only handles HTTP endpoints. For APIs that expose other protocols like raw TCP or UDP, `rate.Limiter` can help simulate a sustained load. [`statstee`][statstee] uses one for simulating StatsD traffic.

* **Migrations Throttling.** As systems refactor and grow, data migrations become a neccessity. While the changes resulting from a migration may be simple, the volume can be dangerous. By using a rate limiter in a migration pipeline, throttling becomes a cinch.

* **Traffic Shaping.** Fronting an `io.Reader/Writer` with a `rate.Limiter` can shape the flow of bytes to a particular bandwidth. This could simulate network conditions (like a 3G connection) when applied as an HTTP middleware.

### What about service clusters?

A distributed system here would complicate things, but the mechanisms would remain similar. For instance, in a typical microservice architecture, multiple instances of the same service execute in a cluster with a load balancer spreading the traffic between them. While the strategies above work for a single node, it is not ideal for each to manage its own rates. Using a shared rate limiter avoids this concern, and it just so happens that Lyft recently open-sourced [Ratelimit][lyft], a very powerful generic rate-limiting service. `</shameless-plug>`

### Wrapping Up

I've only demonstrated a small number of use cases for `rate.Limiter`. I'm curious to see how others have used this spartan but powerful package. Feel free to comment with some novel examples that I haven't covered here!

[bucket]:    https://en.wikipedia.org/wiki/Token_bucket
[cascade]:   https://en.wikipedia.org/wiki/Cascading_failure
[dcdr]:      https://github.com/vsco/dcdr
[nines]:     https://en.wikipedia.org/wiki/High_availability#.22Nines.22
[rate]:      https://godoc.org/golang.org/x/time/rate
[statstee]:  https://github.com/rodaine/statstee/blob/master/example/jerks/jerks.go
[tollbooth]: https://github.com/didip/tollbooth
[vegeta]:    https://github.com/tsenart/vegeta
[wait]:      https://godoc.org/golang.org/x/time/rate#Limiter.Wait
[wiki]:      https://github.com/golang/go/wiki/RateLimiting
[lyft]:      https://eng.lyft.com/announcing-ratelimit-c2e8f3182555
