# Where scenarios come from

- `from_vignettes()`: the vignettes of the baseline, read from the
  `vignettes/` folder of its source tarball. Each R chunk becomes a step
  that is run as in the vignette, with the chunk's `fig.width` and
  `fig.height` (or `fig.dim`, or the defaults the vignette sets with
  `knitr::opts_chunk$set()` or its output format) for plots. Chunks with
  `eval = FALSE` are listed as not run; an `eval` option that is an
  expression is evaluated in the vignette's environment when the chunk
  is reached. Every visible value is printed and its numbers collected,
  as is every object a chunk assigns at top level.

- `from_examples()`: the examples on the baseline's help pages, read
  from the `man/` folder of its source tarball as `R CMD check` reads
  them ([`tools::Rd2ex()`](https://rdrr.io/r/tools/Rd2HTML.html)). Each
  help page with examples is a scenario (`ex_<page>`) and each top-level
  expression a step. Code in `\donttest{}` is run, as
  `R CMD check --as-cran` runs it; code in `\dontrun{}` is not, and the
  scenario notes it. Examples run from the run's own folder.

- `scenario_file()`: an R file that creates scenarios with
  [`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md)
  and [`step()`](https://hdbt.github.io/pkgdossier/reference/step.md).
  Every scenario the file creates is used, in the order created.

## Usage

``` r
from_vignettes(which = NULL, time = TRUE, values = TRUE)

from_examples(which = NULL, time = FALSE, values = TRUE)

scenario_file(path)
```

## Arguments

- which:

  Vignette file names, or help-page file names for `from_examples()`
  (without extension), to use; `NULL` uses all.

- time:

  Time each chunk (each example expression) with repeats.

- values:

  Collect numbers and element names from each chunk (each example
  expression).

- path:

  Path to a scenario file.

## Value

An object of class `pkgdossier_scenario_source`.

## Details

Vignettes that read stored results
([`readRDS()`](https://rdrr.io/r/base/readRDS.html),
[`load()`](https://rdrr.io/r/base/load.html), `cache = TRUE`) are run as
they are and flagged in the report: their numbers do not test the
computation, so a scenario file is the better source for them.

## Examples

``` r
from_vignettes()
#> <pkgdossier scenario source> baseline vignettes
from_examples(which = c("fit_model", "plot_model"))
#> <pkgdossier scenario source> baseline help-page examples (fit_model, plot_model)
scenario_file("dev/dossier/scenarios.R")
#> <pkgdossier scenario source> scenario file dev/dossier/scenarios.R
```
