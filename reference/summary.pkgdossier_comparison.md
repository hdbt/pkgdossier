# One row per step of a comparison

One row per step of a comparison

## Usage

``` r
# S3 method for class 'pkgdossier_comparison'
summary(object, ...)
```

## Arguments

- object:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- ...:

  Unused.

## Value

A data frame with one row per step: `scenario`, `step`, `label`,
`status` (`"same"`, `"changed"`, `"unstable"`, `"error_new"`,
`"error_fixed"`, `"error_both"` or `"not_run"`), `kinds` (the kinds of
difference, comma separated), `n` (number of differences), `news`
(number of candidate NEWS bullets naming a function the step uses), and
the median elapsed seconds under each version.
