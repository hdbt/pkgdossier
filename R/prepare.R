#' Fetch, build and install both versions
#'
#' Installs the baseline and the candidate into their own libraries in the work
#' folder (`lib-base`, `lib-cand`), byte-compiled from source tarballs as users get
#' them, and records their provenance in `versions.json`: the tarball's sha256, its
#' `Packaged`, `Repository` and `Date/Publication` fields, the git commit, and
#' optionally whether the baseline's `R/` matches a release tag.
#'
#' CRAN sources are downloaded here and nowhere else; the function says what it
#' downloads and where first, and asks when `ask` is `TRUE`. Git sources are exported
#' with `git archive` and built with `R CMD build` inside the work folder.
#'
#' A version whose source has not changed since the last call (same tarball checksum,
#' same commit, same folder contents, or the same CRAN version) is not reinstalled
#' unless `force = TRUE`, so re-running after a fix rebuilds only the candidate. For
#' [cran_release()] every call reads CRAN's package index to find the current
#' version, so a new release is picked up; if the index cannot be read, an installed
#' copy is reused and the function says so.
#'
#' @param d A [dossier()].
#' @param force Reinstall both versions even when they look unchanged.
#' @param ask Ask before downloading from CRAN.
#' @param quiet Suppress progress messages.
#' @return The provenance of both versions, invisibly (a list with elements `base`
#'   and `cand`).
#' @examples
#' \donttest{
#' d <- example_dossier()
#' vers <- prepare_versions(d)
#' vers$cand$version
#' }
#' @export
prepare_versions <- function(d, force = FALSE, ask = interactive(), quiet = FALSE) {
  stopifnot(inherits(d, "pkgdossier_dossier"))
  preflight(d)
  # the installed version becomes the CRAN version it is, before anything is fetched
  base_installed <- identical(d$base$type, "installed")
  d$base <- resolve_installed(d, d$base, "base", quiet)
  d$candidate <- resolve_installed(d, d$candidate, "cand", quiet)
  if (base_installed) check_something_to_compare(d, ask, quiet)
  dir.create(d$work, recursive = TRUE, showWarnings = FALSE)
  old <- read_versions(d, must_exist = FALSE)
  # with deps = "snapshot" the baseline sets the date (unless deps_date does), and
  # the candidate uses the same snapshot
  base <- prepare_one(d, "base", d$base, old$base, force, ask, quiet, deps_date = d$deps_date)
  vers <- list(
    base = base,
    cand = prepare_one(d, "cand", d$candidate, old$cand, force, ask, quiet,
                       deps_date = d$deps_date %||% base$deps_date)
  )
  if (identical(vers$base$version, vers$cand$version)) {
    warning("Baseline and candidate have the same version number (", vers$base$version,
            "); the report labels them by role.", call. = FALSE)
  }
  vers$base$tag_check <- baseline_tag_check(d, vers$base)
  vers$cand$commits_since_tag <- commits_since_tag(d, vers$cand)
  vers$deps <- deps_provenance(deps_ctx(d, d$deps_date %||% vers$base$deps_date))
  write_rds_atomic(vers, work_path(d, "versions.rds"))
  jsonlite::write_json(vers, work_path(d, "versions.json"), auto_unbox = TRUE,
                       pretty = TRUE, null = "null", na = "null")
  for (v in vers[c("base", "cand")]) {
    say(sprintf("%-4s %s %s  sha256 %s  packaged %s", v$role, d$pkg, v$version,
                substr(v$sha256, 1, 12), v$packaged %||% "?"), quiet = quiet)
  }
  if (!is.null(vers$base$tag_check)) say("     ", vers$base$tag_check, quiet = quiet)
  if (identical(vers$deps$mode, "cran")) {
    say(sprintf("deps %d package(s) at their current versions from %s", length(vers$deps$packages),
                vers$deps$repo), quiet = quiet)
  } else if (identical(vers$deps$mode, "snapshot")) {
    say(sprintf("deps %d package(s) as on %s, from %s", length(vers$deps$packages), vers$deps$date,
                vers$deps$repo), quiet = quiet)
    caveat <- snapshot_caveat(vers$deps)
    if (!is.null(caveat)) warning(caveat, call. = FALSE)
    newer <- unlist(vers$deps$newer_than_snapshot)
    if (length(newer)) {
      say(sprintf("     newer than the snapshot: %s", paste(sprintf("%s %s", names(newer), newer), collapse = "; ")),
          quiet = quiet)
    }
  }
  invisible(vers)
}

