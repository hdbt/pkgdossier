# Package index

## Describe a dossier

Where the two versions come from and which code to run. Nothing is
fetched or run until the stages below.

- [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md)
  : Describe an upgrade dossier
- [`cran_release()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  [`cran_version()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  [`installed_version()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  [`tarball()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  [`git_ref()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  [`local_path()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  : Describe where a version of the package comes from
- [`deps_shared()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  [`deps_cran()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  [`deps_snapshot()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  : Where the dependencies come from
- [`from_vignettes()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
  [`from_examples()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
  [`scenario_file()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
  : Where scenarios come from
- [`step()`](https://hdbt.github.io/pkgdossier/reference/step.md)
  [`scenario()`](https://hdbt.github.io/pkgdossier/reference/step.md) :
  Write scenarios by hand
- [`default_skip_classes()`](https://hdbt.github.io/pkgdossier/reference/default_skip_classes.md)
  : Classes skipped when collecting numbers
- [`example_dossier()`](https://hdbt.github.io/pkgdossier/reference/example_dossier.md)
  : A dossier over a small bundled package

## Run it

Each stage caches its work in the work folder; run_dossier() calls them
all.

- [`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
  : Make a dossier in one call
- [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
  : Fetch, build and install both versions
- [`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
  : Run the scenarios under both versions
- [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
  : Compare the runs and label every difference

## Read and share the results

- [`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md)
  : The labelled differences of a comparison
- [`summary(`*`<pkgdossier_comparison>`*`)`](https://hdbt.github.io/pkgdossier/reference/summary.pkgdossier_comparison.md)
  : One row per step of a comparison
- [`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md)
  : Write the comparison as a standalone HTML report
- [`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)
  : Write the comparison as JSON
- [`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
  : Write the comparison as a short Markdown summary

## Pull requests and continuous integration

- [`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)
  : Accept known differences
- [`check_differences()`](https://hdbt.github.io/pkgdossier/reference/check_differences.md)
  : Stop when differences nobody accepted remain
