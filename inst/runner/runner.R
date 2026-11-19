# Runs the scenarios under ONE installed version of a package and saves everything the
# comparison needs: console transcripts, printed values, warnings and errors with
# their classes, flattened numbers, element names, plots and timings.
#
# This file is sourced into a fresh environment inside a child R process (one per
# version and run) whose library path starts with that version's library. It uses
# only base R and evaluate, so the child loads nothing from pkgdossier itself.

`%||%` <- function(x, y) if (is.null(x)) y else x

run_version <- function(a) {
  options(width = a$width, cli.num_colors = 1, crayon.enabled = FALSE,
          cli.dynamic = FALSE, cli.unicode = FALSE)
  lib <- normalizePath(a$lib, winslash = "/", mustWork = TRUE)
  suppressPackageStartupMessages(library(a$pkg, lib.loc = lib, character.only = TRUE))
  pkg_path <- normalizePath(find.package(a$pkg), winslash = "/")
  if (!startsWith(tolower(pkg_path), tolower(lib))) {
    stop(a$pkg, " loaded from ", pkg_path, ", not from ", lib)
  }
  scenarios <- readRDS(a$scenarios)
  plotdir <- file.path(a$out, "plots")
  unlink(plotdir, recursive = TRUE)
  dir.create(plotdir, recursive = TRUE, showWarnings = FALSE)

  desc <- utils::packageDescription(a$pkg, lib.loc = lib)
  results <- list(
    meta = list(
      label = a$label, pkg = a$pkg, pkg_version = desc$Version, pkg_path = pkg_path,
      pkg_packaged = desc$Packaged %||% NA_character_, identity = a$identity, setup = a$setup,
      scenario_hash = a$scenario_hash, r_version = R.version.string,
      packages = dep_versions(desc),
      started = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      machine = paste(Sys.info()[c("sysname", "release", "machine")], collapse = " "),
      cores = parallel::detectCores(), blas = extSoftVersion()[["BLAS"]],
      functions = namespace_functions(a$pkg), api = export_signatures(a$pkg),
      language = Sys.getenv("LANGUAGE"), width = a$width, reps = a$reps, seed = a$seed,
      reseed = a$reseed %||% "step", dpi = a$dpi, run_key = a$run_key
    ),
    scenarios = list()
  )

  for (sc in scenarios) results$scenarios[[sc$id]] <- run_scenario(sc, a, plotdir)
  results$meta$finished <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  saveRDS(results, file.path(a$out, "results.rds"))
  invisible(file.path(a$out, "results.rds"))
}

