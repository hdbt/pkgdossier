# Fetch, build and install both versions

Installs the baseline and the candidate into their own libraries in the
work folder (`lib-base`, `lib-cand`), byte-compiled from source tarballs
as users get them, and records their provenance in `versions.json`: the
tarball's sha256, its `Packaged`, `Repository` and `Date/Publication`
fields, the git commit, and optionally whether the baseline's `R/`
matches a release tag.

## Usage

``` r
prepare_versions(d, force = FALSE, ask = interactive(), quiet = FALSE)
```

## Arguments

- d:

  A
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md).

- force:

  Reinstall both versions even when they look unchanged.

- ask:

  Ask before downloading from CRAN.

- quiet:

  Suppress progress messages.

## Value

The provenance of both versions, invisibly (a list with elements `base`
and `cand`).

## Details

CRAN sources are downloaded here and nowhere else; the function says
what it downloads and where first, and asks when `ask` is `TRUE`. Git
sources are exported with `git archive` and built with `R CMD build`
inside the work folder.

A version whose source has not changed since the last call (same tarball
checksum, same commit, same folder contents, or the same CRAN version)
is not reinstalled unless `force = TRUE`, so re-running after a fix
rebuilds only the candidate. For
[`cran_release()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
every call reads CRAN's package index to find the current version, so a
new release is picked up; if the index cannot be read, an installed copy
is reused and the function says so.

## Examples

``` r
# \donttest{
d <- example_dossier()
vers <- prepare_versions(d)
#> base: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.0.0.tar.gz unchanged, reusing the installed copy
#> cand: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.1.0.tar.gz unchanged, reusing the installed copy
#> base udfixture 1.0.0  sha256 fd0de4ff9fef  packaged 2026-11-06 15:33:45 UTC; root
#> cand udfixture 1.1.0  sha256 0eaefa1ba295  packaged 2026-11-06 15:33:45 UTC; root
vers$cand$version
#> [1] "1.1.0"
# }
```
