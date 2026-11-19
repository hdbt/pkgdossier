# Write the comparison as a short Markdown summary

A summary for a pull-request comment or a chat message: the version
pair, how many steps were compared, the differences by kind, the most
severe differences with their NEWS candidates, the steps that error
under both versions, the determinism check, and a link to the full
report when `report_url` is given. The first line is the HTML comment
`<!-- pkgdossier -->`, so a bot can find and update its own comment.

## Usage

``` r
write_dossier_md(x, path = NULL, report_url = NULL, max_rows = 20L)
```

## Arguments

- x:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- path:

  File to write (its folder is created if needed), or `NULL` to return
  the text.

- report_url:

  Optional link to the full report (for example the workflow run that
  holds it as an artifact).

- max_rows:

  Most severe differences listed at most.

## Value

The Markdown text (a single string) when `path` is `NULL`, otherwise
`path`, invisibly.

## Details

The template
`system.file("github", "pkgdossier.yaml", package = "pkgdossier")` is a
GitHub Actions workflow that runs a dossier on each pull request and
posts this summary as a comment.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
cat(write_dossier_md(cmp))
#> <!-- pkgdossier -->
#> ### pkgdossier: udfixture 1.0.0 -> 1.1.0
#> 
#> 3 scenario(s), 28 step(s) compared, 2 not run. **24 difference(s)** in 23 step(s). 18 of them in steps no NEWS bullet names.
#> 
#> | Kind | Severity | Differences | Steps |
#> |---|---:|---:|---:|
#> | unstable | 0 | 1 | 1 |
#> | error_new | 1 | 1 | 1 |
#> | field_removed | 1 | 1 | 1 |
#> | argument_removed | 1 | 1 | 1 |
#> | argument_new_required | 1 | 1 | 1 |
#> | condition_class_changed | 2 | 2 | 2 |
#> | value_moved | 2 | 4 | 4 |
#> | warning_new | 2 | 1 | 1 |
#> | default_changed | 2 | 1 | 1 |
#> | output_changed | 3 | 3 | 3 |
#> | plot_changed | 3 | 1 | 1 |
#> | slower | 3 | 1 | 1 |
#> | faster | 3 | 1 | 1 |
#> | warning_gone | 4 | 1 | 1 |
#> | field_added | 4 | 1 | 1 |
#> | error_fixed | 4 | 1 | 1 |
#> | argument_added | 4 | 1 | 1 |
#> | export_added | 4 | 1 | 1 |
#> 
#> #### Most severe (severity 0-2)
#> 
#> Identical changes in several steps are listed once, with the number of steps.
#> 
#> | Kind | Where | 1.0.0 | 1.1.0 | NEWS |
#> |---|---|---|---|---|
#> | unstable | api/noisy | differs between runs | differs between runs | none |
#> | field_removed | api/result `res$b` | - | - | none |
#> | error_new | api/check `error` | - | `x` must be character | `check_input()` now requires character input and errors o... |
#> | argument_new_required | (namespace)/extend_result `keep` | - | (required) | none |
#> | argument_removed | (namespace)/warn_gone `verbose` | TRUE | - | none |
#> | value_moved | `est$main` in 2 steps | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
#> | value_moved | ex_estimate/ex-02 `(value)` | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
#> | warning_new | api/warn_new `warning` | - | results may be unstable | none |
#> | condition_class_changed | api/warn_class `warning` | simpleWarning/warning/condition | slowWarning/warning/condition | none |
#> | condition_class_changed | api/err_class `error` | simpleError/error/condition | inputError/error/condition | none |
#> | value_moved | api/label `lab` | alpha | beta | none |
#> | default_changed | (namespace)/report `digits` | 2 | 3 | none |
#> 
#> Coverage: the scenarios use 17 of 18 exported functions. Not used: `new_helper`.
#> 
#> Scenario problems (error under both versions): api/err_class.
#> 
#> Not compared, because two runs of one version disagree: 1.0.0 api/noisy; 1.1.0 api/noisy.
#> 
#> <sub>pkgdossier 0.1.0, R version 4.6.2 (2026-10-29), abba runs, 3 timed repeat(s) per timed step.</sub>
# }
```
