# The example tarballs in inst/extdata are built from the test fixtures by
# dev/build-example-tarballs.R. These tests fail when the two drift apart.

# Compared line by line: a Windows checkout can give the fixtures CRLF line endings,
# while the tarballs hold LF.
file_lines <- function(f) lapply(f, readLines, warn = FALSE)

test_that("the bundled example tarballs hold the test fixtures", {
  for (v in c("base", "cand")) {
    src <- test_path("fixtures", paste0("udfixture-", v))
    version <- read.dcf(file.path(src, "DESCRIPTION"), fields = "Version")[1, 1]
    tb <- system.file("extdata", paste0("udfixture_", version, ".tar.gz"), package = "pkgdossier")
    expect_true(nzchar(tb), label = paste("tarball for", v))
    exdir <- tempfile("udfixture-")
    utils::untar(tb, exdir = exdir)
    pkg <- file.path(exdir, "udfixture")
    files <- list.files(src, recursive = TRUE)
    files <- files[files != "DESCRIPTION"]  # R CMD build adds Packaged: to DESCRIPTION
    expect_setequal(setdiff(list.files(pkg, recursive = TRUE), "DESCRIPTION"), files)
    expect_equal(file_lines(file.path(pkg, files)), file_lines(file.path(src, files)),
                 label = paste("file contents for", v))
    unlink(exdir, recursive = TRUE)
  }
  expect_equal(
    file_lines(system.file("extdata", "udfixture-scenarios.R", package = "pkgdossier")),
    file_lines(test_path("fixtures", "scenarios.R"))
  )
})

test_that("example_dossier() describes the bundled package and touches nothing", {
  work <- file.path(tempdir(), "ud-example-never-created")
  d <- example_dossier(work = work)
  expect_s3_class(d, "pkgdossier_dossier")
  expect_equal(d$pkg, "udfixture")
  expect_equal(c(d$base$type, d$candidate$type), c("tarball", "tarball"))
  expect_true(file.exists(d$base$path))
  expect_true(file.exists(d$candidate$path))
  expect_false(dir.exists(work))
  expect_equal(example_dossier(reseed = "scenario")$reseed, "scenario")
})
