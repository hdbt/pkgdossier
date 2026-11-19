#' Compare the runs and label every difference
#'
#' Compares the baseline's and the candidate's runs step by step and gives each
#' difference one mechanical kind. The labels say what differs, not whether it is
#' intended: that judgement is left to the reader.
#'
#' | Kind | Rule | Severity |
#' |---|---|---|
#' | `unstable` | the two runs of one version disagree; the step is not compared further | 0 |
#' | `error_new` | the step errors only under the candidate | 1 |
#' | `field_removed` | an element path (`x$a$b`, `x@slot`, a data-frame column) only in the baseline | 1 |
#' | `condition_class_changed` | an error or warning with the same message but a different class | 2 |
#' | `value_moved` | a number whose relative change exceeds `tol`, a number that became or stopped being `NA`, or a short string that changed | 2 |
#' | `warning_new` | a warning message only the candidate gives | 2 |
#' | `output_changed` | the console transcript or the printed value differs (one row per stream), unless every changed line differs only in printed numbers within `tol` | 3 |
#' | `plot_changed` | the PNG files differ (checksum) or their number differs; with the png package, the share of differing pixels is reported, and images whose share is at most `plot_tol` are not labelled | 3 |
#' | `slower`, `faster` | for timed steps of `min_time` seconds or more with at least `min_timings` timings per version: the candidate's timings all lie above (below) the baseline's by more than 5 ms (half the Windows timer tick) and the median ratio is beyond `min_ratio` | 3 |
#' | `warning_gone` | a warning message only the baseline gives | 4 |
#' | `field_added` | an element path only in the candidate | 4 |
#' | `error_fixed` | the step errors only under the baseline | 4 |
#'
#' With `api = TRUE`, the exports and function signatures of the two versions are
#' compared too, without running anything; these differences are listed under the
#' scenario `(namespace)`, with the function as the step and the argument as the
#' path:
#'
#' | Kind | Rule | Severity |
#' |---|---|---|
#' | `export_removed` | an export of the baseline is gone (or is no longer a function) | 1 |
#' | `argument_removed` | an argument of an exported function is gone | 1 |
#' | `argument_new_required` | a new argument without a default, or an argument that lost its default | 1 |
#' | `arguments_reordered` | the arguments both versions have come in a different order | 2 |
#' | `default_changed` | an argument's default differs | 2 |
#' | `argument_added` | a new argument with a default | 4 |
#' | `export_added` | a new export | 4 |
#'
#' **Coverage.** The comparison also records which exported functions the scenarios
#' use (directly or through the objects they produce), which they do not, and which
#' candidate NEWS bullets no step or API difference was matched to: changes the
#' dossier did not exercise. `print()`, the report and the Markdown summary show it.
#'
#' A step that errors under both versions is a scenario problem rather than a
#' finding: it is reported with status `error_both` and compared no further (apart
#' from a change of the error's class), unless under only one version R stopped in
#' it, it timed out or pkgdossier could not capture it, which is `error_new` (or
#' `error_fixed`). A vignette chunk run with `error = TRUE` runs on after an error,
#' as knitr runs it, and the errors it shows its readers are part of its console
#' output (`Error: ...`), compared with the rest; an error from a package that is not
#' installed stays an error. A step that errors under one version is compared no
#' further. Numbers that differ by less than `tol` are counted,
#' not listed: such differences come from optimisers and floating point, not from a
#' change in method.
#'
#' **NEWS candidates.** The candidate's NEWS (`NEWS.md` or a plain-text `NEWS`, at
#' the top level or in `inst/`, or else `inst/NEWS.Rd` through the news database R
#' builds when installing it) is read from the sections written after the baseline's
#' version. For each step, the bullets that name a function of the
#' package the step uses are attached to the step and to each of its differences
#' (column `news`). A function is "used" when its name appears in the step's code,
#' when it is a method for the class of the step's last visible value (so
#' `print.myclass()` for a printed `myclass` object), or when it produced an object
#' the step uses: `fit <- fit_model(d)` in one step makes `summary(fit)` in a later
#' step use `fit_model()` too, following assignments through the scenario. A bullet
#' "names" a function as
#' `fn()`, `pkg::fn()`, `` `fn` ``, or, for names with a dot or an underscore, the
#' bare name. A difference whose step has no such bullet gets `no_news = TRUE`. A
#' large release can have dozens of bullets for a step, so each difference keeps at
#' most three, those naming an element of its path first (`converged` for
#' `fit$diagnostics$converged`), then those using a word that fits its kind
#' (`plot` for `plot_changed`).
#' This finds candidates only; whether a bullet covers the change is for the reader.
#'
#' The comparison reads the stored runs and takes their order and repeats from them.
#' It stops when a version was prepared again after its runs were made (its NEWS and
#' provenance would no longer describe them), and warns when the dossier's run
#' settings differ from those the runs were made with; [run_scenarios()] makes them
#' again. Comparing is cheap: call it again with other tolerances, without running
#' anything. Timings are shown but no step is labelled `slower` or `faster` when runs
#' went at the same time, or when some runs were reused from an earlier call while
#' others were made anew (after a fix, the baseline's runs are reused): ABBA's
#' balance against drift in machine load holds only within one call.
#' `run_scenarios(d, force = TRUE)` makes all runs together.
#'
#' @param d A [dossier()].
#' @param tol Relative tolerance for numbers.
#' @param min_time,min_ratio Timing rule: only steps whose median takes at least
#'   `min_time` seconds in one version are labelled, and only when the median ratio
#'   is at least `min_ratio` (or at most `1 / min_ratio`). The default floor of 30 ms
#'   reflects the 10 ms resolution of the process timer on Windows.
#' @param min_timings Fewest timings per version for a `slower` or `faster` label.
#'   The rule asks that all of one version's timings lie beyond the other's; with two
#'   timings a side that happens by chance one time in three, with five a side one
#'   time in 126, with six (the default `reps = 3` in both runs of a version) one time
#'   in 462. Steps with fewer timings show their times without a label.
#' @param api Compare the exports and function signatures of the two versions.
#' @param keep_metadata Keep differences in the package's own DESCRIPTION fields.
#'   By default, a value or element difference whose path ends in a field of the
#'   package's installed DESCRIPTION (`Version`, `Packaged`, `Built`, ...) and whose two
#'   sides are that field in the two versions is left out and counted: an example
#'   that prints [sessionInfo()] or [packageDescription()] shows them, and they
#'   differ between any two versions.
#' @param accept Rules for differences already read and accepted: a CSV file written
#'   by [accept_differences()] or a data frame with its columns. Accepted
#'   differences keep their rows, marked `accepted`, and are left out of the counts
#'   of `print()`, [write_dossier_md()] and [check_differences()].
#' @param plot_tol Largest share of differing pixels (0 to 1) at which two images of
#'   the same size still count as the same plot, for anti-aliasing or font noise.
#'   Needs the png package; without it plots are compared by checksum only.
#' @return An object of class `pkgdossier_comparison`, with methods for [print()],
#'   [summary()], [differences()], [write_dossier_html()] and [write_dossier_json()].
#'   Its `$dossier` is `d`, so the stages can be called again from the result:
#'   `compare_runs(cmp$dossier, tol = 1e-3)`.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' cmp
#' summary(cmp)
#' differences(cmp, kind = "value_moved")
#' }
#' @export
compare_runs <- function(d, tol = 1e-4, min_time = 0.03, min_ratio = 1.2, min_timings = 5L, plot_tol = 0,
                         api = TRUE, accept = NULL, keep_metadata = FALSE) {
  stopifnot(inherits(d, "pkgdossier_dossier"), is.numeric(plot_tol), plot_tol >= 0, plot_tol <= 1)
  has_png <- requireNamespace("png", quietly = TRUE)
  if (plot_tol > 0 && !has_png) {
    warning("plot_tol needs the png package; plots are compared by checksum only.", call. = FALSE)
  }
  vers <- read_versions(d)
  runs_file <- work_path(d, "runs", "runs.rds")
  if (!file.exists(runs_file)) stop("No runs in ", d$work, "; run run_scenarios() first.", call. = FALSE)
  runs <- readRDS(runs_file)
  rd <- function(run) {
    f <- work_path(d, "runs", run, "results.rds")
    if (file.exists(f)) readRDS(f) else NULL
  }
  ra <- rd("base_a")
  da <- rd("cand_a")
  if (is.null(ra) || is.null(da)) stop("Run results are missing; run run_scenarios() again.", call. = FALSE)
  two <- all(c("base_b", "cand_b") %in% runs$plan$run)
  rb <- if (two) rd("base_b") else NULL
  db <- if (two) rd("cand_b") else NULL
  # the NEWS, provenance and labels come from versions.rds: they must describe the
  # installs the runs were made with
  for (r in list(list(ra, "base"), list(rb, "base"), list(da, "cand"), list(db, "cand"))) {
    m <- r[[1]]$meta
    v <- vers[[r[[2]]]]
    if (!is.null(m) && (!identical(m$identity, v$identity) || (!is.null(m$setup) && !identical(m$setup, v$setup)))) {
      stop("The ", if (r[[2]] == "base") "baseline" else "candidate", " was prepared again after run ",
           m$label, " was made (prepare_versions() after run_scenarios()); run run_scenarios(d) ",
           "before comparing.", call. = FALSE)
    }
  }
  # the runs say how they were made; a dossier described differently since is noted
  if (!is.null(runs$recipe)) {
    now <- run_recipe(d)
    drift <- names(now)[!mapply(identical, now, runs$recipe[names(now)])]
    if (length(drift)) {
      warning("The stored runs were made with other ", paste(drift, collapse = ", "),
              " than the dossier has now; the comparison describes the stored runs. ",
              if (any(startsWith(drift, "deps"))) "Run prepare_versions(d) and run_scenarios(d)"
              else "Run run_scenarios(d)", " to make them again.", call. = FALSE)
    }
  }
  plotdir <- function(run) work_path(d, "runs", run, "plots")

  labels <- version_labels(vers)
  news <- read_news(vers$cand$unpacked, vers$base$version, pkg = d$pkg, lib = vers$cand$lib)
  installed_desc <- function(v) {
    f <- file.path(v$lib, d$pkg, "DESCRIPTION")
    if (file.exists(f)) read_desc(f) else list()
  }
  desc_base <- installed_desc(vers$base)
  desc_cand <- installed_desc(vers$cand)
  n_metadata <- 0L
  ns_functions <- union(ra$meta$functions, da$meta$functions)
  parallel_runs <- if (!is.null(runs$plan$overlapped)) any(runs$plan$overlapped %in% TRUE) else isTRUE(runs$workers > 1L)
  # runs reused from an earlier call were made at another time, under another load:
  # ABBA's balance is lost, so their timings are not labelled either
  mixed_calls <- !is.null(runs$plan$batch) && length(unique(runs$plan$batch)) > 1L
  unlabelled <- parallel_runs || mixed_calls
  # runs that competed for the machine have timings, but not ones to label
  opts <- list(tol = tol, min_time = min_time, min_ratio = min_ratio,
               min_timings = if (unlabelled) Inf else min_timings,
               plot_tol = plot_tol, png = has_png,
               plots_base = plotdir("base_a"), plots_cand = plotdir("cand_a"))
  scen_out <- list()
  rows <- list()
  determinism <- character()
  for (sid in names(ra$scenarios)) {
    sa <- ra$scenarios[[sid]]
    sb <- rb$scenarios[[sid]]
    ta <- da$scenarios[[sid]]
    tb <- db$scenarios[[sid]]
    steps <- list()
    not_run <- list()
    creators <- list()  # object name -> package functions that produced it
    for (st in names(sa$steps)) {
      x <- sa$steps[[st]]
      y <- ta$steps[[st]]
      if (isTRUE(x$not_run) || isTRUE(y$not_run)) {
        not_run[[length(not_run) + 1L]] <- list(
          id = st, label = x$label, code = x$code,
          reason = if (!is.null(x$note)) x$note else if (!is.null(x$eval_expr)) {
            paste0("eval = ", x$eval_expr, " was false", if (!isTRUE(x$not_run) || !isTRUE(y$not_run)) " under one version" else "")
          } else "eval = FALSE"
        )
        next
      }
      rec <- compare_step(x, sb$steps[[st]], y, tb$steps[[st]], opts)
      if (!keep_metadata && nrow(rec$diffs)) {
        own <- own_metadata(rec$diffs, desc_base, desc_cand)
        if (any(own)) {
          n_metadata <- n_metadata + sum(own)
          rec$own_metadata <- sum(own)
          rec$diffs <- rec$diffs[!own, , drop = FALSE]
          rec$kinds <- unique(rec$diffs$kind)
          if (!nrow(rec$diffs) && identical(rec$status, "changed")) rec$status <- "same"
        }
      }
      traced <- trace_step(x$code, unique(c(x$class, y$class)), ns_functions, creators)
      creators <- traced$creators
      rec$news_functions <- traced$functions
      rec$news <- news_for_step(news$bullets, rec$news_functions)
      if (nrow(rec$diffs)) {
        rec$diffs$news <- vapply(seq_len(nrow(rec$diffs)), function(k) {
          b <- rank_news(rec$news, rec$diffs$kind[k], rec$diffs$path[k])
          if (length(b)) paste(b, collapse = "\n") else NA_character_
        }, "")
        rec$diffs$no_news <- if (is.null(news$bullets)) NA else !length(rec$news)
      }
      if (isTRUE(rec$unstable$base)) determinism <- c(determinism, paste0(labels$base, " ", sid, "/", st))
      if (isTRUE(rec$unstable$cand)) determinism <- c(determinism, paste0(labels$cand, " ", sid, "/", st))
      if (nrow(rec$diffs)) rows[[length(rows) + 1L]] <- cbind(scenario = sid, step = st, label = x$label, rec$diffs,
                                                               stringsAsFactors = FALSE)
      rec$diffs <- NULL
      steps[[length(steps) + 1L]] <- rec
    }
    steps <- attribute_problems(steps)
    scen_out[[length(scen_out) + 1L]] <- list(id = sid, title = sa$title, source = sa$source,
                                              notes = sa$notes, steps = steps, not_run = not_run)
  }
  if (api) {
    ad <- api_diff(ra$meta$api, da$meta$api)
    if (!is.null(ad)) {
      ad$news <- vapply(ad$step, function(fn) {
        b <- news_for_step(news$bullets, fn)
        if (length(b)) paste(b, collapse = "\n") else NA_character_
      }, "", USE.NAMES = FALSE)
      ad$no_news <- if (is.null(news$bullets)) NA else is.na(ad$news)
      rows[[length(rows) + 1L]] <- ad
    }
  }
  diffs <- if (length(rows)) do.call(rbind, rows) else empty_diffs()
  diffs <- diffs[order(diffs$severity, match(diffs$scenario, names(ra$scenarios))), , drop = FALSE]
  rownames(diffs) <- NULL
  accepted <- apply_accept(diffs, accept)
  diffs <- accepted$diffs

  structure(list(
    meta = list(
      pkg = d$pkg, labels = labels, base = ra$meta, cand = da$meta,
      provenance = vers, order = runs$order %||% d$order, reps = runs$reps, runs = runs$plan,
      runs_base = c(ra$meta$started, rb$meta$started),
      runs_cand = c(da$meta$started, db$meta$started),
      load_before = runs$load_before, load_after = runs$load_after,
      missing_packages = runs$missing, own_metadata = n_metadata, workers = runs$workers %||% 1L,
      parallel_runs = parallel_runs, mixed_calls = mixed_calls,
      determinism_checked = two, determinism_failures = determinism,
      news = list(file = news$file, note = news$note,
                  bullets = if (is.null(news$bullets)) NULL else news$bullets),
      coverage = coverage(scen_out, ra$meta$api, da$meta$api, news$bullets, diffs),
      api_checked = api && !is.null(ra$meta$api) && !is.null(da$meta$api),
      accept = accepted$info,
      tol = tol, min_time = min_time, min_ratio = min_ratio, min_timings = min_timings, plot_tol = plot_tol,
      timing_unlabelled = if (unlabelled) 0L else sum(unlist(lapply(scen_out, function(s) vapply(s$steps, function(r) {
        !isTRUE(r$time$base$single) && !isTRUE(r$time$cand$single) &&
          min(r$time$base$n, r$time$cand$n) < min_timings
      }, logical(1))))),
      plot_pixels = has_png,
      compared = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      pkgdossier_version = as.character(utils::packageVersion("pkgdossier"))
    ),
    scenarios = scen_out,
    differences = diffs,
    work = d$work,
    dossier = d
  ), class = "pkgdossier_comparison")
}

