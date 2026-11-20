<!-- The site's homepage; README.md stays the page on GitHub. Keep the HTML blocks
free of indentation and blank lines inside a line of links: pandoc reads markdown
between HTML tags. The figures in gallery/ are drawn by pkgdown/gallery.R. -->

<div class="md-hero">

<div class="md-hero-eyebrow">Upgrade checks for R packages</div>

<h1 class="md-hero-title">See what your users meet after an upgrade</h1>

<div class="md-hero-lead">pkgdossier runs the code users learned from your package's release, its vignettes and help-page examples, unchanged under that release and under the new version, each in its own library and R process. It reports what users meet after upgrading: new errors and warnings, changed output, moved numbers, removed fields, changed plots and slower steps, each with a mechanical label.</div>

<div class="md-hero-actions">
<a class="md-btn md-btn-primary" href="articles/pkgdossier.html">Get started</a>
<a class="md-btn md-btn-secondary" href="#gallery">See the gallery</a>
</div>

<div class="md-hero-install">`pak::pak("hdbt/pkgdossier")`</div>

</div>

<div class="md-hero-figure">
<a href="gallery/report-differences.png"><img src="gallery/report-differences.png" width="1085" height="702" alt="The Differences section of a pkgdossier report: counts of each kind of difference, then a table listing each difference with its step, where it is, and the values under version 1.0.0 and 1.1.0."></a>
<div class="md-hero-figure-caption">The report for `example_dossier()`, a tiny package bundled with pkgdossier in two versions with one planted difference of each kind.</div>
</div>

## One call

In your package's folder, `run_dossier()` compares the folder with the package's
CRAN release. It installs both versions, runs the release's vignettes and help-page
examples under each, opens the HTML report and prints a summary that starts with a
verdict:

```r
pkgdossier::run_dossier()
```

To try it without network access, run the bundled example:

```r
library(pkgdossier)
cmp <- run_dossier(example_dossier())
# what breaks code or moves results
differences(cmp, max_severity = 2)
```

## Gallery {#gallery}

What the report shows for `example_dossier()`, drawn from the same comparison. Select
a figure to open it at full size.

<div class="md-gallery">
<div class="md-gallery-item"><a href="gallery/differences-by-kind.svg"><img src="gallery/differences-by-kind.svg" width="648" height="403" loading="lazy" alt="Bar chart of the example's differences by kind, from unstable and error new to export added, coloured by severity."><span class="md-gallery-caption"><strong>Every difference, labelled</strong>The differences by kind, coloured by the severity the report sorts them by.</span></a></div>
<div class="md-gallery-item"><a href="gallery/plot-pair.svg"><img src="gallery/plot-pair.svg" width="648" height="432" loading="lazy" alt="The same scatter plot drawn under version 1.0.0 in black and under 1.1.0 in red, and a third panel marking the pixels that differ."><span class="md-gallery-caption"><strong>Plots, before and after</strong>The same plotting code under each version, and the pixels that differ.</span></a></div>
<div class="md-gallery-item"><a href="gallery/printed-output.svg"><img src="gallery/printed-output.svg" width="648" height="403" loading="lazy" alt="A table of changed printed output, console messages, errors and warnings, with the text under 1.0.0 beside the text under 1.1.0."><span class="md-gallery-caption"><strong>What users read</strong>Printed output, console messages, errors and warnings that changed.</span></a></div>
<div class="md-gallery-item"><a href="gallery/steps-map.svg"><img src="gallery/steps-map.svg" width="648" height="403" loading="lazy" alt="One tile per step of the three scenarios, coloured by the most severe difference in the step, grey where nothing changed."><span class="md-gallery-caption"><strong>Every step at a glance</strong>Each step of the three scenarios, coloured by its most severe difference.</span></a></div>
<div class="md-gallery-item"><a href="gallery/news-coverage.svg"><img src="gallery/news-coverage.svg" width="648" height="403" loading="lazy" alt="Stacked bars by severity: differences in steps that a NEWS bullet names, and differences in steps that no NEWS bullet names."><span class="md-gallery-caption"><strong>Checked against NEWS</strong>Which differences a NEWS bullet names, and which no bullet mentions.</span></a></div>
<div class="md-gallery-item"><a href="gallery/timings.svg"><img src="gallery/timings.svg" width="648" height="403" loading="lazy" alt="Median and range of the timings of each step under both versions; one step became slower and one faster."><span class="md-gallery-caption"><strong>Run time per step</strong>Each version's timings per step; only consistent changes are labelled.</span></a></div>
</div>

## Guides

| Guide | What it covers |
|:---|:---|
| [Getting started](articles/pkgdossier.html) | A first dossier on the bundled example: run it, read the differences, check them against NEWS. |
| [Before a release](articles/before-a-release.html) | Run the dossier on your package, read the verdict, decide about each difference and record the decisions. |
| [On pull requests](articles/on-pull-requests.html) | The GitHub Actions workflow that comments on each pull request and fails when a severe change is neither in NEWS nor accepted. |
| [Writing scenarios](articles/writing-scenarios.html) | Code your users run that neither the vignettes nor the examples show: the README, answers to issues, analyses in papers. |
| [Baselines and dependencies](articles/baselines-and-dependencies.html) | Other baselines than the CRAN release, packages not on CRAN, and the dependency versions both versions run against. |

## How it differs

A package's tests check that each version is consistent with itself, so a change in
a default, an estimate or a printed summary passes them as long as the new code
agrees with itself. Snapshot tests catch only what a maintainer chose to pin.
`R CMD check` and reverse-dependency checks report whether code runs, not what it
now returns.

Other tools compare other things. packageDiff, pkgdiff and diffify compare
functions, arguments, dependencies and NEWS between two versions without running any
code; revdepcheck runs `R CMD check` on reverse dependencies and reports whether each
passes; waldo compares two R objects. pkgdossier runs the released version's
user-facing code under both versions and reports, step by step, what changed:

- Both versions are built from source, installed in their own libraries and run in
  fresh R processes, twice each in the order baseline, candidate, candidate,
  baseline. A step whose results differ between two runs of the same version is set
  aside as unstable rather than reported as a change.
- Values that change from run to run for reasons unrelated to the package, such as
  temporary paths and memory addresses, are masked. Numbers are compared with a
  relative tolerance, and printed output whose only change is digits within it is
  not labelled.
- Each difference gets one of twenty kinds and a severity. Whether it is intended is
  left to you: for each one you get the evidence and the NEWS bullets that name a
  function the step uses.
- Exports and function signatures are compared as well, and the summary lists the
  exported functions and NEWS bullets that no scenario exercises.
- Results come back as data, as JSON with a published schema and as a standalone
  HTML report. A Markdown summary and a GitHub Actions workflow bring them to pull
  requests.

## Citation

Bulut H (2026). *pkgdossier: Compare What Users Meet Before and After a Package
Upgrade*. R package version 0.1.0, <https://github.com/hdbt/pkgdossier>.

`citation("pkgdossier")` gives the same entry, with a BibTeX version.
