---
title: Static vs Dynamic Linking in Go
---

Ran into some linking weirdness with a couple of Go binaries from a seemingly innocuous change. Suppose you have some code that depends on some C bindings. The simplest such program would be:

```go
package main

import "C"

func main() { /* … */ }
```

Building this on linux/amd64, you get a dynamically-linked binary:

```bash
$ go build -o my.bin

$ file my.bin
my.bin: … , dynamically linked, …
```

To make this static, you can tell `go build` to pass the right flags to the C linker:

```bash
$ go build -o my.bin -ldflags="-extldflags=-static"

$ file my.bin
my.bin:  … , statically linked, …
```

Sweet. Time passes and you pick up a dependency on, say, the `net` standard library package:

```go {hl_lines=[5]}
package main

import "C"

import _ "net"

func main() { /* … */ }
```

Upon building, you might see a new warning appear, or you might not. But the binary will still be static:

```bash
$ go build -o my.bin -ldflags="-extldflags=-static"
# a big warning about 'getaddrinfo'

$ file my.bin
my.bin:  … , statically linked, …
```

The new warning seems to imply `net` uses some libraries that are particularly cranky about being statically linked. Oh, well, at least we've still got our standalone, static binary.

Now, Mercury is finally in retrograde, and the stars align, allowing the removal of that pesky C FFI:

```go
package main

import _ "net"

func main() { /* … */ }
```

But when you go to build, something weird happens:

```bash
$ go build -o my.bin -ldflags="-extldflags=-static"

$ file my.bin
my.bin: … , dynamically linked, …
```

Gah! How'd we get back to it being dynamic? The linker flag is still set, but it's not being respected. What gives?

## Internal vs. External Linker

Digging into the [somewhat-hidden docs][docs] on the go link command, by default, the linker used by the compiler checks which packages require cgo, then compares it to a list of [allowed] internal packages. If the binary's cgo dependencies are _only_ from those stdlib packages, then it uses its internal linker … _which ignores the `extldflags` altogether!_

<aside>Oddly, some of the allowed internal packages don't appear to have any cgo dependencies. Perhaps their presence is vestigial, that list hasn't changed much since the compiler was bootstrapped in Go.</aside>

I mean, it's not terribly surprising, given the `ext` prefix. Any other cgo dependencies trigger the use of the external host's linker (typically `clang` or `gcc`) that does respect it.

So how can we ensure that a Go program will _always_ be statically-linked? The answer is a bit messy.

### Solution #1: Disable cgo

If your application (and transitively its dependencies) do not need cgo, build with `CGO_ENABLED=0`. This will also disable any compilation of cgo-dependent source code in the standard lib packages that use it, falling back to a Go implementation.

```bash
$ CGO_ENABLED=0 go build -o disabled-cgo.bin

$ file disabled-cgo.bin
disabled-cgo.bin:  … , statically linked, …
```

### Solution #2: Opt-Out with Build Tags

The stdlib packages that use cgo typically have a build tag which makes the compiler ignore those bits. `-tags netgo` will work in our contrived case above.

```bash
$ go build -o opt-out.bin -tags netgo

$ file opt-out.bin
opt-out.bin:  … , statically linked, …
```

This is not universal across the [allowed] list, so check those package's docs.

If you _do_ have cgo dependencies, this plays nicely with the `extldflags` to annihilate those errors:

```bash
$ go build -o opt-out-cgo.bin -tags netgo -ldflags="-extldflags=-static"
# look, no more warnings!

$ file opt-out-cgo.bin
opt-out-cgo.bin:  … , statically linked, …
```

### Solution #3: Always Use the External Linker

Finally, the most ham-fisted approach is to always use the external linker. You can do this by slipping an `import "C"` into your main package, or by specifying the `linkmode`:

```bash
$ go build -o always-external.bin -ldflags="-extldflags=-static -linkmode=external"
# that warning is back again!

$ file always-external.bin
always-external.bin: … , statically linked, …
```

Ew. Allegedly, the external linker will always be slower than the internal one. This less-than-toy example here doesn't quite stress either enough to be appreciable with `time`. I'd stay away from this nuclear option unless everything else fails.

---

[Statically compiling Go] is not a new topic for discussion by any means. Nor is certain standard lib packages' dependency on cgo. What I think was missing from a lot of the posts about the topic is the specifics about _how_ the linker is chosen, and the role it plays in all these interactions.

[docs]: https://github.com/golang/go/blob/30c1887/src/cmd/cgo/doc.go#L999-L1023
[allowed]: https://github.com/golang/go/blob/30c1887/src/cmd/link/internal/ld/lib.go#L1013-L1020
[Statically compiling Go]: https://www.arp242.net/static-go.html