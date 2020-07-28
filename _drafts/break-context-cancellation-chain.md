---
layout: post
title: Break The Golang Context Chain
description: And enabling a context to be used after cancellation
keywords: go, golang, context, cancellation, shadowing, goroutines
---

Recently, I recalled a useful pattern that's cropped up a few times at work. API handlers (think `http.Handler`), include a `context.Context` tied to the connectivity of the caller. If the client disconnects, the context closes, signaling to the handler that it can fail early and clean itself up. Importantly, the handler function returning _also_ cancels the context.

But what if you want to do an out-of-band operation after the request is complete? Like shadowing a new implementation or emitting analytics data that isn't cheap enough to send inline? Perhaps there are some [request-scoped values][values] attached to the context necessary to perform these operations.

A straightforward solution might be to create a new context and attach used values. Copying works if the application owns those key-value pairs, and they are enumerable. But it should feel rickety. And, in the case of shadowing, this is an assumption that's different than the actual implementation. Is there a better way?

## The Situation

OK, so we've got an HTTP endpoint that _does something_, and we're testing out a new implementation that we think is better. We want to ensure that's the case (via metrics and other heuristics), and we want to verify that, given real production data, it has the same behavior. Instead of doing this sequentially with the actual request, which would add to its latency, we instead choose to do it concurrently in a goroutine:

```go
func Handle(w http.ResponseWriter, req *http.Request) {
	// ex: unmarshal JSON or query parameters
	input := readInput(req)

	// performs the actual business logic
	out, err := DoSomething(req.Context(), input)

	// shadow the new implementation out-of-band
	go shadow(req.Context(), input, out, err)

	// write the output or error to the caller
	writeOutput(w, out, err)
}

func shadow(ctx context.Context, input *Input, expectedOut *Output, expectedErr error) {
	// execute the new implementation wtih the same inputs
	newOut, newErr := DoSomethingBetter(ctx, input)

	// compare results and emit data
	reportComparison(ctx, Comparison{
		Input:          input,
		ExpectedOutput: expectedOut,
		ExpectedError:  expectedErr,
		NewOutput:      newOut,
		NewError:       newErr,
	})
}
```

Satisfied with the approach, we push this code to production and gleefully await the data. Unfortunately, the data indicate that the new implementation often mismatches, returning an error (`context.Canceled`) instead of the expected output. What gives?

> For incoming server requests, the context is canceled when the client's connection closes, the request is canceled (with HTTP/2), or when the ServeHTTP method returns. <cite>[http.Request.Context][request.context]</cite>

In our case, while the `shadow` function is running concurrently, `Handle` may have finished writing the response and returned, which results in the `req.Context.Done` channel being closed. Anywhere the context is used past that point will result in the cancellation error. To understand how we can overcome this, we need to grok context's design.

## The Context Prototype Chain

When creating a context, every single constructor requires a parent `context.Context`:

```go
ctx, cancel := context.WithCancel(parent)
ctx, cancel := context.WithDeadline(parent, deadline)
ctx, cancel := context.WithTimeout(parent, timeout)
ctx := context.WithValue(parent, key, value)
```

Under the hood, the new context composes around the parent, inheriting any pre-existing deadlines, cancellations, and key-value pairs. If the parent (or any other ancestor) is canceled or times out, the "doneness" is propagated down through the chain of child contexts, exposed via the `Done` and `Err` methods. The converse is false however: a canceled child context does not cancel its parent.

Additionally, attaching values results in a new child context for each new key-value pair without mutating the parent. When calling `Value` on a context, it walks up the ancestor chain, checking each parent for the requested key. This pattern permits a child to overwrite a value without mucking up the parent or any other parallel chains sharing a similar root context. It also means that value lookups are `O(n)` and not `O(1)`, so be judicious in how many values you include in a context.

<aside>If you were to google "prototype chain," you will find documentation and tutorials covering the underlying inheritance model of JavaScript. This should not be confused with the "prototype pattern," described by the Gang of Four's design patterns, which is fundamentally different from what we're talking about here.</aside>

