# NEWS candidates, found mechanically: for each step, the bullets of the candidate's
# NEWS written after the baseline's version that name a function of the package the
# step uses. Whether a bullet explains a difference is left to the reader; a
# difference in a step with no candidate bullet is flagged `no_news`.

news_files <- function() c("NEWS.md", "NEWS", file.path("inst", "NEWS.md"), file.path("inst", "NEWS"))

# The bullets of the candidate's NEWS after `base_version`, as a data frame with
# `section` and `text`, plus the file read and a note. `bullets` is NULL when the
# package has no NEWS file this function can read.
read_news <- function(pkg_dir, base_version, pkg = NULL, lib = NULL) {
  if (is.null(pkg_dir) || !dir.exists(pkg_dir)) {
    return(list(file = NA_character_, bullets = NULL, note = "the candidate's sources are not available"))
  }
  found <- news_files()[file.exists(file.path(pkg_dir, news_files()))]
  if (!length(found)) {
    rd <- file.exists(file.path(pkg_dir, "inst", "NEWS.Rd"))
    if (rd && !is.null(pkg) && !is.null(lib)) {
      from_db <- news_db_bullets(pkg, lib, base_version)
      if (!is.null(from_db)) return(from_db)
    }
    return(list(file = NA_character_, bullets = NULL,
                note = if (rd) "the candidate's NEWS is in inst/NEWS.Rd, which is not read" else
                  "the candidate has no NEWS file"))
  }
  lines <- readLines(file.path(pkg_dir, found[1]), warn = FALSE, encoding = "UTF-8")
  all <- parse_news(lines, md = grepl("\\.md$", found[1]))
  keep <- news_after(all$version, base_version)
  bullets <- all[keep, c("section", "text"), drop = FALSE]
  rownames(bullets) <- NULL
  list(file = found[1], bullets = bullets,
       note = sprintf("%d bullet(s) in %s after %s", nrow(bullets), found[1], base_version))
}

# inst/NEWS.Rd is turned into a news database when the package is installed;
# utils::news() reads it from the candidate's library.
news_db_bullets <- function(pkg, lib, base_version) {
  db <- tryCatch(utils::news(package = pkg, lib.loc = lib), error = function(e) NULL)
  if (is.null(db) || !nrow(db)) return(NULL)
  base <- tryCatch(package_version(base_version), error = function(e) NULL)
  newer <- vapply(db$Version, function(v) {
    if (is.na(v) || is.null(base)) return(TRUE)
    pv <- tryCatch(package_version(v), error = function(e) NULL)
    is.null(pv) || pv > base
  }, logical(1))
  section <- ifelse(is.na(db$Category) | !nzchar(db$Category), paste("version", db$Version),
                    paste0("version ", db$Version, ": ", db$Category))
  bullets <- data.frame(section = section, text = gsub("\\s+", " ", trimws(db$Text)),
                        stringsAsFactors = FALSE)[newer, , drop = FALSE]
  rownames(bullets) <- NULL
  list(file = file.path("inst", "NEWS.Rd"), bullets = bullets,
       note = sprintf("%d bullet(s) in inst/NEWS.Rd after %s", nrow(bullets), base_version))
}