difference_kinds <- function() {
  k <- c(unstable = 0L, error_new = 1L, field_removed = 1L, condition_class_changed = 2L,
         value_moved = 2L, warning_new = 2L, output_changed = 3L, plot_changed = 3L,
         slower = 3L, faster = 3L, warning_gone = 4L, field_added = 4L, error_fixed = 4L,
         api_kinds())
  k[order(k)]
}

empty_diffs <- function() {
  data.frame(scenario = character(), step = character(), label = character(),
             kind = character(), severity = integer(), path = character(),
             base = character(), cand = character(), rel_change = numeric(),
             detail = character(), news = character(), no_news = logical(),
             accepted = logical(), accepted_reason = character(), stringsAsFactors = FALSE)
}

version_labels <- function(vers) {
  b <- vers$base$version
  c <- vers$cand$version
  if (identical(b, c)) list(base = paste(b, "(baseline)"), cand = paste(c, "(candidate)")) else list(base = b, cand = c)
}

# One step: the record the report shows, plus its labelled differences.
compare_step <- function(x, x2, y, y2, opts) {
  rows <- list()
  add <- function(kind, path = NA_character_, base = NA_character_, cand = NA_character_,
                  rel = NA_real_, detail = NA_character_) {
    rows[[length(rows) + 1L]] <<- data.frame(
      kind = kind, severity = difference_kinds()[[kind]], path = path,
      base = as.character(base), cand = as.character(cand), rel_change = rel,
      detail = detail, stringsAsFactors = FALSE)
  }
  rec <- list(
    id = x$id, kind = x$kind, label = x$label, code = x$code, note = x$note,
    error = list(base = x$error, cand = y$error),
    error_class = list(base = x$error_class, cand = y$error_class),
    warnings = list(base = x$warnings, cand = y$warnings),
    transcript = list(base = x$transcript, cand = y$transcript),
    time = list(base = pool_times(x, x2), cand = pool_times(y, y2)),
    unstable = list(base = !is.null(x2) && !same_run(x, x2), cand = !is.null(y2) && !same_run(y, y2)),
    capped = list(base = x$capped, cand = y$capped)
  )
  rec$time$ratio <- rec$time$cand$elapsed / rec$time$base$elapsed
  rec$time$cpu_ratio <- rec$time$cand$cpu / rec$time$base$cpu
  if (!identical(x$transcript, y$transcript)) rec$transcript_diff <- line_diff(x$transcript, y$transcript)
  if (length(x$printed) || length(y$printed)) {
    rec$printed_diff <- line_diff(x$printed, y$printed)
    rec$printed_same <- identical(x$printed, y$printed)
  }
  if (!is.null(x$values) && !is.null(y$values)) rec$values <- value_diff(x$values, y$values, opts$tol)
  if (!is.null(x$struct) && !is.null(y$struct)) {
    rec$struct <- list(only_base = setdiff(x$struct, y$struct), only_cand = setdiff(y$struct, x$struct))
  }
  if (length(x$files) || length(y$files)) {
    rec$plot <- list(
      changed = !identical(x$plot_md5, y$plot_md5),
      files_base = file.path(opts$plots_base, x$files),
      files_cand = file.path(opts$plots_cand, y$files),
      w = x$w, h = x$h
    )
    if (rec$plot$changed && opts$png && length(x$files) == length(y$files)) {
      rec$plot$pixel_share <- mapply(pixel_share, rec$plot$files_base, rec$plot$files_cand,
                                     USE.NAMES = FALSE)
      if (all(!is.na(rec$plot$pixel_share)) && max(rec$plot$pixel_share) <= opts$plot_tol) {
        rec$plot$changed <- FALSE
        rec$plot$below_tol <- TRUE
      }
    }
  }

  finish <- function(status) {
    rec$status <- status
    rec$diffs <- if (length(rows)) do.call(rbind, rows) else
      empty_diffs()[, setdiff(names(empty_diffs()), c("scenario", "step", "label", "accepted", "accepted_reason"))]
    rec$kinds <- unique(rec$diffs$kind)
    rec
  }

  if (rec$unstable$base || rec$unstable$cand) {
    who <- c("baseline", "candidate")[c(rec$unstable$base, rec$unstable$cand)]
    add("unstable", base = if (rec$unstable$base) "differs between runs" else "stable",
        cand = if (rec$unstable$cand) "differs between runs" else "stable",
        detail = paste("the two runs of the", paste(who, collapse = " and the "), "disagree"))
    return(finish("unstable"))
  }

  eb <- x$error
  ec <- y$error
  if (!is.null(eb) || !is.null(ec)) {
    if (!is.null(eb) && !is.null(ec)) {
      if (identical(eb, ec) && !identical(x$error_class, y$error_class)) {
        add("condition_class_changed", path = "error", base = class_str(x$error_class),
            cand = class_str(y$error_class), detail = eb)
      }
      # R stopping, a time limit or pkgdossier failing to capture under one version
      # only is a change, even where the other version errors too
      broke <- function(cls) any(startsWith(cls %||% character(), "pkgdossier_"))
      if (broke(y$error_class) && !broke(x$error_class)) {
        add("error_new", path = "error", base = eb, cand = ec,
            detail = "errors under both versions, but under the candidate the step did not run to its error")
        return(finish("error_new"))
      }
      if (broke(x$error_class) && !broke(y$error_class)) {
        add("error_fixed", path = "error", base = eb, cand = ec,
            detail = "errors under both versions, but under the baseline the step did not run to its error")
        return(finish("error_fixed"))
      }
      return(finish("error_both"))
    }
    if (!is.null(ec)) {
      add("error_new", path = "error", cand = ec, detail = class_str(y$error_class))
      return(finish("error_new"))
    }
    add("error_fixed", path = "error", base = eb, detail = class_str(x$error_class))
    return(finish("error_fixed"))
  }

  # errors a chunk with error = TRUE shows are in its console output, and compared
  # there; a changed class is noted here
  if (length(x$shown_errors) || length(y$shown_errors)) rec$expected_error <- TRUE
  for (k in seq_along(x$shown_errors)) {
    j <- match(x$shown_errors[k], y$shown_errors)
    if (!is.na(j) && !identical(x$shown_error_classes[[k]], y$shown_error_classes[[j]])) {
      add("condition_class_changed", path = "error", base = class_str(x$shown_error_classes[[k]]),
          cand = class_str(y$shown_error_classes[[j]]), detail = x$shown_errors[k])
    }
  }

  wb <- x$warnings %||% character()
  wc <- y$warnings %||% character()
  for (w in setdiff(wc, wb)) add("warning_new", path = "warning", cand = w)
  for (w in setdiff(wb, wc)) add("warning_gone", path = "warning", base = w)
  for (w in intersect(wb, wc)) {
    cb <- x$warning_classes[[match(w, wb)]]
    cc <- y$warning_classes[[match(w, wc)]]
    if (!identical(cb, cc)) {
      add("condition_class_changed", path = "warning", base = class_str(cb), cand = class_str(cc), detail = w)
    }
  }

  # output whose only change is printed numbers within tol is counted, not labelled:
  # optimiser noise shows in the last printed digit while the values are unchanged
  if (!is.null(rec$transcript_diff)) {
    if (digits_only(rec$transcript_diff, opts$tol)) {
      rec$transcript_digits_only <- TRUE
    } else {
      add("output_changed", path = "console", detail = diff_detail(rec$transcript_diff),
          base = first_change(rec$transcript_diff, 2L), cand = first_change(rec$transcript_diff, 3L))
    }
  }
  if (isFALSE(rec$printed_same)) {
    if (digits_only(rec$printed_diff, opts$tol)) {
      rec$printed_digits_only <- TRUE
    } else {
      add("output_changed", path = "printed", detail = diff_detail(rec$printed_diff),
          base = first_change(rec$printed_diff, 2L), cand = first_change(rec$printed_diff, 3L))
    }
  }

  v <- rec$values
  if (!is.null(v)) {
    for (r in v$changed) add("value_moved", path = r[[1]], base = fmt_num(r[[2]]), cand = fmt_num(r[[3]]),
                             rel = rel_change(r[[2]], r[[3]]))
    for (r in v$text_changed) add("value_moved", path = r[[1]], base = r[[2]], cand = r[[3]], detail = "text")
  }
  if (!is.null(rec$struct)) {
    for (p in rec$struct$only_base) add("field_removed", path = p)
    for (p in rec$struct$only_cand) add("field_added", path = p)
  }
  if (isTRUE(rec$plot$changed)) {
    nb <- length(x$files)
    nc <- length(y$files)
    add("plot_changed", path = "plot", base = paste(nb, "image(s)"), cand = paste(nc, "image(s)"),
        detail = if (nb != nc) "different number of images" else plot_detail(rec$plot$pixel_share))
  }

  tb <- rec$time$base
  tc <- rec$time$cand
  half_tick <- 0.005  # timings come in ticks of about 10 ms on Windows; equal ticks are not a gap
  if (!tb$single && !tc$single && min(tb$n, tc$n) >= opts$min_timings &&
      max(tb$elapsed, tc$elapsed) >= opts$min_time) {
    ratio <- tc$elapsed / tb$elapsed
    # a median of zero (under the timer's resolution) has no meaningful ratio
    rel <- if (is.finite(ratio)) ratio - 1 else NA_real_
    detail <- sprintf("%s over %d and %d timings",
                      if (is.finite(ratio) && ratio > 0) sprintf("median x%.2f", ratio) else "median from or to 0 s",
                      tb$n, tc$n)
    if (tc$min > tb$max + half_tick && ratio >= opts$min_ratio) {
      add("slower", path = "time", base = fmt_sec(tb$elapsed), cand = fmt_sec(tc$elapsed), rel = rel,
          detail = detail)
    } else if (tc$max < tb$min - half_tick && ratio <= 1 / opts$min_ratio) {
      add("faster", path = "time", base = fmt_sec(tb$elapsed), cand = fmt_sec(tc$elapsed), rel = rel,
          detail = detail)
    }
  }
  finish(if (length(rows)) "changed" else "same")
}

