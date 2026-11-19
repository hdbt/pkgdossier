#' The labelled differences of a comparison
#'
#' @param x An `pkgdossier_comparison` from [compare_runs()].
#' @param kind,scenario Keep only these kinds of difference (see [compare_runs()])
#'   or these scenarios.
#' @param max_severity Keep only differences of this severity or more severe (1 is
#'   the most severe; `unstable` steps have severity 0).
#' @param accepted `TRUE` keeps only accepted differences, `FALSE` only the others
#'   (see [accept_differences()]).
#' @param group `TRUE` gives one row per distinct change instead of one per
#'   occurrence: rows of the same kind with the same `base` and `cand` and the same
#'   path below the object (`*$summary$se` for both `m1$summary$se` and
#'   `m2$summary$se`) are one change, with columns `n` (occurrences), `steps`
#'   (number of steps) and `where` (the first few `scenario/step`). A new field in a
#'   model object, found in every step that holds such an object, is then one row.
#' @param no_news `TRUE` keeps only differences in steps that no NEWS bullet names
#'   (see "NEWS candidates" in [compare_runs()]); `FALSE` keeps only those with a
#'   candidate bullet.
#' @param ... Must be empty; a misspelled filter (`kinds =`) is an error rather than
#'   an unfiltered table.
#' @return A data frame with one row per difference, most severe first: `scenario`,
#'   `step`, `label`, `kind`, `severity`, `path` (where in the step: an element path,
#'   `"printed"`, `"console"`, `"warning"`, `"error"`, `"plot"` or `"time"`), `base`
#'   and `cand` (the two sides, as text), `rel_change` (for numbers and timings),
#'   `detail`, `news` (the candidate NEWS bullets for the step, one per line, or `NA`)
#'   `no_news` (`TRUE` when there are none; `NA` when the candidate has no NEWS file
#'   that could be read), and `accepted` and `accepted_reason` (see
#'   [accept_differences()]).
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' differences(cmp, kind = c("error_new", "field_removed"))
#' differences(cmp, max_severity = 2)
#' }
#' @export
differences <- function(x, ...) UseMethod("differences")

#' @rdname differences
#' @export
differences.pkgdossier_comparison <- function(x, kind = NULL, scenario = NULL,
                                               max_severity = NULL, no_news = NULL,
                                               accepted = NULL, group = FALSE, ...) {
  if (...length()) {
    nms <- names(list(...)) %||% character()
    nms <- nms[nzchar(nms)]
    stop("differences() has no argument", if (length(nms) > 1L) "s", " ",
         if (length(nms)) paste0("`", nms, "`", collapse = ", ") else "given by position after `group`",
         "; its filters are kind, scenario, max_severity, no_news, accepted and group.", call. = FALSE)
  }
  out <- x$differences
  if (!is.null(accepted)) {
    stopifnot(is.logical(accepted), length(accepted) == 1L, !is.na(accepted))
    out <- out[(out$accepted %in% TRUE) == accepted, , drop = FALSE]
  }
  if (!is.null(no_news)) {
    stopifnot(is.logical(no_news), length(no_news) == 1L, !is.na(no_news))
    out <- out[!is.na(out$no_news) & out$no_news == no_news, , drop = FALSE]
  }
  if (!is.null(kind)) {
    bad <- setdiff(kind, names(difference_kinds()))
    if (length(bad)) stop("Unknown kind(s): ", paste(bad, collapse = ", "), call. = FALSE)
    out <- out[out$kind %in% kind, , drop = FALSE]
  }
  if (!is.null(scenario)) out <- out[out$scenario %in% scenario, , drop = FALSE]
  if (!is.null(max_severity)) out <- out[out$severity <= max_severity, , drop = FALSE]
  rownames(out) <- NULL
  if (isTRUE(group)) group_differences(out) else out
}

