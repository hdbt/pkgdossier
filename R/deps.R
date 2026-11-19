#' Where the dependencies come from
#'
#' The `deps` argument of [dossier()] says which versions of the package's
#' dependencies both versions install and run against.
#'
#' * `deps_shared()`: the dependencies in the current library paths, so differences
#'   come from the package alone.
#' * `deps_cran()`: the current CRAN versions of every dependency of both versions
#'   (Depends, Imports and LinkingTo, recursively) are installed into a library in
#'   the work folder, as a new user installing today would get them. [prepare_versions()]
#'   installs them, and reinstalls one when the repository has a newer version.
#' * `deps_snapshot()`: the versions CRAN had on the baseline's release date (its
#'   `Date/Publication`, else the day it was packaged, or `date`), from Posit Package
#'   Manager's dated snapshots, installed the same way. Differences then come from the
#'   package's own changes rather than from changes in its dependencies since its
#'   release; a baseline that fails with today's dependencies (a removed function, a
#'   changed C interface) runs as its users had it. A candidate that needs newer
#'   dependencies than the snapshot has stops with a clear message. A snapshot older
#'   than the R running it can hold versions that no longer build (R removes C entry
#'   points over time); those are installed at their current version, and
#'   [prepare_versions()] and `versions.json` (`newer_than_snapshot`) say which. For a
#'   faithful snapshot, run on an R from the baseline's time.
#'
#' With `deps_cran()` and `deps_snapshot()`, R's base and recommended packages are
#' used as installed, and packages the scenarios use that are not dependencies (a
#' vignette's suggested packages) come from the current library paths. Their
#' libraries in the work folder are kept per R minor version (`lib-deps-R4.6`,
#' `lib-deps-2025-06-10-R4.6`), so the same work folder used under another R installs
#' them afresh.
#'
#' @param repos Repository to install from. `deps_cran()` defaults to the `CRAN`
#'   entry of `getOption("repos")`, or the cloud mirror; `deps_snapshot()` to the
#'   dated Posit Package Manager URL. A given repository is used as is; for
#'   `deps_snapshot()`, versions that do not build are then taken from the same URL
#'   with `latest` in place of its date, and a URL without a date has no such
#'   fallback.
#' @param date The snapshot's date (`"2025-06-10"`, or a `Date`), overriding the
#'   baseline's release date. Set it for a baseline built here (a git ref or a
#'   folder), whose packaging date is today.
#' @return An object of class `pkgdossier_deps`.
#' @examples
#' deps_shared()
#' deps_cran()
#' deps_snapshot("2025-06-10")
#' @name deps
NULL

#' @rdname deps
#' @export
deps_shared <- function() new_deps("shared")

#' @rdname deps
#' @export
deps_cran <- function(repos = NULL) new_deps("cran", repos = repos)

#' @rdname deps
#' @export
deps_snapshot <- function(date = NULL, repos = NULL) new_deps("snapshot", repos = repos, date = date)

