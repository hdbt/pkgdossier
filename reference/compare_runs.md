# Compare the runs and label every difference

Compares the baseline's and the candidate's runs step by step and gives
each difference one mechanical kind. The labels say what differs, not
whether it is intended: that judgement is left to the reader.

## Usage

``` r
compare_runs(
  d,
  tol = 1e-04,
  min_time = 0.03,
  min_ratio = 1.2,
  min_timings = 5L,
  plot_tol = 0,
  api = TRUE,
  accept = NULL,
  keep_metadata = FALSE
)
```

## Arguments

- d:

  A
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md).

- tol:

  Relative tolerance for numbers.

- min_time, min_ratio:

  Timing rule: only steps whose median takes at least `min_time` seconds
  in one version are labelled, and only when the median ratio is at
  least `min_ratio` (or at most `1 / min_ratio`). The default floor of
  30 ms reflects the 10 ms resolution of the process timer on Windows.

- min_timings:

  Fewest timings per version for a `slower` or `faster` label. The rule
  asks that all of one version's timings lie beyond the other's; with
  two timings a side that happens by chance one time in three, with five
  a side one time in 126, with six (the default `reps = 3` in both runs
  of a version) one time in 462. Steps with fewer timings show their
  times without a label.

- plot_tol:

  Largest share of differing pixels (0 to 1) at which two images of the
  same size still count as the same plot, for anti-aliasing or font
  noise. Needs the png package; without it plots are compared by
  checksum only.

- api:

  Compare the exports and function signatures of the two versions.

