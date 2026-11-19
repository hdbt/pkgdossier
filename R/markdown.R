#' Write the comparison as a short Markdown summary
#'
#' A summary for a pull-request comment or a chat message: the version pair, how
#' many steps were compared, the differences by kind, the most severe differences
#' with their NEWS candidates, the steps that error under both versions, the
#' determinism check, and a link to the full report when `report_url` is given. The
#' first line is the HTML comment `<!-- pkgdossier -->`, so a bot can find and update
#' its own comment.
#'
#' The template `system.file("github", "pkgdossier.yaml", package = "pkgdossier")`
#' is a GitHub Actions workflow that runs a dossier on each pull request and posts
#' this summary as a comment.
#'
#' @param x An `pkgdossier_comparison` from [compare_runs()].
#' @param path File to write (its folder is created if needed), or `NULL` to return the text.
#' @param report_url Optional link to the full report (for example the workflow
#'   run that holds it as an artifact).
#' @param max_rows Most severe differences listed at most.
#' @return The Markdown text (a single string) when `path` is `NULL`, otherwise
#'   `path`, invisibly.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d, quiet = TRUE)
#' cmp <- compare_runs(d)
#' cat(write_dossier_md(cmp))
#' }
#' @export
write_dossier_md <- function(x, path = NULL, report_url = NULL, max_rows = 20L) {
  stopifnot(inherits(x, "pkgdossier_comparison"))
  m <- x$meta
  st <- step_table(x)
  d <- x$differences[!(x$differences$accepted %in% TRUE), , drop = FALSE]
  n_accepted <- sum(x$differences$accepted %in% TRUE)
  n_not_run <- sum(vapply(x$scenarios, function(s) length(s$not_run), 0L))
  out <- c("<!-- pkgdossier -->",
           sprintf("### pkgdossier: %s %s -> %s", m$pkg, m$labels$base, m$labels$cand), "")
  summary_line <- sprintf("%d scenario(s), %d step(s) compared, %d not run.",
                          length(x$scenarios), nrow(st), n_not_run)
  if (!nrow(d)) {
    out <- c(out, paste(summary_line, if (n_accepted) "**No differences that are not accepted.**" else "**No differences.**"))
  } else {
    n_steps <- length(unique(paste(d$scenario, d$step)))
    news_line <- if (is.na(m$news$file %||% NA)) {
      paste0(" NEWS not checked: ", m$news$note %||% "no NEWS file", ".")
    } else {
      sprintf(" %d of them in steps no NEWS bullet names.", sum(d$no_news %in% TRUE))
    }
    out <- c(out, sprintf("%s **%d difference(s)** in %d step(s).%s", summary_line, nrow(d),
                          n_steps, news_line), "",
             "| Kind | Severity | Differences | Steps |", "|---|---:|---:|---:|")
    kinds <- difference_kinds()
    for (k in names(kinds)[names(kinds) %in% d$kind]) {
      dk <- d[d$kind == k, , drop = FALSE]
      out <- c(out, sprintf("| %s | %d | %d | %d |", k, kinds[[k]], nrow(dk),
                            length(unique(paste(dk$scenario, dk$step)))))
    }
    top <- group_differences(d[d$severity <= 2L, , drop = FALSE])
    if (nrow(top)) {
      out <- c(out, "", "#### Most severe (severity 0-2)", "",
               "Identical changes in several steps are listed once, with the number of steps.", "",
               sprintf("| Kind | Where | %s | %s | NEWS |", md_cell(m$labels$base), md_cell(m$labels$cand)),
               "|---|---|---|---|---|")
      shown <- utils::head(top, max_rows)
      for (i in seq_len(nrow(shown))) {
        r <- shown[i, ]
        where <- if (r$steps > 1L) {
          paste0(if (!is.na(r$path)) paste0(md_code(r$path), " ") else "", sprintf("in %d steps", r$steps))
        } else {
          paste0(r$scenario, "/", r$step, if (!is.na(r$path)) paste0(" ", md_code(r$path)) else "")
        }
        news <- if (is.na(r$no_news)) "?" else if (r$no_news) "none" else md_cell(strsplit(r$news, "\n")[[1]][1], 60L)
        out <- c(out, sprintf("| %s | %s | %s | %s | %s |", r$kind, where, md_cell(r$base),
                              md_cell(r$cand), news))
      }
      if (nrow(top) > max_rows) out <- c(out, "", sprintf("%d more not shown.", nrow(top) - max_rows))
    }
  }
  if (!is.null(m$accept)) out <- c(out, "", accept_line(m$accept, n_accepted))
  cv <- m$coverage
  if (!is.null(cv) && cv$exported > 0L) {
    out <- c(out, "", coverage_line(cv, code = function(x) paste0("`", x, "`")))
    if (length(cv$news_unmatched)) {
      out <- c(out, "", "NEWS bullets that match no step or API change (changes the scenarios may not exercise):",
               "", paste0("- ", vapply(utils::head(cv$news_unmatched, 5L), md_cell, "", n = 100L)))
      if (length(cv$news_unmatched) > 5L) out <- c(out, sprintf("- and %d more", length(cv$news_unmatched) - 5L))
    }
  }
  dl <- deps_line(m$provenance$deps)
  if (!is.null(dl)) out <- c(out, "", dl)
  crashes <- crash_lines(x)
  if (length(crashes)) {
    out <- c(out, "", paste0("**", sub("^(R crashed|Steps did not run to their end)", "\\1**", crash_header(crashes))),
             "", paste0("- ", crashes))
  }
  problems <- problem_lines(x)
  if (length(problems)) {
    out <- c(out, "", paste0("Scenario problems (error under both versions): ", paste(problems, collapse = "; "), "."))
  }
  det <- m$determinism_failures %||% character()
  if (length(det)) {
    out <- c(out, "", paste0("Not compared, because two runs of one version disagree: ",
                             paste(det, collapse = "; "), "."))
  }
  if (!is.null(report_url) && nzchar(report_url)) out <- c(out, "", sprintf("[Full report](%s)", report_url))
  out <- c(out, "", sprintf("<sub>pkgdossier %s, %s, %s runs, %d timed repeat(s) per timed step.</sub>",
                            m$pkgdossier_version, m$base$r_version, m$order, m$reps))
  text <- paste(out, collapse = "\n")
  if (is.null(path)) return(text)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(text, path, useBytes = TRUE)
  invisible(path)
}

md_cell <- function(s, n = 40L) {
  if (is.null(s) || is.na(s)) return("-")
  s <- gsub("\\s+", " ", s)
  if (nchar(s) > n) s <- paste0(substr(s, 1L, n - 3L), "...")
  gsub("|", "\\|", s, fixed = TRUE)
}

md_code <- function(s) {
  s <- md_cell(s, 60L)
  if (grepl("`", s, fixed = TRUE)) s else paste0("`", s, "`")
}
