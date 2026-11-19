#' Write scenarios by hand
#'
#' A scenario is a sequence of steps run in one environment, so later steps see the
#' objects earlier steps created. Use scenario files for code the vignettes do not
#' cover, or for vignettes that cannot simply run. Each step's code is kept exactly
#' as written and run unchanged under both versions.
#'
#' Kinds of step:
#' * `"setup"`: run, not reported (data preparation).
#' * `"run"`: run and reported (console output, warnings, errors, plots).
#' * `"fit"`: like `"run"`, and timed with repeats.
#' * `"print"`: the visible value is printed and its printed form compared on its
#'   own.
#' * `"plot"`: drawn to PNG at `w` x `h` inches.
#'
#' Every step captures console output, warnings, errors and plots whatever its kind.
#' With `values = TRUE` the step also collects every number and short string inside
#' its visible value, and inside any object it assigns at top level, keyed by path,
#' plus the element names a user's code might read (`x$foo$bar`).
#'
#' @param id Identifier: unique within its scenario (steps) or the dossier
#'   (scenarios).
#' @param kind Kind of step, see Details.
#' @param expr Code of the step, unevaluated. Wrap several lines in `{ }`: each
#'   top-level expression inside runs as if typed at the console.
#' @param label Label shown in the report.
#' @param values Collect numbers and element names (see Details).
#' @param time Time the step with repeats. Defaults to `TRUE` for `"fit"` steps.
#' @param w,h Figure size in inches for plots the step draws.
#' @param ... Steps (`scenario()`).
#' @param title,source Title of the scenario and where its code comes from, shown in
#'   the report.
#' @return `step()`: an `pkgdossier_step`; `scenario()`: an `pkgdossier_scenario`.
#' @examples
#' scenario("basics", title = "Linear model", source = "README",
#'   step("setup", "setup", d <- head(mtcars, 20)),
#'   step("fit", "fit", fit <- lm(mpg ~ wt, data = d)),
#'   step("coef", "print", coef(fit), values = TRUE),
#'   step("plot", "plot", plot(d$wt, d$mpg), w = 5, h = 4)
#' )
#' @export
step <- function(id, kind = c("run", "setup", "fit", "print", "plot"), expr,
                 label = id, values = FALSE, time = NULL, w = 7, h = 4.5) {
  kind <- match.arg(kind)
  new_step(id, kind, expr_code(substitute(expr)), label = label, values = values,
           time = time %||% (kind == "fit"), w = w, h = h)
}

new_step <- function(id, kind, code, label = id, values = FALSE, time = FALSE,
                     w = 7, h = 4.5, eval = TRUE, eval_expr = NULL, note = NULL,
                     expect_error = FALSE) {
  structure(list(id = as.character(id), kind = kind, label = as.character(label), code = code,
                 values = isTRUE(values), time = isTRUE(time), w = w, h = h,
                 eval = eval, eval_expr = eval_expr, note = note,
                 expect_error = isTRUE(expect_error)),
            class = "pkgdossier_step")
}

# One string per top-level expression; the contents of `{ }` count as top level.
expr_code <- function(e) {
  exprs <- if (is.call(e) && identical(e[[1]], as.name("{"))) as.list(e)[-1] else list(e)
  vapply(exprs, function(x) paste(deparse(x, width.cutoff = 70L), collapse = "\n"), "")
}

#' @rdname step
#' @export
scenario <- function(id, ..., title = id, source = "") {
  steps <- list(...)
  if (length(steps) == 1L && is.list(steps[[1]]) && !inherits(steps[[1]], "pkgdossier_step")) {
    steps <- steps[[1]]
  }
  ok <- vapply(steps, inherits, logical(1), "pkgdossier_step")
  if (!all(ok)) stop("scenario(): every element of `...` must be a step().", call. = FALSE)
  sc <- new_scenario(id, steps, title = title, source = source)
  if (isTRUE(registry$active)) registry$items[[length(registry$items) + 1L]] <- sc
  sc
}

# `workdir`: folder, relative to the run's `wd` folder, the scenario runs from
# ("vignettes" for vignette scenarios); NULL runs it from the run folder.
new_scenario <- function(id, steps, title = id, source = "", notes = character(), workdir = NULL) {
  ids <- dedupe(safe_id(vapply(steps, `[[`, "", "id")))
  for (i in seq_along(steps)) steps[[i]]$id <- ids[i]
  structure(list(id = safe_id(id), title = title, source = source, steps = steps, notes = notes,
                 workdir = workdir),
            class = "pkgdossier_scenario")
}

registry <- new.env(parent = emptyenv())

#' @export
print.pkgdossier_scenario <- function(x, ...) {
  cat("<pkgdossier scenario> ", x$id, ": ", x$title, " (", length(x$steps), " steps)\n", sep = "")
  for (st in x$steps) {
    cat(sprintf("  %-24s %-6s%s\n", st$id, st$kind, if (isFALSE(st$eval)) "  (not run)" else ""))
  }
  invisible(x)
}

