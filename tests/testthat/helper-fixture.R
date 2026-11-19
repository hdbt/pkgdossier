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