# What can be checked about folder sources before anything is downloaded: each holds
# the package, the work folder is not built with it, and (with deps_shared()) its
# dependencies are installed.
preflight <- function(d) {
  for (role in c("base", "cand")) {
    src <- if (role == "base") d$base else d$candidate
    if (!identical(src$type, "local")) next
    what <- if (role == "base") "baseline" else "candidate"
    if (!dir.exists(src$path)) stop_pkgdossier("not_package", "The ", what, " folder ", src$path, " does not exist.")
    p <- package_in(src$path)
    if (is.null(p)) {
      stop_pkgdossier("not_package", "The ", what, " folder ", src$path,
                      " is not a package: it has no DESCRIPTION with a Package field.")
    }
    if (!identical(p, d$pkg)) {
      stop_pkgdossier("not_package", "The ", what, " folder ", src$path, " holds the package ", p, ", not ",
                      d$pkg, ".")
    }
    check_work_outside(d, src$path, role)
    if (identical(d$deps %||% "shared", "shared")) {
      check_deps(read_desc(file.path(src$path, "DESCRIPTION")), role, alt = TRUE)
    }
  }
  invisible()
}

# installed_version() as the CRAN version installed: read from the library's
# DESCRIPTION. A version that did not come from CRAN has no CRAN source to build.
resolve_installed <- function(d, src, role, quiet = FALSE) {
  if (!identical(src$type, "installed")) return(src)
  what <- if (role == "base") "baseline" else "candidate"
  arg <- if (role == "base") "base" else "candidate"
  lib <- src$lib %||% .libPaths()
  f <- system.file("DESCRIPTION", package = d$pkg, lib.loc = lib)
  if (!nzchar(f)) {
    stop_pkgdossier("not_installed", d$pkg, " is not installed (in ", paste(lib, collapse = ", "),
                    "), so there is no installed version to use as the ", what, ". Name a version instead: ",
                    arg, " = cran_version(\"x.y.z\").")
  }
  desc <- read_desc(f)
  v <- desc$Version
  remote <- desc$RemoteType %||% "standard"
  repository <- desc$Repository %||% ""
  if (!remote %in% c("standard", "cran") || !(repository %in% c("CRAN", "RSPM", "") ||
      grepl("^https?://(cloud\\.r-project\\.org|cran\\.|packagemanager\\.)", repository))) {
    from <- if (!identical(remote, "standard")) {
      paste0(remote, if (!is.null(desc$RemoteUsername) && !is.null(desc$RemoteRepo))
        paste0(" (", desc$RemoteUsername, "/", desc$RemoteRepo, ")"))
    } else repository
    sha <- desc$RemoteSha
    stop_pkgdossier("not_on_repo", "The installed ", d$pkg, " ", v, " came from ", from, ", not from CRAN, so ",
                    "CRAN has no source for it. Name the ", what, " in dossier():",
                    if (!is.null(sha)) sprintf("\n  that commit, from a clone of its repository: %s = git_ref(\"path/to/%s\", \"%s\")",
                                               arg, d$pkg, substr(sha, 1L, 12L)),
                    sprintf("\n  a CRAN release: %s = cran_version(\"x.y.z\")", arg))
  }
  say(role, ": the installed ", d$pkg, " is ", v, " (", dirname(dirname(f)), "); its CRAN source is used",
      quiet = quiet)
  cran_version(v, repos = src$repos)
}