# One scenario in its own environment. Vignette scenarios run from a copy of the
# baseline's vignettes folder, so code that reads files next to the vignette finds
# them. The seed is set at the start of the scenario and, with reseed = "step", again
# before every step.
run_scenario <- function(sc, a, plotdir) {
  # what one scenario sets must not reach the next
  state <- session_state()
  on.exit(restore_state(state), add = TRUE)
  env <- new.env(parent = globalenv())
  if (!is.null(sc$workdir)) {
    old_wd <- setwd(file.path(a$out, "wd", sc$workdir))
    on.exit(setwd(old_wd), add = TRUE)
  }
  per_step <- !identical(a$reseed, "scenario")
  set.seed(a$seed)
  steps_out <- list()
  for (st in sc$steps) {
    rec <- list(id = st$id, kind = st$kind, label = st$label,
                code = paste(st$code, collapse = "\n"), w = st$w, h = st$h,
                note = st$note, expect_error = isTRUE(st$expect_error))
    run_it <- isTRUE(st$eval)
    if (run_it && !is.null(st$eval_expr)) {
      v <- tryCatch(eval(str2lang(st$eval_expr), env), error = function(e) TRUE)
      run_it <- !isFALSE(v)
      rec$eval_expr <- st$eval_expr
    }
    if (!run_it) {
      rec$not_run <- TRUE
      steps_out[[st$id]] <- rec
      next
    }
    # written before the step runs, so a run that hangs or crashes shows where in its log
    key <- paste0(sc$id, "/", st$id)
    if (key %in% a$timed_out) {
      # stopped by run_scenarios() for taking longer than step_timeout, in this run
      # or in this version's earlier run
      rec <- c(rec, list(transcript = character(), printed = character(), warnings = character(),
                         warning_classes = list(),
                         error = sprintf("timed out after %s s", format(a$step_timeout)),
                         error_class = c("pkgdossier_timeout", "error", "condition"),
                         elapsed = a$step_timeout, cpu = NA_real_, n_values = 0L, timed_out = TRUE))
      if (key %in% names(a$skipped_from)) {
        rec$not_started <- sprintf("not started: it timed out in %s", a$skipped_from[[key]])
      }
      steps_out[[st$id]] <- rec
      cat(sprintf("[%s] %s: timed out, not run\n", a$label, key))
      next
    }
    if (key %in% names(a$crashed)) {
      # the process died in this step on an earlier start; run_scenarios() restarted it
      rec <- c(rec, list(transcript = character(), printed = character(), warnings = character(),
                         warning_classes = list(),
                         error = sprintf("R stopped in this step: %s", a$crashed[[key]]),
                         error_class = c("pkgdossier_crash", "error", "condition"),
                         elapsed = NA_real_, cpu = NA_real_, n_values = 0L, crashed = TRUE))
      steps_out[[st$id]] <- rec
      cat(sprintf("[%s] %s: crashed on an earlier start, not run\n", a$label, key))
      next
    }
    if (key %in% names(a$runner_failed)) {
      # the runner raised an R error while capturing this step on an earlier start
      rec <- c(rec, list(transcript = character(), printed = character(), warnings = character(),
                         warning_classes = list(),
                         error = sprintf("pkgdossier could not capture this step: %s", a$runner_failed[[key]]),
                         error_class = c("pkgdossier_runner_error", "error", "condition"),
                         elapsed = NA_real_, cpu = NA_real_, n_values = 0L, crashed = TRUE))
      steps_out[[st$id]] <- rec
      cat(sprintf("[%s] %s: not captured on an earlier start, not run\n", a$label, key))
      next
    }
    cat(sprintf("[%s] %s: starting\n", a$label, key))
    flush(stdout())
    if (per_step) set.seed(a$seed)
    rng <- get_rng()
    r <- capture_step(st, env, plotdir, paste0(sc$id, "__", st$id), a)
    rec <- c(rec, r)
    if (isTRUE(st$time) && is.null(r$error) && !length(r$shown_errors) && a$reps > 0L) {
      after <- get_rng()
      rec$reps <- time_reps(st, env, a$reps, rng, mark = function(i) {
        # each repeat is an execution of its own for step_timeout
        cat(sprintf("[%s] %s: repeat %d\n", a$label, key, i))
        flush(stdout())
      })
      set_rng(after)  # later steps continue the stream the captured run left
    }
    steps_out[[st$id]] <- rec
    cat(sprintf("[%s] %s: finished\n", a$label, key))
    cat(sprintf("[%s] %-16s %-26s %-6s %7.3fs%s\n", a$label, sc$id, st$id,
                if (is.null(r$error)) "ok" else "ERROR", r$elapsed,
                if (is.null(rec$reps)) "" else sprintf("  reps median %.3fs", stats::median(rec$reps[, "elapsed"]))))
  }
  list(id = sc$id, title = sc$title, source = sc$source, notes = sc$notes, steps = steps_out)
}

# The parts of the session a scenario can change and a later scenario would see.
# Graphics parameters are not among them: every step draws on its own device.
# Namespaces a scenario loads stay loaded; R cannot unload them reliably.
session_state <- function() {
  list(options = options(), search = search(), palette = grDevices::palette(),
       rng_kind = RNGkind(), env = Sys.getenv(), wd = getwd())
}

