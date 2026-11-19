# Turning the baseline's vignette sources into scenarios: one scenario per vignette,
# one step per R chunk. Chunks are split with knitr's own chunk patterns rather than
# knitr::purl(), because purl() drops a chunk whose `eval` option cannot be evaluated
# outside the vignette and leaves unlabelled chunks without a name.

vignette_scenarios <- function(pkg_dir, src) {
  vdir <- file.path(pkg_dir, "vignettes")
  files <- list.files(vdir, pattern = "\\.(Rmd|rmd|Rmarkdown|qmd|Rnw|rnw)$", full.names = TRUE)
  if (!is.null(src$which)) {
    files <- files[tools::file_path_sans_ext(basename(files)) %in% src$which]
  }
  if (!length(files)) {
    # a package without vignettes is common; only vignettes asked for by name must exist
    if (is.null(src$which)) {
      message("The baseline has no vignettes; from_vignettes() gives no scenarios.")
      return(list())
    }
    stop("No vignette sources found in ", vdir, " matching ", paste(src$which, collapse = ", "), ".",
         call. = FALSE)
  }
  lapply(files, vignette_scenario, time = src$time, values = src$values)
}

vignette_scenario <- function(file, time = TRUE, values = TRUE) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  rnw <- grepl("\\.[Rr]nw$", file)
  pat <- if (rnw) knitr::all_patterns$rnw else knitr::all_patterns$md
  chunks <- split_chunks(lines, pat$chunk.begin, pat$chunk.end, rnw)
  defaults <- format_fig_defaults(lines, rnw)
  steps <- list()
  notes <- character()
  for (k in seq_along(chunks)) {
    ch <- chunks[[k]]
    if (!identical(tolower(ch$engine), "r")) {
      steps[[length(steps) + 1L]] <- new_step(ch$label %||% sprintf("chunk-%02d", k), "chunk",
        paste(ch$code, collapse = "\n"), eval = FALSE, note = paste("engine", ch$engine, "is not run"))
      next
    }
    opts <- utils::modifyList(defaults, ch$opts)
    code <- paste(ch$code, collapse = "\n")
    # global defaults set by the vignette apply to the chunks after this one
    defaults <- utils::modifyList(defaults, global_chunk_opts(code))
    fig <- fig_size(opts)
    ev <- opts$eval %||% TRUE
    eval_expr <- NULL
    if (is.language(ev)) {
      eval_expr <- paste(deparse(ev), collapse = " ")
      ev <- TRUE
    }
    ev <- !isFALSE(ev) && !identical(ev, 0) && !identical(ev, 0L)
    if (isTRUE(opts$cache)) notes <- c(notes, sprintf("chunk %s uses cache = TRUE", ch$label %||% k))
    if (ev && grepl("\\b(readRDS|load|readr::read_rds)\\s*\\(", code)) {
      notes <- c(notes, sprintf("chunk %s reads stored results: its numbers do not test the computation",
                                ch$label %||% k))
    }
    steps[[length(steps) + 1L]] <- new_step(
      ch$label %||% sprintf("chunk-%02d", k), "chunk", code,
      label = ch$label %||% sprintf("chunk %d", k), values = values, time = time,
      w = fig[1], h = fig[2], eval = ev, eval_expr = eval_expr,
      expect_error = isTRUE(opts$error)  # the vignette shows this chunk's error
    )
  }
  name <- tools::file_path_sans_ext(basename(file))
  new_scenario(name, steps, title = vignette_title(lines) %||% name,
               source = paste0("vignette ", basename(file)), notes = unique(notes),
               workdir = "vignettes")
}

split_chunks <- function(lines, begin, end, rnw) {
  chunks <- list()
  i <- 1L
  n <- length(lines)
  while (i <= n) {
    if (!grepl(begin, lines[i])) {
      i <- i + 1L
      next
    }
    header <- sub(begin, "\\1", lines[i])
    j <- i + 1L
    while (j <= n && !grepl(end, lines[j])) j <- j + 1L
    code <- if (j > i + 1L) lines[(i + 1L):(j - 1L)] else character()
    # chunks inside block quotes or lists carry the indentation of their fence
    indent <- sub("^([\t >]*).*$", "\\1", lines[i])
    if (nzchar(indent)) code <- substring(code, nchar(indent) + 1L)
    chunks[[length(chunks) + 1L]] <- parse_chunk(header, code, rnw)
    i <- j + 1L
  }
  chunks
}

