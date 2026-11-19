# The CRAN source path, offline: a local repository reached through a file:// URL,
# laid out like CRAN (src/contrib with a package index, older versions under
# src/contrib/Archive/<pkg>/).

test_that("CRAN sources: the current release, a new release, and the archive", {
  skip_on_cran()
  root <- file.path(tempdir(), "ud-cran")
  unlink(root, recursive = TRUE)
  contrib <- file.path(root, "src", "contrib")
  dir.create(contrib, recursive = TRUE)
  index <- function() tools::write_PACKAGES(contrib, type = "source")
  tb <- pkgdossier:::build_tarball(normalizePath(test_path("fixtures", "udfixture-base")),
                                   file.path(root, "build"), "udfixture", "en")
  file.copy(tb, contrib)
  index()
  p <- normalizePath(root, winslash = "/")
  url <- if (startsWith(p, "/")) paste0("file://", p) else paste0("file:///", p)

  work <- file.path(tempdir(), "ud-cran-work")
  unlink(work, recursive = TRUE)
  d <- dossier("udfixture", base = cran_release(repos = url),
               candidate = local_path(test_path("fixtures", "udfixture-cand")),
               scenarios = scenario_file(test_path("fixtures", "scenarios.R")), work = work)
  v1 <- prepare_versions(d, ask = FALSE, quiet = TRUE)
  expect_equal(v1$base$version, "1.0.0")
  expect_match(v1$base$url, "/src/contrib/udfixture_1.0.0.tar.gz", fixed = TRUE)

  # 1.1.0 is released and 1.0.0 moves to the archive: cran_release() must notice
  archive <- file.path(contrib, "Archive", "udfixture")
  dir.create(archive, recursive = TRUE)
  file.rename(file.path(contrib, "udfixture_1.0.0.tar.gz"), file.path(archive, "udfixture_1.0.0.tar.gz"))
  file.copy(v1$cand$tarball, contrib)
  index()
  expect_warning(msgs <- capture_messages(v2 <- prepare_versions(d, ask = FALSE)),
                 "same version number")
  expect_equal(v2$base$version, "1.1.0")
  expect_equal(sum(grepl("unchanged, reusing", msgs)), 1L)  # the candidate only

  # the repository cannot be reached: the installed current release is reused, and
  # without an installed copy the call fails
  hidden <- paste0(root, "-hidden")
  unlink(hidden, recursive = TRUE)
  file.rename(root, hidden)
  expect_warning(msgs <- capture_messages(v3 <- prepare_versions(d, ask = FALSE)),
                 "same version number")
  expect_equal(v3$base$version, "1.1.0")
  expect_true(any(grepl("Could not read the package index", msgs)))
  d_new <- dossier("udfixture", base = cran_release(repos = url), candidate = d$candidate,
                   scenarios = d$scenarios, work = file.path(tempdir(), "ud-cran-fresh"))
  unlink(d_new$work, recursive = TRUE)
  expect_error(suppressWarnings(prepare_versions(d_new, ask = FALSE, quiet = TRUE)))
  file.rename(hidden, root)

  # an archived version is found under Archive/
  d_old <- dossier("udfixture", base = cran_version("1.0.0", repos = url),
                   candidate = d$candidate, scenarios = d$scenarios, work = work)
  v4 <- prepare_versions(d_old, ask = FALSE, quiet = TRUE)
  expect_equal(v4$base$version, "1.0.0")
  expect_match(v4$base$url, "/src/contrib/Archive/udfixture/udfixture_1.0.0.tar.gz", fixed = TRUE)
})

test_that("binary repositories are read as source for the compared package", {
  cr <- pkgdossier:::cran_repo
  p3m <- "https://packagemanager.posit.co/cran/__linux__/noble/latest"
  expect_equal(cr(p3m, source = TRUE), "https://packagemanager.posit.co/cran/latest")
  expect_equal(cr(p3m), p3m)  # dependencies may come as binaries
  expect_equal(cr("https://packagemanager.rstudio.com/all/__linux__/jammy/2024-01-02/", source = TRUE),
               "https://packagemanager.rstudio.com/all/2024-01-02")
  expect_equal(cr("https://cloud.r-project.org/", source = TRUE), "https://cloud.r-project.org")
  withr::with_options(list(repos = c(CRAN = "@CRAN@")), expect_equal(cr(NULL), "https://cloud.r-project.org"))
})

test_that("a binary package tarball is refused", {
  skip_on_cran()
  build <- file.path(tempdir(), "ud-binary-build")
  unlink(build, recursive = TRUE)
  dir.create(build)
  tb <- pkgdossier:::build_tarball(normalizePath(test_path("fixtures", "udfixture-base")),
                                   file.path(build, "src"), "udfixture", "en")
  lib <- file.path(build, "lib")
  dir.create(lib)
  pkgdossier:::rcmd_or_stop("INSTALL", c("--build", paste0("--library=", lib), tb), wd = build)
  bin <- setdiff(list.files(build, pattern = "^udfixture_1\\.0\\.0.*\\.(tar\\.gz|tgz|zip)$", full.names = TRUE), tb)
  skip_if(length(bin) != 1L || !grepl("\\.tar\\.gz$", bin), "no tar.gz binary build on this platform")
  d <- dossier("udfixture", base = tarball(bin), candidate = local_path(test_path("fixtures", "udfixture-cand")),
               scenarios = scenario_file(test_path("fixtures", "scenarios.R")),
               work = file.path(tempdir(), "ud-binary-work"))
  expect_error(prepare_versions(d, ask = FALSE, quiet = TRUE),
               "The base tarball .* is a binary package .* not a source tarball")
})
