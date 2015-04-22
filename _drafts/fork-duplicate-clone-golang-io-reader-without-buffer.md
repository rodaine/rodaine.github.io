---
layout: post
title: Asynchronously Split an io.Reader in Go (golang)
description: Or the many ways to skin a cat — er — stream
keywords: "go, golang, io.Reader, io.Pipe, io.TeeReader, io.MultiWriter, async, asynchronous"
published: true
---

Experimenting with Go, the simplicity and interoperability of the standard library's APIs impressed me. Particularly, I fell in love with the ubiquity of [`io.Reader`][reader] and [`io.Writer`][writer] when dealing with practically any stream of data. And while I am more or less smitten at this point, the reader interface challenged me with something I thought would be simple: splitting it in two.

## The Situation ##

Suppose you have a web service that allows a user to upload a file. Ultimately, this file will be stored up on "the cloud", but first you need to process it a bit. All you have to work with is the `io.Reader` from the incoming request.

## The Solutions ##

There is not one way to go about solving this problem, of course. Depending on the types of files, throughput of the service and the kinds of processing required, some options are more practical than others. Below, I lay out five different methods of varying complexity and flexibility. I imagine there are many more, but these are a hopefully a good starting point.

### Solution #1: The Simple `bytes.Buffer` ###

To begin, you can pump the reader into a [`bytes.Buffer`][buffer] using [`Buffer#ReadFrom`][readFrom], and have at it:

GIST

If the data is small enough, this might be the most convenient option. But suppose the file is large, such as a video or a 22 megapixel RAW photo. These behemoths will chew through your memory rapidly, especially if the service is high-traffic.

**Pro's**: Probably the simplest solution.<br/>
**Con's**: Not prudent if you are expecting many or large files.

### Solution #2: The Reliable File System ###

OK, then how about you pump the data into a file on disk (a'la [`ioutil.WriteFile`][writeFile]) and avoid the penalties of storing it in RAM?

GIST

If the final destination of that file is on the server's file system, then this is probably your best choice, but let's assume the upload is headed for the cloud. Again, if the files are large, the IO costs here would be noticeable. As well, a popular service would be chewing through your disk space. You also run the risk of bugs or crashes orphaning a file on the machine.

**Pro's**: Keeps the whole file out of RAM.<br/>
**Con's**: Lot's of IO and disk space potentially, and orphaned data.

### Solution #3: The Duct-Tape `io.MultiReader` ###

In some cases, the metadata you need exists in the first handful of bytes of the file. For instance, identifying a file as a JPEG only requires checking that the first two bytes of the file are `0xFF 0xD8`. This can be handled synchronously using a [`io.MultiReader`][multiReader], which glues together a set of readers sequentially as if they were one. Here's our JPEG example:

<aside>It is not categorically true that a file beginning with those two bytes is a valid JPEG, but for the most part it's sufficient. If you're curious, the exiv2 team has documented the <a href="http://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files">metadata structure of the JPEG format</a>.</aside>

GIST

This is a great technique if you intend to gate the upload to only JPEG files. With only two bytes, you can cancel the transfer without entirely reading it into memory or writing it to disk. As you might expect, this method falters in situations where you need to read in more than a little bit of the file to gather the data, such as calculating a word count across the it. And while efficient for quick activities, having this process blocking the upload may not be ideal for longer running tasks. And finally, most 3rd-party (and the majority of the standard library) packages entirely consume a reader, preventing you from using a `io.MultiReader` in this way.

**Pro's**: Quick and dirty reads off the top of a file, can be used as a gate.<br/>
**Con's**: Doesn't work for unknown length readers, processing the whole file, long blocking tasks, or with most 3rd party packages.

### Solution #4: The Single-Split `io.TeeReader` and `io.Pipe` ###

Back to our scenario of a large video file, let's change the story a bit. Your users will upload the video in a single format, but you want your service to be able to display those videos in a couple of different formats for compatibility and performance reasons depending on the client. You have a 3rd-party transcoder that can take in an `io.Reader` of (say) MP4 encoded data and return another reader of WebM data. You want the original MP4 and the WebM versions to be uploaded to the cloud together. The previous solutions must perform these steps synchronously and with overhead; let's find a way to do it all in parallel.

Let's take a look at [`io.TeeReader`][teeReader], which has the following signature: `func TeeReader(r Reader, w Writer) Reader`. The docs say "TeeReader returns a Reader that writes to w what it reads from r." This is *exactly* what we want! Now how do we get the data written into *w* to be readable? This is where [`io.Pipe`][pipe] comes into play. This function returns a connected `io.PipeReader` and `io.PipeWriter` that are directly connected (i.e., writes to the latter are immediately available in the former). Let's see it in action:

GIST

So as `tr` is consumed by the transfer to the cloud, the transcoder is receiving the same bytes via the pipe and able to process them synchronously before sending it off to storage. All without a buffer! Be aware of the use of goroutines for both pathways. Because `io.Pipe` is synchronous and blocking until both the writer and reader are being written to and read from respectively, attempting this on the main thread will give you `fatal error: all goroutines are asleep - deadlock!` We use a buffered channel to synchronize back with the main thread.

**Pro's**: Completely independent, parallelized streams of the same data!<br/>
**Con's**: Requires the added complexity of goroutines and channels to work.

### Solution #5: The Multi-Split `io.MultiWriter` and `io.Copy` ###

The `io.TeeReader` solution works great when only one other consumer of the stream exists. As more and more tasks are parallelized though (e.g., more transcoding), teeing off of tees becomes gross. Enter the [`io.MultiWriter`][multiWriter], which returns "a writer that duplicates its writes to all provided writers." We will use pipes like in the previous solution to propagate the data, but instead of using a TeeReader to split it, you can instead use [`io.Copy`][copy], which does exactly that:

GIST

This is more or less analogous with the previous method, but noticeably cleaner when the stream needs multiple clones. Because of the pipes, you'll again require goroutines and synchronizing channels to avoid the deadlock.

**Pro's**: Can make as many forks of the original reader as desired.<br/>
**Con's**: Even more use of goroutines and channels to coordinate.

### What About Channels? ###

Channels are one of the most unique and powerful concurrency tools Go has to offer. Serving as a bridge between goroutines, they combine communication and synchronization in one. Channels can be allocated with a buffer or without, allowing for [many creative ways to share data][channels]. So why did I not provide a solution that leverages them for more than sync?




[reader]: https://golang.org/pkg/io/#Reader
[writer]: https://golang.org/pkg/io/#Writer
[buffer]: https://golang.org/pkg/bytes/#Buffer
[readFrom]: https://golang.org/pkg/bytes/#Buffer.ReadFrom
[writeFile]: https://golang.org/pkg/io/ioutil/#WriteFile
[multiReader]: https://golang.org/pkg/io/#MultiReader
[teeReader]: https://golang.org/pkg/io/#TeeReader
[pipe]: https://golang.org/pkg/io/#Pipe
[chan]: https://golang.org/ref/mem#tmp_7
[multiWriter]: https://golang.org/pkg/io/#MultiWriter
[copy]: https://golang.org/pkg/io/#Copy
[channels]: https://golang.org/doc/effective_go.html#channels
