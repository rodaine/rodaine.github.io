---
layout: post
title: Asynchronously Split an io.Reader in Go (golang)
description: Or how to work with the same stream without a buffer
keywords: "go, golang, io.Reader, io.Pipe, io.TeeReader, io.MultiWriter, async, asynchronous"
published: true
---

Experimenting with Go, the simplicity and interoperability of the standard library's APIs impressed me. Particularly, I fell in love with the ubiquity of [`io.Reader`][reader] and [`io.Writer`][writer] when dealing with practically any stream of data. And while I am more or less smitten at this point, the `io.Reader` interface challenged me with something I thought would be simple: splitting a reader in two.

## The situation ##

Suppose you have a web server that allows a user to upload a file. Ultimately, this file will be stored up on S3, but first you need to pull some metadata from the upload as well. All you have to work with is the `io.Reader` from the request.

### Solution 1: Buffer ###

You could just pump the reader into a [`bytes.Buffer`][buffer] using [`Buffer#ReadFrom`][readFrom], and then you can do anything with it. If the data is small enough, this might be the most convenient option. But suppose the file is large, such as a video or a 22 megapixel RAW photo. Chewing up that much memory will likely cause more problems, and if this web service is high-traffic, you'll run out of room quick.

**Pro's**: Probably the simplest solution.<br/>
**Con's**: Not prudent if you are expecting many or large files.

### Solution 2: On Disk ###

OK, then how about you pump the data into a file on disk (a'la [`ioutil.WriteFile`][writeFile]) and avoid the penalties of storing it in RAM? If the final destination of that file is on the server's file system, then this is probably your best choice, but let's assume the upload is headed for the cloud. Again, if the files are large, the IO costs here would be noticeable. As well, a popular service would be chewing through your disk space. You also run the risk of bugs or crashes orphaning a file on the machine.

**Pro's**: Keeps the whole file out of RAM.<br/>
**Con's**: Lot's of IO and disk space potentially, and orphaned data

### Solution 3: The "Duct-Tape" `io.MultiReader` ###

In some cases, the metadata you need exists in the first handful of bytes of the file. For instance, identifying a file as a JPEG only requires checking that the first two bytes of the file are `0xFF 0xD8`. This can be handled synchronously using a [`io.MultiReader`][multiReader], which glues together a set of readers sequentially as if they were one. Here's our JPEG example:

<aside>It is not categorically true that a file beginning with those two bytes is a valid JPEG, but for the most part it's sufficient. If you're curious, the exiv2 team has documented the <a href="http://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files">metadata structure of the JPEGs</a>.</aside>

GIST

This is a great technique if you intend to gate the upload to only JPEG files. With only two bytes, you can cancel the transfer without entirely reading it into memory or writing it to disk. As you might expect, this method falters in situations where you need to read in more than a little bit of the file to gather the data, such as calculating a word count across the it. And while efficient for quick activities, having this process blocking the upload may not be ideal for longer running tasks. And finally, most 3rd-party (and the majority of the standard library) packages entirely consume a reader, preventing you from using a `io.MultiReader` in this way.

**Pro's**: Quick and dirty reads off the top of a file, can be used as a gate.<br/>
**Con's**: Doesn't work for unknown length readers, processing the whole file, long blocking tasks, or with most 3rd party packages

### Solution 3: The Single-Split `io.TeeReader` and `io.Pipe` ###

Back to our scenario of a large video file, let's change the story a bit. Your users will upload the video in a single format, but you want your service to be able to display those videos in a couple of different formats for compatibility and performance reasons depending on the client. You have a 3rd-party transcoder that can take in an `io.Reader` of (say) MP4 encoded data and return another reader of WebM data. You want the original MP4 and the WebM versions to be uploaded to the cloud together. The previous solutions must perform these steps synchronously with some extra overhead; let's find a way to do them in parallel.



<!-- Now what exactly do I mean by "splitting in two"? **Given an `io.Reader` *r*, I'd like to split *r* into reader *s* that can `Read` in the same data as *r* at the same time.**  -->

[reader]: https://golang.org/pkg/io/#Reader
[writer]: https://golang.org/pkg/io/#Writer
[buffer]: https://golang.org/pkg/bytes/#Buffer
[readFrom]: https://golang.org/pkg/bytes/#Buffer.ReadFrom
[writeFile]: https://golang.org/pkg/io/ioutil/#WriteFile
[multiReader]: https://golang.org/pkg/io/#MultiReader