# One row per bullet: the version section it is in (heading text and version, NA for
# a development heading) and its text with continuation lines joined. Version
# headings are Markdown headings, or unindented lines that are not bullets, holding a
# version number or the words "development" or "unreleased" (in a Markdown file only
# `#` headings count); other headings ("## Bug fixes") stay inside their version's
# section.
parse_news <- function(lines, md = TRUE) {
  version_re <- "[0-9]+(\\.[0-9]+)+(-[0-9]+)?"
  # `*`, `+`, `-`, `o`, and numbered items ("1. ...", "2) ...", as data.table writes them)
  bullet_re <- "^\\s*([*+-]|o|[0-9]+[.)])\\s+"
  is_dev <- function(s) grepl("development|devel\\b|unreleased", s, ignore.case = TRUE)
  section <- NA_character_
  version <- NA_character_
  rows <- list()
  cur <- NULL
  flush <- function() {
    if (!is.null(cur)) {
      rows[[length(rows) + 1L]] <<- data.frame(section = section, version = version,
        text = gsub("\\s+", " ", trimws(paste(cur, collapse = " "))), stringsAsFactors = FALSE)
    }
    cur <<- NULL
  }
  for (ln in lines) {
    md_heading <- grepl("^#+\\s", ln)
    plain_heading <- !md && grepl("^[^\\s*+#-]", ln, perl = TRUE) && !grepl(bullet_re, ln) &&
      (grepl(version_re, ln) || is_dev(ln))
    if (md_heading || plain_heading) {
      flush()
      text <- trimws(sub("^#+\\s*", "", ln))
      v <- regmatches(text, regexpr(version_re, text))
      if (length(v) || is_dev(text)) {
        section <- text
        version <- if (length(v)) v else NA_character_
      }
      next
    }
    if (!nzchar(trimws(ln)) || grepl("^\\s*[-=*_]{3,}\\s*$", ln)) {
      flush()
      next
    }
    if (grepl(bullet_re, ln)) {
      flush()
      cur <- sub(bullet_re, "", ln)
    } else if (!is.null(cur)) {
      cur <- c(cur, trimws(ln))
    }
  }
  flush()
  if (!length(rows)) {
    return(data.frame(section = character(), version = character(), text = character(),
                      stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

# Sections come newest first: keep them until the first one at or below the baseline.
# Bullets before any version heading, and development sections, count as newer.
news_after <- function(versions, base_version) {
  keep <- logical(length(versions))
  base <- tryCatch(package_version(base_version), error = function(e) NULL)
  for (i in seq_along(versions)) {
    v <- versions[i]
    if (!is.na(v) && !is.null(base)) {
      pv <- tryCatch(package_version(v), error = function(e) NULL)
      if (!is.null(pv) && pv <= base) break
    }
    keep[i] <- TRUE
  }
  keep
}

# The package's functions a step uses: every name in its code that is a function in
# either version's namespace, plus the methods of either version for the class of
# the step's last visible value (print.ud_report() for a value of class ud_report).
step_functions <- function(code, classes, ns_functions) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) expression())
  used <- intersect(unique(unlist(lapply(exprs, all.names))), ns_functions)
  if (length(classes)) {
    suffix <- paste0(".", classes)
    used <- c(used, ns_functions[vapply(ns_functions, function(f) any(endsWith(f, suffix)), logical(1))])
  }
  unique(used)
}

# step_functions() plus the functions that produced the objects the step uses.
# `creators` maps object names assigned earlier in the scenario to the package
# functions behind them; this step's top-level assignments are added to it, each
# inheriting the creators of the objects its right-hand side uses.
trace_step <- function(code, classes, ns_functions, creators) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) expression())
  inherited_from <- function(nms) unlist(creators[intersect(nms, names(creators))], use.names = FALSE)
  used <- unique(unlist(lapply(exprs, all.names)))
  functions <- unique(c(step_functions(code, classes, ns_functions), inherited_from(used)))
  for (e in exprs) {
    e <- unparen(e)  # (fit <- glmer(...)) assigns and prints
    if (is.call(e) && as.character(e[[1]])[1] %in% c("<-", "=", "<<-") && is.name(e[[2]])) {
      rhs <- all.names(e[[3]])
      creators[[as.character(e[[2]])]] <- unique(c(intersect(rhs, ns_functions), inherited_from(rhs)))
    }
  }
  list(functions = functions, creators = creators)
}

unparen <- function(e) {
  while (is.call(e) && identical(e[[1]], as.name("(")) && length(e) == 2L) e <- e[[2]]
  e
}

# Does a bullet name the function? `fn(`, `pkg::fn(`, a backticked `fn`, or, for
# names with a dot or underscore (unlikely to be English words), the bare name.
mentions_function <- function(text, fn) {
  q <- gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", fn)
  pat <- paste0("(?<![A-Za-z0-9._])", q, "\\s*\\(|`([A-Za-z0-9.]+::)?", q, "`")
  if (grepl("[._]", fn)) pat <- paste0(pat, "|(?<![A-Za-z0-9._])", q, "(?![A-Za-z0-9._])")
  grepl(pat, text, perl = TRUE)
}

news_for_step <- function(bullets, fns) {
  if (is.null(bullets) || !nrow(bullets) || !length(fns)) return(character())
  hit <- vapply(bullets$text, function(t) any(vapply(fns, mentions_function, logical(1), text = t)),
                logical(1))
  unname(bullets$text[hit])
}

# The step's candidate bullets most likely to be about this difference, at most
# `max`: those naming elements of its path (not the object's own name) first, then
# those with a word that fits its kind, then the rest, in NEWS order.
rank_news <- function(bullets, kind, path, max = 3L) {
  if (!length(bullets)) return(character())
  tokens <- unlist(strsplit(if (is.na(path)) "" else path, "[$@\\[\\](),#*/ ]+", perl = TRUE))
  if (kind %in% c("value_moved", "field_removed", "field_added")) tokens <- tokens[-1L]
  tokens <- unique(tolower(tokens[nchar(tokens) >= 3L & !grepl("^[0-9.]+$", tokens)]))
  words <- switch(kind,
    plot_changed = c("plot", "figure", "axis", "legend", "colour", "color", "title", "subtitle", "theme", "label"),
    output_changed = c("print", "output", "summary", "format", "show"),
    warning_new = , warning_gone = "warning",
    error_new = , error_fixed = "error",
    slower = , faster = c("faster", "slower", "speed", "performance", "time"),
    condition_class_changed = c("class", "condition", "error", "warning"),
    character())
  hits <- function(w) {
    if (!length(w)) return(integer(length(bullets)))
    rowSums(matrix(vapply(w, function(t) grepl(paste0("\\b", gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", t), "\\b"),
                                        bullets, ignore.case = TRUE, perl = TRUE), logical(length(bullets))),
                   nrow = length(bullets)))
  }
  score <- 2L * hits(tokens) + (hits(words) > 0)
  utils::head(bullets[order(-score, seq_along(bullets))], max)
}
