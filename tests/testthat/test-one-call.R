# One call from a package folder: what run_dossier() infers, what it refuses before
# anything is downloaded, and what it says.

copy_fixture <- function(which = "udfixture-cand") {
  root <- tempfile("ud-onecall-")
  dir.create(root)
  file.copy(test_path("fixtures", which), root, recursive = TRUE)
  file.path(root, which)
}

test_that("run_dossier() from a package folder is run_dossier(dossier(<Package>))", {
  pkg_dir <- copy_fixture()
  here <- withr::with_dir(pkg_dir, pkgdossier:::dossier_here())
  expect_identical(here, withr::with_dir(pkg_dir, dossier("udfixture")))
  expect_equal(here$candidate$path, normalizePath(pkg_dir, winslash = "/"))
  expect_equal(here$base$type, "cran")
})

test_that("run_dossier() with no arguments runs to the end from a package folder", {
  skip_on_cran()
  # the "CRAN" the release comes from: a local repository holding udfixture 1.0.0
  root <- tempfile("ud-onecall-cran-")
  contrib <- file.path(root, "src", "contrib")
  dir.create(contrib, recursive = TRUE)
  file.copy(system.file("extdata", "udfixture_1.0.0.tar.gz", package = "pkgdossier", mustWork = TRUE), contrib)
  tools::write_PACKAGES(contrib, type = "source")
  p <- normalizePath(root, winslash = "/")
  url <- if (startsWith(p, "/")) paste0("file://", p) else paste0("file:///", p)
  pkg_dir <- copy_fixture()
  unlink(file.path(tempdir(), "pkgdossier-udfixture"), recursive = TRUE)
  withr::local_options(repos = c(CRAN = url))
  msgs <- capture_messages(cmp <- withr::with_dir(pkg_dir, run_dossier(ask = FALSE, open = FALSE)))
  expect_s3_class(cmp, "pkgdossier_comparison")
  expect_identical(cmp$dossier, withr::with_dir(pkg_dir, dossier("udfixture")))
  expect_equal(c(cmp$meta$labels$base, cmp$meta$labels$cand), c("1.0.0", "1.1.0"))
  expect_true(any(grepl("run_dossier() here is run_dossier(dossier(\"udfixture\"))", msgs, fixed = TRUE)))
  expect_true(any(grepl("After a change, call run_dossier() again", msgs, fixed = TRUE)))
  expect_true(file.exists(file.path(cmp$dossier$work, "page", "dossier.html")))
  expect_true(nrow(differences(cmp)) > 0)
  # a second call reuses everything
  msgs <- capture_messages(withr::with_dir(pkg_dir, run_dossier(ask = FALSE, open = FALSE)))
  expect_true(any(grepl("unchanged, reusing the installed copy", msgs, fixed = TRUE)))
  expect_false(any(grepl("done in", msgs, fixed = TRUE)))
})

