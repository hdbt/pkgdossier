# Write the comparison as a standalone HTML report

Writes a folder that opens in any browser: `dossier.html`, `data.js`
(the same data as
[`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)),
`notes.js` (the hand-written findings) and `img/` with the plot pairs.
The page shows the provenance of both versions, the labelled
differences, and per scenario the timings, side-by-side diffs of console
output and printed values, the numbers that moved, the element names
gained or lost, and the plot pairs with a pixel-difference view.

## Usage

``` r
write_dossier_html(x, dir, notes = NULL)
```

## Arguments

- x:

  An `pkgdossier_comparison` from
  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md).

- dir:

  Folder to write; created if needed.

- notes:

  Optional path to a notes file to copy into the folder as `notes.js`.

## Value

The path of `dossier.html`, invisibly.

## Details

The findings, per-scenario takeaways and extra method notes come from
`notes.js`, the one file written by hand; its format is documented in
the template the first call copies into the folder
(`system.file("report", "notes-template.js", package = "pkgdossier")`).
An existing `notes.js` in the folder is kept.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d, quiet = TRUE)
cmp <- compare_runs(d)
page <- write_dossier_html(cmp, dir = file.path(tempdir(), "dossier-page"))
# open it with utils::browseURL(page)
# }
```
