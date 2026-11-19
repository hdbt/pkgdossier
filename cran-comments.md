## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* win-builder: R-release (4.6.2) and R-devel (2026-11-17 r90926)
* GitHub Actions: Ubuntu (R-devel, R-release, R-oldrel-1, R 4.1), macOS (R-release)
  and Windows (R-release)
* local Windows 11, R 4.5.1

## Comments

* There are no published references describing the methods of this package yet,
  so the Description field cites none.
* Every exported function and method that has its own help page documents its
  return value with `\value`. The print and format methods are registered S3
  methods without help pages of their own.
* No example uses `\dontrun{}`. Examples that only describe objects run
  unwrapped. Examples that build, install and run packages are in `\donttest{}`:
  they use two small source tarballs bundled in `inst/extdata` (about 1.5 KB each),
  install them into `tempdir()` and use no network. Later examples reuse the
  installations and runs of earlier ones, so the whole set takes 20 to 30 seconds
  under `R CMD check --as-cran` on the GitHub Actions runners (Linux, macOS and
  Windows).
* The vignette runs a dossier on the same bundled tarballs, installing them into
  `tempdir()` without network access; it builds in 10 to 20 seconds on the GitHub
  Actions runners and in about 70 seconds on win-builder.
* The tests use no network. They build and install two versions of a tiny fixture
  package shipped in `tests/testthat/fixtures/` from source into `tempdir()` and run
  them in sequential child R processes (one at a time, no parallelism). Timing
  expectations are asserted only when `NOT_CRAN` is set, because elapsed-time
  comparisons depend on machine load.
* The package writes only to the work folder the user names, which defaults to a
  folder in `tempdir()`. Downloads happen only in `prepare_versions()`, which states
  what it fetches and asks first in interactive sessions.