restore_state <- function(s) {
  for (nm in rev(setdiff(search(), s$search))) {
    pos <- match(nm, search())
    if (!is.na(pos)) try(detach(pos = pos), silent = TRUE)
  }
  added <- setdiff(names(options()), names(s$options))
  if (length(added)) options(stats::setNames(rep(list(NULL), length(added)), added))
  options(s$options)
  grDevices::palette(s$palette)
  if (!identical(RNGkind(), s$rng_kind)) suppressWarnings(do.call(RNGkind, as.list(s$rng_kind)))
  env_added <- setdiff(names(Sys.getenv()), names(s$env))
  if (length(env_added)) Sys.unsetenv(env_added)
  do.call(Sys.setenv, as.list(s$env))
  setwd(s$wd)
  invisible()
}

get_rng <- function() {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
}

set_rng <- function(state) {
  if (is.null(state)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
  } else {
    assign(".Random.seed", state, envir = globalenv())
  }
}

# The functions in the package's namespace, exported or not: what NEWS bullets about
# a step's code can name.
namespace_functions <- function(pkg) {
  ns <- asNamespace(pkg)
  nms <- ls(ns, all.names = TRUE)
  sort(nms[vapply(nms, function(n) is.function(get(n, envir = ns)), logical(1))])
}

# Every export with, for functions, its argument names and defaults (NA for an
# argument without one): what code calling the package relies on.
export_signatures <- function(pkg) {
  ex <- sort(getNamespaceExports(pkg))
  ex <- ex[!startsWith(ex, ".__")]
  sig <- lapply(ex, function(nm) {
    obj <- tryCatch(getExportedValue(pkg, nm), error = function(e) NULL)
    if (!is.function(obj)) return(list(type = class(obj)[1L], args = character(), defaults = character()))
    fm <- if (is.primitive(obj)) formals(args(obj)) else formals(obj)
    defaults <- vapply(as.list(fm), function(v) {
      d <- paste(deparse(v, width.cutoff = 500L), collapse = " ")
      if (nzchar(d)) d else NA_character_
    }, "")
    list(type = "function", args = names(fm) %||% character(), defaults = unname(defaults))
  })
  names(sig) <- ex
  sig
}

dep_versions <- function(desc) {
  fields <- c("Depends", "Imports", "LinkingTo", "Suggests")
  txt <- paste(unlist(desc[fields]), collapse = ",")
  pk <- trimws(sub("\\(.*$", "", strsplit(txt, ",")[[1]]))
  pk <- setdiff(unique(pk[nzchar(pk)]), c("R", rownames(utils::installed.packages(priority = "base", noCache = TRUE))))
  vapply(pk, function(p) {
    tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_)
  }, character(1))
}

