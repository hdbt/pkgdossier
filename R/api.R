# Changes to what code calling the package relies on, from the exports and function
# signatures each version's runner recorded: exports removed or added, arguments
# removed, added (with or without a default), reordered, and defaults changed. These
# are found without running anything, so they also catch changes no scenario uses.

api_kinds <- function() {
  c(export_removed = 1L, argument_removed = 1L, argument_new_required = 1L,
    arguments_reordered = 2L, default_changed = 2L, argument_added = 4L, export_added = 4L)
}

api_diff <- function(base, cand) {
  rows <- list()
  add <- function(fn, kind, path, b = NA_character_, c = NA_character_, detail = NA_character_) {
    rows[[length(rows) + 1L]] <<- data.frame(
      scenario = "(namespace)", step = fn, label = fn, kind = kind,
      severity = api_kinds()[[kind]], path = path, base = b, cand = c, rel_change = NA_real_,
      detail = detail, stringsAsFactors = FALSE)
  }
  if (is.null(base) || is.null(cand)) return(NULL)
  for (fn in setdiff(names(base), names(cand))) add(fn, "export_removed", fn, b = base[[fn]]$type)
  for (fn in setdiff(names(cand), names(base))) add(fn, "export_added", fn, c = cand[[fn]]$type)
  for (fn in intersect(names(base), names(cand))) {
    b <- base[[fn]]
    c <- cand[[fn]]
    if (!identical(b$type, "function") || !identical(c$type, "function")) {
      if (!identical(b$type, c$type)) {
        add(fn, "export_removed", fn, b = b$type, c = c$type, detail = "the export changed type")
      }
      next
    }
    bd <- stats::setNames(b$defaults, b$args)
    cd <- stats::setNames(c$defaults, c$args)
    for (arg in setdiff(b$args, c$args)) {
      add(fn, "argument_removed", arg, b = bd[[arg]] %|NA% "(required)")
    }
    for (arg in setdiff(c$args, b$args)) {
      required <- is.na(cd[[arg]]) && arg != "..."
      add(fn, if (required) "argument_new_required" else "argument_added", arg,
          c = cd[[arg]] %|NA% "(required)",
          detail = if (required) "a new argument without a default: existing calls lack it" else NA_character_)
    }
    common <- intersect(b$args, c$args)
    for (arg in common) {
      if (identical(bd[[arg]], cd[[arg]])) next
      now_required <- is.na(cd[[arg]]) && arg != "..."
      add(fn, if (now_required) "argument_new_required" else "default_changed", arg,
          b = bd[[arg]] %|NA% "(required)", c = cd[[arg]] %|NA% "(required)",
          detail = if (now_required) "the argument lost its default" else NA_character_)
    }
    if (!identical(common, intersect(c$args, b$args))) {
      add(fn, "arguments_reordered", fn, b = paste(b$args, collapse = ", "), c = paste(c$args, collapse = ", "),
          detail = "calls that pass these arguments by position get them in a different order")
    }
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

`%|NA%` <- function(x, y) if (is.null(x) || is.na(x)) y else x

# Which exported functions the scenarios use, and which candidate NEWS bullets no
# step or API difference was matched to: what the dossier did not exercise.
coverage <- function(scenarios, base_api, cand_api, bullets, diffs) {
  is_fun <- function(api) names(api)[vapply(api, function(x) identical(x$type, "function"), logical(1))]
  exported <- sort(union(is_fun(base_api %||% list()), is_fun(cand_api %||% list())))
  used <- unique(unlist(lapply(scenarios, function(s) lapply(s$steps, `[[`, "news_functions"))))
  matched <- unique(c(unlist(lapply(scenarios, function(s) lapply(s$steps, `[[`, "news"))),
                      unlist(strsplit(diffs$news[!is.na(diffs$news)], "\n", fixed = TRUE))))
  list(
    exported = length(exported),
    used = sort(intersect(exported, used)),
    unused = sort(setdiff(exported, used)),
    news_unmatched = if (is.null(bullets)) character() else setdiff(bullets$text, matched)
  )
}
