#' Make a dossier in one call
#'
#' Run from a package's folder, `run_dossier()` compares that folder with the
#' package's CRAN release: it installs both, runs the release's vignettes and
#' help-page examples under each, compares everything they produce, writes the HTML
#' report and the JSON, opens the report (in an interactive session) and returns the
#' comparison, which prints a summary.
#'
#' It calls [prepare_versions()], [run_scenarios()] and [compare_runs()] in turn. Each
#' stage caches its work in the dossier's work folder, so a second call after
#' changing the package rebuilds and reruns only the candidate, and a call with other
#' comparison settings only compares again.
#'
#' @section From a package folder:
#' With no dossier, `run_dossier()` is `run_dossier(dossier("<Package>"))`, where
#' `<Package>` is the `Package` field of the working directory's `DESCRIPTION`:
#' the folder against its CRAN release, with the release's vignettes and examples,
#' and every other setting at [dossier()]'s default. Only the package's name is
#' read from the folder. `print(cmp$dossier)` shows every setting.
#'
#' @section Changing a setting:
#' Each setting has one home, and a setting given in the wrong place is an error that
#' writes out the call to use instead.
#' * What is compared and how the runs are made go to [dossier()]:
#'   `run_dossier(dossier("mypkg", base = cran_version("1.2.0"), reps = 0))`.
#' * How the runs go stays here: `run_dossier(step_timeout = 900, workers = 2)`.
#' * The comparison's tolerances go to [compare_runs()] through `...`:
#'   `run_dossier(tol = 1e-3)`.
#'
#' Before upgrading a package you use, see what would change for you:
#' `run_dossier(dossier("ggplot2", base = installed_version(), candidate =
#' cran_release()))`.
#'
#' A quick look, without timings to label: `run_dossier(dossier("mypkg", reps = 0),
#' workers = 2)`. To keep the work between R sessions, give the dossier a work
#' folder: `dossier("mypkg", work = "~/dossiers/mypkg")`.
#'
#' @section When it stops:
#' Before anything is downloaded it stops when the working directory is not a
#' package (naming the package around or below it, if any), and when a folder
#' source does not hold the package or lacks a dependency. A package with no CRAN
#' release, or an index that cannot be read, stops with the `base` to write instead.
#' The errors have classes `pkgdossier_error_not_package`,
#' `pkgdossier_error_not_on_repo`, `pkgdossier_error_offline`,
#' `pkgdossier_error_no_scenarios`, `pkgdossier_error_not_installed` and
#' `pkgdossier_error_nothing_to_compare` (the installed version is already the
#' current release). A step that hangs is stopped after
#' `step_timeout` and recorded; one that crashes R is recorded too; the dossier goes
#' on without them.
#'
#' @param d A [dossier()], or `NULL` for the package in the working directory (see
#'   "From a package folder").
#' @param ... Arguments of [compare_runs()]: `tol`, `min_time`, `min_ratio`,
#'   `min_timings`, `plot_tol`, `api`, `accept` and `keep_metadata`. The arguments
#'   after `...` must be named in full.
#' @param html Folder for the HTML report ([write_dossier_html()]), or `NULL` for none.
#' @param json File for the JSON ([write_dossier_json()]), or `NULL` for none.
#' @param open Open the report in the browser; by default only in an interactive
#'   session.
#' @param force Reinstall both versions and repeat every run.
#' @param ask Ask before every download: package sources, package indexes (once per
#'   repository and session) and dependencies.
#' @param timeout,step_timeout Seconds one run may take, and one execution of a step
#'   (300 by default); see [run_scenarios()].
#' @param workers Runs at once; see [run_scenarios()].
#' @param quiet Suppress progress messages.
#' @return The comparison, an object of class `pkgdossier_comparison`; its
#'   `$dossier` is the dossier it was made from.
#' @examples
#' \donttest{
#' cmp <- run_dossier(example_dossier(), html = file.path(tempdir(), "dossier-page"),
#'                    open = FALSE)
#' cmp
#' }
#' @export
run_dossier <- function(d = NULL, ..., html = file.path(d$work, "page"),
                        json = file.path(d$work, "dossier.json"), open = interactive(), force = FALSE,
                        ask = interactive(), timeout = Inf, step_timeout = 300, workers = 1L,
                        quiet = FALSE) {
  dots <- as.list(substitute(list(...)))[-1L]
  # the other arguments as given, for a suggested call that keeps them
  given <- as.list(match.call())[-1L]
  given <- given[setdiff(names(given), c("", "d", names(dots)))]
  extra <- paste(sprintf("%s = %s", names(given),
                         vapply(given, function(e) paste(deparse(e, width.cutoff = 200L), collapse = " "), "")),
                 collapse = ", ")
  inferred <- is.null(d)
  if (inferred) {
    d <- dossier_here()
  } else if (is.character(d)) {
    usable <- length(d) == 1L && !is.na(d) && nzchar(d)
    folder <- usable && (grepl("[/\\\\]", d) || d %in% c(".", "..") || dir.exists(d))
    name <- if (folder) package_in(d) %||% "<its name>" else d[1]
    stop("`d` must be a dossier(), or NULL for the package in the working directory",
         if (!usable) "." else ". ",
         if (!usable) "" else if (folder) sprintf("For the folder %s: run_dossier() from inside it, or run_dossier(dossier(\"%s\", candidate = local_path(\"%s\"))).",
                             d, name, d)
         else sprintf("For %s: run_dossier(dossier(\"%s\")), or run_dossier() from its folder.", name, name),
         call. = FALSE)
  } else if (!inherits(d, "pkgdossier_dossier")) {
    stop("`d` must be a dossier(), or NULL for the package in the working directory.", call. = FALSE)
  }
  check_dots(dots, names(formals(compare_runs))[-1L], d, inferred, extra = extra)
  # the comparison's settings are checked now, not after the runs
  check_compare_args(list(...))
  check_destinations(d, if (!is.null(html)) html, if (!is.null(json)) json)
  if (inferred) {
    say(sprintf("Comparing %s with %s's CRAN release: run_dossier() here is run_dossier(dossier(\"%s\")); print(cmp$dossier) shows every setting.",
                d$candidate$path, d$pkg, d$pkg), quiet = quiet)
  }
  prepare_versions(d, force = force, ask = ask, quiet = quiet)
  run_scenarios(d, force = force, timeout = timeout, step_timeout = step_timeout, workers = workers,
                quiet = quiet)
  cmp <- compare_runs(d, ...)
  if (!is.null(html)) {
    page <- write_dossier_html(cmp, dir = html)
    opened <- isTRUE(open) && open_page(page)
    say("Report: ", normalizePath(page, winslash = "/"), if (opened) " (opened in the browser)", quiet = quiet)
  }
  if (!is.null(json)) {
    write_dossier_json(cmp, json)
    say("JSON:   ", normalizePath(json, winslash = "/"), quiet = quiet)
  }
  if (inferred) {
    say(sprintf("After a change, call run_dossier() again: what has not changed is reused from %s until R ends.",
                d$work), quiet = quiet)
  }
  cmp
}

