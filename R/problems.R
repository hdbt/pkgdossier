# Scenario problems that come from a package missing from the library: found before
# the runs from the scenarios' code, and after them from the errors.

# Packages a piece of code loads or calls: library(), require(), requireNamespace(),
# loadNamespace() with a literal name, and pkg::f / pkg:::f.
code_packages <- function(code) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) expression())
  out <- character()
  walk <- function(e) {
    if (!is.call(e)) return(invisible())
    fn <- e[[1]]
    if (is.name(fn) && as.character(fn) %in% c("::", ":::") && length(e) == 3L) {
      out <<- c(out, as.character(e[[2]]))
      return(invisible())
    }
    name <- if (is.name(fn)) as.character(fn) else if (is.call(fn) && length(fn) == 3L &&
      as.character(fn[[1]])[1] %in% c("::", ":::")) as.character(fn[[3]]) else ""
    if (name %in% c("library", "require", "requireNamespace", "loadNamespace") && length(e) >= 2L) {
      args <- as.list(e)[-1]
      first <- if (!is.null(args$package)) args$package else if (!is.null(names(args)) && nzchar(names(args)[1])) NULL else args[[1]]
      literal <- is.character(first) || (is.name(first) && !isTRUE(args$character.only))
      if (literal) out <<- c(out, as.character(first))
    }
    if (is.call(fn)) walk(fn)  # splines::ns(...) calls the call splines::ns
    lapply(as.list(e)[-1], function(a) if (!missing(a)) walk(a))
    invisible()
  }
  for (e in exprs) walk(e)
  unique(out)
}

# Per scenario, the packages its code uses that none of `lib_paths` has.
missing_packages <- function(scenarios, pkg, lib_paths) {
  have <- function(p) nzchar(system.file(package = p, lib.loc = lib_paths))
  out <- list()
  for (sc in scenarios) {
    used <- unique(unlist(lapply(sc$steps, function(st) code_packages(paste(st$code, collapse = "\n")))))
    used <- setdiff(used, c(pkg, "base"))
    gone <- used[!vapply(used, have, logical(1))]
    if (length(gone)) out[[sc$id]] <- sort(gone)
  }
  out
}

# "there is no package called 'x'" (with straight or curly quotes)
missing_package_in <- function(msg) {
  if (is.null(msg) || is.na(msg)) return(NA_character_)
  m <- regmatches(msg, regexec("there is no package called [\u2018'\"]([^\u2019'\"]+)[\u2019'\"]", msg))[[1]]
  if (length(m) == 2L) m[2] else NA_character_
}

# Marks each step that errors under both versions because of a missing package, and
# those after it in the scenario that also error under both: they fail because the
# first one did.
attribute_problems <- function(steps) {
  cause <- NA_character_
  for (i in seq_along(steps)) {
    st <- steps[[i]]
    if (!identical(st$status, "error_both")) next
    if (all(vapply(st$error_class[c("base", "cand")], function(cls) "pkgdossier_timeout" %in% cls, logical(1)))) {
      steps[[i]]$problem <- sprintf("timed out under both versions at step_timeout = %s",
                                    sub("^timed out after ", "", st$error$base))
      next
    }
    pkg <- missing_package_in(st$error$base)
    if (!is.na(pkg)) cause <- pkg
    if (!is.na(cause)) steps[[i]]$problem <- sprintf("needs %s, which is not installed", cause)
  }
  steps
}

# Scenario problems as text: one entry per scenario and missing package, then the
# other steps that error under both versions.
problem_lines <- function(x) {
  out <- character()
  other <- character()
  for (sc in x$scenarios) {
    probs <- Filter(function(st) identical(st$status, "error_both"), sc$steps)
    if (!length(probs)) next
    causes <- vapply(probs, function(st) st$problem %||% NA_character_, "")
    for (cs in unique(causes[!is.na(causes)])) {
      out <- c(out, sprintf("%s %s (%d step%s)", sc$id, cs, sum(causes %in% cs), if (sum(causes %in% cs) > 1L) "s" else ""))
    }
    if (any(is.na(causes))) other <- c(other, paste0(sc$id, "/", vapply(probs[is.na(causes)], `[[`, "", "id")))
  }
  c(out, other)
}

# Steps during which R itself stopped (or whose output pkgdossier could not
# capture), one line per version and reason:
# "91 steps under 3.3.0 (segfault): digits/chunk-03, ... and 86 more".
crash_lines <- function(x, max = 5L) {
  rows <- list()
  labels <- x$meta$labels
  for (sc in x$scenarios) for (st in sc$steps) for (side in c("base", "cand")) {
    cls <- st$error_class[[side]]
    if (any(c("pkgdossier_crash", "pkgdossier_runner_error") %in% cls)) {
      reason <- if ("pkgdossier_crash" %in% cls) {
        sub(";.*$", "", sub("^R stopped in this step: ", "", st$error[[side]]))
      } else {
        paste("not captured by pkgdossier:", trim(sub("^pkgdossier could not capture this step: ", "", st$error[[side]]), 60L))
      }
      rows[[length(rows) + 1L]] <- data.frame(version = labels[[side]], reason = reason,
        step = paste0(sc$id, "/", st$id), stringsAsFactors = FALSE)
    }
  }
  if (!length(rows)) return(character())
  d <- do.call(rbind, rows)
  key <- paste(d$version, d$reason, sep = "\r")
  vapply(split(seq_len(nrow(d)), factor(key, levels = unique(key))), function(i) {
    steps <- d$step[i]
    sprintf("%d step%s under %s (%s): %s%s", length(i), if (length(i) > 1L) "s" else "", d$version[i[1]],
            d$reason[i[1]], paste(utils::head(steps, max), collapse = ", "),
            if (length(steps) > max) sprintf(" and %d more", length(steps) - max) else "")
  }, "", USE.NAMES = FALSE)
}

# What the steps listed by crash_lines() have in common.
crash_header <- function(lines) {
  if (any(grepl("not captured by pkgdossier", lines, fixed = TRUE))) {
    "Steps did not run to their end (R crashed, or pkgdossier could not capture them), and are reported as errors:"
  } else {
    "R crashed, and these steps are reported as errors:"
  }
}

# Where the dependencies came from, when not from the library paths, with the
# snapshot's exceptions and caveat.
deps_line <- function(deps) {
  if (identical(deps$mode, "snapshot")) {
    newer <- names(unlist(deps$newer_than_snapshot))
    caveat <- snapshot_caveat(deps)
    sprintf("Dependencies: CRAN as on %s%s.%s", deps$date,
            if (length(newer)) paste0(", except ", paste(newer, collapse = ", "), " (current)") else "",
            if (is.null(caveat)) "" else paste0(" ", caveat))
  } else if (identical(deps$mode, "cran")) {
    "Dependencies: current CRAN versions."
  }
}
