# Make a dossier in one call

Run from a package's folder, `run_dossier()` compares that folder with
the package's CRAN release: it installs both, runs the release's
vignettes and help-page examples under each, compares everything they
produce, writes the HTML report and the JSON, opens the report (in an
interactive session) and returns the comparison, which prints a summary.

## Usage

``` r
run_dossier(
  d = NULL,
  ...,
  html = file.path(d$work, "page"),
  json = file.path(d$work, "dossier.json"),
  open = interactive(),
  force = FALSE,
  ask = interactive(),
  timeout = Inf,
  step_timeout = 300,
  workers = 1L,
  quiet = FALSE
)
```

## Arguments

- d:

  A
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md),
  or `NULL` for the package in the working directory (see "From a
  package folder").

- ...:

  Arguments of
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md):
  `tol`, `min_time`, `min_ratio`, `min_timings`, `plot_tol`, `api`,
  `accept` and `keep_metadata`. The arguments after `...` must be named
  in full.

- html:

  Folder for the HTML report
  ([`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md)),
  or `NULL` for none.

- json:

  File for the JSON
  ([`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)),
  or `NULL` for none.

- open:

  Open the report in the browser; by default only in an interactive
  session.

- force:

  Reinstall both versions and repeat every run.

- ask:

  Ask before every download: package sources, package indexes (once per
  repository and session) and dependencies.

- timeout, step_timeout:

  Seconds one run may take, and one execution of a step (300 by
  default); see
  [`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md).

- workers:

  Runs at once; see
  [`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md).

- quiet:

  Suppress progress messages.

## Value

The comparison, an object of class `pkgdossier_comparison`; its
`$dossier` is the dossier it was made from.

## Details

