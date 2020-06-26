---
layout: post
title: Break The Golang Context Chain
description: And enabling a context to be used after cancellation
keywords: go, golang, context, cancellation, shadowing, goroutines
---

I was recently reminded of a useful pattern at work. For API handlers (think `http.Handler` or an RPC method), a `context.Context` is included that's tied to the connectivity of the caller. If the client disconnects, the context is closed, signaling to the handler's logic that it can fail early and clean itself up. Importantly, the context is _also_ cancelled once the handler returns.

But what if you want to do an out-of-band operation after the request is complete? Like shadowing a new implementation or emitting analytics data that isn't cheap enough to send inline? Perhaps there's some request-scoped values attached to the context necessary to perform these operations, but the cancellation makes it unusable (especially if it requires passing to a client).

A straightforward solution might be to just create a new context and attach the values you're interested in. This works if those key-value pairs are owned by the application and reasonably finite. But this should feel rickety, and in the case of shadowing, is an assumption that's different than the actual implementation. Is there a better way?

## The Situation

OK, so we've got an HTTP endpoint that _does something_ and we're testing out a new implementation that we think is better. We want to ensure that's actually the case (via metrics and other heuristics) and we want to verify that, given real production data, it has the same behavior. Instead of doing this in-band of a real request, which would add to its latency, we instead choose to do it out-of-band in a goroutine:

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

Satisfied with the approach, we push this code to production and gleefully await the data. Unfortunately, anywhere from 50-100% of the time, our reports indicate that the new implementation almost always mismatches, returning an error: `context.Canceled`. What's up with that?

> For incoming server requests, the context is canceled when the client's connection closes, the request is canceled (with HTTP/2), or when the ServeHTTP method returns. <cite>func (\*http.Request) Context</cite>

In our case, while `shadow` is running concurrently, `Handle` may have finished writing the response and returned, which results in `req.Context` being closed. Anywhere the context is used past that point will almost certainly result in the cancellation error. To understand how we can overcome this, we need to understand a skosh about how prototypes are designed.

## The Context Prototype Chain

When creating a context, every single constructor requires a parent `context.Context` to be passed in:

```go
ctx, cancel := context.WithCancel(parent)
ctx, cancel := context.WithDeadline(parent, deadline)
ctx, cancel := context.WithTimeout(parent, timeout)
ctx := context.WithValue(parent, key, value)
```

Under the hood, the new context composes around the parent, inheriting any pre-existing deadlines, cancellations, and key-value pairs. If the parent (or any ancestor) is cancelled or times out, the doneness is propagated down through the chain of child contexts. The reverse is not true however: a cancelled child context does not cancel its parent.

Even attaching values results in a new child context for each new pair without mutating the parent. When `Value` is called on a context, it walks up the chain checking each context for the requested key. This permits a child to shadow a value without mucking up the parent or any other parallel chains sharing a similar root context. It _also_ means that value lookups are `O(n)` and not `O(1)` like a map lookup, so be judicious in how many values are included on a context.

<aside>If you were to google "prototype chain," you will find documentation and tutorials covering the underlying inheritance model of JavaScript. This should not be confused with the "prototype pattern," described by the Gang of Four's design patterns, which is fundamentally different.</aside>

This construction is often referred to as a _prototype chain_, where each "link" is a new context that refers to its predecessors to share and override the behavior. And we want to break that.

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
