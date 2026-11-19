# Stop when differences nobody accepted remain

For continuous integration: stops with an error that lists the
differences of the comparison that are not accepted (see
[`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md))
and match the filters, so the job fails; returns `TRUE` invisibly when
there are none.

## Usage

``` r
check_differences(
  x,
  kind = NULL,
  max_severity = if (is.null(kind)) 1L,
  no_news = NULL
)
```

## Arguments

- x:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- kind:

  Consider only these kinds.

- max_severity:

  Consider differences of this severity or more severe (1 is the most
  severe: new errors, removed elements and exports). Defaults to 1, or,
  when `kind` is given, to no limit: the kinds named are checked
  whatever their severity.

- no_news:

  `TRUE` considers only differences no NEWS bullet names.

## Value

`TRUE`, invisibly, when no such difference remains.

## Details

The filters are those of
[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md),
in the same order.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
try(check_differences(cmp, max_severity = 1))
#> Error : 5 difference(s) of severity 1 or more severe are not accepted:
#>   unstable api/noisy 
#>   field_removed api/result res$b
#>   error_new api/check error
#>   argument_new_required (namespace)/extend_result keep
#>   argument_removed (namespace)/warn_gone verbose
#> Accept the intended ones with accept_differences().
# }
```