same_run <- function(x, y) {
  identical(x$printed, y$printed) && identical(x$transcript, y$transcript) &&
    identical(x$values, y$values) && identical(x$error, y$error) &&
    identical(x$warnings, y$warnings) && identical(x$plot_md5, y$plot_md5)
}

# Timings pooled over both runs of a version: the timed repeats where there are any,
# otherwise the captured runs' own times (marked `single`: too few to label).
pool_times <- function(x, x2) {
  r <- rbind(x$reps, x2$reps)
  if (is.null(r) || nrow(r) == 0L) {
    e <- c(x$elapsed, x2$elapsed)
    cpu <- c(x$cpu, x2$cpu)
    if (!length(e)) {
      return(list(elapsed = NA_real_, cpu = NA_real_, n = 0L, min = NA_real_, max = NA_real_, single = TRUE))
    }
    return(list(elapsed = stats::median(e), cpu = stats::median(cpu), n = length(e),
                min = min(e), max = max(e), single = TRUE))
  }
  list(elapsed = stats::median(r[, "elapsed"]), cpu = stats::median(r[, "cpu"]), n = nrow(r),
       min = min(r[, "elapsed"]), max = max(r[, "elapsed"]), single = FALSE)
}

# Line diff by longest common subsequence; runs of deletions and insertions are paired
# into "~" rows so the report can show them side by side. The lines both sides share
# at the start and the end are matched first, so a local change in long output costs
# little; the LCS, quadratic in time and memory, runs only on the part between them,
# and when that part has more than `max_cells` line pairs it is shown as one replaced
# block instead.
line_diff <- function(a, b, max_cells = 4e6) {
  a <- a %||% character()
  b <- b %||% character()
  n <- length(a)
  m <- length(b)
  k <- min(n, m)
  same <- a[seq_len(k)] == b[seq_len(k)]
  same[is.na(same)] <- FALSE
  pre <- if (all(same)) k else which(!same)[1L] - 1L
  k <- k - pre
  same <- a[n - seq_len(k) + 1L] == b[m - seq_len(k) + 1L]
  same[is.na(same)] <- FALSE
  suf <- if (all(same)) k else which(!same)[1L] - 1L
  keep <- function(x) list("=", x, x)
  mid_a <- a[seq_len(n - pre - suf) + pre]
  mid_b <- b[seq_len(m - pre - suf) + pre]
  c(lapply(a[seq_len(pre)], keep),
    lcs_rows(mid_a, mid_b, max_cells),
    lapply(a[seq_len(suf) + n - suf], keep))
}

