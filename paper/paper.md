---
title: 'pkgdossier: what users of an R package meet after an upgrade'
tags:
  - R
  - package maintenance
  - regression testing
  - software evolution
  - reproducibility
authors:
  - name: Hamid Bulut
    affiliation: 1
    # orcid: add the author's ORCID here
affiliations:
  - name: "Affiliation to be filled in by the author"
    index: 1
date: 6 November 2026
bibliography: paper.bib
---

<!-- Draft for the Journal of Open Source Software. Before submitting: fill in the
affiliation and ORCID, make the repository public, and archive a release. -->

# Summary

When an R package changes, its users meet the change through the code they learned
from it: the vignettes and help-page examples of the version they installed.
`pkgdossier` runs that code, unchanged, under the released version and under a
candidate version, each built from source, installed in its own library and run in
its own R process, and reports what a user meets after upgrading: new errors and
warnings, changed printed output, moved numbers, removed or added elements of
returned objects, changed plots, changes in run time, and changes to the signatures
of exported functions. Each difference is labelled mechanically with one of twenty
kinds and a severity. Whether a difference is intended is left to the reader, who is
given the evidence and, for each difference, the candidate's NEWS entries that name
a function the step uses. Results are returned as data, written as JSON with a
published schema, and rendered as a standalone HTML report; a Markdown summary and a
GitHub Actions workflow bring them to pull requests.

# Statement of need

Changes that break downstream code are a recurring cost of software ecosystems
[@bogart2016; @raemaekers2017], and CRAN's practice of keeping one current version of
every package makes them reach users quickly [@decan2016]. A package's own tests do
not see these changes well: they check that each version is consistent with itself,
so a self-consistent change in a default, an estimate or a printed summary passes
them. Snapshot tests [@testthat; @vdiffr] catch only what a maintainer chose to
pin.

Existing tools compare other things. `packageDiff` [@packageDiff], `pkgdiff`
[@pkgdiff] and diffify [@diffify] compare functions, arguments, dependencies and NEWS
between versions without running any code. `revdepcheck` [@revdepcheck] runs
`R CMD check` on reverse dependencies and reports whether each passes. `waldo`
[@waldo] compares two R objects. None of them runs the released version's user-facing
code under both versions and reports, step by step, what changed. `pkgdossier` is
for maintainers before a release, for continuous integration on pull requests, and
for users and reviewers deciding whether to upgrade.

# How it works

`dossier()` describes a comparison: where each version comes from (a current or
archived CRAN release, a tarball, a git ref or a folder) and which code to run (the
baseline's vignettes, its help-page examples, and scenario files written with
`scenario()` and `step()`). `prepare_versions()` builds both versions from source,
refusing binary builds, and records their provenance. `run_scenarios()` runs every
scenario under each version in a fresh process launched with `callr` [@callr],
capturing each step with `evaluate` [@evaluate]; the versions run twice each in
ABBA order, so steps whose results differ between two runs of the same version are
found and set aside rather than reported as changes. Values that differ from run to
run for reasons unrelated to the package (temporary paths, memory addresses,
`system.time()` output) are masked, numbers are compared with a relative tolerance,
and printed output whose only change is digits within that tolerance is not
labelled. `compare_runs()` labels the differences, groups identical changes found in
several steps, compares the exports and function signatures of the two versions, and
records which exported functions and NEWS entries no scenario exercises. Each stage
caches its work, so re-running after changing the candidate repeats only the
candidate's runs. A file of accepted differences lets continuous integration report
only what nobody has read yet.

# Example

`pkgdossier` was run on three CRAN upgrades, each with the baseline's vignettes and
help-page examples as scenarios. For jsonlite 1.8.8 to 2.0.0 [@jsonlite], the 67
steps showed no difference, while the coverage report noted that six of the eight
NEWS entries match no step: changes the scenarios do not exercise. For lme4 2.0-1 to 2.1-0
[@lme4] (555 steps, six minutes), the 160 differences include a likelihood-ratio
p-value in the `glmer` example that moves from 0.002152404 to 0.002153053, matched to
the NEWS entry stating that `glmer()` now refreshes its working weights before
computing the Laplace approximation. For MAIHDA 0.2.1 to 0.3.0, an implementation of
multilevel analysis of individual heterogeneity and discriminatory accuracy
[@evans2018; @merlo2018] (245 steps, five minutes), 1,764 differences group into 445
distinct changes; among them, the proportional change in variance moves from 0.77 to
0.60 in four steps, each matched first to the NEWS entry on REML-type variances. Each
run also changed `pkgdossier` itself: these packages exposed noise sources and gaps
that a bundled test package with planted differences did not.

# Acknowledgements

<!-- To be written by the author. -->

# References
