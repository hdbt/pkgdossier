# Turning the baseline's help-page examples into scenarios: one scenario per help page
# with examples, one step per top-level expression, extracted with tools::Rd2ex() as
# R CMD check does. \donttest{} code is run (as R CMD check --as-cran runs it);
# \dontrun{} code is left out and noted.

example_scenarios <- function(pkg_dir, src) {
  mdir <- file.path(pkg_dir, "man")
  files <- list.files(mdir, pattern = "\\.[Rr]d$", full.names = TRUE)
  if (!is.null(src$which)) {
    files <- files[tools::file_path_sans_ext(basename(files)) %in% src$which]
  }
  out <- list()
  for (f in files) {
    sc <- rd_example_scenario(f, time = src$time, values = src$values)
    if (!is.null(sc)) out[[length(out) + 1L]] <- sc
  }
  if (!length(out)) {
    if (is.null(src$which)) {
      message("The baseline has no help-page examples; from_examples() gives no scenarios.")
      return(list())
    }
    stop("No help-page examples found in ", mdir, " for ", paste(src$which, collapse = ", "), ".",
         call. = FALSE)
  }
  out
}

rd_example_scenario <- function(file, time = FALSE, values = TRUE) {
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp), add = TRUE)
  ok <- tryCatch({
    suppressWarnings(tools::Rd2ex(file, tmp, commentDontrun = TRUE, commentDonttest = FALSE))
    TRUE
  }, error = function(e) {
    warning("Could not extract the examples of ", basename(file), ": ", conditionMessage(e), call. = FALSE)
    FALSE
  })
  if (!ok || !file.exists(tmp) || !file.size(tmp)) return(NULL)
  lines <- readLines(tmp, warn = FALSE, encoding = "UTF-8")
  name <- header_field(lines, "Name") %||% tools::file_path_sans_ext(basename(file))
  title <- header_field(lines, "Title") %||% name
  notes <- if (any(grepl("^## Not run:", lines))) "has \\dontrun{} code, which is not run" else character()

  exprs <- tryCatch(parse(text = lines, keep.source = TRUE), error = function(e) NULL)
  codes <- if (is.null(exprs)) {
    # run as one step, so the parse error is reported for this page under both versions
    paste(lines[!grepl("^#", lines)], collapse = "\n")
  } else {
    vapply(attr(exprs, "srcref"), function(s) paste(as.character(s), collapse = "\n"), "")
  }
  if (!length(codes) || !any(nzchar(trimws(codes)))) return(NULL)
  # each step draws on its own device, so a call that adds to the current plot
  # (abline() after plot()) joins the step that drew it, with the expressions in
  # between, as on R CMD check's one device
  merged <- character()
  opener <- NA_integer_
  for (cd in codes) {
    if (length(merged) && adds_to_plot(cd)) {
      k <- if (is.na(opener)) length(merged) else opener
      merged <- c(merged[seq_len(k - 1L)], paste(c(merged[k:length(merged)], cd), collapse = "\n"))
      opener <- k
    } else {
      merged <- c(merged, cd)
      if (opens_plot(cd)) opener <- length(merged)
    }
  }
  codes <- merged
  steps <- lapply(seq_along(codes), function(i) {
    first <- trimws(strsplit(codes[i], "\n", fixed = TRUE)[[1]][1])
    new_step(sprintf("ex-%02d", i), "chunk", codes[i],
             label = if (nchar(first) > 60L) paste0(substr(first, 1L, 57L), "...") else first,
             values = values, time = time, w = 7, h = 7)
  })
  new_scenario(paste0("ex_", name), steps, title = title,
               source = paste0("examples in ", basename(file)), notes = notes)
}

# Rd2ex() writes "### Name: x" and "### Title: ..." at the top of its output.
header_field <- function(lines, field) {
  m <- regmatches(lines, regexec(paste0("^### ", field, ":\\s*(.*)$"), lines))
  v <- unlist(lapply(m, `[`, 2L))
  v <- v[!is.na(v) & nzchar(v)]
  if (length(v)) v[1] else NULL
}

# Does this expression start a plot of its own (a high-level graphics call, or a
# call to a function whose name starts with "plot")?
opens_plot <- function(code) {
  e <- tryCatch(str2lang(code), error = function(err) NULL)
  if (is.null(e) || adds_to_plot(code)) return(FALSE)
  high <- c("plot", "hist", "barplot", "boxplot", "image", "contour", "filled.contour", "persp",
            "pie", "dotchart", "stripchart", "matplot", "pairs", "coplot", "curve", "sunflowerplot",
            "symbols", "mosaicplot", "fourfoldplot", "assocplot", "spineplot", "cdplot",
            "smoothScatter", "stars", "plot.new", "frame", "biplot", "qqnorm", "qqplot", "termplot",
            "heatmap", "interaction.plot", "lag.plot", "monthplot", "ts.plot", "screeplot",
            "scatter.smooth")
  fns <- all.names(e)
  any(fns %in% high) || any(startsWith(fns, "plot"))
}

# Does this expression only add to the current plot?
adds_to_plot <- function(code) {
  e <- tryCatch(str2lang(code), error = function(err) NULL)
  if (!is.call(e)) return(FALSE)
  fn <- e[[1]]
  if (is.call(fn) && as.character(fn[[1]])[1] %in% c("::", ":::")) fn <- fn[[3]]
  name <- if (is.name(fn)) as.character(fn) else ""
  low_level <- c("lines", "points", "abline", "text", "mtext", "legend", "title", "axis", "box",
                 "grid", "polygon", "polypath", "segments", "arrows", "rect", "rug", "matlines",
                 "matpoints")
  if (name %in% low_level) return(TRUE)
  name %in% c("curve", "contour", "image", "symbols", "plot", "hist", "barplot") &&
    isTRUE(tryCatch(eval(e$add, baseenv()), error = function(err) FALSE))
}