lcs_rows <- function(a, b, max_cells) {
  n <- length(a)
  m <- length(b)
  if (as.numeric(n) * m > max_cells) {
    ops <- c(lapply(a, function(x) c("-", x, "")), lapply(b, function(x) c("+", "", x)))
    return(pair_ops(ops))
  }
  L <- matrix(0L, n + 1L, m + 1L)
  if (n > 0L && m > 0L) {
    for (i in n:1) for (j in m:1) {
      L[i, j] <- if (identical(a[i], b[j])) L[i + 1L, j + 1L] + 1L else max(L[i + 1L, j], L[i, j + 1L])
    }
  }
  ops <- list()
  i <- 1L
  j <- 1L
  while (i <= n || j <= m) {
    if (i <= n && j <= m && identical(a[i], b[j])) {
      ops[[length(ops) + 1L]] <- c("=", a[i], b[j])
      i <- i + 1L
      j <- j + 1L
    } else if (j <= m && (i > n || L[i, j + 1L] >= L[i + 1L, j])) {
      ops[[length(ops) + 1L]] <- c("+", "", b[j])
      j <- j + 1L
    } else {
      ops[[length(ops) + 1L]] <- c("-", a[i], "")
      i <- i + 1L
    }
  }
  pair_ops(ops)
}