test_that("outside a package it stops before anything is read, naming the package nearby", {
  empty <- tempfile("ud-not-a-pkg-")
  dir.create(empty)
  err <- tryCatch(withr::with_dir(empty, run_dossier(ask = FALSE)), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_not_package")
  expect_match(conditionMessage(err), "has no DESCRIPTION")

  # a package below the working directory is named
  parent <- dirname(copy_fixture())
  err <- tryCatch(withr::with_dir(parent, run_dossier(ask = FALSE)), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_not_package")
  expect_match(conditionMessage(err), "holds the package udfixture", fixed = TRUE)

  # and one around it
  inside <- file.path(copy_fixture(), "R")
  err <- tryCatch(withr::with_dir(inside, run_dossier(ask = FALSE)), error = function(e) e)
  expect_match(conditionMessage(err), "It is inside the package udfixture at", fixed = TRUE)

  # a project's DESCRIPTION is not a package's
  proj <- tempfile("ud-project-")
  dir.create(proj)
  writeLines(c("Type: Project", "Title: An analysis"), file.path(proj, "DESCRIPTION"))
  expect_error(withr::with_dir(proj, run_dossier(ask = FALSE)), "without a Package field",
               class = "pkgdossier_error_not_package")
})

test_that("a setting in the wrong place, or a string, gets the call to write instead", {
  pkg_dir <- copy_fixture()
  withr::with_dir(pkg_dir, {
    expect_error(run_dossier(reps = 0), 'run_dossier(dossier("udfixture", reps = 0))', fixed = TRUE)
    expect_error(run_dossier(base = cran_version("1.0.0")),
                 'run_dossier(dossier("udfixture", base = cran_version("1.0.0")))', fixed = TRUE)
    expect_error(run_dossier(step_timout = 9), "did you mean `step_timeout`?", fixed = TRUE)
    # several settings in one call, keeping the others given
    expect_error(run_dossier(reps = 0, seed = 1L, workers = 2, tol = 1e-3),
                 '`reps` and `seed` are set in dossier(): run_dossier(dossier("udfixture", reps = 0, seed = 1L), workers = 2, tol = 0.001)',
                 fixed = TRUE)
    expect_error(run_dossier(pkg = "udfixture"), '`pkg` is dossier()\'s first argument: run_dossier(dossier("udfixture"))',
                 fixed = TRUE)
    # the comparison's settings are checked before anything runs
    expect_error(run_dossier(tol = "a"), "`tol` must be one number")
    expect_error(run_dossier(accept = "no-such-file.csv"), "no-such-file.csv does not exist", fixed = TRUE)
    # a destination outside the folder, written with "..", is fine to check
    expect_error(run_dossier(html = "R/report"), "add ^R/report$ to .Rbuildignore", fixed = TRUE)
    expect_error(run_dossier(tool = 1e-3), "did you mean `tol`?", fixed = TRUE)
    # the report inside the package folder would go into every build
    expect_error(run_dossier(html = "report"), "add ^report$ to .Rbuildignore", fixed = TRUE)
  })
  expect_error(run_dossier("udfixture"), 'run_dossier(dossier("udfixture"))', fixed = TRUE)
  expect_error(run_dossier(pkg_dir), sprintf('run_dossier(dossier("udfixture", candidate = local_path("%s")))', pkg_dir),
               fixed = TRUE)
  expect_null(pkgdossier:::check_destinations(dossier("udfixture", candidate = local_path(pkg_dir), work = tempfile()),
                                              file.path(pkg_dir, "..", "elsewhere"), NULL))
  expect_error(run_dossier(list()), "`d` must be a dossier()", fixed = TRUE)
  d <- dossier("udfixture", candidate = local_path(pkg_dir), work = tempfile("ud-w-"))
  expect_error(run_dossier(d, reps = 0), "`reps` is set in dossier(): dossier(..., reps = 0)", fixed = TRUE)
  # a path is not a package name
  expect_error(dossier("."), 'candidate = local_path(".")', fixed = TRUE)
  expect_error(dossier("../mypkg"), 'candidate = local_path("../mypkg")', fixed = TRUE)
})

test_that("folder sources are checked before anything is downloaded", {
  not_pkg <- tempfile("ud-plain-")
  dir.create(not_pkg)
  # the CRAN baseline is never reached: its repository does not exist
  d <- dossier("udfixture", base = cran_release(repos = "file:///nonexistent-pkgdossier-repo"),
               candidate = local_path(not_pkg), work = tempfile("ud-w-"))
  expect_error(prepare_versions(d, ask = FALSE, quiet = TRUE), "is not a package",
               class = "pkgdossier_error_not_package")
  other <- dossier("otherpkg", base = cran_release(repos = "file:///nonexistent-pkgdossier-repo"),
                   candidate = local_path(copy_fixture()), work = tempfile("ud-w-"))
  expect_error(prepare_versions(other, ask = FALSE, quiet = TRUE), "holds the package udfixture, not otherpkg",
               class = "pkgdossier_error_not_package")
  # a dependency the folder needs and the library lacks, with deps_cran() offered
  needy <- copy_fixture()
  cat("Imports: notapkg.xyz\n", file = file.path(needy, "DESCRIPTION"), append = TRUE)
  dn <- dossier("udfixture", base = cran_release(repos = "file:///nonexistent-pkgdossier-repo"),
                candidate = local_path(needy), work = tempfile("ud-w-"))
  err <- tryCatch(prepare_versions(dn, ask = FALSE, quiet = TRUE), error = conditionMessage)
  expect_match(err, "notapkg.xyz: not installed", fixed = TRUE)
  expect_match(err, "deps = deps_cran()", fixed = TRUE)
})

test_that("no release to compare with, or no index, stops with the base to write instead", {
  repo <- tempfile("ud-repo-")
  contrib <- file.path(repo, "src", "contrib")
  dir.create(contrib, recursive = TRUE)
  writeLines(c("Package: otherpkg", "Version: 1.0.0", ""), file.path(contrib, "PACKAGES"))
  url <- paste0("file://", normalizePath(repo, winslash = "/"))
  if (!startsWith(url, "file:///")) url <- sub("^file://", "file:///", url)
  pkg_dir <- copy_fixture()
  if (pkgdossier:::git_available()) {
    git <- function(...) system2("git", c("-C", shQuote(pkg_dir), ...), stdout = FALSE, stderr = FALSE)
    git("init", "-q")
    git("add", ".")
    git("-c", "user.email=t@example.org", "-c", "user.name=t", "commit", "-q", "-m", "x")
    git("tag", "v1.0.0")
  }
  d <- dossier("udfixture", base = cran_release(repos = url), candidate = local_path(pkg_dir),
               work = tempfile("ud-w-"))
  err <- tryCatch(prepare_versions(d, ask = FALSE, quiet = TRUE), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_not_on_repo")
  expect_match(conditionMessage(err), "so there is no release of it to use as the baseline", fixed = TRUE)
  expect_match(conditionMessage(err), 'base = tarball("path/to/udfixture_x.y.z.tar.gz")', fixed = TRUE)
  if (pkgdossier:::git_available()) {
    expect_match(conditionMessage(err), sprintf('base = git_ref("%s", "v1.0.0")', normalizePath(pkg_dir, winslash = "/")),
                 fixed = TRUE)
  }

  off <- dossier("udfixture", base = cran_release(repos = "file:///nonexistent-pkgdossier-repo"),
                 candidate = local_path(pkg_dir), work = tempfile("ud-w-"))
  err <- tryCatch(prepare_versions(off, ask = FALSE, quiet = TRUE), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_offline")
  expect_match(conditionMessage(err), "Offline, use a tarball you have", fixed = TRUE)
})

test_that("sources that give no scenarios stop with a way to add one", {
  empty <- tempfile("ud-empty-pkg-")
  dir.create(empty)
  d <- dossier("udfixture", candidate = local_path("."), scenarios = from_vignettes(), work = tempfile("ud-w-"))
  vers <- list(base = list(unpacked = empty, version = "1.0.0"))
  err <- tryCatch(suppressMessages(pkgdossier:::resolve_scenarios(d, vers)), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_no_scenarios")
  expect_match(conditionMessage(err), 'scenario_file("dev/dossier/scenarios.R")', fixed = TRUE)
})

test_that("missing packages are named once each, with one install line", {
  msg <- pkgdossier:::missing_message(list(ex_a = "ggplot2", ex_b = c("ggplot2", "MASS"), ex_c = "ggplot2",
                                           ex_d = "ggplot2"))
  expect_match(msg, "ggplot2 (ex_a, ex_b, ex_c and 1 more); MASS (ex_b)", fixed = TRUE)
  expect_match(msg, 'install.packages(c("ggplot2", "MASS"))', fixed = TRUE)
})

test_that("the comparison keeps its dossier, says its verdict and opens the report", {
  r <- get_res()
  expect_identical(r$cmp$dossier, r$d)
  out <- capture.output(print(r$cmp))
  expect_match(out[3], "^Verdict: [0-9]+ severe changes? \\(")
  expect_match(out[3], "scenario problem")
  page <- file.path(tempdir(), "ud-onecall-page")
  testthat::local_mocked_bindings(open_page = function(page) TRUE)
  msgs <- capture_messages(cmp <- run_dossier(r$d, html = page, json = NULL, ask = FALSE, open = TRUE))
  expect_true(any(grepl("(opened in the browser)", msgs, fixed = TRUE)))
  msgs <- capture_messages(run_dossier(r$d, html = page, json = NULL, ask = FALSE, open = FALSE))
  expect_false(any(grepl("opened in the browser", msgs, fixed = TRUE)))
})

test_that("pkgdossier_error classes", {
  e <- tryCatch(pkgdossier:::stop_pkgdossier("offline", "a ", "b"), error = function(e) e)
  expect_s3_class(e, c("pkgdossier_error_offline", "pkgdossier_error", "error"))
  expect_equal(conditionMessage(e), "a b")
  expect_equal(pkgdossier:::fmt_duration(40), "40 s")
  expect_equal(pkgdossier:::fmt_duration(360), "6 min")
  expect_equal(pkgdossier:::fmt_duration(5400), "1.5 h")
})

test_that("installed_version() is the installed version, fetched from CRAN as source", {
  skip_on_cran()
  # a CRAN-like repository: 1.1.0 current, 1.0.0 archived
  root <- tempfile("ud-inst-cran-")
  contrib <- file.path(root, "src", "contrib")
  archive <- file.path(contrib, "Archive", "udfixture")
  dir.create(archive, recursive = TRUE)
  ext <- function(f) system.file("extdata", f, package = "pkgdossier", mustWork = TRUE)
  file.copy(ext("udfixture_1.1.0.tar.gz"), contrib)
  file.copy(ext("udfixture_1.0.0.tar.gz"), archive)
  tools::write_PACKAGES(contrib, type = "source")
  p <- normalizePath(root, winslash = "/")
  url <- if (startsWith(p, "/")) paste0("file://", p) else paste0("file:///", p)
  # a library where udfixture is installed, as its DESCRIPTION says
  fake_lib <- function(...) {
    lib <- tempfile("ud-lib-")
    dir.create(file.path(lib, "udfixture"), recursive = TRUE)
    writeLines(c("Package: udfixture", ...), file.path(lib, "udfixture", "DESCRIPTION"))
    lib
  }
  mk <- function(lib) {
    dossier("udfixture", base = installed_version(lib = lib, repos = url), candidate = cran_release(repos = url),
            scenarios = scenario_file(test_path("fixtures", "scenarios.R")), reps = 0L, order = "ab",
            work = tempfile("ud-inst-w-"))
  }
  expect_output(print(mk(fake_lib("Version: 1.0.0"))), "base: +the installed version, from CRAN")

  # what an upgrade would change: the installed 1.0.0 against the current 1.1.0
  msgs <- capture_messages(vers <- prepare_versions(mk(fake_lib("Version: 1.0.0", "Repository: CRAN")), ask = FALSE))
  expect_true(any(grepl("base: the installed udfixture is 1.0.0", msgs, fixed = TRUE)))
  expect_equal(c(vers$base$version, vers$cand$version), c("1.0.0", "1.1.0"))
  expect_equal(vers$base$source, "CRAN version 1.0.0")
  expect_match(vers$base$url, "Archive/udfixture/udfixture_1.0.0.tar.gz", fixed = TRUE)

  # already the current release: nothing to compare
  expect_error(prepare_versions(mk(fake_lib("Version: 1.1.0", "Repository: CRAN")), ask = FALSE, quiet = TRUE),
               "is the current CRAN release", class = "pkgdossier_error_nothing_to_compare")
  # a development version from GitHub has no CRAN source: the commit is named
  gh <- fake_lib("Version: 1.0.0.9000", "RemoteType: github", "RemoteUsername: someone",
                 "RemoteRepo: udfixture", "RemoteSha: 0123456789abcdef0123")
  err <- tryCatch(prepare_versions(mk(gh), ask = FALSE, quiet = TRUE), error = function(e) e)
  expect_s3_class(err, "pkgdossier_error_not_on_repo")
  expect_match(conditionMessage(err), "came from github (someone/udfixture), not from CRAN", fixed = TRUE)
  expect_match(conditionMessage(err), 'base = git_ref("path/to/udfixture", "0123456789ab")', fixed = TRUE)
  # from R-universe: refused the same way
  expect_error(prepare_versions(mk(fake_lib("Version: 1.0.0", "Repository: https://someone.r-universe.dev")),
                                ask = FALSE, quiet = TRUE),
               "came from https://someone.r-universe.dev", class = "pkgdossier_error_not_on_repo")
  # not installed at all
  expect_error(prepare_versions(mk(tempfile("ud-empty-lib-")), ask = FALSE, quiet = TRUE),
               "is not installed", class = "pkgdossier_error_not_installed")
})
