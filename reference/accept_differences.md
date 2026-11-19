# Accept known differences

Once a difference has been read and found intended (a fixed bug, a new
default that NEWS announces), it can be accepted, so that later
comparisons, the pull-request summary and
[`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md)
report only differences nobody has looked at yet. `accept_differences()`
appends rows of
[`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md)
to a CSV file of rules; pass that file to
[`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
(or
[`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md))
as `accept`.

## Usage

``` r
accept_differences(x, path, reason = NA_character_)
```

## Arguments

- x:

  A data frame of differences to accept, from
  [`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md).

- path:

  The CSV file of rules; created if needed, appended to otherwise.

- reason:

  Why these differences are accepted, kept with the rules.

## Value

`path`, invisibly.

## Details

A rule has the columns `kind`, `scenario`, `step`, `path`, `cand` and
`reason`. A difference is accepted when it matches every one of the
first five; an empty field or `*` matches anything, and `*` and `?` work
as wildcards inside a field (`step = "fit_*"`). The candidate's side
(`cand`) is part of the rule, so a number accepted at its new value
shows up again if it moves further; set it to `*` to accept any value.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
rules <- file.path(tempdir(), "accepted.csv")
accept_differences(differences(cmp, kind = "plot_changed"), rules,
                   reason = "points are red now, as NEWS says")
cmp <- compare_runs(d, accept = rules)
differences(cmp, accepted = TRUE)
#>   scenario step label         kind severity path       base       cand
#> 1    intro draw  draw plot_changed        3 plot 1 image(s) 1 image(s)
#>   rel_change                 detail news no_news accepted
#> 1         NA 0.22% of pixels differ <NA>    TRUE     TRUE
#>                    accepted_reason
#> 1 points are red now, as NEWS says
# }
```