# Runs of "-" and "+" become "~" rows (one deleted and one inserted line side by side),
# with any surplus left as "-" or "+".
pair_ops <- function(ops) {
  out <- list()
  k <- 1L
  while (k <= length(ops)) {
    if (ops[[k]][1] %in% c("-", "+")) {
      dels <- character()
      ins <- character()
      while (k <= length(ops) && ops[[k]][1] %in% c("-", "+")) {
        if (ops[[k]][1] == "-") dels <- c(dels, ops[[k]][2]) else ins <- c(ins, ops[[k]][3])
        k <- k + 1L
      }
      for (p in seq_len(max(length(dels), length(ins)))) {
        l <- if (p <= length(dels)) dels[p] else NA_character_
        r <- if (p <= length(ins)) ins[p] else NA_character_
        op <- if (!is.na(l) && !is.na(r)) "~" else if (!is.na(l)) "-" else "+"
        out[[length(out) + 1L]] <- list(op, if (is.na(l)) "" else l, if (is.na(r)) "" else r)
      }
    } else {
      out[[length(out) + 1L]] <- list("=", ops[[k]][2], ops[[k]][3])
      k <- k + 1L
    }
  }
  out
}

# TRUE when every changed line differs only in its numbers, each pair within `tol`
# relative to the larger: the same text once numbers are masked (whitespace runs
# collapsed, since column widths move with the digits) and as many numbers on each
# side. Lines added or removed are never digits only.
digits_only <- function(rows, tol) {
  changed <- Filter(function(r) r[[1]] != "=", rows)
  if (!length(changed)) return(FALSE)
  num_re <- "[-+]?(?:[0-9]+\\.?[0-9]*|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?"
  skeleton <- function(s) gsub("\\s+", " ", trimws(gsub(num_re, "#", s, perl = TRUE)))
  numbers <- function(s) suppressWarnings(as.numeric(regmatches(s, gregexpr(num_re, s, perl = TRUE))[[1]]))
  for (r in changed) {
    if (r[[1]] != "~" || !identical(skeleton(r[[2]]), skeleton(r[[3]]))) return(FALSE)
    a <- numbers(r[[2]])
    b <- numbers(r[[3]])
    if (length(a) != length(b) || anyNA(a) || anyNA(b)) return(FALSE)
    rel <- abs(a - b) / pmax(abs(a), abs(b), 1e-12)
    if (any(rel > tol)) return(FALSE)
  }
  TRUE
}

