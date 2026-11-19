# A dossier over a small bundled package

Describes a dossier over `udfixture`, a tiny package shipped with
pkgdossier as two source tarballs (versions 1.0.0 and 1.1.0) with one
planted difference of each kind: a moved number, changed printed output,
a changed plot, a removed and an added element, a new and a fixed error,
a new and a gone warning, a changed warning class, a slower and a faster
step, and an unseeded step. Its scenarios are the baseline's vignette,
its help-page examples and a scenario file. Use it to try the stages and
the report without network access; like
[`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md),
it only describes, and nothing is installed until
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md).

## Usage

``` r
example_dossier(work = file.path(tempdir(), "pkgdossier-example"), ...)
```

## Arguments

- work:

  Work folder; defaults to a folder in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html).

- ...:

  Further arguments to
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md),
  such as `reps = 0` for a quick run.

## Value

An object of class `pkgdossier_dossier`.

## Examples

``` r
d <- example_dossier()
d
#> <pkgdossier dossier> udfixture
#>   base:      tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.0.0.tar.gz
#>   candidate: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.1.0.tar.gz
#>   scenarios: baseline vignettes; baseline help-page examples; scenario file /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture-scenarios.R
#>   runs:      abba, 3 timed repeats per timed step, seed 20261027 set per step
#>   capture:   width 80, 100 dpi, LANGUAGE en
#>   collect:   default caps; default skipped classes
#>   deps:      shared, from the current library paths
#>   work:      /tmp/RtmpFl7ulk/pkgdossier-example
# \donttest{
prepare_versions(d)
#> base: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.0.0.tar.gz unchanged, reusing the installed copy
#> cand: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.1.0.tar.gz unchanged, reusing the installed copy
#> base udfixture 1.0.0  sha256 fd0de4ff9fef  packaged 2026-11-06 15:33:45 UTC; root
#> cand udfixture 1.1.0  sha256 0eaefa1ba295  packaged 2026-11-06 15:33:45 UTC; root
run_scenarios(d)
#> Running 3 scenario(s), 30 steps, under udfixture 1.0.0 and 1.1.0 in 4 runs (abba), 3 timed repeats per timed step; a step's run stops after 300 s (step_timeout)
#> Machine before: CPU 0% busy, 0 other R processes
#> [1/4] base_a: up to date, reused
#> [2/4] cand_a: up to date, reused
#> [3/4] cand_b: up to date, reused
#> [4/4] base_b: up to date, reused
compare_runs(d)
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
