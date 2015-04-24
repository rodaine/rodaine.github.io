---
layout: post
title: Asynchronously Split an io.Reader in Go (golang)
description: Or the many ways to skin a cat — er — stream
keywords: "go, golang, io.Reader, io.Pipe, io.TeeReader, io.MultiWriter, async, asynchronous, concurrent"
---

The simplicity and interoperability of the Go standard library's APIs impressed me. Particularly, I fell in love with the ubiquity of [`io.Reader`][reader] and [`io.Writer`][writer] when dealing with any stream of data. And while I am more or less smitten at this point, the reader interface challenged me with something simple: splitting it in two.

## The Situation ##

Suppose you have a web service that allows a user to upload a file. The service will store the file on "the cloud", but first it needs a bit of processing. All you have to work with is the `io.Reader` from the incoming request.

## The Solutions ##

There is not one way to go about solving this problem, of course. Depending on the types of files, throughput of the service and the kinds of processing required, some options are more practical than others. Below, I lay out five different methods of varying complexity and flexibility. I imagine there are many more, but these are a good starting point.

### Solution #1: The Simple `bytes.Buffer` ###

To begin, you can pump the reader into a [`bytes.Reader`][bytes] and have at it:

GIST

If the data is small enough, this might be the most convenient option. But suppose the file is large, such as a video or a 22 megapixel RAW photo. These behemoths will chew through your memory, especially if the service is high-traffic.

**Pro's**: Probably the simplest solution.<br/>
**Con's**: Not prudent if you expect many or large files.

### Solution #2: The Reliable File System ###