diff_detail <- function(rows) {
  ops <- vapply(rows, `[[`, "", 1L)
  sprintf("%d line(s) changed, %d removed, %d added", sum(ops == "~"), sum(ops == "-"), sum(ops == "+"))
}

first_change <- function(rows, side) {
  for (r in rows) if (r[[1]] != "=") return(r[[side]])
  NA_character_
}

# Numbers that moved (relative change above tol, or an NA appearing or going away),
# tiny differences below tol (counted), changed short strings, paths one side lacks.
value_diff <- function(va, vb, tol) {
  # paths must be unique for the merge; the runner numbers repeated ones
  va$path <- number_duplicate_paths(va$path)
  vb$path <- number_duplicate_paths(vb$path)
  m <- merge(va, vb, by = "path", all = TRUE, suffixes = c(".a", ".b"), sort = FALSE)
  if (!nrow(m)) {
    return(list(n_compared = 0L, n_changed = 0L, n_tiny = 0L, tiny_max_rel = 0,
                changed = list(), text_changed = list(), only_base = list(), only_cand = list()))
  }
  in_a <- m$path %in% va$path
  in_b <- m$path %in% vb$path
  both <- in_a & in_b
  num <- both & is.na(m$text.a) & is.na(m$text.b)
  diff <- abs(m$value.a - m$value.b)
  rel <- diff / pmax(abs(m$value.a), 1e-12)
  na_flip <- num & (is.na(m$value.a) != is.na(m$value.b))
  changed <- num & ((!is.na(rel) & rel > tol & diff > 1e-10) | na_flip)
  tiny <- num & !changed & !is.na(rel) & rel > 1e-8 & diff > 1e-12
  txt_changed <- both & (!is.na(m$text.a) | !is.na(m$text.b)) & !mapply(identical, m$text.a, m$text.b)
  ord <- order(match(m$path, unique(c(va$path, vb$path))))
  pick <- function(idx, cols) {
    idx <- ord[idx[ord]]
    unname(lapply(idx, function(i) unname(as.list(m[i, cols]))))
  }
  list(
    n_compared = sum(num), n_changed = sum(changed), n_tiny = sum(tiny),
    tiny_max_rel = if (any(tiny)) max(rel[tiny]) else 0,
    changed = pick(changed, c("path", "value.a", "value.b")),
    text_changed = pick(txt_changed, c("path", "text.a", "text.b")),
    only_base = pick(in_a & !in_b, c("path", "value.a", "text.a")),
    only_cand = pick(!in_a & in_b, c("path", "value.b", "text.b"))
  )
}