parse_chunk <- function(header, code, rnw) {
  header <- trimws(header)
  engine <- "r"
  if (!rnw) {
    engine <- sub("^([a-zA-Z0-9_]+).*$", "\\1", header)
    header <- trimws(sub("^[a-zA-Z0-9_]+[ ,]*", "", header))
  }
  label <- NULL
  first <- if (nzchar(header)) trimws(strsplit(header, ",", fixed = TRUE)[[1]][1]) else ""
  if (!is.na(first) && nzchar(first) && !grepl("=", first, fixed = TRUE)) {
    label <- gsub("^['\"]|['\"]$", "", first)
    header <- trimws(sub("^[^,]*,?", "", header))
  }
  opts <- parse_opts(header)
  if (!is.null(opts$label)) {
    label <- as.character(opts$label)
    opts$label <- NULL
  }
  # options written inside the chunk as `#| key: value` (YAML, as knitr and Quarto
  # read them) or `#| key = value` (R)
  pipe <- grepl("^#\\|", code)
  if (any(pipe)) {
    body <- sub("^#\\|\\s*", "", code[pipe])
    yaml <- grepl("^[A-Za-z0-9._-]+\\s*:", body)
    for (ln in body[yaml]) {
      kv <- regmatches(ln, regexec("^([A-Za-z0-9._-]+)\\s*:\\s*(.*)$", ln))[[1]]
      key <- gsub("-", ".", kv[2])
      val <- yaml_value(kv[3])
      if (key == "label") label <- paste(as.character(val), collapse = " ") else opts[[key]] <- val
    }
    # the other lines are R, as in a chunk header, possibly several options to a line
    # and one option over several lines
    r_lines <- body[!yaml & nzchar(trimws(body))]
    if (length(r_lines)) {
      r_opts <- parse_opts(paste(sub(",\\s*$", "", r_lines), collapse = ", "))
      if (!is.null(r_opts$label)) {
        label <- as.character(r_opts$label)
        r_opts$label <- NULL
      }
      opts[names(r_opts)] <- r_opts
    }
    code <- code[!pipe]
  }
  list(engine = engine, label = label, opts = opts, code = code)
}

# A YAML scalar or flow list as knitr reads chunk options: `true`/`false` (and
# `yes`/`no`), numbers, quoted or bare strings (`label: fig-one` is a string, not
# R code), `[4, 3]`, and `!expr` for R code evaluated at run time.
yaml_value <- function(s) {
  s <- trimws(s)
  # a quoted string ends at its closing quote; what follows is a comment
  q <- quoted_prefix(s)
  if (!is.null(q)) return(q)
  s <- trimws(sub("(^|\\s+)#.*$", "", s))  # a trailing comment
  if (grepl("^!expr\\s", s)) return(r_value(sub("^!expr\\s+", "", s)))
  if (grepl("^\\[.*\\]$", s)) {
    inner <- trimws(substr(s, 2L, nchar(s) - 1L))
    if (!nzchar(inner)) return(character())
    parts <- lapply(split_flow(inner), yaml_value)
    return(if (all(vapply(parts, is.numeric, logical(1)))) unlist(parts) else
      vapply(parts, function(p) paste(as.character(p), collapse = " "), ""))
  }
  low <- tolower(s)
  if (low %in% c("true", "yes")) return(TRUE)
  if (low %in% c("false", "no")) return(FALSE)
  if (low %in% c("null", "~")) return(NULL)
  if (grepl("^[-+]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?$", s)) return(as.numeric(s))
  s
}

# The string a value starting with a quote holds (YAML escapes: \\" in double quotes,
# '' in single quotes), or NULL when it does not start with one.
quoted_prefix <- function(s) {
  if (!grepl("^['\"]", s)) return(NULL)
  m <- if (startsWith(s, '"')) regmatches(s, regexpr('^"([^"\\\\]|\\\\.)*"', s)) else
    regmatches(s, regexpr("^'([^']|'')*'", s))
  if (!length(m)) return(substring(s, 2L))  # no closing quote: take the rest
  v <- substr(m, 2L, nchar(m) - 1L)
  if (startsWith(s, '"')) gsub('\\\\(["\\\\])', "\\1", v) else gsub("''", "'", v, fixed = TRUE)
}

# The items of a YAML flow list, split at commas outside quotes.
split_flow <- function(inner) {
  chars <- strsplit(inner, "", fixed = TRUE)[[1]]
  out <- character()
  cur <- ""
  quote <- ""
  for (ch in chars) {
    if (nzchar(quote)) {
      if (ch == quote) quote <- ""
    } else if (ch %in% c("'", '"')) {
      quote <- ch
    } else if (ch == ",") {
      out <- c(out, trimws(cur))
      cur <- ""
      next
    }
    cur <- paste0(cur, ch)
  }
  c(out, trimws(cur))
}