# Run one step as a console user meets it: each top-level expression in turn, visible
# values printed, output and messages in one transcript, warnings listed separately
# (R prints them after the call), the first error stops the step. Plots go straight to
# PNG files at the step's figure size.
capture_step <- function(st, env, plotdir, stem, a) {
  pattern <- file.path(plotdir, paste0(stem, "_%02d.png"))
  grDevices::png(pattern, width = st$w, height = st$h, units = "in", res = a$dpi)
  dev <- grDevices::dev.cur()
  grDevices::dev.control(displaylist = "enable")
  on.exit(if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev), add = TRUE)
  vals <- list()
  printed <- character()
  timing_shown <- FALSE
  handler <- evaluate::new_output_handler(value = function(x, visible) {
    if (!visible) return(invisible())
    # system.time() results differ in every run; the runner times steps itself
    if (inherits(x, "proc_time")) {
      timing_shown <<- TRUE
      return(invisible())
    }
    vals[[length(vals) + 1L]] <<- x
    printed <<- c(printed, utils::capture.output(if (isS4(x)) methods::show(x) else print(x)))
    invisible()
  })
  # a chunk with error = TRUE goes on after an error, as knitr runs it, and shows it
  expect <- isTRUE(st$expect_error)
  t0 <- proc.time()
  res <- evaluate::evaluate(st$code, envir = env, new_device = FALSE, stop_on_error = if (expect) 0L else 1L,
                            output_handler = handler)
  dt <- proc.time() - t0
  # Some png devices write a blank file even when nothing is drawn; an empty display
  # list on the step's device means no plot.
  drawn <- FALSE
  if (dev %in% grDevices::dev.list()) {
    grDevices::dev.set(dev)
    drawn <- length(grDevices::recordPlot()[[1]]) > 0L
    grDevices::dev.off(dev)
  }
  stem_files <- list.files(plotdir, pattern = paste0("^", gsub(".", "\\.", stem, fixed = TRUE), "_[0-9]+\\.png$"),
                           full.names = TRUE)
  if (!drawn && length(stem_files) == 1L) unlink(stem_files)

  transcript <- character()
  warnings <- list()
  error <- NULL
  shown <- list()
  for (o in res) {
    if (inherits(o, "source") || inherits(o, "recordedplot")) next
    if (is.character(o)) {
      transcript <- c(transcript, split_lines(o))
    } else if (inherits(o, "error")) {
      if (expect && !missing_package_error(o)) {
        # an error the vignette shows its readers is part of its output; one from a
        # package that is not installed stays an error, a problem with the scenario
        transcript <- c(transcript, split_lines(paste0("Error: ", message_of(o))))
        shown[[length(shown) + 1L]] <- list(message = message_of(o), class = class(o))
      } else if (is.null(error)) {
        error <- list(message = message_of(o), class = class(o))
      }
    } else if (inherits(o, "warning")) {
      warnings[[length(warnings) + 1L]] <- list(message = message_of(o), class = class(o))
    } else if (inherits(o, "message")) {
      transcript <- c(transcript, split_lines(sub("\n$", "", message_of(o))))
    }
  }

  rec <- list(transcript = transcript, printed = printed,
              warnings = vapply(warnings, `[[`, "", "message"),
              warning_classes = lapply(warnings, `[[`, "class"),
              error = error$message, error_class = error$class,
              shown_errors = vapply(shown, `[[`, "", "message"),
              shown_error_classes = lapply(shown, `[[`, "class"),
              elapsed = dt[["elapsed"]], cpu = dt[["user.self"]] + dt[["sys.self"]],
              n_values = length(vals), timing_shown = timing_shown,
              class = if (length(vals)) class(vals[[length(vals)]]) else NULL)
  files <- basename(stem_files[file.exists(stem_files)])
  rec$files <- files
  rec$plot_md5 <- unname(tools::md5sum(file.path(plotdir, files)))

  if (isTRUE(st$values)) {
    flat <- list()
    struct <- character()
    capped <- character()
    assigned <- assigned_names(st$code)
    assigned <- assigned[vapply(assigned, exists, logical(1), envir = env, inherits = FALSE)]
    for (nm in assigned) {
      obj <- get(nm, envir = env, inherits = FALSE)
      f <- flatten_values(obj, nm, a$assign_depth, a)
      flat[[length(flat) + 1L]] <- f$values
      capped <- c(capped, f$capped)
      struct <- c(struct, struct_paths(obj, nm, a$skip_classes))
    }
    for (k in seq_along(vals)) {
      x <- vals[[k]]
      if (any(vapply(assigned, function(nm) identical(x, get(nm, envir = env)), logical(1)))) next
      root <- if (length(vals) > 1L) paste0("#", k) else ""
      f <- flatten_values(x, root, a$max_depth, a)
      flat[[length(flat) + 1L]] <- f$values
      capped <- c(capped, f$capped)
      struct <- c(struct, struct_paths(x, root, a$skip_classes))
    }
    rec$values <- if (length(flat)) do.call(rbind, flat) else empty_values()
    rec$values$path <- number_duplicates(rec$values$path)
    rec$struct <- unique(struct)
    rec$capped <- unique(capped)
  }
  # paths and memory addresses differ from run to run; a step that shows one would
  # be unstable
  for (f in c("transcript", "printed", "warnings", "error", "shown_errors")) rec[[f]] <- mask_volatile(rec[[f]], a)
  # print() pads strings to the longest, whose length a masked path no longer shows:
  # trailing spaces on a console line carry nothing a reader sees
  for (f in c("transcript", "printed")) rec[[f]] <- sub("[ \t]+$", "", rec[[f]])
  if (!is.null(rec$values)) rec$values$text <- mask_volatile(rec$values$text, a)
  rec
}