rel_change <- function(a, b) {
  if (is.na(a) || is.na(b) || a == 0) return(NA_real_)
  (b - a) / abs(a)
}

fmt_num <- function(v) if (is.na(v)) "NA" else format(v, digits = 7)

fmt_sec <- function(s) sprintf("%.3f s", s)

class_str <- function(cl) paste(cl %||% character(), collapse = "/")

# Share of pixels that differ between two PNG files (any channel), or NA when the
# images differ in size or cannot be read.
pixel_share <- function(a, b) {
  img_a <- tryCatch(png::readPNG(a), error = function(e) NULL)
  img_b <- tryCatch(png::readPNG(b), error = function(e) NULL)
  if (is.null(img_a) || is.null(img_b) || !identical(dim(img_a), dim(img_b))) return(NA_real_)
  differ <- abs(img_a - img_b) > 1e-8
  if (length(dim(differ)) == 3L) {
    any_channel <- differ[, , 1L]
    for (k in seq_len(dim(differ)[3L])[-1L]) any_channel <- any_channel | differ[, , k]
    differ <- any_channel
  }
  mean(differ)
}

plot_detail <- function(share) {
  if (is.null(share) || !length(share) || all(is.na(share))) return("image checksums differ")
  sprintf("%s of pixels differ", paste(ifelse(is.na(share), "size changed", fmt_share(share)), collapse = ", "))
}