# The installed version compared with the current release: nothing to compare when
# they are the same.
check_something_to_compare <- function(d, ask, quiet) {
  b <- d$base
  cnd <- d$candidate
  if (identical(cnd$type, "cran") && is.null(cnd$version)) {
    now <- cran_current_version(d$pkg, cran_repo(cnd$repos, source = TRUE), ask, quiet)
    if (identical(now, b$version)) {
      stop_pkgdossier("nothing_to_compare", "The installed ", d$pkg, " ", b$version, " is the current CRAN ",
                      "release: there is nothing to upgrade to, so nothing to compare. To see what changed ",
                      "since an earlier release: base = cran_version(\"x.y.z\").")
    }
  }
  invisible()
}

read_versions <- function(d, must_exist = TRUE) {
  f <- work_path(d, "versions.rds")
  if (!file.exists(f)) {
    if (must_exist) stop("No installed versions in ", d$work, "; run prepare_versions() first.", call. = FALSE)
    return(NULL)
  }
  readRDS(f)
}

prepare_one <- function(d, role, src, old, force, ask, quiet, deps_date = NULL) {
  srcdir <- work_path(d, "src", role)
  lib <- work_path(d, paste0("lib-", role))
  dir.create(srcdir, recursive = TRUE, showWarnings = FALSE)
  installed <- file.exists(file.path(lib, d$pkg, "DESCRIPTION"))

  if (identical(src$type, "local")) check_work_outside(d, src$path, role)
  # A cheap identity first, so an unchanged source is not rebuilt or reinstalled.
  identity <- switch(src$type,
    git = paste0("git:", git_commit(src$repo, src$ref), ":", src$subdir %||% ""),
    tarball = paste0("sha256:", sha256_file(normalizePath(src$path, mustWork = TRUE))),
    local = dir_identity(src$path, skip = d$work),
    cran = cran_identity(d$pkg, src, old, installed, ask, quiet, d = d, role = role)
  )
  # an install made from a binary tarball (before binaries were refused) is not reused
  was_binary <- !is.null(old$unpacked) && file.exists(file.path(old$unpacked, "DESCRIPTION")) &&
    !is.null(read_desc(file.path(old$unpacked, "DESCRIPTION"))$Built)
  if (!force && installed && !is.null(old) && identical(old$identity, identity) && !was_binary) {
    # the same source: reused when it was built against the same R and dependency
    # setup, LinkingTo headers included (bring the dependencies up to date first)
    old_desc <- read_desc(file.path(old$unpacked, "DESCRIPTION"))
    date <- if (identical(d$deps, "snapshot")) deps_date %||% snapshot_date(old_desc)
    ctx <- deps_ctx(d, date)
    if (!identical(d$deps, "shared")) ensure_deps(ctx, old_desc, ask, quiet)
    if (identical(old$setup, install_setup(d, date, old_desc, ctx))) {
      say(role, ": ", format(src), " unchanged, reusing the installed copy", quiet = quiet)
      old$deps_date <- date
      return(old)
    }
    say(role, ": ", format(src), " unchanged, but R or the dependencies it is built against changed; ",
        "installing it again", quiet = quiet)
  }

  info <- list()
  tb <- switch(src$type,
    cran = {
      dl <- download_cran(d$pkg, sub("^cran:", "", identity), cran_repo(src$repos, source = TRUE),
                          srcdir, ask, quiet)
      info$url <- dl$url
      dl$path
    },
    tarball = {
      dest <- file.path(srcdir, basename(src$path))
      if (normalizePath(src$path, mustWork = TRUE) != normalizePath(dest, mustWork = FALSE)) {
        file.copy(src$path, dest, overwrite = TRUE)
      }
      dest
    },
    git = {
      say(role, ": exporting ", src$ref, " from ", src$repo, " with git archive", quiet = quiet)
      exported <- export_git(src$repo, src$ref, src$subdir, file.path(srcdir, "export"))
      info$commit <- git_commit(src$repo, src$ref)
      info$ref <- src$ref
      say(role, ": R CMD build", quiet = quiet)
      build_tarball(exported, file.path(srcdir, "build"), d$pkg, d$language)
    },
    local = {
      say(role, ": R CMD build ", src$path, quiet = quiet)
      build_tarball(normalizePath(src$path, mustWork = TRUE), file.path(srcdir, "build"),
                    d$pkg, d$language)
    }
  )

  unpacked <- file.path(srcdir, "unpacked")
  unlink(unpacked, recursive = TRUE)
  utils::untar(tb, exdir = unpacked)
  desc_file <- file.path(unpacked, d$pkg, "DESCRIPTION")
  if (!file.exists(desc_file)) {
    stop("The ", role, " tarball ", basename(tb), " does not hold package ", d$pkg, ".", call. = FALSE)
  }
  desc <- read_desc(desc_file)
  if (!is.null(desc$Built)) {
    stop("The ", role, " tarball ", basename(tb), " is a binary package (built for ", desc$Built,
         "), not a source tarball. Both versions must be built from source; ",
         if (src$type == "cran") "use a repository that serves sources (repos = \"https://cloud.r-project.org\")."
         else "use the source tarball (R CMD build), not an installed or binary build.",
         call. = FALSE)
  }
  if (identical(d$deps, "snapshot")) info$deps_date <- deps_date %||% snapshot_date(desc)
  ctx <- deps_ctx(d, info$deps_date)
  if (!identical(d$deps, "shared")) ensure_deps(ctx, desc, ask, quiet)
  # the snapshot's advice only where a package from the snapshot falls short
  check_deps(desc, role, lib_paths = shared_libpaths(d, ctx), alt = identical(d$deps %||% "shared", "shared"),
             hint_for = if (identical(d$deps, "snapshot")) {
               from_snapshot <- names(deps_state(ctx))
               function(pkgs) if (any(pkgs %in% from_snapshot)) {
                 sprintf("\nThe snapshot of %s has older versions; use a later deps_snapshot(date), or deps_cran() or deps_shared().",
                         ctx$date)
               }
             })
  setup <- install_setup(d, info$deps_date, desc, ctx)

  say(role, ": R CMD INSTALL ", basename(tb), " into ", lib, quiet = quiet)
  unlink(lib, recursive = TRUE)
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  rcmd_or_stop("INSTALL", c(paste0("--library=", lib), tb), wd = srcdir,
               language = d$language, log = file.path(srcdir, "install.log"),
               libpath = shared_libpaths(d, ctx))

  c(list(
    role = role, source = format(src), type = src$type, identity = identity, setup = setup,
    tarball = normalizePath(tb, winslash = "/"), sha256 = sha256_file(tb),
    version = desc$Version, packaged = desc$Packaged, repository = desc$Repository,
    publication = desc$`Date/Publication`, lib = normalizePath(lib, winslash = "/"),
    unpacked = normalizePath(file.path(unpacked, d$pkg), winslash = "/"),
    prepared = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  ), info)
}

