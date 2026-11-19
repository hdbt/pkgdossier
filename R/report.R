#' Write the comparison as a standalone HTML report
#'
#' Writes a folder that opens in any browser: `dossier.html`, `data.js` (the same
#' data as [write_dossier_json()]), `notes.js` (the hand-written findings) and `img/`
#' with the plot pairs. The page shows the provenance of both versions, the labelled
#' differences, and per scenario the timings, side-by-side diffs of console output
#' and printed values, the numbers that moved, the element names gained or lost, and
#' the plot pairs with a pixel-difference view.
#'
#' The findings, per-scenario takeaways and extra method notes come from `notes.js`,
#' the one file written by hand; its format is documented in the template the first
#' call copies into the folder (`system.file("report", "notes-template.js", package =
#' "pkgdossier")`). An existing `notes.js` in the folder is kept.
#'
#' @param x An `pkgdossier_comparison` from [compare_runs()].
#' @param dir Folder to write; created if needed.
#' @param notes Optional path to a notes file to copy into the folder as `notes.js`.
#' @return The path of `dossier.html`, invisibly.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' page <- write_dossier_html(cmp, dir = file.path(tempdir(), "dossier-page"))
#' # open it with utils::browseURL(page)
#' }
#' @export
write_dossier_html <- function(x, dir, notes = NULL) {
  stopifnot(inherits(x, "pkgdossier_comparison"))
  dir.create(file.path(dir, "img"), recursive = TRUE, showWarnings = FALSE)
  copy_plot <- function(sid, step, files, side) {
    vapply(seq_along(files), function(k) {
      rel <- sprintf("img/%s__%s_%d_%s.png", sid, step, k, side)
      file.copy(files[k], file.path(dir, rel), overwrite = TRUE)
      rel
    }, "")
  }
  data <- dossier_data(x, plot_path = copy_plot)
  json <- to_json(data)
  writeLines(c("window.DOSSIER = ", json, ";"), file.path(dir, "data.js"), useBytes = TRUE)

  tpl <- system.file("report", "dossier.html", package = "pkgdossier", mustWork = TRUE)
  html <- readLines(tpl, warn = FALSE, encoding = "UTF-8")
  html <- gsub("__PKG__", html_escape(x$meta$pkg), html, fixed = TRUE)
  html <- gsub("__BASE_VERSION__", html_escape(x$meta$labels$base), html, fixed = TRUE)
  html <- gsub("__CAND_VERSION__", html_escape(x$meta$labels$cand), html, fixed = TRUE)
  page <- file.path(dir, "dossier.html")
  writeLines(enc2utf8(html), page, useBytes = TRUE)

  notes_out <- file.path(dir, "notes.js")
  if (!is.null(notes)) {
    if (normalizePath(notes, mustWork = TRUE) != normalizePath(notes_out, mustWork = FALSE)) {
      file.copy(notes, notes_out, overwrite = TRUE)
    }
  } else if (!file.exists(notes_out)) {
    file.copy(system.file("report", "notes-template.js", package = "pkgdossier", mustWork = TRUE), notes_out)
  }
  invisible(page)
}

