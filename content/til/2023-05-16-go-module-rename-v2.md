---
title: Go Module Rename & V2 Release
---

Today, I'm working on a project that intends to both rename a Go module and cut a v2 release (all while keeping `main` as the default branch). Why do both? Essentially rebranding without losing existing links.

In any case, before attempting this level of shenanigans, I wanted to make sure that it worked (spoiler alert: it did). Below are the steps I followed that got me there using a dummy repository:

1. **Have existing module at some v1.x.x release.**

    I waited until [pkg.go.dev](https://pkg.go.dev) picked up the changes to be sure, but this could also be verified by querying the [Go module proxy][goproxy]:

   ```shell
   $ curl https://proxy.golang.org/github.com/rodaine/modulemagic@v/list
   v1.0.0
   v1.0.1
   ```

1. **Cut a `v1` branch off `main`**

   For support reasons, we intend to still maintain the `v1.x.x` releases for any sort of bug fixes and the like, just not new features. Splitting the trunk to a `v1` branch allows that git history to continue. Tags are independent of branches and are tied directly to a commit so this is free and has no impact on the Go module.

   To be on the safe side, I also set up GitHub [branch protections][branch-protection] on both `main` and `v1` to make sure these branches aren't accidentally damaged. GitHub (blessedly) remembers everything, so recovery is always possible, but better to avoid that kind of "oh, s#!%" moment if you can. There's also a beta for something called [repository rulesets][repo-rulesets] which lets you protect a pattern of tags or branches with similar rules provided by the branch protections. Worth checking that out as well. Don't want someone accidentally removing or changing a tag. 

1. **Create `v2` in a new branch off `main`**

   This is a temporary `v2` branch for the new code, so in case we have issues getting everything squared away, `main` hasn't (yet) been polluted. Here we replace the `go.mod` import path with the new module name suffixed with "/v2", and update the code accordingly. At this point, make sure CI is still functional. 
   
   I would _not_ tag the `v2.0.0` release on this branch. To avoid rebase/merge situations, we only want to add tags to commits on `main` (or, for legacy support, on `v1`). Unless we get lucky with a fast-forward, tags changing references will potentially misalign with `go.mod.sum` and cause a world of hurt downstream.

1. **Rename, merge & release `v2.0.0`**

   Once satisfied with the code, use the GitHub repository settings UI to rename the repo to the new desired module name. GitHub automatically maintains redirects from the old name to the new one. Pleasantly, it maintains redirects for the entire name history of a repository. (This will be the third rename of this repository, and I **strongly** don't recommend ever having to do this if you can avoid it.) 
   
   Merge the `v2` branch into `main`, and tag the `HEAD` commit as `v2.0.0`. You can once again verify this on the module proxy:

   ```shell
   $ curl https://proxy.golang.org/github.com/rodaine/renamedmodule/v2/@v/list
   v2.0.0
   ```

1. **Revel in your Go module chicanery**

   🎉 ~ Despite the two modules being collocated in the same repository, `go get` blocks fetching the original module as `v2` and the new module as `v1` due to the name mismatch in the `go.mod` files. [pkg.go.dev](https://pkg.go.dev) takes its sweet time updating, but will eventually resolve the new module.


[branch-protection]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches
[repo-rulesets]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
[goproxy]: https://go.dev/ref/mod#goproxy-protocol