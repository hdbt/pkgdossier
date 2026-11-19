# Getting started with pkgdossier

A package’s tests check that each version is consistent with itself.
They do not check what a user of the last release meets after upgrading:
the code from the vignettes and the help pages they learned from, run
unchanged under the new version. pkgdossier runs that code under both
versions, each installed in its own library and run in its own R
process, and lists every difference with a mechanical label. It does not
decide whether a difference is intended; it gives you the evidence and
the NEWS bullets that might explain it.

## A first dossier

pkgdossier ships a tiny package, `udfixture`, in two versions with one
planted difference of each kind.
[`example_dossier()`](https://hdbt.github.io/pkgdossier/reference/example_dossier.md)
describes a comparison of the two; like
[`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md),
it only describes, and nothing is installed yet.

``` r

library(pkgdossier)
#> 
#> Attaching package: 'pkgdossier'
#> The following object is masked from 'package:stats':
#> 
#>     step
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
#>   work:      /tmp/RtmpUsOiPb/pkgdossier-example
```

[`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
runs the stages in turn:
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
installs both versions into the work folder,
[`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
runs the scenarios four times (baseline, candidate, candidate,
baseline), and
[`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
compares the runs. It then writes the HTML report and the JSON. Each
stage caches its work, so a second call after changing the candidate
rebuilds and reruns only the candidate.

``` r

cmp <- run_dossier(d, html = file.path(tempdir(), "dossier-page"), open = FALSE, quiet = TRUE)
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
```

## Reading the differences

Each difference has one kind, with a severity for sorting: 1 for code
that breaks (a new error, a removed element), 2 for results that move, 3
for output, plots and timing, 4 for additions and fixes. `unstable` (0)
marks a step whose two runs under one version disagree, so it cannot be
compared.

[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md)
returns them as a data frame to filter:

``` r

diffs <- differences(cmp, max_severity = 2)
diffs[, c("step", "kind", "path", "base", "cand")]
#>             step                    kind     path
#> 1          noisy                unstable     <NA>
#> 2         result           field_removed    res$b
#> 3          check               error_new    error
#> 4  extend_result   argument_new_required     keep
#> 5      warn_gone        argument_removed  verbose
#> 6       estimate             value_moved est$main
#> 7          ex-01             value_moved est$main
#> 8          ex-02             value_moved  (value)
#> 9       warn_new             warning_new  warning
#> 10    warn_class condition_class_changed  warning
#> 11     err_class condition_class_changed    error
#> 12         label             value_moved      lab
#> 13        report         default_changed   digits
#>                               base                          cand
#> 1             differs between runs          differs between runs
#> 2                             <NA>                          <NA>
#> 3                             <NA>         `x` must be character
#> 4                             <NA>                    (required)
#> 5                             TRUE                          <NA>
#> 6                              0.5                           0.6
#> 7                              0.5                           0.6
#> 8                              0.5                           0.6
#> 9                             <NA>       results may be unstable
#> 10 simpleWarning/warning/condition slowWarning/warning/condition
#> 11     simpleError/error/condition    inputError/error/condition
#> 12                           alpha                          beta
#> 13                               2                             3
```

[`summary()`](https://rdrr.io/r/base/summary.html) has one row per step:

``` r

s <- summary(cmp)
head(s[, c("scenario", "step", "status", "kinds", "news")], 10)
#>       scenario     step  status                       kinds news
#> 1        intro    setup    same                                0
#> 2        intro chunk-02    same                                0
#> 3        intro estimate changed                 value_moved    1
#> 4        intro   report changed              output_changed    1
#> 5        intro     draw changed                plot_changed    0
#> 6        intro     data    same                                0
#> 7        intro expected    same                                1
#> 8  ex_estimate    ex-01 changed                 value_moved    1
#> 9  ex_estimate    ex-02 changed output_changed, value_moved    1
#> 10 ex_estimate    ex-03    same                                1
```

## NEWS candidates

For each step, pkgdossier reads the candidate’s NEWS from the sections
written after the baseline’s version and attaches the bullets that name
a function the step uses. A difference in a step that no bullet names
gets `no_news = TRUE`: a change users will meet that the NEWS may not
tell them about.

``` r

named <- differences(cmp, no_news = FALSE)
named[, c("step", "kind", "news")]
#>       step           kind
#> 1    check      error_new
#> 2 estimate    value_moved
#> 3    ex-01    value_moved
#> 4    ex-02    value_moved
#> 5   report output_changed
#> 6    ex-02 output_changed
#>                                                                       news
#> 1       `check_input()` now requires character input and errors otherwise.
#> 2                   `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 3                   `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 4                   `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 5 Printed reports show the version in their heading (`print.ud_report()`).
#> 6                   `estimate()` returns a main estimate of 0.6 (was 0.5).
nrow(differences(cmp, no_news = TRUE))
#> [1] 18
```

This is a search, not a judgement: a bullet can name a function without
covering the change, and a change can be covered by a bullet in other
words.

## Writing it up

The report
([`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md))
is a folder that opens in any browser without a network: provenance of
both versions, the labelled differences, and per step the side-by-side
output, the numbers that moved and the plot pairs.
[`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)
writes the same data as JSON.
[`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
writes a short summary for a pull-request comment:

``` r

cat(write_dossier_md(cmp))
```

### pkgdossier: udfixture 1.0.0 -\> 1.1.0

3 scenario(s), 28 step(s) compared, 2 not run. **24 difference(s)** in
23 step(s). 18 of them in steps no NEWS bullet names.

| Kind                    | Severity | Differences | Steps |
|-------------------------|---------:|------------:|------:|
| unstable                |        0 |           1 |     1 |
| error_new               |        1 |           1 |     1 |
| field_removed           |        1 |           1 |     1 |
| argument_removed        |        1 |           1 |     1 |
| argument_new_required   |        1 |           1 |     1 |
| condition_class_changed |        2 |           2 |     2 |
| value_moved             |        2 |           4 |     4 |
| warning_new             |        2 |           1 |     1 |
| default_changed         |        2 |           1 |     1 |
| output_changed          |        3 |           3 |     3 |
| plot_changed            |        3 |           1 |     1 |
| slower                  |        3 |           1 |     1 |
| faster                  |        3 |           1 |     1 |
| warning_gone            |        4 |           1 |     1 |
| field_added             |        4 |           1 |     1 |
| error_fixed             |        4 |           1 |     1 |
| argument_added          |        4 |           1 |     1 |
| export_added            |        4 |           1 |     1 |

#### Most severe (severity 0-2)

Identical changes in several steps are listed once, with the number of
steps.

| Kind | Where | 1.0.0 | 1.1.0 | NEWS |
|----|----|----|----|----|
| unstable | api/noisy | differs between runs | differs between runs | none |
| field_removed | api/result `res$b` | \- | \- | none |
| error_new | api/check `error` | \- | `x` must be character | `check_input()` now requires character input and errors o… |
| argument_new_required | (namespace)/extend_result `keep` | \- | (required) | none |
| argument_removed | (namespace)/warn_gone `verbose` | TRUE | \- | none |
| value_moved | `est$main` in 2 steps | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
| value_moved | ex_estimate/ex-02 `(value)` | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
| warning_new | api/warn_new `warning` | \- | results may be unstable | none |
| condition_class_changed | api/warn_class `warning` | simpleWarning/warning/condition | slowWarning/warning/condition | none |
| condition_class_changed | api/err_class `error` | simpleError/error/condition | inputError/error/condition | none |
| value_moved | api/label `lab` | alpha | beta | none |
| default_changed | (namespace)/report `digits` | 2 | 3 | none |

Coverage: the scenarios use 17 of 18 exported functions. Not used:
`new_helper`.

Scenario problems (error under both versions): api/err_class.

Not compared, because two runs of one version disagree: 1.0.0 api/noisy;
1.1.0 api/noisy.

_(pkgdossier 0.1.0, R version 4.6.2 (2026-10-29), abba runs, 3 timed repeat(s) per timed step.)

The package ships a GitHub Actions workflow that runs a dossier of the
CRAN release against each pull request and posts this summary:
`system.file("github", "pkgdossier.yaml", package = "pkgdossier")`.

## Your own package

In your package’s folder, one call makes the dossier:

``` r

run_dossier()
```

It compares the folder with the package’s CRAN release, running the
release’s vignettes and help-page examples under both, and is the same
as `run_dossier(dossier("mypkg"))`: only the package’s name is read from
the folder. It asks before downloading, opens the report, and prints the
comparison, starting with a one-line verdict. When it cannot start, it
says why and what to write instead: outside a package folder it names
the package nearby; for a package not on CRAN yet it names the
repository’s tags (`base = git_ref(".", "v0.3.0")`); for a missing
dependency it gives the
[`install.packages()`](https://rdrr.io/r/utils/install.packages.html)
line. A step that hangs is stopped after `step_timeout` (5 minutes for
one execution) and recorded, and a step that crashes R is recorded too.
Call it again after a change: what has not changed is reused, and only
the candidate is rebuilt and rerun (its timings are then shown but not
labelled, as they were not made alongside the baseline’s).

As a user of a package rather than its maintainer, compare the version
you have with the current release before upgrading:
`run_dossier(dossier("ggplot2", base = installed_version(), candidate = cran_release()))`.
A version installed from GitHub or R-universe has no CRAN source, and
the call says what to write instead.

To say more, describe the dossier: where both versions come from and
which code to run. Scenario files add code neither the vignettes nor the
examples cover.

``` r

d <- dossier("mypkg",
  base = cran_release(),                       # or cran_version("1.2.0"), tarball()
  candidate = git_ref("path/to/mypkg", "main"), # or local_path("path/to/mypkg")
  scenarios = list(from_vignettes(), from_examples(),
                   scenario_file("dev/dossier/scenarios.R")),
  work = file.path(tempdir(), "dossier-mypkg")
)
cmp <- run_dossier(d)
```

Everything that shapes the runs (`reps`, the seed, the console width,
the dependencies and so on) is set in
[`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md),
and `print(d)` shows it. The stages take only how they run, such as
`step_timeout` and `workers`, and
[`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
takes the tolerances: changing one only compares again. A setting given
to the wrong function is an error that writes out the right call, and
`cmp$dossier` is the dossier a comparison was made from.

A scenario file uses
[`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md) and
[`step()`](https://hdbt.github.io/pkgdossier/reference/step.md). Steps
in one scenario share an environment, so later steps see what earlier
steps created:

``` r

scenario("basics", title = "Linear model", source = "README",
  step("setup", "setup", d <- head(mtcars, 20)),
  step("fit", "fit", fit <- lm(mpg ~ wt, data = d)),
  step("coef", "print", coef(fit), values = TRUE),
  step("plot", "plot", plot(d$wt, d$mpg), w = 5, h = 4)
)
```

By default both versions use the dependencies in your library, so
differences come from the package alone;
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
says before installing if a version needs a dependency you do not have.
With `dossier(..., deps = deps_cran())` it instead installs the current
CRAN versions of every dependency into the work folder, as a new user
installing today would get them, and with
[`deps_snapshot()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
the versions CRAN had when the baseline was released (see
[`?deps`](https://hdbt.github.io/pkgdossier/reference/deps.md)).
Downloads happen only in
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md),
which says what it fetches and asks first in an interactive session.
