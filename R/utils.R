`%||%` <- function(x, y) if (is.null(x)) y else x

say <- function(..., quiet = FALSE) {
  if (!quiet) message(...)
}

# An error with a class of its own, so that callers and tests can tell the failure
# modes apart: pkgdossier_error_not_package, _not_on_repo, _offline, _no_scenarios.
stop_pkgdossier <- function(class, ...) {
  stop(structure(class = c(paste0("pkgdossier_error_", class), "pkgdossier_error", "error", "condition"),
                 list(message = paste0(...), call = NULL)))
}


sha256_file <- function(path) digest::digest(file = path, algo = "sha256")

# Environment for child processes: callr's safe defaults plus LANGUAGE, so that
# messages come out in one language whatever the machine's locale.
child_env <- function(language) {
  env <- callr::rcmd_safe_env()
  if (!is.null(language)) env <- c(env, LANGUAGE = language)
  env
}

# R CMD <cmd> in a child process; stops with the tail of the output on failure.
rcmd_or_stop <- function(cmd, args, wd = ".", language = "en", log = NULL, libpath = .libPaths()) {
  res <- callr::rcmd(cmd, args, wd = wd, env = child_env(language), libpath = libpath,
                     fail_on_status = FALSE, echo = FALSE, show = FALSE)
  out <- c(res$stdout, res$stderr)
  if (!is.null(log)) writeLines(out, log, useBytes = TRUE)
  if (res$status != 0L) {
    lines <- utils::tail(strsplit(paste(out, collapse = "\n"), "\n")[[1]], 25L)
    stop("R CMD ", cmd, " failed:\n", paste(lines, collapse = "\n"),
         if (!is.null(log)) paste0("\nFull output: ", normalizePath(log, winslash = "/", mustWork = FALSE)),
         call. = FALSE)
  }
  invisible(res)
}

git_available <- function() nzchar(Sys.which("git"))

git <- function(repo, ..., stop_on_error = TRUE) {
  if (!git_available()) stop("git is not on the PATH.", call. = FALSE)
  out <- suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L
  if (status != 0L && stop_on_error) {
    stop("git ", paste(c(...), collapse = " "), " failed:\n", paste(out, collapse = "\n"), call. = FALSE)
  }
  if (status != 0L) return(NULL)
  as.character(out)
}

read_desc <- function(path) {
  d <- read.dcf(path)
  as.list(d[1L, ])
}

safe_id <- function(x) {
  x <- gsub("[^A-Za-z0-9_.-]+", "_", x)
  x[!nzchar(x)] <- "step"
  x
}

dedupe <- function(x) {
  if (!anyDuplicated(x)) return(x)
  make.unique(x, sep = "_")
}

write_rds_atomic <- function(x, path) {
  tmp <- paste0(path, ".tmp")
  saveRDS(x, tmp)
  unlink(path)
  invisible(file.rename(tmp, path))
}