# With deps = "shared" both versions install against the library paths of this
# session. A dependency that is missing there, or older than a version requires, is
# reported here, all at once, instead of as the tail of R CMD INSTALL's output.
check_deps <- function(desc, role, lib_paths = .libPaths(), hint_for = NULL, alt = FALSE) {
  base_pkgs <- c("base", "compiler", "datasets", "grDevices", "graphics", "grid", "methods",
                 "parallel", "splines", "stats", "stats4", "tcltk", "tools", "utils")
  deps <- rbind(dep_table(desc$Depends), dep_table(desc$Imports), dep_table(desc$LinkingTo))
  problems <- character()
  missing_pkgs <- character()
  for (i in seq_len(nrow(deps))) {
    p <- deps$name[i]
    op <- deps$op[i]
    need <- deps$version[i]
    if (p == "R") {
      if (nzchar(op) && !version_ok(as.character(getRversion()), op, need)) {
        problems <- c(problems, sprintf("R (%s %s): this is R %s", op, need, getRversion()))
      }
      next
    }
    if (p %in% base_pkgs) next
    have <- tryCatch(as.character(utils::packageVersion(p, lib.loc = lib_paths)),
                     error = function(e) NA_character_)
    if (is.na(have)) {
      problems <- c(problems, sprintf("%s: not installed", p))
      missing_pkgs <- c(missing_pkgs, p)
    } else if (nzchar(op) && !version_ok(have, op, need)) {
      problems <- c(problems, sprintf("%s (%s %s): installed %s", p, op, need, have))
      missing_pkgs <- c(missing_pkgs, p)
    }
  }
  problems <- unique(problems)
  if (!length(problems)) return(invisible(TRUE))
  hint <- if (!is.null(hint_for)) hint_for(missing_pkgs)
  hint <- if (!is.null(hint)) hint else if (length(missing_pkgs)) {
    paste0(sprintf("\nInstall or update them first, for example with\n  install.packages(c(%s))",
                   paste0("\"", unique(missing_pkgs), "\"", collapse = ", ")),
           if (alt) paste0("\nor let pkgdossier install CRAN's current versions into the work folder ",
                           "(your library is not touched): dossier(..., deps = deps_cran())"))
  } else ""
  stop(sprintf("The %s (%s %s) needs what the library paths both versions use do not have:\n  %s%s",
               if (role == "base") "baseline" else "candidate", desc$Package, desc$Version,
               paste(problems, collapse = "\n  "), hint), call. = FALSE)
}