It calls
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md),
[`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
and
[`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
in turn. Each stage caches its work in the dossier's work folder, so a
second call after changing the package rebuilds and reruns only the
candidate, and a call with other comparison settings only compares
again.

## From a package folder

With no dossier, `run_dossier()` is `run_dossier(dossier("<Package>"))`,
where `<Package>` is the `Package` field of the working directory's
`DESCRIPTION`: the folder against its CRAN release, with the release's
vignettes and examples, and every other setting at
[`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md)'s
default. Only the package's name is read from the folder.
`print(cmp$dossier)` shows every setting.

## Changing a setting

Each setting has one home, and a setting given in the wrong place is an
error that writes out the call to use instead.

- What is compared and how the runs are made go to
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md):
  `run_dossier(dossier("mypkg", base = cran_version("1.2.0"), reps = 0))`.

- How the runs go stays here:
  `run_dossier(step_timeout = 900, workers = 2)`.

- The comparison's tolerances go to
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
  through `...`: `run_dossier(tol = 1e-3)`.

Before upgrading a package you use, see what would change for you:
`run_dossier(dossier("ggplot2", base = installed_version(), candidate = cran_release()))`.

A quick look, without timings to label:
`run_dossier(dossier("mypkg", reps = 0), workers = 2)`. To keep the work
between R sessions, give the dossier a work folder:
`dossier("mypkg", work = "~/dossiers/mypkg")`.

## When it stops

Before anything is downloaded it stops when the working directory is not
a package (naming the package around or below it, if any), and when a
folder source does not hold the package or lacks a dependency. A package
with no CRAN release, or an index that cannot be read, stops with the
`base` to write instead. The errors have classes
`pkgdossier_error_not_package`, `pkgdossier_error_not_on_repo`,
`pkgdossier_error_offline`, `pkgdossier_error_no_scenarios`,
`pkgdossier_error_not_installed` and
`pkgdossier_error_nothing_to_compare` (the installed version is already
the current release). A step that hangs is stopped after `step_timeout`
and recorded; one that crashes R is recorded too; the dossier goes on
without them.

## Examples

``` r
# \donttest{
cmp <- run_dossier(example_dossier(), html = file.path(tempdir(), "dossier-page"),
                   open = FALSE)
#> base: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.0.0.tar.gz unchanged, reusing the installed copy
#> cand: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.1.0.tar.gz unchanged, reusing the installed copy
#> base udfixture 1.0.0  sha256 fd0de4ff9fef  packaged 2026-11-06 15:33:45 UTC; root
#> cand udfixture 1.1.0  sha256 0eaefa1ba295  packaged 2026-11-06 15:33:45 UTC; root
#> Running 3 scenario(s), 30 steps, under udfixture 1.0.0 and 1.1.0 in 4 runs (abba), 3 timed repeats per timed step; a step's run stops after 300 s (step_timeout)
#> Machine before: CPU 1% busy, 0 other R processes
#> [1/4] base_a: up to date, reused
#> [2/4] cand_a: up to date, reused
#> [3/4] cand_b: up to date, reused
#> [4/4] base_b: up to date, reused
#> Report: /tmp/RtmpDR5Lhw/dossier-page/dossier.html
#> JSON:   /tmp/RtmpDR5Lhw/pkgdossier-example/dossier.json
cmp
#> <pkgdossier comparison> udfixture 1.0.0 -> 1.1.0
#> 3 scenario(s), 28 step(s) compared, 2 not run; abba runs, 3 timed repeats per timed step
#> Verdict: 4 severe changes (field_removed, error_new, argument_new_required, argument_removed); 19 other differences; 1 unstable step; 1 scenario problem.
#> 
#> Differences by kind (severity):
#>   unstable                  0     1 in 1 step(s)
#>   error_new                 1     1 in 1 step(s)
#>   field_removed             1     1 in 1 step(s)
#>   argument_removed          1     1 in 1 step(s)
#>   argument_new_required     1     1 in 1 step(s)
#>   condition_class_changed   2     2 in 2 step(s)
#>   value_moved               2     4 in 4 step(s), 3 distinct
#>   warning_new               2     1 in 1 step(s)
#>   default_changed           2     1 in 1 step(s)
#>   output_changed            3     3 in 3 step(s)
#>   plot_changed              3     1 in 1 step(s)
#>   slower                    3     1 in 1 step(s)
#>   faster                    3     1 in 1 step(s)
#>   warning_gone              4     1 in 1 step(s)
#>   field_added               4     1 in 1 step(s)
#>   error_fixed               4     1 in 1 step(s)
#>   argument_added            4     1 in 1 step(s)
#>   export_added              4     1 in 1 step(s)
#> 
#> NEWS candidates (3 bullet(s) in NEWS.md after 1.0.0): 18 of 24 difference(s) in steps no NEWS bullet names.
#> 
#> 2 difference(s) in udfixture's own DESCRIPTION fields (Version, Packaged, ...), as an example printing sessionInfo() shows them, are not listed.
#> 
#> Coverage: the scenarios use 17 of 18 exported functions. Not used: new_helper.
#> 
#> Scenario problems (error under both versions): api/err_class
#> 
#> Most severe (severity 0-2), identical changes once:
#>   unstable                 api/noisy : differs between runs -> differs between runs  [no NEWS]
#>   field_removed            api/result res$b  [no NEWS]
#>   error_new                api/check error: - -> `x` must be character
#>   argument_new_required    (namespace)/extend_result keep: - -> (required)  [no NEWS]
#>   argument_removed         (namespace)/warn_gone verbose: TRUE -> -  [no NEWS]
#>   value_moved              est$main (2 steps): 0.5 -> 0.6
#>   value_moved              ex_estimate/ex-02 (value): 0.5 -> 0.6
#>   warning_new              api/warn_new warning: - -> results may be unstable  [no NEWS]
#>   condition_class_changed  api/warn_class warning: simpleWarning/warning/condition -> slowWarning/warning/condition  [no NEWS]
#>   condition_class_changed  api/err_class error: simpleError/error/condition -> inputError/error/condition  [no NEWS]
#>   value_moved              api/label lab: alpha -> beta  [no NEWS]
#>   default_changed          (namespace)/report digits: 2 -> 3  [no NEWS]
# }
```