OK, then how about you pump the data into a file on disk (a'la [`ioutil.WriteFile`][writeFile]) and avoid the penalties of storing it in RAM?

GIST

If the final destination is on the server's file system, then this is probably your best choice, but let's assume it will end up on the cloud. Again, if the files are large, the IO costs here could be noticeable. As well, a popular service could gobble up your disk space. You also run the risk of bugs or crashes orphaning files on the machine.

**Pro's**: Keeps the whole file out of RAM.<br/>
**Con's**: Potential for lots of IO, disk space, and orphaned data.

### Solution #3: The Duct-Tape `io.MultiReader` ###

In some cases, the metadata you need exists in the first handful of bytes of the file. For instance, identifying a file as a JPEG only requires checking that the first two bytes of the file are `0xFF 0xD8`. This can be handled synchronously using a [`io.MultiReader`][multiReader], which glues together a set of readers as if they were one. Here's our JPEG example:

<aside>It is not categorically true that a file beginning with those two bytes is a valid JPEG, but for the most part it's enough. If you're curious, the exiv2 team has documented the <a href="http://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files">metadata structure of the JPEG format</a>.</aside>

GIST

This is a great technique if you intend to gate the upload to only JPEG files. With only two bytes, you can cancel the transfer without entirely reading it into memory or writing it to disk. As you might expect, this method falters in situations where you need to read in more than a little bit of the file to gather the data, such as calculating a word count across the it. Having this process blocking the upload may not be ideal for longer running tasks. And finally, most 3rd-party (and the majority of the standard library) packages entirely consume a reader, preventing you from using a `io.MultiReader` in this way.

A similar solution, would be to use [`bufio.Reader.Peek`][peek]. It essentially performs the same operation but in a more elegant way. That and it gives you access to some other useful methods on the reader.

**Pro's**: Quick and dirty reads off the top of a file, can act as a gate.<br/>
**Con's**: Doesn't work for unknown length readers, processing the whole file, long blocking tasks, or with most 3rd party packages.

### Solution #4: The Single-Split `io.TeeReader` and `io.Pipe` ###

Back to our scenario of a large video file, let's change the story a bit. Your users will upload the video in a single format, but you want your service to be able to display those videos in a couple of different formats for compatibility and performance reasons depending on the client. You have a 3rd-party transcoder that can take in an `io.Reader` of (say) MP4 encoded data and return another reader of WebM data. The service will upload the original MP4 and WebM versions to the cloud. The previous solutions must perform these steps synchronously and with overhead; you want to do it in parallel.

Take a look at [`io.TeeReader`][teeReader], which has the following signature: `func TeeReader(r Reader, w Writer) Reader`. The docs say "TeeReader returns a Reader that writes to w what it reads from r." This is *exactly* what you want! Now how do you get the data written into *w* to be readable? This is where [`io.Pipe`][pipe] comes into play, yielding a connected `io.PipeReader` and `io.PipeWriter` (i.e., writes to the latter are immediately available in the former). Let's see it in action:

GIST

As the uploader consumes `tr`, the transcoder receives and processes the same bytes before sending it off to storage. All without a buffer and in parallel! Be aware of the use of goroutines for both pathways, though. `io.Pipe` blocks until something writes *and* reads from it. Attempting this on the same thread will give you a `fatal error: all goroutines are asleep - deadlock!` panic.

**Pro's**: Completely independent, parallelized streams of the same data!<br/>
**Con's**: Requires the added complexity of goroutines and channels to work well.

### Solution #5: The Multi-Split `io.MultiWriter` and `io.Copy` ###

The `io.TeeReader` solution works great when only one other consumer of the stream exists. As the service parallelizes more tasks (e.g., more transcoding), teeing off of tees becomes gross. Enter the [`io.MultiWriter`][multiWriter]: "a writer that duplicates its writes to all provided writers." This method utilizes pipes like in the previous solution to propagate the data, but instead of a TeeReader, you can instead use [`io.Copy`][copy] to do just that:

GIST

This is more or less analogous with the previous method, but noticeably cleaner when the stream needs multiple clones. Because of the pipes, you'll again require goroutines and synchronizing channels to avoid the deadlock.

**Pro's**: Can make as many forks of the original reader as desired.<br/>
**Con's**: Even more use of goroutines and channels to coordinate.

### What About Channels? ###

Channels are one of the most unique and powerful concurrency tools Go has to offer. Serving as a bridge between goroutines, they combine communication and synchronization in one. You can allocate a channel with or without a buffer, allowing for [many creative ways to share data][channels]. So why did I not provide a solution that leverages them for more than sync?

Looking through the top-level packages of the standard library, channels rarely appear in function signatures:

* `time`: useful for [a select with timeout][chanTimeout]
* `reflect`: 'cause reflection
* `fmt`: for formatting it as a pointer
* `builtin`: exposes the `close` function

The implementation of [`io.Pipe`][pipeSrc] forgoes a channel in favor of `sync.Mutex` to move data safely between the reader and writer. My suspicion is that channels are just not as performant, and presumably mutexes prevail for this reason.

When developing a reusable package, I'd avoid channels in my public API to be consistent with the standard library but maybe use them internally for synchronization. If the complexity is low enough, replacing them with mutexes may even be ideal. That said, within an application, channels are wonderful abstractions, easier to grok than locks and more flexible.

## Wrapping Up ##

I've only broached a handful of ways to go about processing the data coming from an `io.Reader`, and I can only imagine there are plenty more. Go's implicit interface model plus the standard library's heavy use of them permits many creative ways of gluing together various components without having to worry about the source of the data. I cannot begin to express how refreshing this has been, coming from the land of dynamically-typed languages and classical OOP.

Over the next few weeks I'll be working on converting a PHP API to Go, and I am excited for the challenge. I hope some of the exploration I've done here will prove as useful for you as it did for me!

[bytes]: https://golang.org/pkg/bytes/#NewReader
[chan]: https://golang.org/ref/mem#tmp_7
[channels]: https://golang.org/doc/effective_go.html#channels
[chanTimeout]: https://gobyexample.com/timeouts
[copy]: https://golang.org/pkg/io/#Copy
[multiReader]: https://golang.org/pkg/io/#MultiReader
[multiWriter]: https://golang.org/pkg/io/#MultiWriter
[peek]: https://golang.org/pkg/bufio/#Reader.Peek
[pipe]: https://golang.org/pkg/io/#Pipe
[pipeSrc]: https://golang.org/src/io/pipe.go
[reader]: https://golang.org/pkg/io/#Reader
[readFrom]: https://golang.org/pkg/bytes/#Buffer.ReadFrom
[teeReader]: https://golang.org/pkg/io/#TeeReader
[writeFile]: https://golang.org/pkg/io/ioutil/#WriteFile
[writer]: https://golang.org/pkg/io/#Writer