# A DESCRIPTION dependency field as a data frame of name, operator and version.
dep_table <- function(field) {
  empty <- data.frame(name = character(), op = character(), version = character(),
                      stringsAsFactors = FALSE)
  if (is.null(field) || is.na(field) || !nzchar(trimws(field))) return(empty)
  parts <- trimws(strsplit(gsub("\\s+", " ", field), ",", fixed = TRUE)[[1]])
  parts <- parts[nzchar(parts)]
  m <- regmatches(parts, regexec("^([A-Za-z][A-Za-z0-9.]*)\\s*(\\(\\s*([<>=!]+)\\s*([^) ]+)\\s*\\))?", parts))
  m <- m[lengths(m) > 0L]
  if (!length(m)) return(empty)
  data.frame(name = vapply(m, `[`, "", 2L), op = vapply(m, `[`, "", 4L),
             version = vapply(m, `[`, "", 5L), stringsAsFactors = FALSE)
}

version_ok <- function(have, op, need) {
  ok <- tryCatch(do.call(op, list(package_version(have), package_version(need))),
                 error = function(e) TRUE)
  isTRUE(ok)
}

# The repository to read: `repos`, or the CRAN entry of getOption("repos"), or the
# cloud mirror. With `source = TRUE` (for the package under comparison), a Posit
# Package Manager URL that serves Linux binaries under src/contrib
# (".../cran/__linux__/noble/latest") becomes its source URL (".../cran/latest"):
# both versions must be built from source, the same way.
cran_repo <- function(repos, source = FALSE) {
  r <- repos %||% getOption("repos")[["CRAN"]]
  if (is.null(r) || is.na(r) || identical(r, "@CRAN@")) r <- "https://cloud.r-project.org"
  r <- sub("/+$", "", r)
  if (source) r <- sub("/__linux__/[^/]+/", "/", r)
  r
}

