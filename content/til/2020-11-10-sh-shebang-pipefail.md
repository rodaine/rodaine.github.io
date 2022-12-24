---
title: A sh, shebang, and pipefail fail
---

It could be argued this falls squarely under <abbr title="Read The Fucking Manual">RTFM</abbr>, but in any case this was a bit of a wild ride.

At work, we have a piece of software that receives a shell script via an API and executes it. Simple enough. The script looked something like this:

```bash
#!/usr/bin/env bash
set -eu
# do some real work
echo "done!"
```

I needed to do some refactoring in that script. Mostly out of habit, I also added the `pipefail` option alongside my changes.

<aside><code>pipefail</code>, for the uninitiated, prevents errors in a pipeline from being ignored. Without it, only the exit code of the last command in the pipeline is returned.</aside>

```bash {hl_lines=[2]}
#!/usr/bin/env bash
set -euo pipefail
# do some real work
echo "done!"
```

Innocuous enough. However, about 30min later, I get notified the script failed with:

```txt
set: Illegal option -o pipefail
```

That's rude. Never in all my years of slinging bash have I seen this. A quick search had me second guessing myself: all responses said "you're not actually using bash." OK, then _what_ am I using?

Looking through the executing code:

```go
err := ioutil.WriteFile(path, content, 0600)
```

Uhm, how are we executing this if it's not even executa&mdash;

```go
cmd := exec.Command("/bin/sh", path)
output, err := cmd.CombinedOutput()
```

&mdash;oh.

Of course, when I run `/bin/sh my_script.sh` locally on my Mac it just works! What gives? Popping open `man sh`:

> sh is a POSIX-compliant command interpreter (shell).  It is implemented by re-execing as either bash(1), dash(1), or zsh(1) as determined by the symbolic link located at /private/var/select/sh.

Checking out that symlink:

```sh
$ readlink /private/var/select/sh
/bin/bash
```

Well, that explains why it works locally. Now what about on the actual environment the script is typically executed (Ubuntu)? `man sh` actually pops up the docs for [dash(1)]! Sure enough:

```sh
$ readlink /bin/sh
dash
```

<aside>Apparently in Ubuntu 6.10, the default system shell was <a href="https://wiki.ubuntu.com/DashAsBinSh">changed</a> to dash (a good five years before I had even opened a terminal in earnest).</aside>

dash is a pared-down version of bash. And one of its casualities was the `pipefail` option. I suppose I never noticed because normally I'd create executable scripts with the appropriate shebang and `chmod +x`. Yet, even if the script file was written out as executable in the Go code above, calling it with sh (or dash, or bash) still ignores the shebang entirely.

I'd say this was a good teachable moment for me:

- The shebang only matters if the script has the executable flag and is, well, executed. Otherwise, it's just a comment.

- When running a script with sh, limit code to POSIX-only or, even more strictly, Bourne shell-only features since there's no guarantee what sh is actually pointing at. This is good for portability, but pretty limiting if you don't need it.

[dash(1)]: https://linux.die.net/man/1/dash