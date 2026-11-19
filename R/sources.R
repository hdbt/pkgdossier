#' Describe where a version of the package comes from
#'
#' These constructors only describe a source. Nothing is downloaded, exported or
#' built until [prepare_versions()], which says what it fetches and where.
#'
#' * `cran_release()`: the version on CRAN now.
#' * `cran_version()`: a given CRAN version, current or archived.
#' * `installed_version()`: the version installed in your library, fetched as source
#'   from CRAN (or its archive) by [prepare_versions()]: what you have now, to
#'   compare with `cran_release()` before upgrading. The installed copy itself is
#'   never used, as both versions are built from source the same way. A version that
#'   did not come from CRAN (a development version from GitHub or R-universe) stops
#'   with what to write instead, as does a package that is not installed; with
#'   `candidate = cran_release()`, so does an installed version that is already the
#'   current release.
#' * `tarball()`: a source tarball on disk (for example one downloaded from CRAN
#'   earlier).
#' * `git_ref()`: a commit, branch or tag of a git repository, exported with
#'   `git archive` and built with `R CMD build` inside the work folder, never in the
#'   repository.
#' * `local_path()`: a package source folder, built with `R CMD build` (which builds
#'   from a copy, so nothing is written into the folder).
#'
#' @param version Version string, for example `"0.2.1"`.
#' @param repos CRAN mirror. Defaults to the `CRAN` entry of `getOption("repos")`, or
#'   the cloud mirror when that is unset.
#' @param lib Library to look in for `installed_version()`; defaults to
#'   [.libPaths()], searched in order as [library()] does.
#' @param path Path to a tarball (`tarball()`) or a package folder (`local_path()`).
#' @param repo Path to a git repository.
#' @param ref Git ref: a branch, tag or commit. Only committed content is exported.
#' @param subdir Folder of the package inside the repository, if it is not the root.
#' @return An object of class `pkgdossier_source`.
#' @examples
#' cran_version("0.2.1")
#' # what changes for you if you upgrade: describing reads nothing yet
#' dossier("ggplot2", base = installed_version(), candidate = cran_release())
#' git_ref("path/to/MAIHDA", "main")
#' @name sources
NULL

new_source <- function(type, ...) {
  structure(list(type = type, ...), class = "pkgdossier_source")
}

#' @rdname sources
#' @export
cran_release <- function(repos = NULL) {
  new_source("cran", version = NULL, repos = repos)
}

#' @rdname sources
#' @export
cran_version <- function(version, repos = NULL) {
  stopifnot(is.character(version), length(version) == 1L)
  new_source("cran", version = version, repos = repos)
}

#' @rdname sources
#' @export
installed_version <- function(lib = NULL, repos = NULL) {
  if (!is.null(lib)) stopifnot(is.character(lib), length(lib) >= 1L)
  new_source("installed", lib = lib, repos = repos)
}

#' @rdname sources
#' @export
tarball <- function(path) {
  stopifnot(is.character(path), length(path) == 1L)
  new_source("tarball", path = path)
}

#' @rdname sources
#' @export
git_ref <- function(repo, ref = "HEAD", subdir = NULL) {
  stopifnot(is.character(repo), length(repo) == 1L, is.character(ref), length(ref) == 1L)
  new_source("git", repo = repo, ref = ref, subdir = subdir)
}

#' @rdname sources
#' @export
local_path <- function(path) {
  stopifnot(is.character(path), length(path) == 1L)
  new_source("local", path = path)
}

#' @export
format.pkgdossier_source <- function(x, ...) {
  switch(x$type,
    cran = if (is.null(x$version)) "CRAN release (current)" else paste("CRAN version", x$version),
    installed = "the installed version, from CRAN",
    tarball = paste("tarball", x$path),
    git = paste0("git ", x$repo, " @ ", x$ref, if (!is.null(x$subdir)) paste0(" (", x$subdir, ")")),
    local = paste("local folder", x$path)
  )
}

#' @export
print.pkgdossier_source <- function(x, ...) {
  cat("<pkgdossier source> ", format(x), "\n", sep = "")
  invisible(x)
}