# The temporary folders are this process's and that of the R session that started it
# (callr's script files live there; commandArgs() shows them).
# Memory addresses as R prints them (`<environment: 0x55e7ad2f3268>` for a formula's
# environment, `<bytecode: 0x...>`, `<pointer: 0x...>`) and as packages show them
# (data.table's address(), tracemem()'s `<0x...>`: a 0x followed by 8 to 16 hex
# digits) become 0x<address>; then the session's temporary folder becomes <tempdir>
# and the run's folder <run>, in every spelling a path can take in output (as given,
# normalized, with backslashes, with the doubled backslashes print() shows); a file
# name in the temporary folder with a run of hex digits, as tempfile() makes, becomes
# <tempfile>, keeping its extension, as does a bare name of tempfile()'s default
# form (`file` and 8 or more hex digits, as dir(tempdir()) lists them). The padding
# between values on a masked line is reduced to one space.
mask_volatile <- function(x, a) {
  if (!length(x) || !is.character(x)) return(x)
  x <- utf8_safe(x)
  orig <- x
  x <- gsub("(<[A-Za-z][A-Za-z ._]*: )0x[0-9a-fA-F]+>", "\\10x<address>>", x, perl = TRUE)
  x <- gsub("\\b0x[0-9a-fA-F]{8,16}\\b", "0x<address>", x, perl = TRUE)
  spellings <- function(r) {
    v <- unique(c(r, normalizePath(r, winslash = "/", mustWork = FALSE),
                  normalizePath(r, winslash = "\\", mustWork = FALSE)))
    unique(c(v, gsub("\\", "\\\\", v, fixed = TRUE)))
  }
  run <- if (is.null(a$out)) character() else spellings(a$out)
  tmp <- unique(c(spellings(tempdir()), if (!is.null(a$host_tempdir)) spellings(a$host_tempdir)))
  roots <- c(stats::setNames(run, rep("<run>", length(run))), stats::setNames(tmp, rep("<tempdir>", length(tmp))))
  roots <- roots[nzchar(roots)]
  roots <- roots[order(-nchar(roots))]
  for (i in seq_along(roots)) x <- gsub(roots[[i]], names(roots)[i], x, fixed = TRUE)
  # the separator after a masked folder is written "/", so a masked path reads the same
  # on Windows (where tempfile() joins with a backslash) as elsewhere
  x <- gsub("(<tempdir>|<run>)\\\\+", "\\1/", x, perl = TRUE)
  x <- gsub("(<tempdir>[/\\\\]+)[^/\\\\\\s'\"]*?[0-9a-f]{6,}", "\\1<tempfile>", x, perl = TRUE)
  x <- gsub("(?<![A-Za-z0-9_.])file[0-9a-f]{8,}(?![A-Za-z0-9_])", "<tempfile>", x, perl = TRUE)
  # print() pads columns to the longest value, whose length a masked one no longer
  # shows: on a line where something was masked, a run of spaces between values is one
  masked <- !is.na(x) & x != orig
  x[masked] <- gsub("(?<=\\S) {2,}(?=\\S)", " ", x[masked], perl = TRUE)
  x
}

# Text a step outputs can hold bytes that are not valid UTF-8 (a latin1 string, raw
# bytes); they are shown as <xx> so that capture never fails on them.
utf8_safe <- function(x) {
  x <- enc2utf8(as.character(x))
  bad <- !is.na(x) & !validUTF8(x)
  if (any(bad)) x[bad] <- iconv(x[bad], "UTF-8", "UTF-8", sub = "byte")
  x
}

message_of <- function(cond) utf8_safe(conditionMessage(cond))

# library(), loadNamespace() and `::` on a package that is not installed.
missing_package_error <- function(cond) {
  inherits(cond, "packageNotFoundError") || grepl("there is no package called", conditionMessage(cond))
}

split_lines <- function(x) {
  x <- paste(utf8_safe(x), collapse = "")
  if (!nzchar(x)) return(character())
  strsplit(sub("\n$", "", x), "\n", fixed = TRUE)[[1]]
}