# The dossier of the package in the working directory: dossier(<its Package>),
# nothing else inferred.
dossier_here <- function(path = getwd()) {
  path <- absolute_path(path)
  desc_file <- file.path(path, "DESCRIPTION")
  unreadable <- NULL
  pkg <- if (file.exists(desc_file)) {
    tryCatch(read_desc(desc_file)$Package, error = function(e) {
      unreadable <<- conditionMessage(e)
      NULL
    })
  }
  if (!is.null(pkg) && !is.na(pkg) && nzchar(pkg)) return(dossier(pkg))
  hints <- character()
  # a package around the working directory, or exactly one inside it, is named
  above <- dirname(path)
  while (!identical(above, dirname(above))) {
    p <- package_in(above)
    if (!is.null(p)) {
      hints <- c(hints, sprintf("It is inside the package %s at %s: setwd(\"%s\") first.", p, above, above))
      break
    }
    above <- dirname(above)
  }
  subs <- list.dirs(path, recursive = FALSE)
  below <- Filter(Negate(is.null), stats::setNames(lapply(subs, package_in), subs))
  if (length(below) == 1L) {
    hints <- c(hints, sprintf("The folder %s holds the package %s: setwd(\"%s\") first, or run_dossier(dossier(\"%s\", candidate = local_path(\"%s\"))).",
                              names(below), below[[1]], names(below), below[[1]], names(below)))
  }
  stop_pkgdossier("not_package",
    "run_dossier() without a dossier compares the package in the working directory, but ", path,
    if (!is.null(unreadable)) paste0(" has a DESCRIPTION that R cannot read (", unreadable, ").")
    else if (file.exists(desc_file)) " has a DESCRIPTION without a Package field (a project's DESCRIPTION?)."
    else " has no DESCRIPTION.",
    if (length(hints)) paste0(" ", paste(hints, collapse = " ")),
    " Or describe it: run_dossier(dossier(\"mypkg\", candidate = local_path(\"path/to/mypkg\"))).")
}

# The package a folder holds, or NULL.
package_in <- function(dir) {
  f <- file.path(dir, "DESCRIPTION")
  if (!file.exists(f)) return(NULL)
  p <- tryCatch(read_desc(f)$Package, error = function(e) NULL)
  if (is.null(p) || is.na(p) || !nzchar(p)) NULL else p
}

