# pkgdossier <img src="man/figures/logo.png" align="right" height="139" alt="pkgdossier logo" />

[![R-CMD-check](https://github.com/hdbt/pkgdossier/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hdbt/pkgdossier/actions/workflows/R-CMD-check.yaml)

pkgdossier runs the code users learned from a package's released version (its
vignettes and help-page examples, or scenario scripts) unchanged under that release
and under a candidate version, each installed in its own library and run in its own
R process, and reports what a user meets after upgrading: new errors and warnings,
changed printed output, moved numbers, removed or added object fields, changed
plots, and changes in run time.

Each difference gets a mechanical label (`error_new`, `field_removed`,
`value_moved`, `output_changed`, `plot_changed`, `slower`, ...). Whether a change is
intended, undocumented or a defect is left to the reader.

In your package's folder, one call:

```r
pkgdossier::run_dossier()
```

compares the folder with the package's CRAN release. It installs both, runs the
release's vignettes and help-page examples under each, compares everything they
produce, opens the HTML report and prints a summary that starts with a verdict.
Before anything is downloaded it asks, and it says what is wrong when it cannot
start: not a package folder, no CRAN release yet (it names the git tags to use
instead), a dependency missing. A step that hangs is stopped after 5 minutes and
recorded. Call it again after a fix: only the changed version is rebuilt and rerun.

Every setting has one home. What is compared and how the runs are made go to
`dossier()`; how the runs go stays with `run_dossier()`; the tolerances go to
`compare_runs()` through `run_dossier()`:

```r
run_dossier(dossier("mypkg", base = cran_version("0.2.1")))   # another baseline
run_dossier(dossier("mypkg", reps = 0), workers = 2)           # a quick look, no timing labels
run_dossier(tol = 1e-3)                                        # a looser tolerance

d <- dossier(
  pkg       = "mypkg",
  base      = cran_release(),                 # or cran_version("0.2.1"), tarball("...")
  candidate = git_ref("path/to/mypkg", "main"), # or local_path("path/to/mypkg")
  scenarios = list(from_vignettes(),          # the baseline's vignettes
                   from_examples(),           # its help-page examples
                   scenario_file("dev/dossier/scenarios.R")),
  reps      = 3,
  deps      = deps_shared()                   # or deps_cran(), deps_snapshot()
)
cmp <- run_dossier(d)    # the report and the JSON go into the work folder
```

A setting given in the wrong place is an error that writes out the right call.

As a user of a package, see what an upgrade would change for you before you
install it: the version you have against the current release, both built from
CRAN's sources.

```r
run_dossier(dossier("ggplot2", base = installed_version(), candidate = cran_release()))
```

Or stage by stage, each caching its work in the work folder (after a call to
`run_dossier()`, `cmp$dossier` is the dossier it used):

```r
prepare_versions(d)      # download / export / build / install; provenance
run_scenarios(d)         # base, candidate, candidate, base, each in a fresh R process
cmp <- compare_runs(d)
cmp                      # counts by kind of difference
summary(cmp)             # one row per step
differences(cmp, kind = "value_moved")
write_dossier_html(cmp, dir = file.path(d$work, "page"))
write_dossier_json(cmp, file.path(d$work, "dossier.json"))
```

Everything that shapes the runs is set in `dossier()`; the stages take only how
they run (time limits, parallel runs, whether to ask before downloading), and
`compare_runs()` takes the comparison's tolerances, so it can be called again on
the stored runs at no cost.

`vignette("pkgdossier")` walks through a full dossier. To try it without network access, `example_dossier()` describes a dossier over a
tiny package bundled with pkgdossier, in two versions with one planted difference of
each kind:

```r
d <- example_dossier()
prepare_versions(d)
run_scenarios(d)
compare_runs(d)
```

Scenario files use `scenario()` and `step()`:

```r
scenario("basics", title = "Linear model", source = "README",
  step("setup", "setup", d <- head(mtcars, 20)),
  step("fit", "fit", fit <- lm(mpg ~ wt, data = d)),
  step("coef", "print", coef(fit), values = TRUE),
  step("plot", "plot", plot(d$wt, d$mpg), w = 5, h = 4)
)
```

By default the scenarios are the baseline's vignettes and help-page examples
(`from_vignettes()` and `from_examples()`); scenario files add code neither covers.

## On pull requests

`write_dossier_md()` writes a short Markdown summary for a pull-request comment. The
package ships a GitHub Actions workflow that runs a dossier of the CRAN release
against each pull request, uploads the report and posts the summary:

```r
file.copy(system.file("github", "pkgdossier.yaml", package = "pkgdossier"),
          ".github/workflows/pkgdossier.yaml")
```

Differences you have read and found intended can be accepted with
`accept_differences()`, which writes them to a CSV file of rules; pass that file to
`compare_runs()` or `run_dossier()` as `accept`, and later summaries list only what
nobody has looked at yet. The workflow fails its check, through
`check_differences()`, when severe differences remain that are neither accepted nor
named by NEWS.

Nothing is downloaded until `prepare_versions()`, which says what it fetches and
where. Everything is written to the work folder (`tempdir()` by default).