assigned_names <- function(code) {
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) expression())
  out <- character()
  for (e in exprs) {
    # (x <- f()) assigns and prints
    while (is.call(e) && identical(e[[1]], as.name("(")) && length(e) == 2L) e <- e[[2]]
    if (is.call(e) && as.character(e[[1]])[1] %in% c("<-", "=", "<<-") && is.name(e[[2]])) {
      out <- c(out, as.character(e[[2]]))
    }
  }
  unique(out)
}

# Timed repeats. Each repeat runs in a throwaway child of the scenario environment, so
# a step like `x <- x + 1` does not change what later steps see, and starts from the
# random-number state the captured run started from. Output is discarded and visible
# values are not printed: the repeats time the computation.
time_reps <- function(st, env, n, rng, mark = function(i) NULL) {
  exprs <- tryCatch(parse(text = st$code, keep.source = FALSE), error = function(e) expression())
  out <- matrix(NA_real_, n, 2L, dimnames = list(NULL, c("elapsed", "cpu")))
  null_con <- file(nullfile(), "w")
  on.exit(close(null_con), add = TRUE)
  grDevices::pdf(NULL)
  dev <- grDevices::dev.cur()
  on.exit(if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev), add = TRUE)
  for (i in seq_len(n)) {
    mark(i)
    tenv <- new.env(parent = env)
    set_rng(rng)
    sink(null_con)
    sink(null_con, type = "message")
    t0 <- proc.time()
    try(suppressWarnings(suppressMessages(for (e in exprs) eval(e, tenv))), silent = TRUE)
    dt <- proc.time() - t0
    sink(type = "message")
    sink()
    out[i, ] <- c(dt[["elapsed"]], dt[["user.self"]] + dt[["sys.self"]])
  }
  out
}

empty_values <- function() {
  data.frame(path = character(), value = numeric(), text = character(), stringsAsFactors = FALSE)
}

# Data-frame rows are keyed by a unique character column where there is one, so a
# reordered table still compares row by row.
row_keys <- function(df) {
  chr <- names(df)[vapply(df, function(v) is.character(v) || is.factor(v), logical(1))]
  for (col in chr) {
    k <- as.character(df[[col]])
    if (!anyDuplicated(k) && !anyNA(k)) return(k)
  }
  if (length(chr) > 1L) {
    k <- do.call(paste, c(lapply(df[chr], as.character), sep = "|"))
    if (!anyDuplicated(k)) return(k)
  }
  rn <- rownames(df)
  if (!is.null(rn) && !identical(rn, as.character(seq_len(nrow(df))))) return(rn)
  as.character(seq_len(nrow(df)))
}