# "cran:<version>". For cran_release() the version comes from the package index, read
# on every call so that a new release is noticed. When the index cannot be read (no
# network, or the user declined) and a copy of the same source is installed, that
# copy's identity is returned, so it is reused.
cran_identity <- function(pkg, src, old, installed, ask, quiet, d = NULL, role = "base") {
  if (!is.null(src$version)) return(paste0("cran:", src$version))
  repo <- cran_repo(src$repos, source = TRUE)
  reusable <- installed && !is.null(old) && identical(old$source, format(src))
  v <- tryCatch(cran_current_version(pkg, repo, ask, quiet), error = function(e) {
    if (!reusable) {
      what <- if (role == "base") "baseline" else "candidate"
      if (inherits(e, "pkgdossier_error_not_on_repo")) {
        stop_pkgdossier("not_on_repo", pkg, " is not on ", repo, ", so there is no release of it to use as the ",
                        what, ". Name the ", what, " in dossier():", source_suggestions(d, role))
      }
      if (inherits(e, "pkgdossier_error_offline")) {
        stop_pkgdossier("offline", conditionMessage(e), ". So ", pkg, "'s release can be neither found nor ",
                        "downloaded, and the work folder has no copy from an earlier call. Offline, use a ",
                        "tarball you have: dossier(\"", pkg, "\", ", if (role == "base") "base" else "candidate",
                        " = tarball(\"path/to/", pkg, "_x.y.z.tar.gz\")).")
      }
      stop(e)
    }
    say(sub("[.]?$", "", conditionMessage(e)), "; reusing the installed ", pkg, " ", old$version, quiet = quiet)
    NULL
  })
  if (is.null(v)) old$identity else paste0("cran:", v)
}

cran_current_version <- function(pkg, repo, ask, quiet) {
  ap <- read_index(repo, ask, quiet, paste("to find the current version of", pkg))
  if (!pkg %in% rownames(ap)) stop_pkgdossier("not_on_repo", pkg, " is not on ", repo, ".")
  unname(ap[pkg, "Version"])
}

# What to write instead of a CRAN release that does not exist: a tag of the
# candidate's repository (the newest three are named), a tarball, an archived
# version. Nothing is chosen: a tag is not necessarily what users have.
source_suggestions <- function(d, role = "base") {
  arg <- if (role == "base") "base" else "candidate"
  pkg <- d$pkg %||% "mypkg"
  out <- character()
  repo <- d$repo
  if (!is.null(repo) && git_available()) {
    tags <- git(repo, "tag", "--list", "--sort=-v:refname", stop_on_error = FALSE)
    tags <- utils::head(tags[nzchar(tags)], 3L)
    if (length(tags)) {
      # a git_ref() candidate in a subfolder of its repository keeps that subfolder
      sub_arg <- if (identical(d$candidate$type, "git") && !is.null(d$candidate$subdir) &&
                     identical(repo, d$candidate$repo)) sprintf(", subdir = \"%s\"", d$candidate$subdir) else ""
      out <- c(out, sprintf("a tag of %s (the newest: %s): %s = git_ref(\"%s\", \"%s\"%s)", repo,
                            paste(tags, collapse = ", "), arg, repo, tags[1], sub_arg))
    }
  }
  out <- c(out, sprintf("a source tarball you have: %s = tarball(\"path/to/%s_x.y.z.tar.gz\")", arg, pkg),
           sprintf("a version in the CRAN archive: %s = cran_version(\"x.y.z\")", arg))
  paste0("\n  ", out, collapse = "")
}

download_cran <- function(pkg, version, repo, dest_dir, ask, quiet) {
  file <- paste0(pkg, "_", version, ".tar.gz")
  dest <- file.path(dest_dir, file)
  urls <- c(paste0(repo, "/src/contrib/", file), paste0(repo, "/src/contrib/Archive/", pkg, "/", file))
  say("Downloading ", file, " from ", urls[1], " (or the CRAN archive) into ", dest_dir, quiet = quiet)
  if (ask && !isTRUE(utils::askYesNo(paste0("Download ", file, " from ", repo, "?")))) {
    stop_pkgdossier("declined", "Download declined: without ", file, " there is no ", pkg, " ", version,
                    " to compare. To use a tarball you have instead: tarball(\"path/to/", file, "\").")
  }
  for (url in urls) {
    ok <- tryCatch(utils::download.file(url, dest, mode = "wb", quiet = TRUE) == 0L,
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && file.exists(dest) && file.size(dest) > 0) return(list(path = dest, url = url, version = version))
  }
  unlink(dest)
  stop("Could not download ", file, " from ", repo, ".", call. = FALSE)
}