#' Where scenarios come from
#'
#' * `from_vignettes()`: the vignettes of the baseline, read from the `vignettes/`
#'   folder of its source tarball. Each R chunk becomes a step that is run as in
#'   the vignette, with the chunk's `fig.width` and `fig.height` (or `fig.dim`, or
#'   the defaults the vignette sets with `knitr::opts_chunk$set()` or its output
#'   format) for plots. Chunks with `eval = FALSE` are listed as not run; an `eval`
#'   option that is an expression is evaluated in the vignette's environment when
#'   the chunk is reached. Every visible value is printed and its numbers
#'   collected, as is every object a chunk assigns at top level.
#' * `from_examples()`: the examples on the baseline's help pages, read from the
#'   `man/` folder of its source tarball as `R CMD check` reads them
#'   ([tools::Rd2ex()]). Each help page with examples is a scenario (`ex_<page>`)
#'   and each top-level expression a step. Code in `\donttest{}` is run, as
#'   `R CMD check --as-cran` runs it; code in `\dontrun{}` is not, and the scenario
#'   notes it. Examples run from the run's own folder.
#' * `scenario_file()`: an R file that creates scenarios with [scenario()] and
#'   [step()]. Every scenario the file creates is used, in the order created.
#'
#' Vignettes that read stored results (`readRDS()`, `load()`, `cache = TRUE`) are
#' run as they are and flagged in the report: their numbers do not test the
#' computation, so a scenario file is the better source for them.
#'
#' @param which Vignette file names, or help-page file names for `from_examples()`
#'   (without extension), to use; `NULL` uses all.
#' @param time Time each chunk (each example expression) with repeats.
#' @param values Collect numbers and element names from each chunk (each example
#'   expression).
#' @param path Path to a scenario file.
#' @return An object of class `pkgdossier_scenario_source`.
#' @examples
#' from_vignettes()
#' from_examples(which = c("fit_model", "plot_model"))
#' scenario_file("dev/dossier/scenarios.R")
#' @export
from_vignettes <- function(which = NULL, time = TRUE, values = TRUE) {
  structure(list(type = "vignettes", which = which, time = time, values = values),
            class = "pkgdossier_scenario_source")
}

#' @rdname from_vignettes
#' @export
from_examples <- function(which = NULL, time = FALSE, values = TRUE) {
  structure(list(type = "examples", which = which, time = time, values = values),
            class = "pkgdossier_scenario_source")
}

#' @rdname from_vignettes
#' @export
scenario_file <- function(path) {
  stopifnot(is.character(path), length(path) == 1L)
  structure(list(type = "file", path = path), class = "pkgdossier_scenario_source")
}

#' @export
format.pkgdossier_scenario_source <- function(x, ...) {
  which <- if (!is.null(x$which)) paste0(" (", paste(x$which, collapse = ", "), ")") else ""
  if (x$type == "vignettes") {
    paste0("baseline vignettes", which)
  } else if (x$type == "examples") {
    paste0("baseline help-page examples", which)
  } else {
    paste("scenario file", x$path)
  }
}

#' @export
print.pkgdossier_scenario_source <- function(x, ...) {
  cat("<pkgdossier scenario source> ", format(x), "\n", sep = "")
  invisible(x)
}

resolve_scenarios <- function(d, vers) {
  out <- list()
  for (src in d$scenarios) {
    out <- c(out, switch(src$type,
      vignettes = vignette_scenarios(vers$base$unpacked, src),
      examples = example_scenarios(vers$base$unpacked, src),
      file = file_scenarios(src$path)
    ))
  }
  if (!length(out)) {
    stop_pkgdossier("no_scenarios", "The scenario sources (", paste(vapply(d$scenarios, format, ""), collapse = "; "),
                    ") gave no scenarios from ", d$pkg, " ", vers$base$version, ", the baseline: there is no code ",
                    "to run under both versions. Write the code users run in a scenario file and add it: ",
                    "dossier(\"", d$pkg, "\", scenarios = list(from_vignettes(), from_examples(), ",
                    "scenario_file(\"dev/dossier/scenarios.R\"))); see ?scenario.")
  }
  ids <- dedupe(vapply(out, `[[`, "", "id"))
  for (i in seq_along(out)) out[[i]]$id <- ids[i]
  out
}

file_scenarios <- function(path) {
  path <- normalizePath(path, mustWork = TRUE)
  registry$active <- TRUE
  registry$items <- list()
  on.exit({ registry$active <- FALSE; registry$items <- list() }, add = TRUE)
  host <- new.env(parent = globalenv())
  host$scenario <- scenario
  host$step <- step
  env <- new.env(parent = host)
  sys.source(path, envir = env, keep.source = FALSE)
  found <- registry$items
  # the format of the scripts this package grew out of: a `scenarios` list of
  # list(id, title, source, steps), each step list(id, kind, expr, label, ...)
  if (!length(found) && is.list(env$scenarios)) found <- lapply(env$scenarios, legacy_scenario)
  if (!length(found)) stop("Scenario file ", path, " creates no scenario().", call. = FALSE)
  found
}

legacy_scenario <- function(sc) {
  steps <- lapply(sc$steps, function(st) {
    kind <- if (st$kind %in% c("setup", "run", "fit", "print", "plot")) st$kind else "run"
    new_step(st$id, kind, expr_code(st$expr), label = st$label %||% st$id,
             values = st$values, time = st$time %||% (kind == "fit"),
             w = st$w %||% 7, h = st$h %||% 4.5)
  })
  new_scenario(sc$id, steps, title = sc$title %||% sc$id, source = sc$source %||% "")
}
