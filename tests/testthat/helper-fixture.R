# The fixture dossier shared by the test files: two versions of a tiny package with
# planted differences, built and installed from source into a temporary work
# folder (no network), run once per test session.

fixture <- function(...) test_path("fixtures", ...)

run_fixture_dossier <- function() {
  work <- file.path(tempdir(), "ud-fixture-dossier")
  unlink(work, recursive = TRUE)
  d <- dossier("udfixture",
    base = local_path(fixture("udfixture-base")),
    candidate = local_path(fixture("udfixture-cand")),
    scenarios = list(from_vignettes(), scenario_file(fixture("scenarios.R"))),
    reps = 3L, work = work
  )
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  list(d = d, cmp = compare_runs(d))
}

fixture_cache <- new.env(parent = emptyenv())
get_res <- function() {
  if (is.null(fixture_cache$res)) fixture_cache$res <- run_fixture_dossier()
  fixture_cache$res
}

# install.packages() on Windows and macOS also reads a repository's binary index, and
# for a file:// repository a missing index is an error: the local repositories the
# tests build get an empty one, so that their source packages are installed.
# (tools::write_PACKAGES() writes no file for an empty folder.)
add_empty_binary_index <- function(repo_dir) {
  if (identical(.Platform$pkgType, "source")) return(invisible())
  bin <- utils::contrib.url(repo_dir, type = "binary")
  dir.create(bin, recursive = TRUE, showWarnings = FALSE)
  file.create(file.path(bin, "PACKAGES"))
  invisible()
}