#' Write the comparison as JSON
#'
#' The JSON holds everything the report shows, as data. Its JSON Schema ships with
#' the package: `system.file("schema", "dossier.schema.json", package = "pkgdossier")`.
#' Its top level:
#'
#' * `schema` (`"pkgdossier"`) and `schema_version` (`"0.1.0"`);
#' * `meta`: package, version labels, the provenance of both versions (as recorded
#'   by [prepare_versions()]), the run plan, the environment of the first run of
#'   each version (R version, dependency versions, machine, seed, repeats), machine
#'   load, the determinism check, the comparison's tolerances, and `news` (the NEWS
#'   file read, a note, and the bullets after the baseline's version);
#' * `differences`: one record per labelled difference, with the columns of
#'   [differences()]; `differences_grouped`: one record per distinct change, as
#'   `differences(group = TRUE)`;
#' * `scenarios`: per scenario its `id`, `title`, `source`, `notes`, `not_run` chunks
#'   and `steps`. Each step holds `status`, `kinds`, the code, both versions' errors
#'   (`error`, `error_class`), `warnings`, console `transcript`, line diffs
#'   (`transcript_diff`, `printed_diff`: rows of `[op, base, cand]` with op `=`, `~`,
#'   `-` or `+`), `values` (numbers compared, changed, tiny, only on one side),
#'   `struct` (element paths only in one version), `time` (median, min, max and
#'   number of timings per version), `plot` (whether the images differ, and the
#'   image files relative to the work folder), `news` (candidate NEWS bullets) and
#'   `news_functions` (the package functions the step uses).
#'
#' @param x An `pkgdossier_comparison` from [compare_runs()].
#' @param path File to write; its folder is created if needed.
#' @return `path`, invisibly.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' json <- write_dossier_json(cmp, file.path(tempdir(), "dossier.json"))
#' names(jsonlite::fromJSON(json, simplifyVector = FALSE))
#' }
#' @export
write_dossier_json <- function(x, path) {
  stopifnot(inherits(x, "pkgdossier_comparison"))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  work <- normalizePath(x$work, winslash = "/", mustWork = FALSE)
  rel <- function(sid, step, files, side) {
    f <- normalizePath(files, winslash = "/", mustWork = FALSE)
    sub(paste0("^", gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", work), "/"), "", f)
  }
  writeLines(to_json(dossier_data(x, plot_path = rel), pretty = TRUE), path, useBytes = TRUE)
  invisible(path)
}

# The comparison as plain lists ready for JSON. Fields that are arrays stay arrays
# even with one element (I() stops jsonlite from unboxing them).
dossier_data <- function(x, plot_path) {
  arr <- function(v) I(as.character(unlist(v %||% character())))
  scen <- lapply(x$scenarios, function(s) {
    steps <- lapply(s$steps, function(st) {
      for (side in c("base", "cand")) {
        st$warnings[[side]] <- arr(st$warnings[[side]])
        st$transcript[[side]] <- arr(st$transcript[[side]])
        st$error_class[[side]] <- arr(st$error_class[[side]])
        st$capped[[side]] <- arr(st$capped[[side]])
      }
      st$kinds <- arr(st$kinds)
      st$news <- arr(st$news)
      st$news_functions <- arr(st$news_functions)
      if (!is.null(st$struct)) st$struct <- lapply(st$struct, arr)
      if (!is.null(st$plot)) {
        st$plot$base <- arr(plot_path(s$id, st$id, st$plot$files_base, "base"))
        st$plot$cand <- arr(plot_path(s$id, st$id, st$plot$files_cand, "cand"))
        if (!is.null(st$plot$pixel_share)) st$plot$pixel_share <- I(as.numeric(st$plot$pixel_share))
        st$plot$files_base <- NULL
        st$plot$files_cand <- NULL
      }
      st
    })
    list(id = s$id, title = s$title, source = s$source, notes = arr(s$notes),
         not_run = s$not_run, steps = steps)
  })
  meta <- x$meta
  meta$determinism_failures <- arr(meta$determinism_failures)
  meta$runs_base <- arr(meta$runs_base)
  meta$runs_cand <- arr(meta$runs_cand)
  if (!is.null(meta$coverage)) {
    for (f in c("used", "unused", "news_unmatched")) meta$coverage[[f]] <- arr(meta$coverage[[f]])
  }
  for (side in c("base", "cand")) {
    meta[[side]]$functions <- arr(meta[[side]]$functions)
    if (!is.null(meta[[side]]$api)) meta[[side]]$api <- lapply(meta[[side]]$api, function(f) {
      f$args <- arr(f$args)
      f$defaults <- I(as.character(f$defaults %||% character()))  # NA (no default) stays null
      f
    })
  }
  list(schema = "pkgdossier", schema_version = "0.1.0", meta = meta,
       differences = x$differences, differences_grouped = group_differences(x$differences),
       scenarios = scen)
}

to_json <- function(x, pretty = FALSE) {
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA,
                   pretty = pretty, force = TRUE)
}

html_escape <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  gsub(">", "&gt;", s, fixed = TRUE)
}