r_value <- function(s) {
  s <- trimws(s)
  if (tolower(s) %in% c("true", "yes")) return(TRUE)
  if (tolower(s) %in% c("false", "no")) return(FALSE)
  e <- tryCatch(str2lang(s), error = function(e) NULL)
  if (is.null(e)) return(gsub("^['\"]|['\"]$", "", s))
  const_or_lang(e)
}

parse_opts <- function(s) {
  if (!nzchar(trimws(s))) return(list())
  e <- tryCatch(str2lang(paste0("alist(", s, ")")), error = function(e) NULL)
  if (is.null(e)) return(list())
  args <- as.list(e)[-1]
  nms <- names(args)
  if (is.null(nms)) return(list())
  out <- lapply(args[nzchar(nms)], const_or_lang)
  out
}

# A constant expression (`7`, `c(4, 3)`, `7 * 0.6`, `FALSE`) is evaluated; anything
# that refers to a variable is kept as an expression for run time.
const_or_lang <- function(e) {
  if (!is.language(e)) return(e)
  if (length(setdiff(all.names(e), c("c", "*", "/", "+", "-", "(", "TRUE", "FALSE", "T", "F", "!"))) == 0L) {
    v <- tryCatch(eval(e, baseenv()), error = function(err) NULL)
    if (!is.null(v)) return(v)
  }
  e
}

global_chunk_opts <- function(code) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) NULL)
  out <- list()
  walk <- function(x) {
    if (!is.call(x)) return()
    fn <- paste(deparse(x[[1]]), collapse = "")
    if (fn %in% c("knitr::opts_chunk$set", "opts_chunk$set")) {
      args <- as.list(x)[-1]
      for (nm in intersect(names(args), c("fig.width", "fig.height", "fig.dim", "eval", "error"))) {
        v <- const_or_lang(args[[nm]])
        if (!is.language(v)) out[[nm]] <<- v
      }
    }
    for (i in seq_along(x)[-1]) if (is.call(x[[i]])) walk(x[[i]])
  }
  for (e in exprs) walk(e)
  out
}

fig_size <- function(opts) {
  w <- opts$fig.width
  h <- opts$fig.height
  if (is.numeric(opts$fig.dim) && length(opts$fig.dim) == 2L) {
    w <- opts$fig.dim[1]
    h <- opts$fig.dim[2]
  }
  num <- function(x, default) if (is.numeric(x) && length(x) >= 1L && !is.na(x[1])) x[1] else default
  c(num(w, 7), num(h, 7))
}

# Figure size defaults of the vignette's output format; knitr's own default is 7 x 7.
format_fig_defaults <- function(lines, rnw) {
  out <- list(fig.width = 7, fig.height = 7)
  if (rnw) return(out)
  yaml <- yaml_header(lines)
  if (any(grepl("html_vignette", yaml))) out <- list(fig.width = 3, fig.height = 3)
  else if (any(grepl("html_document", yaml))) out <- list(fig.width = 7, fig.height = 5)
  else if (any(grepl("pdf_document", yaml))) out <- list(fig.width = 6.5, fig.height = 4.5)
  num <- function(key) {
    m <- regmatches(yaml, regexec(paste0("^\\s*", key, "\\s*:\\s*([0-9.]+)"), yaml))
    v <- unlist(lapply(m, `[`, 2L))
    v <- v[!is.na(v)]
    if (length(v)) as.numeric(v[1]) else NULL
  }
  if (!is.null(fw <- num("fig_width"))) out$fig.width <- fw
  if (!is.null(fh <- num("fig_height"))) out$fig.height <- fh
  out
}

yaml_header <- function(lines) {
  if (!length(lines) || !grepl("^---\\s*$", lines[1])) return(character())
  end <- which(grepl("^(---|\\.\\.\\.)\\s*$", lines))
  end <- end[end > 1L]
  if (!length(end)) return(character())
  lines[2:(end[1] - 1L)]
}

vignette_title <- function(lines) {
  m <- regmatches(lines, regexpr("\\\\VignetteIndexEntry\\{[^}]*\\}", lines))
  if (length(m)) return(sub("^\\\\VignetteIndexEntry\\{(.*)\\}$", "\\1", m[1]))
  yaml <- yaml_header(lines)
  t <- grep("^title\\s*:", yaml, value = TRUE)
  if (length(t)) return(gsub("^title\\s*:\\s*['\"]?|['\"]?\\s*$", "", t[1]))
  NULL
}