new_deps <- function(mode, repos = NULL, date = NULL) {
  if (!is.null(repos) && (!is.character(repos) || length(repos) != 1L || is.na(repos) || !nzchar(repos))) {
    stop("`repos` must be one repository URL.", call. = FALSE)
  }
  if (!is.null(date)) {
    iso <- inherits(date, "Date") ||
      (is.character(date) && length(date) == 1L && grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", date))
    when <- if (iso) tryCatch(as.Date(date, format = "%Y-%m-%d"), error = function(e) as.Date(NA)) else as.Date(NA)
    if (length(when) != 1L || is.na(when)) {
      stop("`date` must be one date written year-month-day, such as \"2025-06-10\", or a Date.", call. = FALSE)
    }
    date <- as.character(when)
  }
  structure(list(mode = mode, repos = repos, date = date), class = "pkgdossier_deps")
}

#' @export
format.pkgdossier_deps <- function(x, ...) {
  from <- if (is.null(x$repos)) "" else paste0(" from ", x$repos)
  switch(x$mode,
    cran = paste0("current CRAN versions", from, ", in the work folder"),
    snapshot = paste0("CRAN as on ", x$date %||% "the baseline's release date", from, ", in the work folder"),
    "shared, from the current library paths")
}

#' @export
print.pkgdossier_deps <- function(x, ...) {
  cat("<pkgdossier deps> ", format(x), "\n", sep = "")
  invisible(x)
}


# The dependency setup of a dossier: mode, library, state file, repository and, for
# snapshots, the date. `date` is needed for "snapshot" only.
deps_ctx <- function(d, date = NULL) {
  mode <- d$deps %||% "shared"
  if (identical(mode, "shared")) return(list(mode = "shared", lib = NULL))
  # packages compiled under one R minor version are not reused under another
  r_minor <- paste0("R", R.version$major, ".", sub("\\..*$", "", R.version$minor))
  if (identical(mode, "snapshot")) {
    if (is.null(date)) stop("No snapshot date: run prepare_versions() first, or set deps_snapshot(date).", call. = FALSE)
    date <- as.character(as.Date(date))
    lib <- work_path(d, paste0("lib-deps-", date, "-", r_minor))
    repo <- snapshot_repo(date, d$deps_repos)
    # where a snapshot version that does not build under this R is taken from
    # instead: the same repository's "latest" for a dated URL, else (with no
    # repository given) the CRAN mirror
    fallback <- sub("/[0-9]{4}-[0-9]{2}-[0-9]{2}/?$", "/latest", repo)
    if (identical(fallback, repo)) fallback <- if (is.null(d$deps_repos)) cran_repo(NULL) else NULL
  } else {
    lib <- work_path(d, paste0("lib-deps-", r_minor))
    repo <- cran_repo(d$deps_repos)
    fallback <- NULL
  }
  list(mode = mode, date = date, lib = lib, repo = repo, fallback = fallback,
       state_file = paste0(lib, "-state.rds"), fallback_file = paste0(lib, "-newer.rds"))
}

# The snapshot date recorded by prepare_versions(), or the one the dossier sets.
deps_date_of <- function(d) {
  if (!identical(d$deps, "snapshot")) return(NULL)
  d$deps_date %||% read_versions(d, must_exist = FALSE)$deps$date
}

# The day the baseline was released: its Date/Publication (CRAN), else the day it
# was packaged.
snapshot_date <- function(desc) {
  when <- desc$`Date/Publication` %||% desc$Packaged
  if (is.null(when) || is.na(when)) {
    stop("Cannot tell when the baseline was released (its DESCRIPTION has no Date/Publication or ",
         "Packaged field); set the date with deps = deps_snapshot(date).", call. = FALSE)
  }
  as.character(as.Date(substr(when, 1L, 10L)))
}

# A dated snapshot of CRAN. With `repos` given (a mirror, or a local repository in
# tests) that is used as is; otherwise a Posit Package Manager URL in
# getOption("repos") keeps its form (Linux binaries included) with the date in place
# of "latest", and anything else becomes Package Manager's source snapshot.
snapshot_repo <- function(date, repos = NULL) {
  if (!is.null(repos)) return(sub("/+$", "", repos))
  r <- getOption("repos")[["CRAN"]] %||% ""
  m <- regmatches(r, regexec("^(https?://[^/]*packagemanager[^/]*/[^/]+/(__linux__/[^/]+/)?)(latest|[0-9]{4}-[0-9]{2}-[0-9]{2})/?$", r))[[1]]
  if (length(m)) paste0(m[2], date) else paste0("https://packagemanager.posit.co/cran/", date)
}

# The library paths both versions install and run against, after their own library.
shared_libpaths <- function(d, ctx = deps_ctx(d, deps_date_of(d))) {
  if (is.null(ctx$lib)) .libPaths() else c(normalizePath(ctx$lib, winslash = "/", mustWork = FALSE), .libPaths())
}

# Package -> the repository's version when it was installed into the library; NULL
# for deps = "shared".
deps_state <- function(ctx) {
  if (is.null(ctx$lib)) return(NULL)
  if (file.exists(ctx$state_file)) readRDS(ctx$state_file) else stats::setNames(character(), character())
}

r_bundled_packages <- function() {
  ip <- utils::installed.packages(lib.loc = .Library, priority = c("base", "recommended"), noCache = TRUE)
  unique(c(rownames(ip), "base", "compiler", "datasets", "grDevices", "graphics", "grid",
           "methods", "parallel", "splines", "stats", "stats4", "tcltk", "tools", "utils"))
}

ensure_deps <- function(ctx, desc, ask, quiet) {
  bundled <- r_bundled_packages()
  direct <- unique(rbind(dep_table(desc$Depends), dep_table(desc$Imports), dep_table(desc$LinkingTo))$name)
  direct <- setdiff(direct, c("R", bundled))
  if (!length(direct)) return(invisible(character()))
  repo <- ctx$repo
  where <- if (identical(ctx$mode, "snapshot")) sprintf("the snapshot of %s (%s)", ctx$date, repo) else repo
  ap <- read_index(repo, ask, quiet,
                   sprintf("to find the %s versions of the dependencies of %s %s",
                           if (identical(ctx$mode, "snapshot")) paste(ctx$date, "") else "current ",
                           desc$Package, desc$Version))
  not_there <- function(pkgs) {
    absent <- setdiff(pkgs, rownames(ap))
    if (length(absent)) {
      stop(desc$Package, " ", desc$Version, " needs ", paste(absent, collapse = ", "), ", which ", where,
           " does not have", if (identical(ctx$mode, "snapshot")) " (it may be newer than the snapshot)" else
             " (a Bioconductor or GitHub package?)",
           ". Use deps = deps_shared() with it installed.", call. = FALSE)
    }
  }
  not_there(direct)
  all <- unique(c(direct, unlist(tools::package_dependencies(direct, db = ap,
    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE), use.names = FALSE)))
  all <- setdiff(all, c("R", bundled))
  not_there(all)

  lib <- ctx$lib
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  state <- deps_state(ctx)
  want <- stats::setNames(unname(ap[all, "Version"]), all)
  have <- file.exists(file.path(lib, all, "DESCRIPTION"))
  need <- all[!have | is.na(state[all]) | state[all] != want[all]]
  if (!length(need)) return(invisible(character()))

  say(sprintf("Installing %d dependenc%s of %s %s from %s into %s: %s", length(need),
              if (length(need) == 1L) "y" else "ies", desc$Package, desc$Version, where, lib,
              paste(need, collapse = ", ")), quiet = quiet)
  if (ask && !isTRUE(utils::askYesNo(sprintf("Download and install %d package(s) from %s?", length(need), repo)))) {
    stop_pkgdossier("declined", "Download declined: the dependencies of ", desc$Package, " ", desc$Version,
                    " were not installed into the work folder. To use those in your library instead: ",
                    "dossier(..., deps = deps_shared()).")
  }
  rdeps <- tools::package_dependencies(all, db = ap, which = c("Depends", "Imports", "LinkingTo"),
                                       recursive = TRUE)
  # a package needed now that depends on one an earlier call took at its current
  # version is taken current as well, as it would have been then
  before <- names(read_newer(ctx))
  stale <- if (is.null(ctx$fallback)) character() else
    need[vapply(need, function(p) any(before %in% rdeps[[p]]), logical(1))]
  problems <- character()
  first <- setdiff(need, stale)
  if (length(first)) {
    withCallingHandlers(
      utils::install.packages(first, lib = lib, repos = repo, dependencies = FALSE, quiet = TRUE),
      warning = function(w) {
        problems <<- c(problems, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  }
  failed <- first[!file.exists(file.path(lib, first, "DESCRIPTION"))]
  newer <- character()
  if (length(failed) && !is.null(ctx$fallback)) {
    # a snapshot older than this R can hold versions that no longer build under it
    # (R removes C entry points): retry each on its own, in dependency order, in case
    # it only lacked a dependency
    for (p in dependency_order(failed, ap)) quiet_install(p, lib, repo)
    failed <- first[!file.exists(file.path(lib, first, "DESCRIPTION"))]
  }
  if ((length(failed) || length(stale)) && !is.null(ctx$fallback)) {
    # what still fails is taken at its current version, with every package of the
    # snapshot that depends on it, so that no package runs against a dependency newer
    # than any it was released with; and what those current versions need that the
    # snapshot lacks (a new dependency, a newer version) comes along
    own <- failed[vapply(failed, function(p) !any(setdiff(failed, p) %in% rdeps[[p]]), logical(1))]
    why <- character()
    why[own] <- sprintf("its %s version does not build under R %s", want[own], getRversion())
    for (p in stale) why[[p]] <- sprintf("depends on %s", paste(intersect(before, rdeps[[p]]), collapse = ", "))
    pull_dependents <- function(causes) {
      for (p in all) {
        if (is.na(why[p]) && any(causes %in% rdeps[[p]])) {
          why[[p]] <<- sprintf("depends on %s", paste(intersect(causes, rdeps[[p]]), collapse = ", "))
        }
      }
    }
    pull_dependents(own)
    now <- read_index(ctx$fallback, ask, quiet, "for the current versions")
    repeat {
      add <- current_requirements(names(why), now, all, want, need, lib, bundled)
      add <- add[is.na(why[names(add)])]
      if (!length(add)) break
      why[names(add)] <- add
      pull_dependents(names(add))
    }
    move <- names(why)
    say(sprintf("Taking the current versions of %s from %s: %s.", paste(move, collapse = ", "), ctx$fallback,
                if (length(own)) {
                  sprintf("the snapshot of %s has versions of %s that do not build under %s", ctx$date,
                          paste(own, collapse = ", "), R.version.string)
                } else "they depend on packages taken at their current version before"), quiet = quiet)
    if (ask && !isTRUE(utils::askYesNo(sprintf("Download and install the current versions of %d package(s) from %s?",
                                               length(move), ctx$fallback)))) {
      stop_pkgdossier("declined", "Download declined: without the current versions of ", paste(move, collapse = ", "),
                      " the snapshot cannot be installed under this R. Run on an R from the snapshot's time, or ",
                      "use dossier(..., deps = deps_cran()).")
    }
    for (p in dependency_order(move, now)) {
      problems <- c(problems, quiet_install(p, lib, ctx$fallback))
      if (file.exists(file.path(lib, p, "DESCRIPTION"))) {
        newer[[p]] <- sprintf("%s (%s)", utils::packageDescription(p, lib.loc = lib)$Version, why[[p]])
      }
    }
    # packages new in the current versions are recorded with their current version
    extra <- intersect(setdiff(move, all), rownames(now))
    if (length(extra)) want[extra] <- unname(now[extra, "Version"])
    need <- union(need, move)
  }
  failed <- need[!file.exists(file.path(lib, need, "DESCRIPTION"))]
  if (length(failed)) {
    stop("Could not install ", paste(failed, collapse = ", "), " into ", lib,
         if (length(problems)) paste0(":\n  ", paste(unique(problems), collapse = "\n  ")),
         if (identical(ctx$mode, "snapshot") && is.null(ctx$fallback)) {
           paste0("\nThe repository given (", repo, ") has no date in its URL, so there is no current ",
                  "counterpart to take versions that do not build from.")
         }, call. = FALSE)
  }
  state[need] <- want[need]
  saveRDS(state, ctx$state_file)
  if (length(newer)) {
    old <- read_newer(ctx)
    old[names(newer)] <- newer
    saveRDS(old, ctx$fallback_file)
  }
  invisible(need)
}

# Package -> "version (reason)" for the packages taken at their current version
# instead of the snapshot's.
read_newer <- function(ctx) {
  if (!is.null(ctx$fallback_file) && file.exists(ctx$fallback_file)) readRDS(ctx$fallback_file) else character()
}

# What the current versions of `pkgs` (in the index `now`) need that the library
# will not have: a package outside the snapshot's set `all` and not installed, or a
# newer version than the one installed or about to be (the snapshot's, for those in
# `need`). Returns package -> reason.
current_requirements <- function(pkgs, now, all, want, need, lib, bundled) {
  out <- character()
  for (p in intersect(pkgs, rownames(now))) {
    reqs <- rbind(dep_table(now[p, "Depends"]), dep_table(now[p, "Imports"]), dep_table(now[p, "LinkingTo"]))
    for (i in seq_len(nrow(reqs))) {
      q <- reqs$name[i]
      if (q %in% c("R", bundled, pkgs) || !is.na(out[q])) next
      f <- file.path(lib, q, "DESCRIPTION")
      have <- if (q %in% need || (q %in% all && !file.exists(f))) want[[q]] else
        if (file.exists(f)) read_desc(f)$Version else NA_character_
      if (is.na(have) || (nzchar(reqs$op[i]) && !version_ok(have, reqs$op[i], reqs$version[i]))) {
        out[[q]] <- sprintf("needed by %s %s", p, now[p, "Version"])
      }
    }
  }
  out
}

# The package index of a repository; available.packages() only warns when it cannot
# read one, so its warning becomes the error.
read_index <- function(repo, ask, quiet, why) {
  say("Reading the package index from ", repo, " ", why, quiet = quiet)
  # asked once per session and repository: cran_release() reads the index on every call
  if (ask && !isTRUE(consent[[repo]])) {
    if (!isTRUE(utils::askYesNo(paste0("Download the package index from ", repo, "?")))) {
      stop_pkgdossier("declined", "Download declined: the package index from ", repo, " was not read.")
    }
    consent[[repo]] <- TRUE
  }
  problems <- character()
  ap <- withCallingHandlers(
    tryCatch(utils::available.packages(contriburl = paste0(repo, "/src/contrib"), filters = list()),
             error = function(e) {
               problems <<- c(problems, conditionMessage(e))
               matrix(character(), 0L, 1L)
             }),
    warning = function(w) {
      problems <<- c(problems, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  if (!nrow(ap) && length(problems)) {
    stop_pkgdossier("offline", "Could not read the package index from ", repo, ": ", problems[1])
  }
  ap
}

# Repositories whose package index the user agreed to download in this session.
consent <- new.env(parent = emptyenv())

deps_provenance <- function(ctx) {
  if (is.null(ctx$lib)) return(list(mode = "shared"))
  newer <- read_newer(ctx)
  # the versions in the library, which for a snapshot's fallbacks differ from the
  # repository versions the state file records
  pkgs <- names(deps_state(ctx))
  installed <- vapply(pkgs, function(p) {
    f <- file.path(ctx$lib, p, "DESCRIPTION")
    if (file.exists(f)) read_desc(f)$Version else NA_character_
  }, "")
  list(mode = ctx$mode, date = ctx$date, repo = ctx$repo,
       lib = normalizePath(ctx$lib, winslash = "/", mustWork = FALSE),
       packages = as.list(installed), newer_than_snapshot = as.list(newer),
       r_version = as.character(getRversion()), r_series = r_series(),
       r_series_began = as.character(r_series_began()),
       older_than_r = identical(ctx$mode, "snapshot") && as.Date(ctx$date) < r_series_began())
}

# The day this R was released.
r_release_date <- function() {
  as.Date(sprintf("%s-%s-%s", R.version$year, R.version$month, R.version$day))
}

r_series <- function(version = getRversion()) paste(unlist(version)[1:2], collapse = ".")

# The day this R's minor series (x.y.0) was released: R removes C entry points at
# minor releases, so a snapshot from before it can hold packages that no longer
# build or misbehave. Known dates, else April of the series' year (minor releases
# come each spring); an x.y.0 (or R-devel) is its own date.
r_series_began <- function(version = getRversion(), released = r_release_date()) {
  known <- c("4.0" = "2020-04-24", "4.1" = "2021-05-18", "4.2" = "2022-04-22", "4.3" = "2023-04-21",
             "4.4" = "2024-04-24", "4.5" = "2025-04-11")
  series <- r_series(version)
  if (series %in% names(known)) return(as.Date(known[[series]]))
  parts <- unlist(version)
  if (length(parts) < 3L || parts[3] == 0L) return(released)
  year <- as.integer(format(released, "%Y"))
  if (as.integer(format(released, "%m")) < 4L) year <- year - 1L
  as.Date(sprintf("%d-04-01", year))
}

# For a snapshot older than the R running it: compiled packages from it may fail
# to build (taken current then) or build and misbehave, which nothing here can tell.
snapshot_caveat <- function(deps) {
  if (!isTRUE(deps$older_than_r)) return(NULL)
  sprintf(paste("The dependency snapshot of %s is older than the R %s series running it (from %s): compiled",
                "packages from it may misbehave under this R, crashes included. For a faithful snapshot,",
                "compare on an R from the baseline's time."),
          deps$date, deps$r_series %||% deps$r_version, deps$r_series_began %||% deps$r_released)
}

# One package, its warnings returned rather than shown.
quiet_install <- function(p, lib, repo) {
  problems <- character()
  withCallingHandlers(
    tryCatch(utils::install.packages(p, lib = lib, repos = repo, dependencies = FALSE, quiet = TRUE),
             error = function(e) problems <<- c(problems, conditionMessage(e))),
    warning = function(w) {
      problems <<- c(problems, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  problems
}

# `pkgs` with each after those of the others it depends on.
dependency_order <- function(pkgs, ap) {
  needs <- tools::package_dependencies(pkgs, db = ap, which = c("Depends", "Imports", "LinkingTo"))
  out <- character()
  left <- pkgs
  while (length(left)) {
    ready <- left[vapply(left, function(p) !any(setdiff(needs[[p]] %||% character(), p) %in% left), logical(1))]
    if (!length(ready)) ready <- left[1L]  # a cycle: break it anywhere
    out <- c(out, ready)
    left <- setdiff(left, ready)
  }
  out
}
