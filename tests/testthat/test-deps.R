test_that("dependency fields are split into name, operator and version", {
  t <- pkgdossier:::dep_table("R (>= 4.1.0), stats,\n    jsonlite (>=1.8), digest ( == 0.6.1 )")
  expect_equal(t$name, c("R", "stats", "jsonlite", "digest"))
  expect_equal(t$op, c(">=", "", ">=", "=="))
  expect_equal(t$version, c("4.1.0", "", "1.8", "0.6.1"))
  expect_equal(nrow(pkgdossier:::dep_table(NULL)), 0L)
  expect_equal(nrow(pkgdossier:::dep_table(NA)), 0L)
})

test_that("missing and too-old dependencies are reported before installing", {
  desc <- list(Package = "x", Version = "2.0",
               Depends = "R (>= 3.5)",
               Imports = "stats, jsonlite (>= 999.0), notapkg.xyz",
               LinkingTo = NULL)
  err <- tryCatch(pkgdossier:::check_deps(desc, "cand"), error = conditionMessage)
  expect_match(err, "The candidate (x 2.0) needs", fixed = TRUE)
  expect_match(err, "jsonlite (>= 999.0): installed ", fixed = TRUE)
  expect_match(err, "notapkg.xyz: not installed", fixed = TRUE)
  expect_match(err, "install.packages(c(\"jsonlite\", \"notapkg.xyz\"))", fixed = TRUE)
  expect_false(grepl("stats", err))

  old_r <- list(Package = "x", Version = "2.0", Depends = "R (>= 99.0)")
  expect_error(pkgdossier:::check_deps(old_r, "base"), "The baseline .*R \\(>= 99.0\\): this is R")

  fine <- list(Package = "x", Version = "1.0", Depends = "R (>= 3.5)", Imports = "jsonlite, digest (>= 0.1)")
  expect_true(pkgdossier:::check_deps(fine, "cand"))

  # advice that fits the problem: a snapshot's only for packages from the snapshot
  snap_hint <- function(pkgs) if ("jsonlite" %in% pkgs) "\nuse a later snapshot"
  expect_error(pkgdossier:::check_deps(desc, "cand", hint_for = snap_hint), "use a later snapshot")
  err <- tryCatch(pkgdossier:::check_deps(old_r, "base", hint_for = snap_hint), error = conditionMessage)
  expect_false(grepl("snapshot", err))
})

test_that("an install is reused only for the same R, dependency setup and LinkingTo versions", {
  d <- dossier("x", candidate = local_path("."), work = file.path(tempdir(), "ud-setup-never"))
  ctx <- pkgdossier:::deps_ctx(d)
  plain <- pkgdossier:::install_setup(d, NULL, list(Package = "x"), ctx)
  linked <- pkgdossier:::install_setup(d, NULL, list(Package = "x", LinkingTo = "testthat"), ctx)
  expect_match(plain, R.version.string, fixed = TRUE)
  expect_match(linked, paste0("testthat ", utils::packageVersion("testthat")), fixed = TRUE)
  dc <- dossier("x", candidate = local_path("."), work = file.path(tempdir(), "ud-setup-never"), deps = deps_cran())
  expect_false(identical(plain, pkgdossier:::install_setup(dc, NULL, list(Package = "x"), pkgdossier:::deps_ctx(dc))))
})

