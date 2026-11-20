# Describe where a version of the package comes from

These constructors only describe a source. Nothing is downloaded,
exported or built until
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md),
which says what it fetches and where.

## Usage

``` r
cran_release(repos = NULL)

cran_version(version, repos = NULL)

installed_version(lib = NULL, repos = NULL)

tarball(path)

git_ref(repo, ref = "HEAD", subdir = NULL)

local_path(path)
```

## Arguments

- repos:

  CRAN mirror. Defaults to the `CRAN` entry of `getOption("repos")`, or
  the cloud mirror when that is unset.

- version:

  Version string, for example `"0.2.1"`.

- lib:

  Library to look in for `installed_version()`; defaults to
  [`.libPaths()`](https://rdrr.io/r/base/libPaths.html), searched in
  order as [`library()`](https://rdrr.io/r/base/library.html) does.

- path:

  Path to a tarball (`tarball()`) or a package folder (`local_path()`).

- repo:

  Path to a git repository.

- ref:

  Git ref: a branch, tag or commit. Only committed content is exported.

- subdir:

  Folder of the package inside the repository, if it is not the root.

## Value

An object of class `pkgdossier_source`.

## Details

- `cran_release()`: the version on CRAN now.

- `cran_version()`: a given CRAN version, current or archived.

- `installed_version()`: the version installed in your library, fetched
  as source from CRAN (or its archive) by
  [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md):
  what you have now, to compare with `cran_release()` before upgrading.
  The installed copy itself is never used, as both versions are built
  from source the same way. A version that did not come from CRAN (a
  development version from GitHub or R-universe) stops with what to
  write instead, as does a package that is not installed; with
  `candidate = cran_release()`, so does an installed version that is
  already the current release.

- `tarball()`: a source tarball on disk (for example one downloaded from
  CRAN earlier).

- `git_ref()`: a commit, branch or tag of a git repository, exported
  with `git archive` and built with `R CMD build` inside the work
  folder, never in the repository.

- `local_path()`: a package source folder, built with `R CMD build`
  (which builds from a copy, so nothing is written into the folder).

## Examples

``` r
cran_version("0.2.1")
#> <pkgdossier source> CRAN version 0.2.1
# what changes for you if you upgrade: describing reads nothing yet
dossier("ggplot2", base = installed_version(), candidate = cran_release())
#> <pkgdossier dossier> ggplot2
#>   base:      the installed version, from CRAN
#>   candidate: CRAN release (current)
#>   scenarios: baseline vignettes; baseline help-page examples
#>   runs:      abba, 3 timed repeats per timed step, seed 20261027 set per step
#>   capture:   width 80, 100 dpi, LANGUAGE en
#>   collect:   default caps; default skipped classes
#>   deps:      shared, from the current library paths
#>   work:      /tmp/RtmpP91dCr/pkgdossier-ggplot2
git_ref("path/to/MAIHDA", "main")
#> <pkgdossier source> git path/to/MAIHDA @ main
```
