# The labelled differences of a comparison

The labelled differences of a comparison

## Usage

``` r
differences(x, ...)

# S3 method for class 'pkgdossier_comparison'
differences(
  x,
  kind = NULL,
  scenario = NULL,
  max_severity = NULL,
  no_news = NULL,
  accepted = NULL,
  group = FALSE,
  ...
)
```

## Arguments

- x:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- ...:

  Must be empty; a misspelled filter (`kinds =`) is an error rather than
  an unfiltered table.

- kind, scenario:

  Keep only these kinds of difference (see
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md))
  or these scenarios.

- max_severity:

  Keep only differences of this severity or more severe (1 is the most
  severe; `unstable` steps have severity 0).

- no_news:

  `TRUE` keeps only differences in steps that no NEWS bullet names (see
  "NEWS candidates" in
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md));
  `FALSE` keeps only those with a candidate bullet.

- accepted:

  `TRUE` keeps only accepted differences, `FALSE` only the others (see
  [`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)).

- group:

  `TRUE` gives one row per distinct change instead of one per
  occurrence: rows of the same kind with the same `base` and `cand` and
  the same path below the object (`*$summary$se` for both
  `m1$summary$se` and `m2$summary$se`) are one change, with columns `n`
  (occurrences), `steps` (number of steps) and `where` (the first few
  `scenario/step`). A new field in a model object, found in every step
  that holds such an object, is then one row.

## Value

A data frame with one row per difference, most severe first: `scenario`,
`step`, `label`, `kind`, `severity`, `path` (where in the step: an
element path, `"printed"`, `"console"`, `"warning"`, `"error"`, `"plot"`
or `"time"`), `base` and `cand` (the two sides, as text), `rel_change`
(for numbers and timings), `detail`, `news` (the candidate NEWS bullets
for the step, one per line, or `NA`) `no_news` (`TRUE` when there are
none; `NA` when the candidate has no NEWS file that could be read), and
`accepted` and `accepted_reason` (see
[`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)).

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
differences(cmp, kind = c("error_new", "field_removed"))
#>   scenario   step  label          kind severity  path base
#> 1      api result result field_removed        1 res$b <NA>
#> 2      api  check  check     error_new        1 error <NA>
#>                    cand rel_change                      detail
#> 1                  <NA>         NA                        <NA>
#> 2 `x` must be character         NA simpleError/error/condition
#>                                                                 news no_news
#> 1                                                               <NA>    TRUE
#> 2 `check_input()` now requires character input and errors otherwise.   FALSE
#>   accepted accepted_reason
#> 1    FALSE            <NA>
#> 2    FALSE            <NA>
differences(cmp, max_severity = 2)
#>       scenario          step             label                    kind severity
#> 1          api         noisy             noisy                unstable        0
#> 2          api        result            result           field_removed        1
#> 3          api         check             check               error_new        1
#> 4  (namespace) extend_result     extend_result   argument_new_required        1
#> 5  (namespace)     warn_gone         warn_gone        argument_removed        1
#> 6        intro      estimate          estimate             value_moved        2
#> 7  ex_estimate         ex-01 est <- estimate()             value_moved        2
#> 8  ex_estimate         ex-02          est$main             value_moved        2
#> 9          api      warn_new          warn_new             warning_new        2
#> 10         api    warn_class        warn_class condition_class_changed        2
#> 11         api     err_class         err_class condition_class_changed        2
#> 12         api         label             label             value_moved        2
#> 13 (namespace)        report            report         default_changed        2
#>        path                            base                          cand
#> 1      <NA>            differs between runs          differs between runs
#> 2     res$b                            <NA>                          <NA>
#> 3     error                            <NA>         `x` must be character
#> 4      keep                            <NA>                    (required)
#> 5   verbose                            TRUE                          <NA>
#> 6  est$main                             0.5                           0.6
#> 7  est$main                             0.5                           0.6
#> 8   (value)                             0.5                           0.6
#> 9   warning                            <NA>       results may be unstable
#> 10  warning simpleWarning/warning/condition slowWarning/warning/condition
#> 11    error     simpleError/error/condition    inputError/error/condition
#> 12      lab                           alpha                          beta
#> 13   digits                               2                             3
#>    rel_change                                                   detail
#> 1          NA  the two runs of the baseline and the candidate disagree
#> 2          NA                                                     <NA>
#> 3          NA                              simpleError/error/condition
#> 4          NA a new argument without a default: existing calls lack it
#> 5          NA                                                     <NA>
#> 6         0.2                                                     <NA>
#> 7         0.2                                                     <NA>
#> 8         0.2                                                     <NA>
#> 9          NA                                                     <NA>
#> 10         NA                                      convergence is slow
#> 11         NA                                                bad input
#> 12         NA                                                     text
#> 13         NA                                                     <NA>
#>                                                                  news no_news
#> 1                                                                <NA>    TRUE
#> 2                                                                <NA>    TRUE
#> 3  `check_input()` now requires character input and errors otherwise.   FALSE
#> 4                                                                <NA>    TRUE
#> 5                                                                <NA>    TRUE
#> 6              `estimate()` returns a main estimate of 0.6 (was 0.5).   FALSE
#> 7              `estimate()` returns a main estimate of 0.6 (was 0.5).   FALSE
#> 8              `estimate()` returns a main estimate of 0.6 (was 0.5).   FALSE
#> 9                                                                <NA>    TRUE
#> 10                                                               <NA>    TRUE
#> 11                                                               <NA>    TRUE
#> 12                                                               <NA>    TRUE
#> 13                                                               <NA>    TRUE
#>    accepted accepted_reason
#> 1     FALSE            <NA>
#> 2     FALSE            <NA>
#> 3     FALSE            <NA>
#> 4     FALSE            <NA>
#> 5     FALSE            <NA>
#> 6     FALSE            <NA>
#> 7     FALSE            <NA>
#> 8     FALSE            <NA>
#> 9     FALSE            <NA>
#> 10    FALSE            <NA>
#> 11    FALSE            <NA>
#> 12    FALSE            <NA>
#> 13    FALSE            <NA>
# }
```