test_that("a work folder inside a folder source must be build-ignored", {
  pkg <- file.path(tempfile("ud-inside-"), "pkg")
  dir.create(file.path(pkg, "R"), recursive = TRUE)
  writeLines("Package: pkg", file.path(pkg, "DESCRIPTION"))
  writeLines("f <- 1", file.path(pkg, "R", "f.R"))
  d <- dossier("pkg", candidate = local_path(pkg), work = file.path(pkg, "dossier.work"))
  expect_error(pkgdossier:::check_work_outside(d, pkg, "cand"),
               "Add \\^dossier\\\\\\.work\\$ to .Rbuildignore")
  writeLines("^dossier\\.work$", file.path(pkg, ".Rbuildignore"))
  expect_null(pkgdossier:::check_work_outside(d, pkg, "cand"))
  # its contents, and what .Rbuildignore excludes, do not change the folder's identity
  id <- pkgdossier:::dir_identity(pkg, skip = d$work)
  dir.create(file.path(pkg, "dossier.work"))
  writeLines("run", file.path(pkg, "dossier.work", "x.txt"))
  writeLines("^notes$", file.path(pkg, ".Rbuildignore"), sep = "\n")
  cat("^dossier\\.work$\n", file = file.path(pkg, ".Rbuildignore"), append = TRUE)
  dir.create(file.path(pkg, "notes"))
  writeLines("draft", file.path(pkg, "notes", "a.md"))
  id2 <- pkgdossier:::dir_identity(pkg, skip = d$work)
  expect_identical(id2, id)
  writeLines("draft 2", file.path(pkg, "notes", "a.md"))
  writeLines("run 2", file.path(pkg, "dossier.work", "x.txt"))
  expect_identical(pkgdossier:::dir_identity(pkg, skip = d$work), id2)
  writeLines("f <- 2", file.path(pkg, "R", "f.R"))
  expect_false(identical(pkgdossier:::dir_identity(pkg, skip = d$work), id2))
  d_same <- dossier("pkg", candidate = local_path(pkg), work = pkg)
  expect_error(pkgdossier:::check_work_outside(d_same, pkg, "cand"), "Use a work folder outside the package")
})

