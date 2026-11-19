test_that("git_ref sources are exported, built and checked against a tag", {
  skip_if(!nzchar(Sys.which("git")), "git is not available")
  repo <- file.path(tempdir(), "ud-git-repo")
  unlink(repo, recursive = TRUE)
  dir.create(repo)
  g <- function(...) {
    out <- system2("git", c("-C", shQuote(repo), "-c", "user.name=fixture", "-c", "user.email=fixture@example.org",
                            "-c", "core.autocrlf=false", ...), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(out, "status"))) stop(paste(out, collapse = "\n"))
    out
  }
  copy_version <- function(v) {
    unlink(list.files(repo, full.names = TRUE), recursive = TRUE)
    src <- test_path("fixtures", paste0("udfixture-", v))
    file.copy(list.files(src, full.names = TRUE), repo, recursive = TRUE)
  }
  g("init", "-q")
  copy_version("base")
  g("add", "-A")
  g("commit", "-q", "-m", "1.0.0")
  g("tag", "v1.0.0")
  copy_version("cand")
  g("add", "-A")
  g("commit", "-q", "-m", "1.1.0")

  work <- file.path(tempdir(), "ud-git-work")
  unlink(work, recursive = TRUE)
  d <- dossier("udfixture", base = local_path(test_path("fixtures", "udfixture-base")),
               candidate = git_ref(repo, "HEAD"), base_tag = "v1.0.0",
               scenarios = scenario_file(test_path("fixtures", "scenarios.R")), work = work)
  vers <- prepare_versions(d, ask = FALSE, quiet = TRUE)
  expect_equal(vers$cand$version, "1.1.0")
  expect_equal(vers$cand$commit, g("rev-parse", "HEAD"))
  expect_equal(vers$base$tag_check, "R/ identical to v1.0.0 (line endings aside)")
  expect_equal(vers$cand$commits_since_tag, "1 commits after v1.0.0")
  expect_false(file.exists(file.path(repo, "udfixture_1.1.0.tar.gz")))  # nothing built in the repository
  expect_true(file.exists(file.path(work, "lib-cand", "udfixture", "DESCRIPTION")))

  # a baseline whose R/ is not the tagged release is reported
  work2 <- file.path(tempdir(), "ud-git-work-differs")
  unlink(work2, recursive = TRUE)
  d2 <- dossier("udfixture", base = local_path(test_path("fixtures", "udfixture-cand")),
                candidate = git_ref(repo, "HEAD"), base_tag = "v1.0.0",
                scenarios = scenario_file(test_path("fixtures", "scenarios.R")), work = work2)
  vers2 <- suppressWarnings(prepare_versions(d2, ask = FALSE, quiet = TRUE))
  expect_equal(vers2$base$tag_check, "R/ differs from v1.0.0 in 1 file(s): fns.R")
  d3 <- d2
  d3$base_tag <- "no-such-tag"
  expect_match(pkgdossier:::baseline_tag_check(d3, vers2$base), "could not export tag no-such-tag")
})
