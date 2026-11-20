# Changelog

## pkgdossier (development version)

- The GitHub Actions workflow template no longer overwrites comments
  that other workflows post as `github-actions[bot]`, such as coverage
  reports. It used to edit the bot’s last comment on the pull request,
  whichever workflow had posted it; it now edits its own, found by the
  `<!-- pkgdossier -->` marker that
  [`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
  puts on the summary’s first line, and posts one when there is none.
  Repositories that copied the template should copy it again.

## pkgdossier 0.1.0

First release.

- [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md)
  describes a comparison of two versions of a package: the baseline from
  CRAN (current or archived), the version installed in your library
  ([`installed_version()`](https://hdbt.github.io/pkgdossier/reference/sources.md),
  fetched from CRAN as source), a tarball, a git ref or a folder, and
  the candidate likewise. Scenarios come from the baseline’s vignettes
  ([`from_vignettes()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)),
  its help-page examples
  ([`from_examples()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md))
  and scenario files written with
  [`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md)
  and [`step()`](https://hdbt.github.io/pkgdossier/reference/step.md).
- [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
  builds both versions from source and installs each into its own
  library, recording their provenance; dependencies come from the
  current library
  ([`deps_shared()`](https://hdbt.github.io/pkgdossier/reference/deps.md)),
  at their current CRAN versions
  ([`deps_cran()`](https://hdbt.github.io/pkgdossier/reference/deps.md)),
  or as CRAN had them on the baseline’s release date
  ([`deps_snapshot()`](https://hdbt.github.io/pkgdossier/reference/deps.md)).
  [`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
  runs the scenarios under each version in its own R process, twice per
  version in ABBA order, with run and per-step time limits (300 s for
  one execution of a step by default); a step that runs past its limit
  or crashes R is recorded as an error and the run goes on without it.
  Runs are cached and reused while nothing that shapes them changes.
  [`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
  runs every stage; from a package’s folder,
  [`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
  with no arguments makes the dossier of that folder against its CRAN
  release, opens the report and prints a verdict, and says what to write
  instead when it cannot start.
- [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
  labels each difference with one of twenty kinds: new and fixed errors
  and warnings, changed condition classes, moved numbers, removed and
  added elements, changed output and plots (with the share of changed
  pixels), slower and faster steps, unstable steps, and changes to
  exported functions’ signatures. It attaches the candidate’s NEWS
  bullets that name a function each step uses, and records which
  exported functions and NEWS bullets the scenarios do not exercise.
- [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html) and
  [`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md)
  give the results as text and data;
  [`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md)
  writes a standalone HTML report,
  [`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)
  JSON with a published schema, and
  [`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
  a summary for a pull-request comment. A GitHub Actions workflow
  template posts it.
- [`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)
  records differences already read and found intended, and
  [`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md)
  fails a CI job when others remain.
- [`example_dossier()`](https://hdbt.github.io/pkgdossier/reference/example_dossier.md)
  runs all of this on a small bundled package.
