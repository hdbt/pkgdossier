# Where the dependencies come from

The `deps` argument of
[`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md)
says which versions of the package's dependencies both versions install
and run against.

## Usage

``` r
deps_shared()

deps_cran(repos = NULL)

deps_snapshot(date = NULL, repos = NULL)
```

## Arguments

- repos:

  Repository to install from. `deps_cran()` defaults to the `CRAN` entry
  of `getOption("repos")`, or the cloud mirror; `deps_snapshot()` to the
  dated Posit Package Manager URL. A given repository is used as is; for
  `deps_snapshot()`, versions that do not build are then taken from the
  same URL with `latest` in place of its date, and a URL without a date
  has no such fallback.

- date:

  The snapshot's date (`"2025-06-10"`, or a `Date`), overriding the
  baseline's release date. Set it for a baseline built here (a git ref
  or a folder), whose packaging date is today.

## Value

An object of class `pkgdossier_deps`.

## Details

- `deps_shared()`: the dependencies in the current library paths, so
  differences come from the package alone.

- `deps_cran()`: the current CRAN versions of every dependency of both
  versions (Depends, Imports and LinkingTo, recursively) are installed
  into a library in the work folder, as a new user installing today
  would get them.
  [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
  installs them, and reinstalls one when the repository has a newer
  version.

- `deps_snapshot()`: the versions CRAN had on the baseline's release
  date (its `Date/Publication`, else the day it was packaged, or
  `date`), from Posit Package Manager's dated snapshots, installed the
  same way. Differences then come from the package's own changes rather
  than from changes in its dependencies since its release; a baseline
  that fails with today's dependencies (a removed function, a changed C
  interface) runs as its users had it. A candidate that needs newer
  dependencies than the snapshot has stops with a clear message. A
  snapshot older than the R running it can hold versions that no longer
  build (R removes C entry points over time); those are installed at
  their current version, and
  [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
  and `versions.json` (`newer_than_snapshot`) say which. For a faithful
  snapshot, run on an R from the baseline's time.

With `deps_cran()` and `deps_snapshot()`, R's base and recommended
packages are used as installed, and packages the scenarios use that are
not dependencies (a vignette's suggested packages) come from the current
library paths. Their libraries in the work folder are kept per R minor
version (`lib-deps-R4.6`, `lib-deps-2025-06-10-R4.6`), so the same work
folder used under another R installs them afresh.

## Examples

``` r
deps_shared()
#> <pkgdossier deps> shared, from the current library paths
deps_cran()
#> <pkgdossier deps> current CRAN versions, in the work folder
deps_snapshot("2025-06-10")
#> <pkgdossier deps> CRAN as on 2025-06-10, in the work folder
```
