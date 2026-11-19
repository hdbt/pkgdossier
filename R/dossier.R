#' Describe an upgrade dossier
#'
#' A dossier runs the code users learned from a released version (the baseline)
#' unchanged under that version and under a candidate, each installed in its own
#' library, and compares everything the code produces. `dossier()` only describes the
#' comparison; the stages do the work, each usable alone and each caching its results
#' in the work folder:
#'
#' 1. [prepare_versions()] fetches, builds and installs both versions;
#' 2. [run_scenarios()] runs the scenarios under each version;
#' 3. [compare_runs()] compares the runs and labels every difference;
#' 4. [write_dossier_html()], [write_dossier_json()] and [write_dossier_md()] write
#'    the results.
#'
#' [run_dossier()] calls them all. Everything that shapes the runs is set here, so
#' `print(d)` shows all of it and the stages take only how they run (time limits,
#' workers, whether to ask); the comparison's tolerances belong to [compare_runs()],
#' which is cheap to call again on stored runs.
#'
#' @param pkg Package name.
#' @param base,candidate Sources, see [sources]: the release users have (baseline)
#'   and the version they would upgrade to (candidate). The candidate defaults to the
#'   package folder this is called from, `local_path(".")`; a folder's path is made
#'   absolute here, so a later [setwd()] does not change which folder is meant.
#' @param scenarios A scenario source or a list of them: [from_vignettes()] (the
#'   baseline's vignettes), [from_examples()] (its help-page examples), both by
#'   default, and [scenario_file()].
#' @param work Work folder holding downloads, builds, libraries, runs and results.
#'   Defaults to a folder in [tempdir()]. A work folder inside a [local_path()]
#'   candidate must be listed in its `.Rbuildignore`, or `R CMD build` would copy it
#'   into the build.
#' @param reps Timed repeats per timed step in each run. `0` times nothing beyond the
#'   captured run (a quick smoke run).
#' @param order `"abba"` runs base, candidate, candidate, base, so that drift in
#'   machine load hits both versions alike and each version runs twice (which is how
#'   unseeded steps are found). `"ab"` runs each version once.
#' @param seed Seed set at the start of every scenario and, with `reseed = "step"`,
#'   before every step.
#' @param reseed `"step"` sets the seed before every step, so a change in how many
#'   random numbers one step draws does not move the numbers of later steps: each
#'   difference stays where it arises. `"scenario"` sets it once per scenario, so a
#'   vignette that calls `set.seed()` in one chunk and draws in the next gives the
#'   numbers its readers saw. Timed repeats always start from the random-number state
#'   of the step's captured run.
#' @param language Value of the `LANGUAGE` environment variable in the child
#'   processes, so that messages and warnings compare across locales. `NULL` leaves
#'   it alone.
#' @param width Console width (`options(width)`) in the child processes.
#' @param dpi Resolution of the PNG plots.
#' @param caps Size caps for collecting numbers, any of `max_depth` (nesting depth
#'   for visible values, default 6), `assign_depth` (for assigned objects, 3),
#'   `max_rows` (data-frame rows, 200), `max_length` (vector length, 200) and
#'   `max_cells` (matrix cells, 400). What a cap skips is reported.
#' @param skip_classes Classes whose objects are not walked when collecting numbers
#'   and element names (heavy model fits, plots, environments). See
#'   [default_skip_classes()].
#' @param deps Where the dependencies come from: [deps_shared()] (the current library
#'   paths, the default), [deps_cran()] (current CRAN versions, in the work folder) or
#'   [deps_snapshot()] (CRAN as on the baseline's release date). See [deps].
#' @param base_tag Optional: a git tag to check the baseline's `R/` folder against
#'   (line endings ignored), and to count the candidate's commits since.
#' @param repo The git repository holding `base_tag`. Defaults to the candidate's: a
#'   [git_ref()]'s repository, or the git work tree around a [local_path()] (for a
#'   package in a subfolder of its repository, that subfolder is compared). Set it
#'   for a tarball or CRAN candidate.
#' @return An object of class `pkgdossier_dossier`.
#' @examples
#' # describing a dossier reads and downloads nothing
#' dossier("MAIHDA",
#'   base = cran_version("0.2.1"),
#'   candidate = git_ref("path/to/MAIHDA", "main"),
#'   work = file.path(tempdir(), "dossier-0.3.0")
#' )
#'
#' # the whole pipeline, on the small package bundled for examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d)
#' run_scenarios(d)
#' cmp <- compare_runs(d)
#' cmp
#' write_dossier_html(cmp, dir = file.path(tempdir(), "dossier-page"))
#' }
#' @export
dossier <- function(pkg, base = cran_release(), candidate = local_path("."),
                    scenarios = list(from_vignettes(), from_examples()),
                    work = file.path(tempdir(), paste0("pkgdossier-", pkg)),
                    reps = 3L, order = c("abba", "ab"), seed = 20261027L,
                    reseed = c("step", "scenario"), language = "en", width = 80L, dpi = 100,
                    caps = list(), skip_classes = default_skip_classes(),
                    deps = deps_shared(), base_tag = NULL, repo = NULL) {
  if (!is.character(pkg) || length(pkg) != 1L || is.na(pkg) || !nzchar(pkg)) {
    stop("`pkg` must be the package's name.", call. = FALSE)
  }
  if (!grepl("^[A-Za-z]([A-Za-z0-9.]*[A-Za-z0-9])?$", pkg)) {
    stop("`pkg` must be the package's name, such as \"mypkg\", not ", encodeString(pkg, quote = '"'),
         if (grepl("[/\\\\]", pkg) || pkg %in% c(".", "..")) {
           paste0(". For a package folder: dossier(\"<its name>\", candidate = local_path(",
                  encodeString(pkg, quote = '"'), ")), or run_dossier() from inside it")
         }, ".", call. = FALSE)
  }
  check_source(base, "base")
  check_source(candidate, "candidate")
  if (!is.character(work) || length(work) != 1L || is.na(work) || !nzchar(work)) {
    stop("`work` must be the path of one folder.", call. = FALSE)
  }
  order <- match.arg(order)
  reseed <- match.arg(reseed)
  if (inherits(scenarios, "pkgdossier_scenario_source")) scenarios <- list(scenarios)
  ok <- vapply(scenarios, inherits, logical(1), "pkgdossier_scenario_source")
  if (!length(scenarios) || !all(ok)) {
    stop("`scenarios` must be from_vignettes(), from_examples(), scenario_file() or a list of them.",
         call. = FALSE)
  }
  count <- function(x, what, min = 0) {
    if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < min) {
      stop("`", what, "` must be one number of at least ", min, ".", call. = FALSE)
    }
    x
  }
  count(reps, "reps")
  count(width, "width", 10)
  count(dpi, "dpi", 1)
  if (is.character(deps)) {
    stop("`deps` takes deps_shared(), deps_cran() or deps_snapshot()",
         if (length(deps) == 1L && deps %in% c("shared", "cran", "snapshot")) paste0(": use deps_", deps, "()"),
         ".", call. = FALSE)
  }
  if (!inherits(deps, "pkgdossier_deps")) {
    stop("`deps` must be deps_shared(), deps_cran() or deps_snapshot().", call. = FALSE)
  }
  candidate <- absolute_source(candidate)
  if (is.null(repo)) repo <- switch(candidate$type, git = candidate$repo, local = candidate$path, NULL)
  if (!is.null(base_tag) && is.null(repo)) {
    stop("`base_tag` needs the git repository holding the tag: set `repo` (the candidate is ",
         format(candidate), ").", call. = FALSE)
  }
  structure(list(
    pkg = pkg, base = absolute_source(base), candidate = candidate, scenarios = scenarios,
    work = absolute_path(work),
    reps = as.integer(reps), order = order, seed = as.integer(seed), reseed = reseed,
    language = language, width = as.integer(width), dpi = as.numeric(dpi), caps = run_caps(caps),
    skip_classes = skip_classes, deps = deps$mode, deps_repos = deps$repos, deps_date = deps$date,
    base_tag = base_tag, repo = repo
  ), class = "pkgdossier_dossier")
}