fmt_share <- function(x) {
  ifelse(x > 0 & x < 0.0001, "<0.01%", sprintf("%.2f%%", 100 * x))
}

number_duplicate_paths <- function(paths) {
  if (!anyDuplicated(paths)) return(paths)
  k <- stats::ave(seq_along(paths), paths, FUN = seq_along)
  ifelse(k > 1L, paste0(paths, "#", k), paths)
}

# Differences that are the package's own DESCRIPTION fields: the path's last element
# is a field of one version's installed DESCRIPTION, and the two sides are that
# field's values in the two versions (or the field is in only one of them).
own_metadata <- function(rows, desc_base, desc_cand) {
  norm <- function(x) if (is.null(x) || is.na(x)) NA_character_ else gsub("\\s+", " ", trimws(x))
  fields <- union(names(desc_base), names(desc_cand))
  vapply(seq_len(nrow(rows)), function(i) {
    path <- rows$path[i]
    if (is.na(path) || !grepl("[$@]", path)) return(FALSE)
    f <- sub("^.*[$@]", "", path)
    if (!f %in% fields) return(FALSE)
    switch(rows$kind[i],
      value_moved = identical(norm(rows$base[i]), norm(desc_base[[f]])) &&
        identical(norm(rows$cand[i]), norm(desc_cand[[f]])),
      field_removed = f %in% names(desc_base) && !f %in% names(desc_cand),
      field_added = f %in% names(desc_cand) && !f %in% names(desc_base),
      FALSE)
  }, logical(1))
}