# Every number (and short string) inside an object, keyed by its path. Walks lists,
# data frames, matrices, S4 slots and S7 properties; skips the classes in
# a$skip_classes; reports what it did not walk because of the size caps.
flatten_values <- function(x, root, max_depth, a) {
  paths <- character()
  vals <- numeric()
  txts <- character()
  capped <- character()
  add <- function(p, v, t = NA_character_) {
    paths[length(paths) + 1L] <<- p
    vals[length(vals) + 1L] <<- v
    txts[length(txts) + 1L] <<- t
  }
  join <- function(path, nm, sep = "$") if (nzchar(path)) paste0(path, sep, nm) else nm
  label <- function(path) if (nzchar(path)) path else "(value)"
  walk <- function(x, path, depth) {
    # system.time() and proc.time() results differ in every run; the runner times
    # steps itself
    if (depth > max_depth || is.null(x) || is.function(x) || is.environment(x) ||
        is.language(x) || inherits(x, c(a$skip_classes, "proc_time"))) return(invisible())
    if (inherits(x, "S7_object")) {
      at <- attributes(x)
      for (nm in setdiff(names(at), c("class", "S7_class"))) walk(at[[nm]], join(path, nm, "@"), depth + 1L)
      return(invisible())
    }
    if (isS4(x)) {
      for (s in methods::slotNames(x)) walk(methods::slot(x, s), join(path, s, "@"), depth + 1L)
      return(invisible())
    }
    if (is.data.frame(x)) {
      if (nrow(x) == 0L) return(invisible())
      if (nrow(x) > a$max_rows) {
        capped <<- c(capped, sprintf("%s: data frame with %d rows (cap %d)", label(path), nrow(x), a$max_rows))
        return(invisible())
      }
      key <- row_keys(x)
      for (col in names(x)) {
        v <- x[[col]]
        if (is.numeric(v) || is.logical(v)) {
          for (i in seq_len(nrow(x))) add(sprintf("%s[%s]", join(path, col), key[i]), as.numeric(v[i]))
        }
      }
      return(invisible())
    }
    if (is.matrix(x) && (is.numeric(x) || is.logical(x))) {
      if (length(x) > a$max_cells) {
        capped <<- c(capped, sprintf("%s: %d x %d matrix (cap %d cells)", label(path), nrow(x), ncol(x), a$max_cells))
        return(invisible())
      }
      rn <- rownames(x) %||% seq_len(nrow(x))
      cn <- colnames(x) %||% seq_len(ncol(x))
      for (i in seq_len(nrow(x))) for (j in seq_len(ncol(x))) {
        add(sprintf("%s[%s,%s]", path, rn[i], cn[j]), as.numeric(x[i, j]))
      }
      return(invisible())
    }
    if (is.list(x)) {
      nms <- names(x)
      for (i in seq_along(x)) {
        nm <- if (!is.null(nms) && !is.na(nms[i]) && nzchar(nms[i])) nms[i] else paste0("[[", i, "]]")
        walk(x[[i]], if (startsWith(nm, "[[")) paste0(path, nm) else join(path, nm), depth + 1L)
      }
      return(invisible())
    }
    if (is.numeric(x) || is.logical(x)) {
      if (length(x) > a$max_length) {
        capped <<- c(capped, sprintf("%s: vector of length %d (cap %d)", label(path), length(x), a$max_length))
        return(invisible())
      }
      if (length(x) == 1L && is.null(names(x))) {
        add(label(path), as.numeric(x))
      } else {
        nms <- names(x)
        for (i in seq_along(x)) {
          add(sprintf("%s[%s]", path, if (!is.null(nms) && nzchar(nms[i])) nms[i] else i), as.numeric(x[i]))
        }
      }
      return(invisible())
    }
    if ((is.character(x) || is.factor(x)) && length(x) == 1L && !is.na(x) &&
        nchar(as.character(x)) <= 120L) {
      add(label(path), NA_real_, as.character(x))
    }
    invisible()
  }
  walk(x, root, 0L)
  list(values = data.frame(path = number_duplicates(paths), value = vals, text = txts,
                           stringsAsFactors = FALSE),
       capped = capped)
}

# Repeated element names (list(a = 1, a = 2), c(x = 1, x = 5)) give one path twice;
# the second and later get "#2", "#3", ... so that every path names one number.
number_duplicates <- function(paths) {
  if (!anyDuplicated(paths)) return(paths)
  k <- stats::ave(seq_along(paths), paths, FUN = seq_along)
  ifelse(k > 1L, paste0(paths, "#", k), paths)
}

# Element names down to depth 3: what code reading x$foo$bar (or x@slot) relies on.
# A data frame gives its columns as x$df$col.
struct_paths <- function(x, path, skip, depth = 0L) {
  if (depth >= 3L || inherits(x, skip)) return(character())
  join <- function(nm, sep = "$") if (nzchar(path)) paste0(path, sep, nm) else nm
  if (isS4(x) && !inherits(x, "S7_object")) {
    out <- character()
    for (s in methods::slotNames(x)) {
      p <- join(s, "@")
      out <- c(out, p, struct_paths(methods::slot(x, s), p, skip, depth + 1L))
    }
    return(out)
  }
  if (!is.list(x)) return(character())
  if (is.data.frame(x)) return(vapply(names(x), join, ""))
  nms <- names(x)
  if (is.null(nms)) return(character())
  out <- character()
  for (nm in unique(nms[!is.na(nms) & nzchar(nms)])) {
    p <- join(nm)
    out <- c(out, p, struct_paths(x[[nm]], p, skip, depth + 1L))
  }
  unname(out)
}
