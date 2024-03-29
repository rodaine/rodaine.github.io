---
title: Asynchronously Split an io.Reader in Go (golang)
description: Or the many ways to skin a cat — er — stream
keywords: "go, golang, io, stream, async, concurrent, parallel"
---

I have fallen in love with the flexibility of [`io.Reader`][reader] and [`io.Writer`][writer] when dealing with any stream of data in Go. And while I am more or less smitten at this point, the reader interface challenged me with something you might think simple: splitting it in two.

I'm not even certain "split" is the right word. I would like to receive an `io.Reader` and read over it multiple times, possibly in parallel. But because readers don't necessarily expose the `Seek` method to reset them, I need a way to duplicate it. Or would that be clone it? Fork?!

### The Situation

Suppose you have a web service that allows a user to upload a file. The service will store the file on "the cloud", but first it needs a bit of processing. All you have to work with is the `io.Reader` from the incoming request.

### The Solutions

There is not one way to go about solving this problem, of course. Depending on the types of files, throughput of the service and the kinds of processing required, some options are more practical than others. Below, I lay out five different methods of varying complexity and flexibility. I imagine there are many more, but these are a good starting point.

#### Solution #1: The Simple `bytes.Reader`

If the source reader doesn't have a `Seek` method, then why not make one? You can pump the input into a [`bytes.Reader`][bytes] and rewind it as many times as you like:

```go
func handleUpload(u io.Reader) (err error) {
  // capture all bytes from upload
  b, err := ioutil.ReadAll(u)
  if err != nil {
    return
  }

  // wrap the bytes in a ReadSeeker
  r := bytes.NewReader(b)

  // process the metadata
  err = processMetadata(r)
  if err != nil {
    return
  }

  // rewind the reader back to the start
  r.Seek(0, 0)

  // upload the data
  err = uploadFile(r)
  if err != nil {
    return
  }

  return nil
}
```

If the data is small enough, this might be the most convenient option; you could forgo the `bytes.Reader` altogether and work off the byte slice instead. But suppose the file is large, such as a video or RAW photo. These behemoths will chew through memory, especially if the service is high-traffic. Not to mention, you cannot perform these actions in parallel.

**Pro's**: Probably the simplest solution.  
**Con's**: Synchronous and not prudent if you expect many or large files.

#### Solution #2: The Reliable File System