- accept:

  Rules for differences already read and accepted: a CSV file written by
  [`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)
  or a data frame with its columns. Accepted differences keep their
  rows, marked `accepted`, and are left out of the counts of
  [`print()`](https://rdrr.io/r/base/print.html),
  [`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
  and
  [`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md).

- keep_metadata:

  Keep differences in the package's own DESCRIPTION fields. By default,
  a value or element difference whose path ends in a field of the
  package's installed DESCRIPTION (`Version`, `Packaged`, `Built`, ...)
  and whose two sides are that field in the two versions is left out and
  counted: an example that prints
  [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html) or
  [`packageDescription()`](https://rdrr.io/r/utils/packageDescription.html)
  shows them, and they differ between any two versions.

## Value

An object of class `pkgdossier_comparison`, with methods for
[`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md),
[`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md)
and
[`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md).
Its `$dossier` is `d`, so the stages can be called again from the
result: `compare_runs(cmp$dossier, tol = 1e-3)`.

## Details

|  |  |  |
|----|----|----|
| Kind | Rule | Severity |
| `unstable` | the two runs of one version disagree; the step is not compared further | 0 |
| `error_new` | the step errors only under the candidate | 1 |
| `field_removed` | an element path (`x$a$b`, `x@slot`, a data-frame column) only in the baseline | 1 |
| `condition_class_changed` | an error or warning with the same message but a different class | 2 |
| `value_moved` | a number whose relative change exceeds `tol`, a number that became or stopped being `NA`, or a short string that changed | 2 |
| `warning_new` | a warning message only the candidate gives | 2 |
| `output_changed` | the console transcript or the printed value differs (one row per stream), unless every changed line differs only in printed numbers within `tol` | 3 |
| `plot_changed` | the PNG files differ (checksum) or their number differs; with the png package, the share of differing pixels is reported, and images whose share is at most `plot_tol` are not labelled | 3 |
| `slower`, `faster` | for timed steps of `min_time` seconds or more with at least `min_timings` timings per version: the candidate's timings all lie above (below) the baseline's by more than 5 ms (half the Windows timer tick) and the median ratio is beyond `min_ratio` | 3 |
| `warning_gone` | a warning message only the baseline gives | 4 |
| `field_added` | an element path only in the candidate | 4 |
| `error_fixed` | the step errors only under the baseline | 4 |

With `api = TRUE`, the exports and function signatures of the two
versions are compared too, without running anything; these differences
are listed under the scenario `(namespace)`, with the function as the
step and the argument as the path:

|  |  |  |
|----|----|----|
| Kind | Rule | Severity |
| `export_removed` | an export of the baseline is gone (or is no longer a function) | 1 |
| `argument_removed` | an argument of an exported function is gone | 1 |
| `argument_new_required` | a new argument without a default, or an argument that lost its default | 1 |
| `arguments_reordered` | the arguments both versions have come in a different order | 2 |
| `default_changed` | an argument's default differs | 2 |
| `argument_added` | a new argument with a default | 4 |
| `export_added` | a new export | 4 |

**Coverage.** The comparison also records which exported functions the
scenarios use (directly or through the objects they produce), which they
do not, and which candidate NEWS bullets no step or API difference was
matched to: changes the dossier did not exercise.
[`print()`](https://rdrr.io/r/base/print.html), the report and the
Markdown summary show it.

A step that errors under both versions is a scenario problem rather than
a finding: it is reported with status `error_both` and compared no
further (apart from a change of the error's class), unless under only
one version R stopped in it, it timed out or pkgdossier could not
capture it, which is `error_new` (or `error_fixed`). A vignette chunk
run with `error = TRUE` runs on after an error, as knitr runs it, and
the errors it shows its readers are part of its console output
(`Error: ...`), compared with the rest; an error from a package that is
not installed stays an error. A step that errors under one version is
compared no further. Numbers that differ by less than `tol` are counted,
not listed: such differences come from optimisers and floating point,
not from a change in method.

**NEWS candidates.** The candidate's NEWS (`NEWS.md` or a plain-text
`NEWS`, at the top level or in `inst/`, or else `inst/NEWS.Rd` through
the news database R builds when installing it) is read from the sections
written after the baseline's version. For each step, the bullets that
name a function of the package the step uses are attached to the step
and to each of its differences (column `news`). A function is "used"
when its name appears in the step's code, when it is a method for the
class of the step's last visible value (so `print.myclass()` for a
printed `myclass` object), or when it produced an object the step uses:
`fit <- fit_model(d)` in one step makes `summary(fit)` in a later step
use `fit_model()` too, following assignments through the scenario. A
bullet "names" a function as `fn()`, `pkg::fn()`, `` `fn` ``, or, for
names with a dot or an underscore, the bare name. A difference whose
step has no such bullet gets `no_news = TRUE`. A large release can have
dozens of bullets for a step, so each difference keeps at most three,
those naming an element of its path first (`converged` for
`fit$diagnostics$converged`), then those using a word that fits its kind
(`plot` for `plot_changed`). This finds candidates only; whether a
bullet covers the change is for the reader.

The comparison reads the stored runs and takes their order and repeats
from them. It stops when a version was prepared again after its runs
were made (its NEWS and provenance would no longer describe them), and
warns when the dossier's run settings differ from those the runs were
made with;
[`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
makes them again. Comparing is cheap: call it again with other
tolerances, without running anything. Timings are shown but no step is
labelled `slower` or `faster` when runs went at the same time, or when
some runs were reused from an earlier call while others were made anew
(after a fix, the baseline's runs are reused): ABBA's balance against
drift in machine load holds only within one call.
`run_scenarios(d, force = TRUE)` makes all runs together.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
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
summary(cmp)
#>       scenario        step             label      status
#> 1        intro       setup             setup        same
#> 2        intro    chunk-02           chunk 2        same
#> 3        intro    estimate          estimate     changed
#> 4        intro      report            report     changed
#> 5        intro        draw              draw     changed
#> 6        intro        data              data        same
#> 7        intro    expected          expected        same
#> 8  ex_estimate       ex-01 est <- estimate()     changed
#> 9  ex_estimate       ex-02          est$main     changed
#> 10 ex_estimate       ex-03  round(est$small)        same
#> 11         api      result            result     changed
#> 12         api    extended          extended     changed
#> 13         api       check             check   error_new
#> 14         api       fixed             fixed error_fixed
#> 15         api    warn_new          warn_new     changed
#> 16         api   warn_gone         warn_gone     changed
#> 17         api  warn_class        warn_class     changed
#> 18         api        slow              slow     changed
#> 19         api       quick             quick     changed
#> 20         api       noisy             noisy    unstable
#> 21         api   unchanged         unchanged        same
#> 22         api    progress          progress     changed
#> 23         api      digits            digits        same
#> 24         api   err_class         err_class  error_both
#> 25         api       label             label     changed
#> 26         api         tmp               tmp        same
#> 27         api     formula           formula        same
#> 28         api        meta              meta        same
#> 29       intro       later             later     not_run
#> 30       intro conditional       conditional     not_run
#>                          kinds n news base_s cand_s
#> 1                              0    0 0.0000 0.0000
#> 2                              0    0 0.0000 0.0000
#> 3                  value_moved 1    1 0.0000 0.0000
#> 4               output_changed 1    1 0.0000 0.0000
#> 5                 plot_changed 1    0 0.0000 0.0000
#> 6                              0    0 0.0000 0.0010
#> 7                              0    1 0.0025 0.0030
#> 8                  value_moved 1    1 0.0025 0.0025
#> 9  output_changed, value_moved 2    1 0.0025 0.0020
#> 10                             0    1 0.0020 0.0020
#> 11               field_removed 1    0 0.0025 0.0020
#> 12                 field_added 1    0 0.0020 0.0030
#> 13                   error_new 1    1 0.0020 0.0020
#> 14                 error_fixed 1    0 0.0020 0.0020
#> 15                 warning_new 1    0 0.0015 0.0020
#> 16                warning_gone 1    0 0.0020 0.0020
#> 17     condition_class_changed 1    0 0.0020 0.0025
#> 18                      slower 1    0 0.0000 0.2500
#> 19                      faster 1    0 0.2500 0.0000
#> 20                    unstable 1    0 0.0030 0.0020
#> 21                             0    0 0.0045 0.0040
#> 22              output_changed 1    0 0.0020 0.0020
#> 23                             0    0 0.0025 0.0020
#> 24     condition_class_changed 1    0 0.0045 0.0040
#> 25                 value_moved 1    0 0.0020 0.0020
#> 26                             0    0 0.0025 0.0030
#> 27                             0    1 0.0020 0.0020
#> 28                             0    0 0.0020 0.0025
#> 29                             0    0     NA     NA
#> 30                             0    0     NA     NA
differences(cmp, kind = "value_moved")
#>      scenario     step             label        kind severity     path  base
#> 1       intro estimate          estimate value_moved        2 est$main   0.5
#> 2 ex_estimate    ex-01 est <- estimate() value_moved        2 est$main   0.5
#> 3 ex_estimate    ex-02          est$main value_moved        2  (value)   0.5
#> 4         api    label             label value_moved        2      lab alpha
#>   cand rel_change detail                                                   news
#> 1  0.6        0.2   <NA> `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 2  0.6        0.2   <NA> `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 3  0.6        0.2   <NA> `estimate()` returns a main estimate of 0.6 (was 0.5).
#> 4 beta         NA   text                                                   <NA>
#>   no_news accepted accepted_reason
#> 1   FALSE    FALSE            <NA>
#> 2   FALSE    FALSE            <NA>
#> 3   FALSE    FALSE            <NA>
#> 4    TRUE    FALSE            <NA>
# }
```
