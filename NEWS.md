# pkgdossier 0.1.0

First release.

* `dossier()` describes a comparison of two versions of a package: the baseline
  from CRAN (current or archived), the version installed in your library
  (`installed_version()`, fetched from CRAN as source), a tarball, a git ref or a
  folder, and the candidate likewise. Scenarios come from the baseline's vignettes
  (`from_vignettes()`), its help-page examples (`from_examples()`) and scenario files
  written with `scenario()` and `step()`.
* `prepare_versions()` builds both versions from source and installs each into its
  own library, recording their provenance; dependencies come from the current
  library (`deps_shared()`), at their current CRAN versions (`deps_cran()`), or as
  CRAN had them on the baseline's release date (`deps_snapshot()`).
  `run_scenarios()` runs the scenarios under each version in its own R process,
  twice per version in ABBA order, with run and per-step time limits (300 s for one
  execution of a step by default); a step that runs past its limit or crashes R is
  recorded as an error and the run goes on without it. Runs are cached and reused while nothing that shapes them changes.
  `run_dossier()` runs every stage; from a package's folder, `run_dossier()` with
  no arguments makes the dossier of that folder against its CRAN release, opens the
  report and prints a verdict, and says what to write instead when it cannot start.
* `compare_runs()` labels each difference with one of twenty kinds: new and fixed
  errors and warnings, changed condition classes, moved numbers, removed and added
  elements, changed output and plots (with the share of changed pixels), slower and
  faster steps, unstable steps, and changes to exported functions' signatures. It
  attaches the candidate's NEWS bullets that name a function each step uses, and
  records which exported functions and NEWS bullets the scenarios do not exercise.
* `print()`, `summary()` and `differences()` give the results as text and data;
  `write_dossier_html()` writes a standalone HTML report, `write_dossier_json()` JSON
  with a published schema, and `write_dossier_md()` a summary for a pull-request
  comment. A GitHub Actions workflow template posts it.
* `accept_differences()` records differences already read and found intended, and
  `check_differences()` fails a CI job when others remain.
* `example_dossier()` runs all of this on a small bundled package.