# Quoted: a git built on MSYS2 (as on CRAN's Windows machines) expands braces in an
# unquoted argument, and would receive HEAD^{commit} as HEAD^commit.
git_commit <- function(repo, ref) {
  git(repo, "rev-parse", "--verify", shQuote(paste0(ref, "^{commit}")))[1]
}

export_git <- function(repo, ref, subdir, dest) {
  unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE)
  tarfile <- normalizePath(paste0(dest, ".tar"), winslash = "/", mustWork = FALSE)
  treeish <- if (is.null(subdir)) ref else paste0(ref, ":", subdir)
  # a file, not a pipe: binary output through some shells' pipes is mangled
  git(repo, "archive", "--format=tar", paste0("--output=", shQuote(tarfile)), treeish)
  utils::untar(tarfile, exdir = dest)
  unlink(tarfile)
  dest
}

build_tarball <- function(srcdir, outdir, pkg, language) {
  unlink(outdir, recursive = TRUE)
  dir.create(outdir, recursive = TRUE)
  rcmd_or_stop("build", c("--no-build-vignettes", "--no-manual", srcdir), wd = outdir,
               language = language, log = file.path(dirname(outdir), "build.log"))
  tb <- list.files(outdir, pattern = paste0("^", pkg, "_.*\\.tar\\.gz$"), full.names = TRUE)
  if (length(tb) != 1L) stop("R CMD build did not produce one ", pkg, " tarball in ", outdir, call. = FALSE)
  tb
}

# The contents of a package folder as R CMD build sees them: files its .Rbuildignore
# excludes, and the work folder when it lies inside, do not count.
dir_identity <- function(path, skip = NULL) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  rel <- list.files(path, recursive = TRUE)
  rel <- rel[!build_ignored(rel, path)]
  inside <- if (is.null(skip)) NULL else path_within(skip, path)
  if (!is.null(inside)) rel <- rel[!(rel == inside | startsWith(rel, paste0(inside, "/")))]
  md5 <- tools::md5sum(file.path(path, rel))
  paste0("local:", digest::digest(paste(rel, md5), algo = "sha256"))
}

# Which of these paths (relative to the package folder) .Rbuildignore excludes: its
# lines are Perl regular expressions, matched without regard to case against a file's
# path and the paths of the folders above it.
build_ignored <- function(rel, path) {
  f <- file.path(path, ".Rbuildignore")
  if (!length(rel) || !file.exists(f)) return(logical(length(rel)))
  pats <- readLines(f, warn = FALSE)
  pats <- pats[nzchar(trimws(pats))]
  if (!length(pats)) return(logical(length(rel)))
  vapply(rel, function(r) {
    parts <- strsplit(r, "/", fixed = TRUE)[[1]]
    prefixes <- vapply(seq_along(parts), function(k) paste(parts[seq_len(k)], collapse = "/"), "")
    any(vapply(pats, function(p) {
      any(tryCatch(grepl(p, prefixes, perl = TRUE, ignore.case = TRUE), error = function(e) FALSE))
    }, logical(1)))
  }, logical(1), USE.NAMES = FALSE)
}