# One row per distinct change: same kind, base and cand, and, for changes inside
# objects, the same path below the object's name.
group_differences <- function(d) {
  cols <- data.frame(kind = character(), severity = integer(), path = character(), base = character(),
                     cand = character(), rel_change = numeric(), detail = character(), n = integer(),
                     steps = integer(), where = character(), scenario = character(), step = character(),
                     label = character(), news = character(), no_news = logical(), accepted = logical(),
                     stringsAsFactors = FALSE)
  if (!nrow(d)) return(cols)
  pattern <- change_pattern(d$kind, d$path)
  key <- paste(d$kind, pattern, d$base, d$cand, sep = "\r")
  groups <- split(seq_len(nrow(d)), factor(key, levels = unique(key)))
  rows <- lapply(groups, function(i) {
    where <- unique(paste0(d$scenario[i], "/", d$step[i]))
    news <- d$news[i][!is.na(d$news[i])]
    # the real path when every occurrence has it, the pattern (`*$...`) otherwise
    path <- if (length(unique(d$path[i])) == 1L) d$path[i[1]] else pattern[i[1]]
    data.frame(kind = d$kind[i[1]], severity = d$severity[i[1]], path = path,
               base = d$base[i[1]], cand = d$cand[i[1]], rel_change = d$rel_change[i[1]],
               detail = d$detail[i[1]], n = length(i), steps = length(where),
               where = paste0(paste(utils::head(where, 3L), collapse = ", "),
                              if (length(where) > 3L) sprintf(" and %d more", length(where) - 3L) else ""),
               scenario = d$scenario[i[1]], step = d$step[i[1]], label = d$label[i[1]],
               news = if (length(news)) news[1] else NA_character_,
               no_news = if (all(is.na(d$no_news[i]))) NA else all(d$no_news[i] %in% TRUE),
               accepted = all(d$accepted[i] %in% TRUE), stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$severity, -out$n), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# For changes inside objects, the path with the object's name replaced by `*`.
change_pattern <- function(kind, path) {
  inside <- kind %in% c("value_moved", "field_removed", "field_added") & !is.na(path) &
    !startsWith(path, "(") & !startsWith(path, "#")
  ifelse(inside, sub("^[^$@[]+", "*", path), path)
}

#' @export
print.pkgdossier_comparison <- function(x, ...) {
  m <- x$meta
  st <- step_table(x)
  cat(sprintf("<pkgdossier comparison> %s %s -> %s\n", m$pkg, m$labels$base, m$labels$cand))
  cat(sprintf("%d scenario(s), %d step(s) compared, %d not run; %s runs, %d timed repeats per timed step\n",
              length(x$scenarios), nrow(st), sum(vapply(x$scenarios, function(s) length(s$not_run), 0L)),
              m$order, m$reps))
  d <- x$differences[!(x$differences$accepted %in% TRUE), , drop = FALSE]
  n_accepted <- sum(x$differences$accepted %in% TRUE)
  cat(verdict_line(x, d), "\n", sep = "")
  if (!nrow(d)) {
    cat(if (n_accepted) "\nNo differences that are not accepted.\n" else "\nNo differences.\n")
  } else {
    kinds <- difference_kinds()
    counts <- table(factor(d$kind, levels = names(kinds)))
    counts <- counts[counts > 0]
    steps_per <- tapply(paste(d$scenario, d$step), factor(d$kind, levels = names(kinds)),
                        function(s) length(unique(s)))
    g <- group_differences(d)
    distinct <- table(factor(g$kind, levels = names(kinds)))
    cat("\nDifferences by kind (severity):\n")
    for (k in names(counts)) {
      cat(sprintf("  %-24s %2d  %4d in %d step(s)%s\n", k, kinds[[k]], counts[[k]], steps_per[[k]],
                  if (distinct[[k]] < counts[[k]]) sprintf(", %d distinct", distinct[[k]]) else ""))
    }
    if (is.na(m$news$file %||% NA)) {
      cat("\nNEWS candidates not checked: ", m$news$note %||% "no NEWS file", ".\n", sep = "")
    } else {
      cat(sprintf("\nNEWS candidates (%s): %d of %d difference(s) in steps no NEWS bullet names.\n",
                  m$news$note, sum(d$no_news %in% TRUE), nrow(d)))
    }
  }
  if (isTRUE(m$own_metadata > 0L)) {
    cat(sprintf("\n%d difference(s) in %s's own DESCRIPTION fields (Version, Packaged, ...), as an example printing sessionInfo() shows them, are not listed.\n",
                m$own_metadata, m$pkg))
  }
  if (isTRUE(m$parallel_runs %||% (m$workers > 1L))) {
    cat(sprintf("\nRuns went up to %d at a time: timings are shown, but no step is labelled slower or faster.\n",
                m$workers))
  } else if (isTRUE(m$mixed_calls)) {
    cat("\nSome runs were reused from an earlier call and others made anew: timings are shown, but no step is",
        "labelled slower or faster. run_scenarios(cmp$dossier, force = TRUE) makes all runs together.\n")
  }
  if (isTRUE(m$timing_unlabelled > 0L)) {
    cat(sprintf("\nTimings: %d timed step(s) have fewer than %d timings per version, too few to label slower or faster; raise reps.\n",
                m$timing_unlabelled, m$min_timings))
  }
  if (!is.null(m$accept)) cat("\n", accept_line(m$accept, n_accepted), "\n", sep = "")
  cv <- m$coverage
  if (!is.null(cv) && cv$exported > 0L) {
    cat("\n", coverage_line(cv, code = function(x) x), "\n", sep = "")
    if (length(cv$news_unmatched)) {
      cat(sprintf("%d NEWS bullet(s) match no step or API change: changes the scenarios may not exercise.\n",
                  length(cv$news_unmatched)))
    }
  }
  dl <- deps_line(m$provenance$deps)
  if (!is.null(dl)) cat("\n", dl, "\n", sep = "")
  crashes <- crash_lines(x)
  if (length(crashes)) {
    cat("\n", crash_header(crashes), "\n", paste0("  ", crashes, "\n"), sep = "")
  }
  problems <- problem_lines(x)
  if (length(problems)) {
    cat("\nScenario problems (error under both versions): ", paste(problems, collapse = "; "), "\n", sep = "")
  }
  top <- group_differences(d[d$severity <= 2L, , drop = FALSE])
  if (nrow(top)) {
    cat("\nMost severe (severity 0-2), identical changes once:\n")
    shown <- utils::head(top, 15L)
    for (i in seq_len(nrow(shown))) {
      r <- shown[i, ]
      what <- if (is.na(r$path)) "" else r$path
      sides <- if (!is.na(r$base) || !is.na(r$cand)) sprintf(": %s -> %s", trim(r$base), trim(r$cand)) else ""
      flag <- if (isTRUE(r$no_news)) "  [no NEWS]" else ""
      at <- if (r$steps > 1L) sprintf("%s (%d steps)", what, r$steps) else sprintf("%s/%s %s", r$scenario, r$step, what)
      cat(sprintf("  %-24s %s%s%s\n", r$kind, at, sides, flag))
    }
    if (nrow(top) > 15L) cat(sprintf("  ... %d more; see differences(group = TRUE)\n", nrow(top) - 15L))
  }
  invisible(x)
}

trim <- function(s, n = 40L) {
  s <- ifelse(is.na(s), "-", gsub("\\s+", " ", s))
  ell <- if (isTRUE(l10n_info()[["UTF-8"]])) "\u2026" else "..."
  ifelse(nchar(s) > n, paste0(substr(s, 1L, n - nchar(ell)), ell), s)
}

#' One row per step of a comparison
#'
#' @param object An `pkgdossier_comparison` from [compare_runs()].
#' @param ... Unused.
#' @return A data frame with one row per step: `scenario`, `step`,
#'   `label`, `status` (`"same"`, `"changed"`, `"unstable"`, `"error_new"`,
#'   `"error_fixed"`, `"error_both"` or `"not_run"`), `kinds` (the kinds of
#'   difference, comma separated), `n` (number of differences), `news` (number of
#'   candidate NEWS bullets naming a function the step uses), and the median elapsed
#'   seconds under each version.
#' @export
summary.pkgdossier_comparison <- function(object, ...) {
  out <- step_table(object)
  nr <- do.call(rbind, lapply(object$scenarios, function(s) {
    if (!length(s$not_run)) return(NULL)
    data.frame(scenario = s$id, step = vapply(s$not_run, `[[`, "", "id"),
               label = vapply(s$not_run, function(r) r$label %||% r$id, ""), status = "not_run",
               kinds = "", n = 0L, news = 0L, base_s = NA_real_, cand_s = NA_real_,
               stringsAsFactors = FALSE)
  }))
  out <- rbind(out, nr)
  rownames(out) <- NULL
  out
}

step_table <- function(x) {
  rows <- lapply(x$scenarios, function(s) {
    if (!length(s$steps)) return(NULL)
    data.frame(
      scenario = s$id,
      step = vapply(s$steps, `[[`, "", "id"),
      label = vapply(s$steps, `[[`, "", "label"),
      status = vapply(s$steps, `[[`, "", "status"),
      kinds = vapply(s$steps, function(r) paste(r$kinds, collapse = ", "), ""),
      n = vapply(s$steps, function(r) sum(x$differences$scenario == s$id & x$differences$step == r$id), 0L),
      news = vapply(s$steps, function(r) length(r$news), 0L),
      base_s = vapply(s$steps, function(r) r$time$base$elapsed, 0),
      cand_s = vapply(s$steps, function(r) r$time$cand$elapsed, 0),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    out <- data.frame(scenario = character(), step = character(), label = character(),
                      status = character(), kinds = character(), n = integer(), news = integer(),
                      base_s = numeric(), cand_s = numeric(), stringsAsFactors = FALSE)
  }
  out
}

coverage_line <- function(cv, code, max = 10L) {
  out <- sprintf("Coverage: the scenarios use %d of %d exported functions.", length(cv$used), cv$exported)
  if (length(cv$unused)) {
    shown <- utils::head(cv$unused, max)
    out <- paste0(out, " Not used: ", paste(code(shown), collapse = ", "),
                  if (length(cv$unused) > max) sprintf(" and %d more", length(cv$unused) - max), ".")
  }
  out
}

accept_line <- function(info, n_accepted) {
  out <- sprintf("%d difference(s) accepted by %d rule(s) in %s; not counted above.",
                 n_accepted, info$rules, info$source)
  n_unused <- nrow(info$unused %||% data.frame())
  if (n_unused) out <- paste0(out, sprintf(" %d rule(s) match nothing now and may be stale.", n_unused))
  out
}

# One line before the details: severe changes, other differences, unstable steps
# and scenario problems.
verdict_line <- function(x, d) {
  plural <- function(n, one, many = paste0(one, "s")) sprintf("%d %s", n, if (n == 1L) one else many)
  st <- step_table(x)
  n_steps <- if (is.null(st)) 0L else nrow(st)
  compared <- if (n_steps) sum(!st$status %in% c("error_both", "unstable")) else 0L
  if (!compared) {
    return(sprintf("Verdict: no step could be compared (%s, each erroring under both versions or unstable).",
                   plural(n_steps, "step")))
  }
  severe <- d[d$severity == 1L, , drop = FALSE]
  unstable <- d[d$severity == 0L, , drop = FALSE]
  other <- nrow(d) - nrow(severe) - nrow(unstable)
  probs <- length(problem_lines(x))
  parts <- c(
    if (nrow(severe)) sprintf("%s (%s)", plural(nrow(group_differences(severe)), "severe change"),
                              paste(unique(severe$kind), collapse = ", ")) else "nothing severe",
    if (other) plural(other, "other difference"),
    if (nrow(unstable)) plural(nrow(unstable), "unstable step"),
    if (probs) plural(probs, "scenario problem"))
  paste0("Verdict: ", paste(parts, collapse = "; "), ".")
}