# The report and the JSON must not land inside a folder source unless its
# .Rbuildignore excludes them: R CMD build would copy them into the build, and every
# call would rebuild the folder.
check_destinations <- function(d, html, json) {
  for (src in list(d$base, d$candidate)) {
    if (!identical(src$type, "local")) next
    for (dest in c(html, json)) {
      inside <- path_within(dest, src$path)
      if (is.null(inside)) next
      if (!nzchar(inside) || !build_ignored(inside, src$path)) {
        stop("The destination ", dest, " is inside the folder ", src$path,
             if (nzchar(inside)) {
               paste0(", and its .Rbuildignore does not exclude it, so R CMD build would copy it into every build. ",
                      "Write it elsewhere, or add ^", gsub("([][.+?(){}|^$*\\\\])", "\\\\\\1", inside, perl = TRUE),
                      "$ to .Rbuildignore.")
             } else ", which R CMD build would copy into every build. Write it elsewhere.",
             call. = FALSE)
      }
    }
  }
  invisible()
}

# Opens the report in the browser; FALSE when that fails.
open_page <- function(page) {
  isTRUE(tryCatch({
    utils::browseURL(page)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE))
}

# The arguments run_dossier() passes on must be compare_runs()'s; a setting given in
# the wrong place is named with its home and the call that sets it there. The
# arguments are not evaluated here.
check_dots <- function(dots, allowed, d = NULL, inferred = FALSE, extra = "") {
  if (!length(dots)) return(invisible())
  nms <- names(dots) %||% rep("", length(dots))
  if (any(!nzchar(nms))) stop("Arguments in `...` must be named (they go to compare_runs()).", call. = FALSE)
  bad <- setdiff(nms, allowed)
  if (!length(bad)) return(invisible())
  known <- unique(c(allowed, setdiff(names(formals(run_dossier)), c("d", "...")),
                    setdiff(names(formals(dossier)), "pkg")))
  value <- function(nm) paste(deparse(dots[[nm]], width.cutoff = 200L), collapse = " ")
  # the dossier() settings together, in one call
  to_dossier <- intersect(bad, setdiff(names(formals(dossier)), "pkg"))
  settings <- paste(sprintf("%s = %s", to_dossier, vapply(to_dossier, value, "")), collapse = ", ")
  home <- function(nm) {
    if (nm == "pkg") {
      return(sprintf("`pkg` is dossier()'s first argument: run_dossier(dossier(%s))", value(nm)))
    }
    if (nm %in% to_dossier) {
      if (nm != to_dossier[1]) return(NA_character_)
      rest <- c(names(dots)[!names(dots) %in% c(to_dossier, "pkg") & names(dots) %in% allowed])
      keep <- paste(c(if (nzchar(extra)) extra,
                      if (length(rest)) sprintf("%s = %s", rest, vapply(rest, value, ""))), collapse = ", ")
      call <- if (inferred) {
        sprintf("run_dossier(dossier(\"%s\", %s)%s)", d$pkg, settings, if (nzchar(keep)) paste0(", ", keep) else "")
      } else sprintf("dossier(..., %s)", settings)
      return(sprintf("%s %s set in dossier(): %s", paste0("`", to_dossier, "`", collapse = " and "),
                     if (length(to_dossier) > 1L) "are" else "is", call))
    }
    if (nm == "report") return("the report folder is `html`")
    if (nm %in% c("dir", "notes")) return(sprintf("`%s` belongs to write_dossier_html()", nm))
    if (nm %in% names(formals(write_dossier_md))) return(sprintf("`%s` belongs to write_dossier_md()", nm))
    near <- known[utils::adist(nm, known, ignore.case = TRUE)[1, ] <= max(1L, nchar(nm) %/% 4L)]
    sprintf("`%s` is not an argument of run_dossier() or compare_runs()%s", nm,
            if (length(near)) sprintf("; did you mean `%s`?", near[1]) else "")
  }
  parts <- vapply(bad, home, "")
  msg <- paste(parts[!is.na(parts)], collapse = "; ")
  stop(msg, if (!grepl("[?.)]$", msg)) ".", call. = FALSE)
}

# compare_runs()'s settings, checked before anything runs: a mistyped value or a
# missing accept file would otherwise surface only after every install and run.
check_compare_args <- function(args) {
  num <- function(nm, lo = 0, hi = Inf) {
    v <- args[[nm]]
    if (!is.null(v) && (!is.numeric(v) || length(v) != 1L || is.na(v) || v < lo || v > hi)) {
      stop("`", nm, "` must be one number", if (is.finite(hi)) sprintf(" from %s to %s", lo, hi)
           else sprintf(" of at least %s", lo), ".", call. = FALSE)
    }
  }
  num("tol"); num("min_time"); num("min_ratio", 1); num("min_timings", 1); num("plot_tol", 0, 1)
  for (nm in c("api", "keep_metadata")) {
    v <- args[[nm]]
    if (!is.null(v) && !(is.logical(v) && length(v) == 1L && !is.na(v))) {
      stop("`", nm, "` must be TRUE or FALSE.", call. = FALSE)
    }
  }
  a <- args$accept
  if (!is.null(a) && !is.data.frame(a) && !(is.character(a) && length(a) == 1L && file.exists(a))) {
    stop("`accept` must be a data frame or an existing CSV file written by accept_differences()",
         if (is.character(a)) paste0("; ", a[1], " does not exist"), ".", call. = FALSE)
  }
  invisible()
}
