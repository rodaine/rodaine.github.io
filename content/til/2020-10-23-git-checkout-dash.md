---
title: git checkout -
---

I am already familiar with `cd -`, which I use often to toggle between two directories. In zsh with `setopt AUTO_CD`, this is even shorter: `-`. Mechanically, it's pretty simple. When you `cd` into a directory, the previous directory is first set to `$OLDPWD`. A call to `cd -` swaps `$PWD` and `$OLDPWD`. Easy-peasy.

So, definitely chuffed to discover `git checkout -` toggles between branches the current and last branch! How it operates is a bit more complicated.

{{<citation title="git-checkout Documentation" url="https://git-scm.com/docs/git-checkout#Documentation/git-checkout.txt-ltbranchgt">}}
You can use the `@{-N}` syntax to refer to the N-th last branch/commit checked out using "git checkout" operation. You may also specify `-` which is synonymous to `@{-1}`.
{{</citation>}}

Git queries the reflog (.git/logs/HEAD) for the N-th last checkout and grabs that for you. This little morsel of intuitive consistentcy brought to you by a (now) 12-year-old [patch]. Thanks, @trast!

[patch]: https://github.com/git/git/commit/696acf45f9638b014c7132508de26d1a571c8a33