# `child` relative to `parent` ("" for the folder itself), or NULL when it is not inside.
# On Windows the comparison ignores case; the part returned keeps the child's case.
path_within <- function(child, parent) {
  norm <- function(p) sub("/+$", "", absolute_path(p))
  ch <- norm(child)
  pa <- norm(parent)
  same_case <- if (.Platform$OS.type == "windows") tolower else identity
  if (identical(same_case(ch), same_case(pa))) return("")
  if (startsWith(same_case(ch), paste0(same_case(pa), "/"))) substring(ch, nchar(pa) + 2L) else NULL
}

# R CMD build of a folder copies everything .Rbuildignore does not exclude: a work
# folder inside it (libraries, runs) would go into every build.
check_work_outside <- function(d, path, role) {
  inside <- path_within(d$work, path)
  if (is.null(inside)) return(invisible())
  if (!nzchar(inside) || !build_ignored(inside, path)) {
    stop("The work folder ", d$work, " is inside the ", if (role == "base") "baseline" else "candidate",
         "'s folder ", path, ", and ",
         if (nzchar(inside)) paste0("its .Rbuildignore does not exclude it, so R CMD build would copy ",
                                    "the work folder into the build. Add ^",
                                    gsub("([][.+?(){}|^$*\\\\])", "\\\\\\1", inside, perl = TRUE),
                                    "$ to .Rbuildignore, or use a work folder outside the package.")
         else "R CMD build would copy the work folder into the build. Use a work folder outside the package.",
         call. = FALSE)
  }
  invisible()
}

# R, the dependency setup and the versions of the LinkingTo packages (whose headers
# are compiled in) a version is installed against.
install_setup <- function(d, deps_date, desc, ctx) {
  linking <- dep_table(desc$LinkingTo)$name
  libs <- shared_libpaths(d, ctx)
  versions <- vapply(linking, function(p) {
    tryCatch(as.character(utils::packageVersion(p, lib.loc = libs)), error = function(e) NA_character_)
  }, "")
  paste(R.version.string, R.version$platform, d$deps %||% "shared",
        if (identical(d$deps, "snapshot")) deps_date %||% "" else "", d$deps_repos %||% "",
        paste(linking, versions, collapse = ","), sep = "|")
}

# Is the baseline tarball's R/ the tagged release? Carriage returns are stripped:
# a tarball built on Windows and a git export differ in line endings only.
baseline_tag_check <- function(d, base) {
  if (is.null(d$base_tag) || is.null(d$repo)) return(NULL)
  subdir <- if (d$candidate$type == "git") d$candidate$subdir else NULL
  tmp <- tempfile("tagcheck")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  tagged <- tryCatch(export_git(d$repo, d$base_tag, subdir, tmp), error = function(e) NULL)
  if (is.null(tagged)) return(sprintf("could not export tag %s from %s", d$base_tag, d$repo))
  a <- file.path(base$unpacked, "R")
  b <- file.path(tagged, "R")
  fa <- list.files(a)
  fb <- list.files(b)
  rd <- function(f) sub("\r$", "", readLines(f, warn = FALSE))
  common <- intersect(fa, fb)
  differ <- c(setdiff(union(fa, fb), common),
              Filter(function(f) !identical(rd(file.path(a, f)), rd(file.path(b, f))), common))
  if (length(differ)) {
    sprintf("R/ differs from %s in %d file(s): %s", d$base_tag, length(differ),
            paste(utils::head(differ, 5L), collapse = ", "))
  } else {
    sprintf("R/ identical to %s (line endings aside)", d$base_tag)
  }
}

# For a folder candidate, the commits up to its work tree's HEAD.
commits_since_tag <- function(d, cand) {
  upto <- cand$commit %||% if (identical(d$candidate$type, "local")) "HEAD"
  if (is.null(d$base_tag) || is.null(d$repo) || is.null(upto)) return(NULL)
  n <- git(d$repo, "rev-list", "--count", paste0(d$base_tag, "..", upto), stop_on_error = FALSE)
  if (is.null(n)) NULL else sprintf("%s commits after %s", n[1], d$base_tag)
}
