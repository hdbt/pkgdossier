# Writing scenarios

By default a dossier runs the code users learned from the release: its
vignettes and its help-page examples. Users also run code that neither
shows, such as the README’s example, the answer to an issue, or the
analysis in a paper that uses the package. A scenario file adds that
code to the dossier. This article covers when you need one, how to write
it, and what makes a scenario useful evidence.

## What the defaults leave out

[`from_vignettes()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
makes each vignette a scenario and each R chunk a step.
[`from_examples()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
makes each help page with examples a scenario and each top-level
expression a step. Neither runs:

- example code in `\dontrun{}`, or vignette chunks with `eval = FALSE`;
  these are listed as not run;
- the computation behind vignettes that read stored results
  ([`readRDS()`](https://rdrr.io/r/base/readRDS.html),
  [`load()`](https://rdrr.io/r/base/load.html), `cache = TRUE`): they
  run, but their numbers come from the file, and the report flags them;
- functions no vignette or example calls. The summary’s coverage line
  lists the exported functions the scenarios do not use, and says how
  many NEWS bullets match no step;
- code users run that your documentation does not show.

To run only some vignettes or help pages, name them:
`from_examples(which = c("fit_model", "plot_model"))`.

## A scenario file

A scenario file is an R file of
[`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md)
calls, each with its
[`step()`](https://hdbt.github.io/pkgdossier/reference/step.md)s:

``` r

# dev/dossier/scenarios.R
scenario("readme", title = "The README's example", source = "README.md",
  step("data", "setup", d <- subset(mtcars, cyl > 4)),
  step("fit", "fit", fit <- fit_model(mpg ~ wt, data = d)),
  step("estimates", "print", estimates(fit), values = TRUE),
  step("plot", "plot", plot(fit), w = 6, h = 4)
)
```

Here `fit_model()` and `estimates()` stand for your package’s functions;
the package is attached before the scenarios run, as
[`library(mypkg)`](https://rdrr.io/r/base/library.html) would. Keep the
file in your repository, in a folder that `.Rbuildignore` excludes, and
add it to the dossier’s scenarios, from the package’s folder:

``` r

d <- dossier("mypkg", scenarios = list(from_vignettes(), from_examples(),
                                       scenario_file("dev/dossier/scenarios.R")))
cmp <- run_dossier(d)
```

The path is read when the dossier runs, relative to the working
directory. Then:

- every
  [`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md)
  the file creates is used, in the order created. The code in each
  [`step()`](https://hdbt.github.io/pkgdossier/reference/step.md) is not
  run when the file is read: it is kept and run unchanged under each
  version, in a fresh R process;
- the steps of a scenario share one environment, so later steps see what
  earlier ones created. Each scenario starts afresh: options, attached
  packages, environment variables and the working directory that one
  scenario sets are put back before the next;
- the seed is set before every step;
- scenarios from a file run from the run’s own folder, not from your
  package’s folder.

Each step has a kind:

| Kind | What the step adds |
|----|----|
| `"setup"` | runs, but is not reported: data preparation |
| `"run"` | console output, warnings, errors and plots, compared |
| `"fit"` | as `"run"`, and timed with repeats, for the `slower` and `faster` labels |
| `"print"` | as `"run"`, and the printed form of its value, compared on its own |
| `"plot"` | as `"run"`, with plots drawn at `w` by `h` inches |

`values = TRUE` makes a step collect every number and short string in
its visible value and in any object it assigns at top level, with the
element names users’ code might read (`fit$estimates$se`). Moved numbers
(`value_moved`) and removed and added elements (`field_removed`,
`field_added`) are found from these; without them, a step’s results are
compared only as printed text. Objects of heavy classes, such as model
fits and plots, are not walked (see
[`default_skip_classes()`](https://hdbt.github.io/pkgdossier/reference/default_skip_classes.md)):
collect what users read from them, `coef(fit)` or `summary(fit)`, in a
step of its own. Vignette chunks and examples collect values by default;
the steps you write collect them only when you say so.

## One change, three steps

The small package bundled with pkgdossier, `udfixture`, has a function
`make_result()` that loses its element `b` in version 1.1.0. Here is a
scenario file that meets this change in three ways, plus one step that
uses an argument only 1.1.0 has:

``` r

scenario("results", title = "What users read from a result",
  step("assigned", "run", res <- make_result()),
  step("printed", "print", make_result()),
  step("collected", "run", res <- make_result(), values = TRUE),
  step("new_api", "plot", draw(col = "blue"))
)
```

With the file saved as `scenarios.R` in the temporary folder, a dossier
of the two bundled versions runs it.
[`tarball()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
takes a source tarball on disk:

``` r

fixture <- function(version) {
  system.file("extdata", paste0("udfixture_", version, ".tar.gz"), package = "pkgdossier")
}
d <- dossier("udfixture",
  base = tarball(fixture("1.0.0")),
  candidate = tarball(fixture("1.1.0")),
  scenarios = scenario_file(file.path(tempdir(), "scenarios.R")),
  reps = 0
)
cmp <- run_dossier(d, html = NULL, json = NULL, open = FALSE, quiet = TRUE)
summary(cmp)[, c("step", "status", "kinds")]
#>        step      status          kinds
#> 1  assigned        same               
#> 2   printed     changed output_changed
#> 3 collected     changed  field_removed
#> 4   new_api error_fixed    error_fixed
```

The same change, found three ways:

- **`assigned`**: the result is assigned and never shown, so there is
  nothing to compare. The step is the same under both versions.
- **`printed`**: the printed list lacks `$b`. The change is found, as
  changed output (severity 3).
- **`collected`**: with `values = TRUE`, `res$b` is found missing:
  `field_removed`, severity 1, which is what it is for users whose code
  reads `res$b`.

And **`new_api`**: `draw(col = )` exists only in 1.1.0, so under 1.0.0
the step errors with “unused argument”, and the dossier reports an error
the candidate fixed. That is evidence of nothing. A scenario runs under
both versions, so write it with what the release has.

## What makes a good scenario

- **Users’ code, unchanged.** Copy it as users wrote it, and say where
  it comes from in `source`, which the report shows.
- **The release’s functions only.** Code that needs the new version
  shows up as `error_fixed`, as above.
- **Values where users read results.** Use `values = TRUE` on the steps
  whose results users’ code takes apart.
- **One step per thing a user looks at.** Differences are reported per
  step, and NEWS bullets are matched to the functions each step uses, so
  smaller steps place both more precisely.
- **Repeatable.** Avoid the clock and the network. Files in your
  repository are not in the run’s folder: read data shipped with the
  package through
  `system.file("extdata", "survey.csv", package = "mypkg")`, or make it
  in a `"setup"` step.

A step that errors under both versions is listed as a scenario problem:
it tests nothing, so fix the scenario.

## Trying a scenario file

While you write the file, run only it, without timed repeats:

``` r

run_dossier(dossier("mypkg", scenarios = scenario_file("dev/dossier/scenarios.R"),
                    reps = 0))
```

The installed versions are reused between calls; changing the file runs
the scenarios again.
