#' Accept known differences
#'
#' Once a difference has been read and found intended (a fixed bug, a new default
#' that NEWS announces), it can be accepted, so that later comparisons, the
#' pull-request summary and [check_differences()] report only differences nobody has
#' looked at yet. `accept_differences()` appends rows of [differences()] to a CSV
#' file of rules; pass that file to [compare_runs()] (or [run_dossier()]) as
#' `accept`.
#'
#' A rule has the columns `kind`, `scenario`, `step`, `path`, `cand` and `reason`. A
#' difference is accepted when it matches every one of the first five; an empty
#' field or `*` matches anything, and `*` and `?` work as wildcards inside a field
#' (`step = "fit_*"`). The candidate's side (`cand`) is part of the rule, so a number
#' accepted at its new value shows up again if it moves further; set it to `*` to
#' accept any value.
#'
#' @param x A data frame of differences to accept, from [differences()].
#' @param path The CSV file of rules; created if needed, appended to otherwise.
#' @param reason Why these differences are accepted, kept with the rules.
#' @return `path`, invisibly.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' rules <- file.path(tempdir(), "accepted.csv")
#' accept_differences(differences(cmp, kind = "plot_changed"), rules,
#'                    reason = "points are red now, as NEWS says")
#' cmp <- compare_runs(d, accept = rules)
#' differences(cmp, accepted = TRUE)
#' }
#' @export
accept_differences <- function(x, path, reason = NA_character_) {
  stopifnot(is.data.frame(x), all(c("kind", "scenario", "step", "path", "cand") %in% names(x)),
            is.character(path), length(path) == 1L)
  new <- data.frame(kind = x$kind, scenario = x$scenario, step = x$step,
                    path = ifelse(is.na(x$path), "", x$path), cand = ifelse(is.na(x$cand), "*", x$cand),
                    reason = if (length(reason)) rep_len(as.character(reason), nrow(x)) else NA_character_,
                    stringsAsFactors = FALSE)
  rules <- if (file.exists(path)) rbind(read_accept(path), new) else new
  rules <- rules[!duplicated(rules[, c("kind", "scenario", "step", "path", "cand")]), , drop = FALSE]
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(rules, path, row.names = FALSE, na = "")
  invisible(path)
}

#' Stop when differences nobody accepted remain
#'
#' For continuous integration: stops with an error that lists the differences of
#' the comparison that are not accepted (see [accept_differences()]) and match the
#' filters, so the job fails; returns `TRUE` invisibly when there are none.
#'
#' The filters are those of [differences()], in the same order.
#'
#' @param x An `pkgdossier_comparison` from [compare_runs()].
#' @param kind Consider only these kinds.
#' @param max_severity Consider differences of this severity or more severe (1 is
#'   the most severe: new errors, removed elements and exports). Defaults to 1, or,
#'   when `kind` is given, to no limit: the kinds named are checked whatever their
#'   severity.
#' @param no_news `TRUE` considers only differences no NEWS bullet names.
#' @return `TRUE`, invisibly, when no such difference remains.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' try(check_differences(cmp, max_severity = 1))
#' }
#' @export
check_differences <- function(x, kind = NULL, max_severity = if (is.null(kind)) 1L, no_news = NULL) {
  stopifnot(inherits(x, "pkgdossier_comparison"))
  d <- differences(x, kind = kind, max_severity = max_severity, no_news = no_news, accepted = FALSE)
  if (!nrow(d)) return(invisible(TRUE))
  shown <- utils::head(d, 10L)
  lines <- sprintf("  %s %s/%s %s", shown$kind, shown$scenario, shown$step,
                   ifelse(is.na(shown$path), "", shown$path))
  what <- c(if (!is.null(kind)) paste("of kind", paste(kind, collapse = ", ")),
            if (!is.null(max_severity)) sprintf("of severity %d or more severe", max_severity),
            if (isTRUE(no_news)) "that no NEWS bullet names")
  stop(sprintf("%d difference(s)%s are not accepted:\n%s%s\n%s",
               nrow(d), if (length(what)) paste0(" ", paste(what, collapse = " and ")) else "",
               paste(lines, collapse = "\n"),
               if (nrow(d) > 10L) sprintf("\n  ... and %d more", nrow(d) - 10L) else "",
               "Accept the intended ones with accept_differences()."), call. = FALSE)
}

read_accept <- function(accept) {
  rules <- if (is.data.frame(accept)) accept else {
    utils::read.csv(accept, colClasses = "character", na.strings = character(), check.names = FALSE)
  }
  need <- c("kind", "scenario", "step", "path", "cand")
  missing_cols <- setdiff(need, names(rules))
  if (length(missing_cols)) {
    stop("Accepted-differences rules lack the column(s) ", paste(missing_cols, collapse = ", "), ".", call. = FALSE)
  }
  if (!"reason" %in% names(rules)) rules$reason <- NA_character_
  rules <- rules[, c(need, "reason"), drop = FALSE]
  rules[] <- lapply(rules, as.character)
  rules
}

# Marks the differences the rules accept; also says which rules matched nothing.
apply_accept <- function(diffs, accept) {
  diffs$accepted <- rep(FALSE, nrow(diffs))
  diffs$accepted_reason <- rep(NA_character_, nrow(diffs))
  if (is.null(accept)) return(list(diffs = diffs, info = NULL))
  rules <- read_accept(accept)
  used <- logical(nrow(rules))
  for (i in seq_len(nrow(rules))) {
    r <- rules[i, ]
    matches <- glob_match(r$kind, diffs$kind) & glob_match(r$scenario, diffs$scenario) &
      glob_match(r$step, diffs$step) & glob_match(r$path, diffs$path) & glob_match(r$cand, diffs$cand)
    used[i] <- any(matches)
    hit <- matches & !diffs$accepted  # the first rule that matches gives the reason
    diffs$accepted[hit] <- TRUE
    diffs$accepted_reason[hit] <- if (is.na(r$reason) || !nzchar(r$reason)) "accepted" else r$reason
  }
  info <- list(source = if (is.data.frame(accept)) "a data frame" else as.character(accept),
               rules = nrow(rules), unused = rules[!used, c("kind", "scenario", "step", "path", "cand"), drop = FALSE])
  list(diffs = diffs, info = info)
}

# Wildcard match: `*` any run of characters, `?` one character; an empty or NA
# pattern, or "*", matches everything, NA values included.
glob_match <- function(pattern, x) {
  if (is.na(pattern) || !nzchar(pattern) || identical(pattern, "*")) return(rep(TRUE, length(x)))
  rx <- gsub("([][{}()+^$|\\\\.])", "\\\\\\1", pattern)
  rx <- gsub("?", ".", gsub("*", ".*", rx, fixed = TRUE), fixed = TRUE)
  !is.na(x) & grepl(paste0("^", rx, "$"), x)
}