# The size caps the runner uses, with the given ones in place of the defaults.
run_caps <- function(caps = list()) {
  defaults <- list(max_depth = 6L, assign_depth = 3L, max_rows = 200L, max_length = 200L, max_cells = 400L)
  if (!is.list(caps) || (length(caps) && is.null(names(caps)))) {
    stop("`caps` must be a named list, such as list(max_rows = 50).", call. = FALSE)
  }
  bad <- setdiff(names(caps), names(defaults))
  if (length(bad)) {
    stop("Unknown cap(s): ", paste(bad, collapse = ", "), ". The caps are ",
         paste(names(defaults), collapse = ", "), ".", call. = FALSE)
  }
  for (nm in names(caps)) {
    v <- caps[[nm]]
    if (!is.numeric(v) || length(v) != 1L || is.na(v) || v < 0) {
      stop("Cap `", nm, "` must be one number of at least 0.", call. = FALSE)
    }
    caps[[nm]] <- as.integer(v)
  }
  utils::modifyList(defaults, caps)
}

# A folder's path, made absolute when the dossier is described.
absolute_source <- function(src) {
  if (identical(src$type, "local")) src$path <- absolute_path(src$path)
  src
}

# An absolute path, also for a folder that does not exist yet (normalizePath()
# leaves those as given): "." and ".." are resolved, and the deepest part that exists
# is normalized (symbolic links followed), the rest appended.
absolute_path <- function(p) {
  p <- path.expand(p)
  if (!grepl("^(/|[A-Za-z]:[/\\\\]|\\\\\\\\)", p)) p <- file.path(getwd(), p)
  p <- gsub("\\\\", "/", p)
  root <- regmatches(p, regexpr("^(//[^/]+/[^/]+|[A-Za-z]:|)/*", p))
  parts <- strsplit(substring(p, nchar(root) + 1L), "/+")[[1]]
  out <- character()
  for (part in parts) {
    if (part %in% c("", ".")) next
    if (part == "..") out <- out[-length(out)] else out <- c(out, part)
  }
  root <- sub("/*$", "/", root)
  rest <- character()
  while (length(out) && !file.exists(paste0(root, paste(out, collapse = "/")))) {
    rest <- c(out[length(out)], rest)
    out <- out[-length(out)]
  }
  base <- normalizePath(paste0(root, paste(out, collapse = "/")), winslash = "/", mustWork = FALSE)
  if (length(rest)) paste(c(sub("/$", "", base), rest), collapse = "/") else base
}