test_that("deps = 'cran' installs current dependencies from the repository, offline", {
  skip_on_cran()
  root <- file.path(tempdir(), "ud-deps-repo")
  unlink(root, recursive = TRUE)
  contrib <- file.path(root, "src", "contrib")
  dir.create(contrib, recursive = TRUE)
  publish_dep <- function(version, value) {
    src <- file.path(tempdir(), "uddep-src", version, "uddep")
    unlink(dirname(src), recursive = TRUE)
    dir.create(file.path(src, "R"), recursive = TRUE)
    writeLines(c("Package: uddep", paste("Version:", version), "Title: Dependency Fixture",
                 "Description: A dependency for the pkgdossier tests.",
                 "Authors@R: person('Test', 'Fixture', role = c('aut', 'cre'), email = 'fixture@example.org')",
                 "License: MIT + file LICENSE"), file.path(src, "DESCRIPTION"))
    writeLines(c("YEAR: 2026", "COPYRIGHT HOLDER: pkgdossier authors"), file.path(src, "LICENSE"))
    writeLines("export(dep_value)", file.path(src, "NAMESPACE"))
    writeLines(sprintf("dep_value <- function() %d", value), file.path(src, "R", "f.R"))
    unlink(list.files(contrib, pattern = "^uddep_", full.names = TRUE))
    tb <- pkgdossier:::build_tarball(src, file.path(dirname(src), "build"), "uddep", "en")
    file.copy(tb, contrib)
    tools::write_PACKAGES(contrib, type = "source")
  }
  publish_dep("0.1.0", 42L)
  p <- normalizePath(root, winslash = "/")
  url <- if (startsWith(p, "/")) paste0("file://", p) else paste0("file:///", p)

  # a candidate that imports uddep
  cand <- file.path(tempdir(), "ud-deps-cand")
  unlink(cand, recursive = TRUE)
  dir.create(cand)
  file.copy(list.files(test_path("fixtures", "udfixture-cand"), full.names = TRUE), cand, recursive = TRUE)
  cat("Imports: uddep\n", file = file.path(cand, "DESCRIPTION"), append = TRUE)
  cat("uses_dep <- function() uddep::dep_value()\n", file = file.path(cand, "R", "fns.R"), append = TRUE)
  scen <- tempfile(fileext = ".R")
  writeLines("scenario('dep', step('v', 'run', x <- udfixture:::uses_dep(), values = TRUE))", scen)

  mk <- function(deps, work) {
    dossier("udfixture", base = local_path(test_path("fixtures", "udfixture-base")),
            candidate = local_path(cand), scenarios = scenario_file(scen), deps = deps,
            order = "ab", reps = 0L, work = work)
  }
  skip_if(requireNamespace("uddep", quietly = TRUE), "uddep is installed in the library")
  missing_dep <- list(Package = "x", Version = "1.0", Imports = "uddep, notinrepo")
  expect_error(pkgdossier:::ensure_deps(pkgdossier:::deps_ctx(mk(deps_cran(url), file.path(tempdir(), "ud-deps-missing"))),
                                             missing_dep, ask = FALSE, quiet = TRUE),
               "needs notinrepo, which .* does not have")
  shared <- mk(deps_shared(), file.path(tempdir(), "ud-deps-shared"))
  expect_error(prepare_versions(shared, ask = FALSE, quiet = TRUE), "uddep: not installed")

  work <- file.path(tempdir(), "ud-deps-cran")
  unlink(work, recursive = TRUE)
  d <- mk(deps_cran(url), work)
  vers <- prepare_versions(d, ask = FALSE, quiet = TRUE)
  expect_equal(vers$deps$mode, "cran")
  expect_equal(vers$deps$packages$uddep, "0.1.0")
  run_scenarios(d, quiet = TRUE)
  res <- readRDS(file.path(work, "runs", "cand_a", "results.rds"))
  expect_equal(res$scenarios$dep$steps$v$values$value, 42)
  expect_equal(unname(res$meta$packages["uddep"]), "0.1.0")

  # unchanged: nothing reinstalled, runs reused
  msgs <- capture_messages(prepare_versions(d, ask = FALSE))
  expect_false(any(grepl("Installing", msgs)))
  expect_true(all(run_scenarios(d, quiet = TRUE)$reused))

  # a new release of the dependency is installed, and the runs are repeated
  publish_dep("0.2.0", 43L)
  msgs <- capture_messages(vers <- prepare_versions(d, ask = FALSE))
  expect_true(any(grepl("Installing 1 dependency of udfixture 1.1.0 .*: uddep", msgs)))
  expect_equal(vers$deps$packages$uddep, "0.2.0")
  # only the candidate imports it: only its runs are repeated
  plan <- run_scenarios(d, quiet = TRUE)
  expect_equal(plan$reused[plan$role == "base"], TRUE)
  expect_equal(plan$reused[plan$role == "cand"], FALSE)
  res <- readRDS(file.path(work, "runs", "cand_a", "results.rds"))
  expect_equal(res$scenarios$dep$steps$v$values$value, 43)
  # deps_snapshot(): the same repository read as the snapshot of the baseline's day
  ds <- dossier("udfixture", base = local_path(test_path("fixtures", "udfixture-base")),
                candidate = local_path(cand), scenarios = scenario_file(scen), deps = deps_snapshot(repos = url),
                order = "ab", reps = 0L, work = file.path(tempdir(), "ud-deps-snapshot"))
  unlink(ds$work, recursive = TRUE)
  vs <- prepare_versions(ds, ask = FALSE, quiet = TRUE)
  expect_equal(vs$deps$mode, "snapshot")
  expect_equal(vs$deps$date, pkgdossier:::snapshot_date(as.list(read.dcf(file.path(vs$base$unpacked, "DESCRIPTION"))[1, ])))
  expect_true(dir.exists(file.path(ds$work, paste0("lib-deps-", vs$deps$date, "-R", pkgdossier:::r_series()))))
  expect_equal(vs$deps$packages$uddep, "0.2.0")
  run_scenarios(ds, quiet = TRUE)
  res <- readRDS(file.path(ds$work, "runs", "cand_a", "results.rds"))
  expect_equal(res$scenarios$dep$steps$v$values$value, 43)
  ds$deps_date <- "2025-01-01"   # a set date names its own library
  expect_equal(pkgdossier:::deps_ctx(ds, pkgdossier:::deps_date_of(ds))$date, "2025-01-01")
})

