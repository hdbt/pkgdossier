# Write the comparison as JSON

The JSON holds everything the report shows, as data. Its JSON Schema
ships with the package:
`system.file("schema", "dossier.schema.json", package = "pkgdossier")`.
Its top level:

## Usage

``` r
write_dossier_json(x, path)
```

## Arguments

- x:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- path:

  File to write; its folder is created if needed.

## Value

`path`, invisibly.

## Details

- `schema` (`"pkgdossier"`) and `schema_version` (`"0.1.0"`);

- `meta`: package, version labels, the provenance of both versions (as
  recorded by
  [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)),
  the run plan, the environment of the first run of each version (R
  version, dependency versions, machine, seed, repeats), machine load,
  the determinism check, the comparison's tolerances, and `news` (the
  NEWS file read, a note, and the bullets after the baseline's version);

- `differences`: one record per labelled difference, with the columns of
  [`differences()`](https://hdbt.github.io/pkgdossier/reference/differences.md);
  `differences_grouped`: one record per distinct change, as
  `differences(group = TRUE)`;

- `scenarios`: per scenario its `id`, `title`, `source`, `notes`,
  `not_run` chunks and `steps`. Each step holds `status`, `kinds`, the
  code, both versions' errors (`error`, `error_class`), `warnings`,
  console `transcript`, line diffs (`transcript_diff`, `printed_diff`:
  rows of `[op, base, cand]` with op `=`, `~`, `-` or `+`), `values`
  (numbers compared, changed, tiny, only on one side), `struct` (element
  paths only in one version), `time` (median, min, max and number of
  timings per version), `plot` (whether the images differ, and the image
  files relative to the work folder), `news` (candidate NEWS bullets)
  and `news_functions` (the package functions the step uses).

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
json <- write_dossier_json(cmp, file.path(tempdir(), "dossier.json"))
names(jsonlite::fromJSON(json, simplifyVector = FALSE))
#> [1] "schema"              "schema_version"      "meta"               
#> [4] "differences"         "differences_grouped" "scenarios"          
# }
```