check_source <- function(x, what) {
  if (!inherits(x, "pkgdossier_source")) {
    stop("`", what, "` must be a source: cran_release(), cran_version(), installed_version(), tarball(), ",
         "git_ref() or local_path().", call. = FALSE)
  }
}

#' A dossier over a small bundled package
#'
#' Describes a dossier over `udfixture`, a tiny package shipped with pkgdossier as two
#' source tarballs (versions 1.0.0 and 1.1.0) with one planted difference of each
#' kind: a moved number, changed printed output, a changed plot, a removed and an
#' added element, a new and a fixed error, a new and a gone warning, a changed
#' warning class, a slower and a faster step, and an unseeded step. Its scenarios
#' are the baseline's vignette, its help-page examples and a scenario file. Use it to try the stages and the
#' report without network access; like [dossier()], it only describes, and nothing
#' is installed until [prepare_versions()].
#'
#' @param work Work folder; defaults to a folder in [tempdir()].
#' @param ... Further arguments to [dossier()], such as `reps = 0` for a quick run.
#' @return An object of class `pkgdossier_dossier`.
#' @examples
#' d <- example_dossier()
#' d
#' \donttest{
#' prepare_versions(d)
#' run_scenarios(d)
#' compare_runs(d)
#' }
#' @export
example_dossier <- function(work = file.path(tempdir(), "pkgdossier-example"), ...) {
  ext <- function(f) system.file("extdata", f, package = "pkgdossier", mustWork = TRUE)
  dossier("udfixture",
    base = tarball(ext("udfixture_1.0.0.tar.gz")),
    candidate = tarball(ext("udfixture_1.1.0.tar.gz")),
    scenarios = list(from_vignettes(), from_examples(), scenario_file(ext("udfixture-scenarios.R"))),
    work = work, ...
  )
}

#' Classes skipped when collecting numbers
#'
#' Objects of these classes are not walked when a step's values are flattened into
#' numbers and element names: model fits, plot objects and the like are large, and
#' what users read from them is usually reached through a summary or an accessor.
#' Extend the list for package-specific classes:
#' `dossier(..., skip_classes = c(default_skip_classes(), "maihda_model"))`.
#'
#' @return A character vector of class names.
#' @examples
#' default_skip_classes()
#' @export
default_skip_classes <- function() {
  c("lm", "glm", "nls", "merMod", "lmerMod", "glmerMod", "brmsfit", "stanfit",
    "clm", "clmm", "gam", "ggplot", "gg", "ggplot2::ggplot", "patchwork", "gtable",
    "grob", "gTree", "recordedplot", "formula", "family", "terms", "data.table")
}

#' @export
print.pkgdossier_dossier <- function(x, ...) {
  cat("<pkgdossier dossier> ", x$pkg, "\n", sep = "")
  cat("  base:      ", format(x$base), "\n", sep = "")
  cat("  candidate: ", format(x$candidate), "\n", sep = "")
  cat("  scenarios: ", paste(vapply(x$scenarios, format, ""), collapse = "; "), "\n", sep = "")
  cat("  runs:      ", x$order, ", ", x$reps, " timed repeats per timed step, seed ", x$seed, " set per ",
      x$reseed %||% "step", "\n", sep = "")
  cat("  capture:   width ", x$width, ", ", x$dpi %||% 100, " dpi, LANGUAGE ", x$language %||% "as set",
      "\n", sep = "")
  defaults <- run_caps()
  caps <- x$caps %||% defaults
  set <- names(caps)[!mapply(identical, caps, defaults[names(caps)])]
  extra <- setdiff(x$skip_classes, default_skip_classes())
  dropped <- setdiff(default_skip_classes(), x$skip_classes)
  cat("  collect:   ", if (length(set)) paste(sprintf("%s %s", set, unlist(caps[set])), collapse = ", ")
      else "default caps", "; ",
      if (!length(extra) && !length(dropped)) "default skipped classes" else
        paste(c(if (length(extra)) paste("skipping also", paste(extra, collapse = ", ")),
                if (length(dropped)) paste("not skipping", paste(dropped, collapse = ", "))), collapse = "; "),
      "\n", sep = "")
  cat("  deps:      ", format(new_deps(x$deps %||% "shared", repos = x$deps_repos, date = x$deps_date)),
      "\n", sep = "")
  if (!is.null(x$base_tag)) cat("  base_tag:  ", x$base_tag, " in ", x$repo %||% "?", "\n", sep = "")
  cat("  work:      ", x$work, "\n", sep = "")
  invisible(x)
}

work_path <- function(d, ...) file.path(d$work, ...)
