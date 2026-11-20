# Before a release

You have changed your package and are about to send the new version to
CRAN. The tests pass, and `R CMD check` and the reverse-dependency
checks are clean. None of these runs the code your users learned from
the last release, unchanged, under the new version. This article does
that before you submit: run the dossier, read the verdict, decide about
each difference, make NEWS say what users will meet, and record the
decisions so that the next run shows only what is new.

The output below comes from
[`example_dossier()`](https://hdbt.github.io/pkgdossier/reference/example_dossier.md),
a tiny package bundled with pkgdossier in two versions with one planted
difference of each kind, so every call here runs as written. In your
package’s folder the same calls need no dossier.

## Run the dossier

In your package’s folder:

``` r

cmp <- run_dossier()
```

This compares the folder with the package’s current CRAN release. It
installs both, runs the release’s vignettes and help-page examples under
each, opens the report and prints a summary. It asks before downloading
anything. For a package not on CRAN yet, compare with a git tag instead:
`run_dossier(dossier("mypkg", base = git_ref(".", "v0.3.0")))`.

The work folder is in
[`tempdir()`](https://rdrr.io/r/base/tempfile.html) by default, so a new
R session starts over. A release takes more than one session; give the
dossier a folder that lasts, outside the package:

``` r

d <- dossier("mypkg", work = "~/dossiers/mypkg")
cmp <- run_dossier(d)
```

The example, run the same way:

``` r

d <- example_dossier()
cmp <- run_dossier(d, open = FALSE, quiet = TRUE)
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

## Read the verdict

The verdict line counts four things:

- **Severe changes** (severity 1): code from the release that breaks
  under the new version. A new error, an element gone from a returned
  object, an export or an argument removed, an argument that is now
  required. Identical changes in several steps count once.
- **Other differences** (severity 2 to 4): numbers that moved, new
  warnings, changed output, plots and timings, and additions and fixes.
- **Unstable steps**: the two runs under one version disagreed, so the
  step could not be compared.
- **Scenario problems**: steps that error under both versions.

“Nothing severe” is the verdict to aim for, but it does not mean nothing
changed for your users. Severity 2 is where the silent changes are: the
same code runs without an error and gives a different result.

The “Most severe” list below the counts names each change once, with
`[no NEWS]` where no NEWS bullet names a function the step uses. The
report shows the same differences with the two versions’ output side by
side, step by step.

## Clear what cannot be compared

Two kinds of step give no evidence about your change. Deal with them
first.

An **unstable** step disagrees with itself: its two runs under one
version differ. The seed is set before every step and temporary paths
and memory addresses are masked, so what is left is usually the clock: a
step that re-seeds from the time (`set.seed(NULL)`), prints how long
something took, or shows today’s date. In the example, `noisy()`
re-seeds from the clock. The scenarios come from the release’s vignettes
and examples, which you cannot change now; fix the example for the next
release, and accept the step for this one (see below).
[`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md)
counts unstable steps with the severe changes, so an unstable step left
alone fails it.

A **scenario problem** is release code that errors under both versions:
an example that needs a package you have not installed, a network
connection or a file. It says nothing about your change. Install what it
needs, or leave it; `summary(cmp)` lists these steps with the status
`error_both`.

## Decide about each difference

Work from the most severe down. For each difference one of three things
is true:

1.  It is a bug. Fix the code and call
    [`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
    again: only the candidate is rebuilt and rerun.
2.  It is intended, and NEWS does not say so. Write the bullet (next
    section).
3.  It is intended, and NEWS says so. Accept it (the section after).

What each severity means for a user, and what to do before the release:

| Severity | Kinds | Users meet | Before the release |
|----|----|----|----|
| 1 | `error_new`, `field_removed`, `export_removed`, `argument_removed`, `argument_new_required` | code that stops working | Restore it, or deprecate it first: an argument kept with a warning shows up as `warning_new` instead. Otherwise announce it in NEWS as a breaking change. |
| 2 | `value_moved`, `warning_new`, `condition_class_changed`, `default_changed`, `arguments_reordered` | the same code giving other results | Fix it or announce it; these are the changes users will not notice by themselves. A changed condition class breaks code that catches it by class, and reordered arguments break calls by position. |
| 3 | `output_changed`, `plot_changed`, `slower`, `faster` | a different look, or a different speed | Usually fine; announce what users will see. |
| 4 | `error_fixed`, `warning_gone`, `field_added`, `export_added`, `argument_added` | fixes and new things | Good news; worth a NEWS bullet. |

`differences(cmp, group = TRUE)` gives one row per distinct change, with
where it occurs.
[`?compare_runs`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
defines every kind.

## Make NEWS say it

A difference flagged `[no NEWS]`, `no_news = TRUE` in
[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md),
is in a step that no bullet of the candidate’s NEWS names. These are the
changes users may meet without being told:

``` r

silent <- differences(cmp, no_news = TRUE, max_severity = 2)
silent[, c("scenario", "step", "kind", "path")]
#>      scenario          step                    kind    path
#> 1         api         noisy                unstable    <NA>
#> 2         api        result           field_removed   res$b
#> 3 (namespace) extend_result   argument_new_required    keep
#> 4 (namespace)     warn_gone        argument_removed verbose
#> 5         api      warn_new             warning_new warning
#> 6         api    warn_class condition_class_changed warning
#> 7         api     err_class condition_class_changed   error
#> 8         api         label             value_moved     lab
#> 9 (namespace)        report         default_changed  digits
```

pkgdossier reads the candidate’s NEWS from the sections written after
the release’s version, and a bullet counts for a step when it names a
function the step uses: as `fn()`, `pkg::fn()` or `` `fn` ``. So write
the bullet under the new version’s heading and name the function:

``` markdown
# mypkg 1.1.0

* `estimate()` returns a main estimate of 0.6 (was 0.5).
```

Then call
[`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
again. The match is a search, not a judgement: a bullet can name a
function without describing the change, so read the `news` column of
[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md)
to see which bullet was matched.

NEWS can also describe changes that no scenario exercises. When it does,
the summary says how many bullets match no step, and the coverage line
lists the exported functions the scenarios do not use. If users rely on
code that neither your vignettes nor your examples show, add it as a
scenario file: see [Writing
scenarios](https://hdbt.github.io/pkgdossier/articles/writing-scenarios.md).

## Accept what you have decided

Once you have read a difference and found it intended, accept it.
Accepted differences keep their rows, marked `accepted`, but drop out of
the counts, the pull-request summary and
[`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md),
so later runs show only what nobody has looked at yet.

The rules go in a CSV file in your repository, in a folder that
`.Rbuildignore` excludes. `dev/dossier/accepted.csv` is where the GitHub
Actions workflow shipped with pkgdossier looks for it. In the example,
the differences that NEWS names are the ones the new version meant to
make:

``` r

announced <- differences(cmp, no_news = FALSE)
announced[, c("step", "kind", "news")]
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
```

Each does what its bullet says, so they are accepted, and so is the
unstable step, with the reason:

``` r

rules <- file.path(tempdir(), "accepted.csv")   # in your package: "dev/dossier/accepted.csv"
accept_differences(announced, rules, reason = "announced in NEWS")
accept_differences(differences(cmp, kind = "unstable"), rules,
                   reason = "noisy() re-seeds from the clock")
```

A rule matches a difference by its kind, scenario, step, path and the
candidate’s value. A number accepted at 0.6 shows up again if it moves
to 0.7; `*` in a field matches anything. The file is plain text, so the
decisions and their reasons can be reviewed in a pull request like any
other change.

Pass the file to the next run. In your folder,
`run_dossier(accept = "dev/dossier/accepted.csv")`; nothing is rebuilt
or rerun to apply the rules, only compared again:

``` r

cmp <- run_dossier(d, accept = rules, open = FALSE, quiet = TRUE)
cmp
#> <pkgdossier comparison> udfixture 1.0.0 -> 1.1.0
#> 3 scenario(s), 28 step(s) compared, 2 not run; abba runs, 3 timed repeats per timed step
#> Verdict: 3 severe changes (field_removed, argument_new_required, argument_removed); 14 other differences; 1 scenario problem.
#> 
#> Differences by kind (severity):
#>   field_removed             1     1 in 1 step(s)
#>   argument_removed          1     1 in 1 step(s)
#>   argument_new_required     1     1 in 1 step(s)
#>   condition_class_changed   2     2 in 2 step(s)
#>   value_moved               2     1 in 1 step(s)
#>   warning_new               2     1 in 1 step(s)
#>   default_changed           2     1 in 1 step(s)
#>   output_changed            3     1 in 1 step(s)
#>   plot_changed              3     1 in 1 step(s)
#>   slower                    3     1 in 1 step(s)
#>   faster                    3     1 in 1 step(s)
#>   warning_gone              4     1 in 1 step(s)
#>   field_added               4     1 in 1 step(s)
#>   error_fixed               4     1 in 1 step(s)
#>   argument_added            4     1 in 1 step(s)
#>   export_added              4     1 in 1 step(s)
#> 
#> NEWS candidates (3 bullet(s) in NEWS.md after 1.0.0): 17 of 17 difference(s) in steps no NEWS bullet names.
#> 
#> 2 difference(s) in udfixture's own DESCRIPTION fields (Version, Packaged, ...), as an example printing sessionInfo() shows them, are not listed.
#> 
#> 7 difference(s) accepted by 7 rule(s) in /tmp/Rtmppq83nL/accepted.csv; not counted above.
#> 
#> Coverage: the scenarios use 17 of 18 exported functions. Not used: new_helper.
#> 
#> Scenario problems (error under both versions): api/err_class
#> 
#> Most severe (severity 0-2), identical changes once:
#>   field_removed            api/result res$b  [no NEWS]
#>   argument_new_required    (namespace)/extend_result keep: - -> (required)  [no NEWS]
#>   argument_removed         (namespace)/warn_gone verbose: TRUE -> -  [no NEWS]
#>   warning_new              api/warn_new warning: - -> results may be unstable  [no NEWS]
#>   condition_class_changed  api/warn_class warning: simpleWarning/warning/condition -> slowWarning/warning/condition  [no NEWS]
#>   condition_class_changed  api/err_class error: simpleError/error/condition -> inputError/error/condition  [no NEWS]
#>   value_moved              api/label lab: alpha -> beta  [no NEWS]
#>   default_changed          (namespace)/report digits: 2 -> 3  [no NEWS]
```

The summary now counts only what is not accepted. It also says how many
differences the rules accepted, and how many rules no longer match
anything and may be stale.

## The last run

Timings are labelled `slower` or `faster` only when all the runs were
made in one call. After a fix the baseline’s runs are reused, and the
summary then shows timings without labels. Before you submit, make every
run again together:

``` r

cmp <- run_dossier(force = TRUE, accept = "dev/dossier/accepted.csv")
```

Then check what is left, as the GitHub Actions workflow does on every
pull request:

``` r

check_differences(cmp, max_severity = 1, no_news = TRUE)
#> Error:
#> ! 3 difference(s) of severity 1 or more severe and that no NEWS bullet names are not accepted:
#>   field_removed api/result res$b
#>   argument_new_required (namespace)/extend_result keep
#>   argument_removed (namespace)/warn_gone verbose
#> Accept the intended ones with accept_differences().
```

It returns `TRUE` invisibly when no severe change is left that is
neither accepted nor named by NEWS, and stops with a list otherwise. In
the example, three severe changes are left. In a real release, each one
is fixed, announced in NEWS or accepted with a reason before you submit.
For a stricter gate, `check_differences(cmp, max_severity = 2)` also
stops for moved numbers and new warnings, whether or not NEWS names
them.

## In short

1.  [`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
    in the package’s folder, with a work folder that lasts between
    sessions.
2.  Unstable steps and scenario problems first: fix them for the next
    release, and accept or ignore them for this one.
3.  Every severe change fixed, deprecated, or announced as breaking.
4.  Every moved number and new warning fixed or in NEWS.
5.  Intended differences accepted, with reasons, in
    `dev/dossier/accepted.csv`.
6.  A last `run_dossier(force = TRUE, accept = ...)`, then
    [`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md).

To run the same check on every pull request, see [On pull
requests](https://hdbt.github.io/pkgdossier/articles/on-pull-requests.md).
For other baselines than the CRAN release, and for the dependencies both
versions run against, see [Baselines and
dependencies](https://hdbt.github.io/pkgdossier/articles/baselines-and-dependencies.md).