This construction is known as a _prototype chain_, where each "link" is a new context that refers to its predecessors to share and override the behavior. And we want to break that.

## Break The Chain

Well, not exactly. In our shadowing case, we still want access to any values on the parent context, but we want to disconnect the new code from the handler's cancellations. Instead of breaking the chain (which is essentially creating a completely new one), we need to short-circuit the existing one's behavior. We do this by forming a new context "link":

```go
// DisconnectContext returns a child context from parent that does not
// propagate cancellation or deadlines. Value pairs are still propagated.
func DisconnectContext(parent context.Context) context.Context {
	return disconnectedContext{ parent: parent }
}

// disconnectedContext looks very similar to the unexported context.emptyCtx
// implementation from the standard library, with the exception of the parent's
// Value method being the only feature propagated.
type disconnectedContext struct {
	parent context.Context
}

// Deadline will erase any actual deadline from the parent, returning ok==false
func (ctx disconnectedContext) Deadline() (deadline time.Time, ok bool) {
	return
}

// Done will stop propagation of the parent context's done channel. Receiving
// on a nil channel will block forever.
func (ctx disconnectedContext) Done() <-chan struct{} {
	return nil
}

// Err will always return nil since there is no longer any cancellation
func (ctx disconnectedContext) Err() error {
	return nil
}

// Value behaves as normal, continuing up the chain to find a matching
// key-value pair.
func (ctx disconnectedContext) Value(key interface{}) interface{} {
	return ctx.parent.Value(key)
}
```

The implementation is simple and effective; all methods return zero values. The only exception (`Value`) delegates to the parent. The `shadow` goroutine can now be modified to use this new helper:

```go
func shadow(ctx context.Context, input *Input, expectedOut *Output, expectedErr error) {
	// disconnect from the parent context chain
	ctx = DisconnectContext(ctx)

	// execute the new implementation wtih the same inputs
	newOut, newErr := DoSomethingBetter(ctx, input)

	// <snip>
}
```

There we have it!

## Here Be Dragons

I'd categorize this as dark arts: it breaks the fundamental contract of how contexts are supposed to work, and it is opaque to the rest of the stack. To mitigate this at work, our constructor requires a timeout to prevent the context from becoming a permanent zombie:

```go
func DisconnectContext(parent context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	ctx := disconnectedContext{parent: parent}
	return context.WithTimeout(ctx, timeout)
}
```

Even so, this sort of foot-gun should give you the shivers. Breaking the context chain should be well documented and isolated from the main flow of the application (if possible). Ideally, I encourage exploring other strategies, especially if this behavior will be more than temporary.

For example, is there a better way to get shadowing?

- **Have the networking layer do the work for you.** If your service has a configurable proxy in front of it, such as Envoy, you can [mirror traffic][mirror]. Mirroring allows testing a new implementation in isolation alongside the existing one without impacting the downstream client. While more operationally intensive, this will more closely match the real behavior of the application flow and not muddy handler code with shadowing logic.

- **Make it in-your-face.** Right now, the shadowing behavior is ad-hoc, but using an experimentation library, like GitHub's [scientist][scientist], will make the shadowing explicit and structured in the code. A tool like this might come with builtin statistics and tracing to validate the results.

- **Control it with feature flags.** Feature flag tools, such as [dcdr][dcdr], are not exactly a separate strategy, but more of a recommendation. When introducing a new code path, you may not want to expose all traffic to it simultaneously. A subset of all traffic is often enough to vet experiments. By leveraging feature flags, the shadowing can begin in the "off" state, and then slowly ramped up to 1%, 10%, 25% of requests.

All-in-all, while I wouldn't call breaking the chain a _good_ pattern, it can be useful in this context (heh), and other valid use cases surely exist.

[mirror]: https://www.envoyproxy.io/docs/envoy/latest/api-v2/api/v2/route/route_components.proto#envoy-api-msg-route-routeaction-requestmirrorpolicy
[scientist]: https://github.com/github/scientist
[request.context]: https://golang.org/pkg/net/http/#Request.Context
[values]: https://blog.golang.org/context
[dcdr]: https://github.com/vsco/dcdr
