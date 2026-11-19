# Write scenarios by hand

A scenario is a sequence of steps run in one environment, so later steps
see the objects earlier steps created. Use scenario files for code the
vignettes do not cover, or for vignettes that cannot simply run. Each
step's code is kept exactly as written and run unchanged under both
versions.

## Usage

``` r
step(
  id,
  kind = c("run", "setup", "fit", "print", "plot"),
  expr,
  label = id,
  values = FALSE,
  time = NULL,
  w = 7,
  h = 4.5
)

scenario(id, ..., title = id, source = "")
```

## Arguments

- id:

  Identifier: unique within its scenario (steps) or the dossier
  (scenarios).

- kind:

  Kind of step, see Details.

- expr:

  Code of the step, unevaluated. Wrap several lines in
  [`{ }`](https://rdrr.io/r/base/Paren.html): each top-level expression
  inside runs as if typed at the console.

- label:

  Label shown in the report.

- values:

  Collect numbers and element names (see Details).

- time:

  Time the step with repeats. Defaults to `TRUE` for `"fit"` steps.

- w, h:

  Figure size in inches for plots the step draws.

- ...:

  Steps (`scenario()`).

- title, source:

  Title of the scenario and where its code comes from, shown in the
  report.

## Value

`step()`: an `pkgdossier_step`; `scenario()`: an `pkgdossier_scenario`.

## Details

Kinds of step:

- `"setup"`: run, not reported (data preparation).

- `"run"`: run and reported (console output, warnings, errors, plots).

- `"fit"`: like `"run"`, and timed with repeats.

- `"print"`: the visible value is printed and its printed form compared
  on its own.

- `"plot"`: drawn to PNG at `w` x `h` inches.

Every step captures console output, warnings, errors and plots whatever
its kind. With `values = TRUE` the step also collects every number and
short string inside its visible value, and inside any object it assigns
at top level, keyed by path, plus the element names a user's code might
read (`x$foo$bar`).

## Examples

``` r
scenario("basics", title = "Linear model", source = "README",
  step("setup", "setup", d <- head(mtcars, 20)),
  step("fit", "fit", fit <- lm(mpg ~ wt, data = d)),
  step("coef", "print", coef(fit), values = TRUE),
  step("plot", "plot", plot(d$wt, d$mpg), w = 5, h = 4)
)
#> <pkgdossier scenario> basics: Linear model (4 steps)
#>   setup                    setup 
#>   fit                      fit   
#>   coef                     print 
#>   plot                     plot  
```
