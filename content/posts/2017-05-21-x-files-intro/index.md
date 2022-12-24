---
title: "The X-Files: Exploring the Golang Standard Library Sub-Repositories"
description: Or understanding the Go packages under golang.org/x/*
keywords: go, golang, subrepositories, subrepos, extensions, packages, golang.org/x, x-files
content_schema: CreativeWorkSeries
---

![The X-Files logo](x-files-logo.svg)
{ .padded }

This post will be the start of **The X-Files**, a blog series exploring the Go sub-repositories located at `golang.org/x/*`. Chances are, you may not have heard them called that before or know where they came from. Introductions are in order...

### A brief origin story

Go promises, with reasonable exceptions, that its compiler and standard library will remain [forward-compatible][compat] for all minor releases of the Go 1 language specification. This is incredibly refreshing, especially if you've ever used a framework or language that seems to break the world on every patch release. While perhaps this makes Go [boring][boring], it permits developers to confidently use the language and stdlib, leaving the core team to focus on performance in the compiler, optimizations to the garbage collector, and other quality-of-life improvements.

But with this guarantee, the core team needed a place for experimentation, for tooling, for supplements to the standard library: the proverbial junk drawer of the Go language ecosystem. Thus, the sub-repositories were born. These projects live under the parent one, utilizing the same process and tools (like Gerrit), but without the strict compatibility requirements.

### Wherefore art thou sub-repository?

The compatibility document describes subrepos as follows:

{{<citation title="Go 1 and the Future of Go Programs" url="https://go.dev/doc/go1compat#subrepos">}}
Code in sub-repositories of the main go tree [...] may be developed under looser compatibility requirements. However, the sub-repositories will be tagged as appropriate to identify versions that are compatible with the Go 1 point releases.
{{</citation>}}

Well, that's pretty vague ... And, expectedly, the packages have accumulated a smorgasbord of libraries, drivers, tools, and experiments. In them, you can find quite a lot of interesting goodies - some well known, others more obscure. For instance, [`golang.org/x/net`][net] delivered us the beloved `context.Context` now as of 1.7 in the stdlib; meanwhile, [`golang.org/x/text`][text] grows into an incredible text manipulation library that you've never heard of. There are a ton of useful utilities and glimpses behind-the-scenes into the processes of the core team.

So, what qualifies as a sub-repository? At the time of writing, there's been an ongoing discussion on what the [policy][policy] for just that should be. There is a lot of pressure to add more-and-more to these x-packages, which is just not a scalable possibility for the Go team to keep up with. On the flip-side, folks in the community want a space to locate de-facto implementations or interfaces of "foundational packages" (e.g., A/V or image codecs).

I imagine a compromise will be reached that relieves the core team from being buried in sub-repos while also elevating high-quality packages (hopefully under a unified import). Regardless of how that proposal shakes out, though, it's definitely worth diving into these sub-repos.

### What will be covered?

This series will focus on the top-level sub-repositories as reported by [build.golang.org][build]. Some of these packages are light enough to cover in a single post (like [`golang.org/x/time/rate`][rate]), while others will be split into multiple to better accomodate them. CLI tools and their corresponding library packages will be covered together. The order I do this will be primarily driven by interest, so if you'd like me to cover one in particular, let me know!

Without further ado, the series so far:

{{< x-files >}}

[boring]:   https://www.youtube.com/watch?v=4Dr8FXs9aJM
[build]:    https://build.golang.org/
[compat]:   https://golang.org/doc/go1compat
[move]:     https://groups.google.com/forum/#!msg/golang-nuts/eD8dh3T9yyA/l5Ail-xfMiAJ
[net]:      https://godoc.org/golang.org/x/net
[policy]:   https://github.com/golang/go/issues/17244
[subrepos]: https://godoc.org/-/subrepo
[text]:     https://godoc.org/golang.org/x/text
[rate]:     https://godoc.org/golang.org/x/time/rate