test_that("snapshot dates, repositories and libraries", {
  sd <- pkgdossier:::snapshot_date
  expect_equal(sd(list(`Date/Publication` = "2025-06-10 09:00:02 UTC", Packaged = "2025-06-09 1:00:00 UTC; me")),
               "2025-06-10")
  expect_equal(sd(list(Packaged = "2025-06-09 12:00:00 UTC; me")), "2025-06-09")
  expect_error(sd(list()), "deps_snapshot\\(date\\)")
  sr <- pkgdossier:::snapshot_repo
  withr::with_options(list(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest")),
    expect_equal(sr("2025-06-10"), "https://packagemanager.posit.co/cran/__linux__/noble/2025-06-10"))
  withr::with_options(list(repos = c(CRAN = "https://packagemanager.posit.co/cran/2024-01-02")),
    expect_equal(sr("2025-06-10"), "https://packagemanager.posit.co/cran/2025-06-10"))
  withr::with_options(list(repos = c(CRAN = "https://cloud.r-project.org")),
    expect_equal(sr("2025-06-10"), "https://packagemanager.posit.co/cran/2025-06-10"))
  expect_equal(sr("2025-06-10", "file:///x/"), "file:///x")

  work <- file.path(tempdir(), "ud-snapshot-never")
  d <- dossier("p", candidate = local_path("."), deps = deps_snapshot("2025-06-10"), work = work)
  ctx <- pkgdossier:::deps_ctx(d, d$deps_date)
  expect_match(ctx$lib, "lib-deps-2025-06-10-R[0-9]+\\.[0-9]+$")
  expect_match(ctx$repo, "/2025-06-10$")
  expect_match(ctx$fallback, "/latest$")
  # a dated URL given has its own current counterpart; an undated one has none
  given <- pkgdossier:::deps_ctx(dossier("p", candidate = local_path("."), work = work,
    deps = deps_snapshot("2025-06-10", repos = "https://rspm.example/cran/2025-06-10")), "2025-06-10")
  expect_equal(given$fallback, "https://rspm.example/cran/latest")
  local_repo <- pkgdossier:::deps_ctx(dossier("p", candidate = local_path("."), work = work,
    deps = deps_snapshot("2025-06-10", repos = "file:///x")), "2025-06-10")
  expect_null(local_repo$fallback)
  # dates are year-month-day, never guessed
  expect_error(deps_snapshot("10/06/2025"), "year-month-day")
  expect_error(deps_snapshot(20250610), "year-month-day")
  expect_equal(deps_snapshot(as.Date("2025-06-10"))$date, "2025-06-10")
  expect_equal(ctx$state_file, paste0(ctx$lib, "-state.rds"))
  expect_output(print(d), "CRAN as on 2025-06-10")
  d$deps_date <- NULL
  expect_error(pkgdossier:::deps_ctx(d, pkgdossier:::deps_date_of(d)), "No snapshot date")
  expect_false(dir.exists(work))
  expect_null(pkgdossier:::deps_ctx(dossier("p", candidate = local_path("."), work = work))$lib)
})

test_that("snapshot versions that do not build are taken current, with their dependents", {
  skip_on_cran()
  root <- file.path(tempdir(), "ud-fallback")
  unlink(root, recursive = TRUE)
  make_pkg <- function(repo_dir, name, version, body, imports = NULL) {
    src <- file.path(root, "src", basename(repo_dir), name)
    dir.create(file.path(src, "R"), recursive = TRUE)
    writeLines(c(paste("Package:", name), paste("Version:", version), "Title: Fallback Fixture",
                 "Description: A package for the pkgdossier tests.",
                 "Authors@R: person('Test', 'Fixture', role = c('aut', 'cre'), email = 'fixture@example.org')",
                 "License: MIT + file LICENSE", if (!is.null(imports)) paste("Imports:", imports)),
               file.path(src, "DESCRIPTION"))
    writeLines(c("YEAR: 2026", "COPYRIGHT HOLDER: pkgdossier authors"), file.path(src, "LICENSE"))
    writeLines("exportPattern('.')", file.path(src, "NAMESPACE"))
    writeLines(body, file.path(src, "R", "f.R"))
    contrib <- file.path(repo_dir, "src", "contrib")
    dir.create(contrib, recursive = TRUE, showWarnings = FALSE)
    tb <- pkgdossier:::build_tarball(src, file.path(src, "..", paste0(name, "-build")), name, "en")
    file.copy(tb, contrib)
    tools::write_PACKAGES(contrib, type = "source")
  }
  snap <- file.path(root, "snapshot")
  now <- file.path(root, "current")
  make_pkg(snap, "uddep", "0.1.0", "f <- function( 1")                 # does not build
  make_pkg(snap, "uddep2", "0.1.0", "g <- function() uddep::f()", imports = "uddep")
  make_pkg(snap, "uddep3", "0.1.0", "k <- function() uddep::f()", imports = "uddep")
  make_pkg(now, "uddepnew", "0.1.0", "h <- function() 1")             # new in uddep's current version
  make_pkg(now, "uddep", "0.2.0", "f <- function() uddepnew::h() + 1", imports = "uddepnew")
  make_pkg(now, "uddep2", "0.2.0", "g <- function() uddep::f()", imports = "uddep")
  make_pkg(now, "uddep3", "0.2.0", "k <- function() uddep::f()", imports = "uddep")
  url <- function(p) { p <- normalizePath(p, winslash = "/"); if (startsWith(p, "/")) paste0("file://", p) else paste0("file:///", p) }

  d <- dossier("x", candidate = local_path("."), deps = deps_snapshot(), work = file.path(root, "work"))
  ctx <- pkgdossier:::deps_ctx(d, "2025-01-01")
  ctx$repo <- url(snap)
  ctx$fallback <- url(now)
  msgs <- capture_messages(pkgdossier:::ensure_deps(ctx, list(Package = "x", Version = "1.0", Imports = "uddep2"),
                                                    ask = FALSE, quiet = FALSE))
  expect_true(any(grepl("versions of uddep that do not build", msgs, fixed = TRUE)))
  expect_true(any(grepl("current versions of uddep, uddep2", msgs, fixed = TRUE)))
  prov <- pkgdossier:::deps_provenance(ctx)
  expect_equal(prov$packages$uddep, "0.2.0")    # what is installed, not the snapshot's version
  expect_equal(prov$packages$uddep2, "0.2.0")   # moved with its dependency
  expect_match(prov$newer_than_snapshot$uddep, "^0.2.0 \\(its 0.1.0 version does not build under R ")
  expect_equal(prov$newer_than_snapshot$uddep2, "0.2.0 (depends on uddep)")
  # what the current version needs that the snapshot does not have comes along
  expect_equal(prov$newer_than_snapshot$uddepnew, "0.1.0 (needed by uddep 0.2.0)")
  expect_equal(prov$packages$uddepnew, "0.1.0")

  # a later call (the candidate's) needing a snapshot package that depends on one
  # taken current takes it current too, rather than mixing versions
  msgs <- capture_messages(pkgdossier:::ensure_deps(ctx, list(Package = "x", Version = "1.1", Imports = "uddep3"),
                                                    ask = FALSE, quiet = FALSE))
  expect_true(any(grepl("depend on packages taken at their current version before", msgs, fixed = TRUE)))
  prov <- pkgdossier:::deps_provenance(ctx)
  expect_equal(prov$packages$uddep3, "0.2.0")
  expect_equal(prov$newer_than_snapshot$uddep3, "0.2.0 (depends on uddep)")
})

test_that("a snapshot older than this R's series comes with a caveat", {
  old <- list(mode = "snapshot", date = "2020-01-01", r_version = "4.6.2", r_series = "4.6",
              r_series_began = "2026-04-01", older_than_r = TRUE)
  expect_match(pkgdossier:::snapshot_caveat(old), "older than the R 4.6 series running it \\(from 2026-04-01\\)")
  old$older_than_r <- FALSE
  expect_null(pkgdossier:::snapshot_caveat(old))
  expect_s3_class(pkgdossier:::r_release_date(), "Date")
  # a patch release does not move the line: the series' first release does
  began <- pkgdossier:::r_series_began
  expect_equal(began(package_version("4.5.2"), as.Date("2025-10-31")), as.Date("2025-04-11"))
  expect_equal(began(package_version("4.6.2"), as.Date("2026-10-29")), as.Date("2026-04-01"))
  expect_equal(began(package_version("4.6.3"), as.Date("2027-02-20")), as.Date("2026-04-01"))
  expect_equal(began(package_version("4.7.0"), as.Date("2027-04-20")), as.Date("2027-04-20"))
})