OK, then how about you drop the data into a file on disk (a'la [`ioutil.TempFile`][tempFile]) and skip the penalties of storing it in RAM?

```go
func handleUpload(u io.Reader) (err error) {
  // create a temporary file for the upload
  f, err := ioutil.TempFile("", "upload")
  if err != nil {
    return
  }

  // destroy the file once done
  defer func() {
    n := f.Name()
    f.Close()
    os.Remove(n)
  }()

  // transfer the bytes to the file
  _, err = io.Copy(f, u)
  if err != nil {
    return
  }

  // rewind the file
  f.Seek(0, 0)

  // process the metadata
  err = processMetadata(f)
  if err != nil {
    return
  }

  // rewind the file again
  f.Seek(0, 0)

  // upload the file
  err = uploadFile(f)
  if err != nil {
    return
  }

  return nil
}
```

If the final destination is on the service's file system, then this is probably your best choice (albeit with a real file), but let's assume it will end up on the cloud. Again, if the files are large, the IO costs here could be noticeable and unnecessary. You run the risk of bugs or crashes orphaning files on the machine, and I also wouldn't recommend this if the data is sensitive in any way.

**Pro's**: Keeps the whole file out of RAM.  
**Con's**: Still synchronous, potential for lots of IO, disk space, and orphaned data.

#### Solution #3: The Duct-Tape `io.MultiReader`

In some cases, the metadata you need exists in the first handful of bytes of the file. Identifying a file as a JPEG, for instance, only requires checking that the first two bytes are `0xFF 0xD8`.[^pedantic-jpeg] This can be handled synchronously using a [`io.MultiReader`][multiReader], which glues together a set of readers as if they were one. Here's our JPEG example:

[^pedantic-jpeg]: It is not categorically true that a file beginning with those two bytes is a valid JPEG, but for the most part it's enough. If you're curious, the exiv2 team has documented the [metadata structure of the JPEG format](http://dev.exiv2.org/projects/exiv2/wiki/The_Metadata_in_JPEG_files).

```go
func handleUpload(u io.Reader) (err error) {
  // read in the first two bytes
  b := make([]byte, 2)
  _, err = u.Read(b)
  if err != nil {
    return
  }

  // check that they match the JPEG header
  jpg := []byte{0xFF, 0xD8}
  if !bytes.Equal(b, jpg) {
    return errors.New("not a JPEG")
  }

  // glue those bytes back onto the reader
  r := io.MultiReader(bytes.NewReader(b), u)

  // upload the file
  err = uploadFile(r)
  if err != nil {
    return
  }

  return nil
}
```

This is a great technique if you intend to gate the upload to only JPEG files. With only two bytes, you can cancel the transfer without entirely reading it into memory or writing it to disk. As you might expect, this method falters in situations where you need to read in more than a little bit of the file to gather the data, such as calculating a word count across it. Having this process blocking the upload may not be ideal for intensive tasks. And finally, most 3rd-party (and the majority of the standard library) packages entirely consume a reader, preventing you from using an `io.MultiReader` in this way.

Another solution would be to use [`bufio.Reader.Peek`][peek]. It essentially performs the same operation but you can eschew the MultiReader. That, and it gives you access to some other useful methods on the reader.

**Pro's**: Quick and dirty reads off the top of a file, can act as a gate.  
**Con's**: Doesn't work for unknown-length reads, processing the whole file, intensive tasks, or with most 3rd-party packages.

#### Solution #4: The Single-Split `io.TeeReader` and `io.Pipe`

Back to our scenario of a large video file, let's change the story a bit. Your users will upload the video in a single format, but you want your service to be able to display those videos in a couple of different formats. You have a 3rd-party transcoder that can take in an `io.Reader` of (say) MP4 encoded data and return another reader of WebM data. The service will upload the original MP4 and WebM versions to the cloud. The previous solutions must perform these steps synchronously and with overhead; now, you want to do them in parallel.

Take a look at [`io.TeeReader`][teeReader], which has the following signature: `func TeeReader(r Reader, w Writer) Reader`. The docs say "TeeReader returns a Reader that writes to w what it reads from r." This is *exactly* what you want! Now how do you get the data written into *w* to be readable? This is where [`io.Pipe`][pipe] comes into play, yielding a connected `io.PipeReader` and `io.PipeWriter` (i.e., writes to the latter are immediately available in the former). Let's see it in action:

```go
func handleUpload(u io.Reader) {
  // create the pipe and tee reader
  pr, pw := io.Pipe()
  tr := io.TeeReader(u, pw)

  // create channel to synchronize
  done := make(chan bool)
  defer close(done)

  go func() {
    // close the PipeWriter after the
    // TeeReader completes to trigger EOF
    defer pw.Close()

    // upload the original MP4 data
    uploadFile(tr)

    done <- true
  }()

  go func() {
    // transcode to WebM
    webmr := transcode(pr)

    // upload to storage
    uploadFile(webmr)

    done <- true
  }()

  // wait until both are done
  for c := 0; c < 2; c++ {
    <-done
  }
}
```

As the uploader consumes `tr`, the transcoder receives and processes the same bytes before sending it off to storage. All without a buffer and in parallel! Be aware of the use of goroutines for both pathways, though. `io.Pipe` blocks until something writes *and* reads from it. Attempting this on the same thread will give you a `fatal error: all goroutines are asleep - deadlock!` panic. Another point of caution: when using pipes, you will need to explicitly trigger an EOF by closing the `io.PipeWriter` at the appropriate time. In this case, you would close it after the TeeReader has been exhausted.

This method also employs channels to communicate "doneness". If you expect a value back from these processes, you could replace the `chan bool` for a more appropriate type.

**Pro's**: Completely independent, parallelized streams of the same data!  
**Con's**: Requires the added complexity of goroutines and channels to work.

#### Solution #5: The Multi-Split `io.MultiWriter` and `io.Copy`

The `io.TeeReader` solution works great when only one other consumer of the stream exists. As the service parallelizes more tasks (e.g., more transcoding), teeing off of tees becomes gross. Enter the [`io.MultiWriter`][multiWriter]: "a writer that duplicates its writes to all provided writers." This method utilizes pipes like in the previous solution to propagate the data, but instead of a TeeReader, you can use [`io.Copy`][copy] to split the data across all the pipes:

```go
func handleUpload(u io.Reader) {
  // create the pipes
  mp4R, mp4W := io.Pipe()
  webmR, webmW := io.Pipe()
  oggR, oggW := io.Pipe()
  wavR, wavW := io.Pipe()

  // create channel to synchronize
  done := make(chan bool)
  defer close(done)

  // spawn all the task goroutines. These look identical to
  // the TeeReader example, but pulled out into separate
  // methods for clarity
  go uploadMP4(mp4R, done)
  go transcodeAndUploadWebM(webmR, done)
  go transcodeAndUploadOgg(oggR, done)
  go transcodeAndUploadWav(wavR, done)

  go func() {
    // after completing the copy, we need to close
    // the PipeWriters to propagate the EOF to all
    // PipeReaders to avoid deadlock
    defer mp4W.Close()
    defer webmW.Close()
    defer oggW.Close()
    defer wavW.Close()

    // build the multiwriter for all the pipes
    mw := io.MultiWriter(mp4W, webmW, oggW, wavW)

    // copy the data into the multiwriter
    io.Copy(mw, u)
  }()

  // wait until all are done
  for c := 0; c < 4; c++ {
    <-done
  }
}
```

This is more or less analogous with the previous method, but noticeably cleaner when the stream needs multiple clones. Because of the pipes, you'll again require goroutines and synchronizing channels to avoid the deadlock. We defer closing all the pipes until the copy is complete.

**Pro's**: Can make as many forks of the original reader as desired.  
**Con's**: Even more use of goroutines and channels to coordinate.

### What About Channels?

Channels are one of the most unique and powerful concurrency tools Go has to offer. Serving as a bridge between goroutines, they combine communication and synchronization in one. You can allocate a channel with or without a buffer, allowing for [many creative ways to share data][channels]. So why did I not provide a solution that leverages them for more than sync?

Looking through the top-level packages of the standard library, channels rarely appear in function signatures:

* `time`: useful for a [`select` with timeout][chanTimeout]
* `reflect`: … 'cause reflection
* `fmt`: for formatting it as a pointer
* `builtin`: exposes the `close` function

The implementation of [`io.Pipe`][pipeSrc] forgoes a channel in favor of `sync.Mutex` to move data safely between the reader and writer. My suspicion is that channels are just not as performant, and presumably mutexes prevail for this reason.

When developing a reusable package, I'd avoid channels in my public API to be consistent with the standard library but maybe use them internally for synchronization. If the complexity is low enough, replacing them with mutexes may even be ideal. That said, within an application, channels are wonderful abstractions, easier to grok than locks and more flexible.

### Wrapping Up

I've only broached a handful of ways to go about processing the data coming from an `io.Reader`, and without a doubt there are plenty more. Go's implicit interface model plus the standard library's heavy use of them permits many creative ways of gluing together various components without having to worry about the source of the data. I hope some of the exploration I've done here will prove as useful for you as it did for me!

### Errata (Updated: 2017-05-22)

Jamie Talbot kindly pointed out in the comments that [solutions #4 and #5 would panic if one of the concurrent goroutines produced an error][panic]. That's certainly not the intended effect here, especially considering the primary focus is on tee-ing an `io.Reader`. I've since removed the error handling from those examples and will perhaps write up an article at a later date regarding handling errors from concurrent tasks. Thanks again, Jamie!

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
[tempFile]: https://golang.org/pkg/io/ioutil/#TempFile
[writer]: https://golang.org/pkg/io/#Writer
[panic]: https://disqus.com/home/discussion/rodaine/asynchronously_split_an_ioreader_in_go_golang_rodaine_51/#comment-3170239653
