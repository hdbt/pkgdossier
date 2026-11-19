# Run-level behaviour: which settings force a rerun, how the seed is set, and what a
# run that hangs reports. Skipped on CRAN to keep the check time down; the main
# fixture test in test-dossier.R already builds, installs and runs on CRAN.

runs_dossier <- function(scenario_lines, ...) {
  f <- tempfile(fileext = ".R")
  writeLines(scenario_lines, f)
  dossier("udfixture",
    base = local_path(test_path("fixtures", "udfixture-base")),
    candidate = local_path(test_path("fixtures", "udfixture-cand")),
    scenarios = scenario_file(f), order = "ab", reps = 0L,
    work = file.path(tempdir(), "ud-runs"), ...
  )
}

rng_lines <- c(
  "scenario('rng',",
  "  step('seed', 'run', set.seed(1)),",
  "  step('draw', 'run', x <- stats::runif(1), values = TRUE))"
)

drawn <- function(d) {
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))
  res$scenarios$rng$steps$draw$values$value
}

test_that("a changed setting reruns; an unchanged one reuses", {
  skip_on_cran()
  unlink(file.path(tempdir(), "ud-runs"), recursive = TRUE)
  d <- runs_dossier(rng_lines)
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  expect_false(any(run_scenarios(d, quiet = TRUE)$reused))
  expect_true(all(run_scenarios(d, quiet = TRUE)$reused))
  d50 <- runs_dossier(rng_lines, dpi = 50)
  expect_false(any(run_scenarios(d50, quiet = TRUE)$reused))
  expect_true(all(run_scenarios(d50, quiet = TRUE)$reused))
  expect_false(any(run_scenarios(runs_dossier(rng_lines, dpi = 50, caps = list(max_rows = 10L)),
                                 quiet = TRUE)$reused))
  expect_false(any(run_scenarios(runs_dossier(rng_lines, language = "de"), quiet = TRUE)$reused))
  expect_error(runs_dossier(rng_lines, caps = list(max_row = 10)), "Unknown cap\\(s\\): max_row")

  # a time limit no step reached: a looser one reuses the runs, a tighter one reruns
  run_scenarios(d, step_timeout = 60, quiet = TRUE)
  expect_true(all(run_scenarios(d, step_timeout = 120, quiet = TRUE)$reused))
  expect_false(any(run_scenarios(d, step_timeout = 30, quiet = TRUE)$reused))
  # how many runs go at once is not part of what a run is
  expect_true(all(run_scenarios(d, step_timeout = 30, workers = 2L, quiet = TRUE)$reused))
})

test_that("comparing checks the runs against the installs and the dossier", {
  skip_on_cran()
  d <- runs_dossier(rng_lines)
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  expect_s3_class(compare_runs(d), "pkgdossier_comparison")
  # settings changed since the runs: the comparison says so, and describes the runs
  d60 <- d
  d60$width <- 60L
  expect_warning(cmp <- compare_runs(d60), "other width than the dossier has now")
  expect_equal(cmp$meta$base$width, 80L)
  # a version prepared again after its runs: its NEWS and provenance would not fit them
  f <- file.path(d$work, "versions.rds")
  v <- readRDS(f)
  v$cand$identity <- "local:changed"
  saveRDS(v, f)
  expect_error(compare_runs(d), "candidate was prepared again after run cand_a")
})

test_that("the runner leaves the session's temporary folder as a scenario would find it", {
  skip_on_cran()
  d <- runs_dossier("scenario('tmp', step('ls', 'run', n <- length(grep('^libloc_', dir(tempdir()))), values = TRUE))")
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))
  expect_equal(res$scenarios$tmp$steps$ls$values$value, 0)  # no installed.packages() cache files
})

test_that("reseed decides whether a scenario's own set.seed() carries over", {
  skip_on_cran()
  d <- runs_dossier(rng_lines)
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  expect_equal(drawn(d), withr::with_seed(d$seed, stats::runif(1)))

  d2 <- runs_dossier(rng_lines, reseed = "scenario")
  expect_output(print(d2), "seed 20261027 set per scenario")
  expect_false(any(run_scenarios(d2, quiet = TRUE)$reused))  # reseed is part of the run key
  expect_equal(drawn(d2), withr::with_seed(1, stats::runif(1)))
})

test_that("help-page examples run as scenarios and their changes are found", {
  skip_on_cran()
  d <- dossier("udfixture",
    base = local_path(test_path("fixtures", "udfixture-base")),
    candidate = local_path(test_path("fixtures", "udfixture-cand")),
    scenarios = from_examples(), order = "ab", reps = 0L,
    work = file.path(tempdir(), "ud-runs")
  )
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  got <- differences(compare_runs(d, api = FALSE))
  expect_setequal(paste(got$scenario, got$step, got$kind, got$path),
                  c("ex_estimate ex-01 value_moved est$main",
                    "ex_estimate ex-02 value_moved (value)",
                    "ex_estimate ex-02 output_changed printed"))
  # ex-01 calls estimate(), which a NEWS bullet names; ex-02 reads est$main, and est
  # came from estimate()
  expect_false(any(got$no_news))
})

test_that("a run that hangs is stopped and names the step it was in", {
  skip_on_cran()
  d <- runs_dossier("scenario('slow', step('hang', 'run', Sys.sleep(120)))")
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  expect_error(run_scenarios(d, timeout = 8, quiet = TRUE),
               "timed out after 8 s[\\s\\S]*slow/hang: starting", perl = TRUE)
})

test_that("a step over step_timeout is recorded as an error and the run goes on", {
  skip_on_cran()
  d <- runs_dossier(c(
    "scenario('steps',",
    "  step('before', 'run', a <- 1, values = TRUE),",
    "  step('hang', 'run', Sys.sleep(120)),",
    "  step('after', 'run', b <- a + 1, values = TRUE))"
  ))
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  msgs <- capture_messages(run_scenarios(d, step_timeout = 3))
  expect_true(any(grepl("steps/hang took more than 3 s", msgs, fixed = TRUE)))
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))$scenarios$steps$steps
  expect_equal(res$hang$error, "timed out after 3 s")
  expect_true(res$hang$timed_out)
  expect_null(res$after$error)
  expect_equal(res$after$values$value, 2)
  cmp <- compare_runs(d)
  expect_equal(summary(cmp)$status[summary(cmp)$step == "hang"], "error_both")
})

test_that("the step limit is per execution, and a version's second run does not restart a hang", {
  skip_on_cran()
  # three executions of 1.5 s each: over 3 s together, but each under the limit
  d <- runs_dossier("scenario('t', step('slow', 'fit', Sys.sleep(1.5), time = TRUE))")
  d$reps <- 2L
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  plan <- run_scenarios(d, step_timeout = 3, quiet = TRUE)
  expect_equal(plan$timed_out, c("", ""))
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))$scenarios$t$steps$slow
  expect_equal(nrow(res$reps), 2L)

  d2 <- runs_dossier("scenario('h', step('hang', 'run', Sys.sleep(120)), step('after', 'run', z <- 1, values = TRUE))")
  d2$order <- "abba"
  prepare_versions(d2, ask = FALSE, quiet = TRUE)
  msgs <- capture_messages(plan <- run_scenarios(d2, step_timeout = 3))
  expect_true(any(grepl("base_b: not starting h/hang, which timed out in base_a", msgs, fixed = TRUE)))
  expect_true(any(grepl("cand_b: not starting h/hang, which timed out in cand_a", msgs, fixed = TRUE)))
  expect_equal(plan$timed_out, rep("h/hang", 4L))
  rb <- readRDS(file.path(d2$work, "runs", "base_b", "results.rds"))$scenarios$h$steps
  expect_equal(rb$hang$not_started, "not started: it timed out in base_a")
  expect_equal(rb$after$values$value, 1)
  cmp <- compare_runs(d2)
  expect_equal(summary(cmp)$status[summary(cmp)$step == "hang"], "error_both")   # both runs agree
  out <- capture.output(print(cmp))
  expect_true(any(grepl("h timed out under both versions at step_timeout = 3 s (1 step)", out, fixed = TRUE)))
})

test_that("timings of runs from different calls are not labelled", {
  skip_on_cran()
  d <- runs_dossier(rng_lines)
  d$order <- "abba"
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, force = TRUE, quiet = TRUE)
  expect_false(compare_runs(d)$meta$mixed_calls)
  # the candidate's runs made again, the baseline's reused
  unlink(file.path(d$work, "runs", c("cand_a", "cand_b")), recursive = TRUE)
  plan <- run_scenarios(d, quiet = TRUE)
  expect_equal(plan$reused, c(TRUE, FALSE, FALSE, TRUE))
  cmp <- compare_runs(d)
  expect_true(cmp$meta$mixed_calls)
  expect_true(any(grepl("Some runs were reused from an earlier call", capture.output(print(cmp)), fixed = TRUE)))
})

test_that("a step whose process dies is recorded and the run goes on", {
  skip_on_cran()
  d <- runs_dossier(c(
    "scenario('dies',",
    "  step('before', 'run', { a <- 1; n <- length(dir(pattern = '^written')); file.create(paste0('written', n)) },",
    "       values = TRUE),",
    "  step('quit', 'run', quit(save = 'no', status = 3)),",
    "  step('after', 'run', b <- a + 1, values = TRUE))"
  ))
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  msgs <- capture_messages(plan <- run_scenarios(d))
  expect_true(any(grepl("base_a: R stopped in step dies/quit (the R process ended with exit status 3",
                        msgs, fixed = TRUE)))
  expect_equal(plan$crashed, rep("dies/quit", 2L))
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))$scenarios$dies$steps
  expect_equal(res$quit$error,
               "R stopped in this step: the R process ended with exit status 3; R's report is in crash-dies__quit.txt")
  expect_true(file.exists(file.path(d$work, "runs", "base_a", "crash-dies__quit.txt")))
  expect_true(res$quit$crashed)
  expect_equal(res$after$values$value[res$after$values$path == "b"], 2)   # earlier steps ran again; later ones run
  # from a fresh folder: what the stopped attempt wrote is gone
  expect_equal(res$before$values$value[res$before$values$path == "n"], 0)
  expect_equal(dir(file.path(d$work, "runs", "base_a"), pattern = "^written"), "written0")
  cmp <- compare_runs(d)
  expect_equal(summary(cmp)$status[summary(cmp)$step == "quit"], "error_both")
  out <- capture.output(print(cmp))
  expect_true(any(grepl("R crashed, and these steps are reported as errors:", out, fixed = TRUE)))
  expect_true(any(grepl("1 step under 1.0.0 (the R process ended with exit status 3): dies/quit", out, fixed = TRUE)))
})

test_that("a step pkgdossier cannot capture is recorded with R's message", {
  skip_on_cran()
  d <- runs_dossier(c(
    "scenario('odd',",
    "  step('obj', 'run', { registerS3method('[[', 'odd_obj', function(x, i) stop('subscript boom'), envir = globalenv())",
    "    x <- structure(list(a = 1), class = 'odd_obj') }, values = TRUE),",
    "  step('after', 'run', y <- 2, values = TRUE))"
  ))
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  msgs <- capture_messages(plan <- run_scenarios(d))
  expect_true(any(grepl("pkgdossier could not capture step odd/obj (", msgs, fixed = TRUE)))
  res <- readRDS(file.path(d$work, "runs", "base_a", "results.rds"))$scenarios$odd$steps
  expect_match(res$obj$error, "^pkgdossier could not capture this step: .*subscript boom")
  expect_true("pkgdossier_runner_error" %in% res$obj$error_class)
  expect_equal(res$after$values$value, 2)
  expect_equal(plan$crashed, rep("odd/obj", 2L))
  out <- capture.output(print(compare_runs(d)))
  expect_true(any(grepl("not captured by pkgdossier:", out, fixed = TRUE)))
})

test_that("runs need installs that match the dossier, and whole workers", {
  skip_on_cran()
  d <- runs_dossier(rng_lines)
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  dc <- runs_dossier(rng_lines, deps = deps_cran(repos = "file:///nonexistent-repo"))
  expect_error(run_scenarios(dc, quiet = TRUE), "run prepare_versions\\(d\\) first")
  expect_error(run_scenarios(d, workers = 1.5, quiet = TRUE), "whole number")
})

test_that("a segfault in a step is reported as such", {
  skip_on_cran()
  skip_on_os("windows")
  d <- runs_dossier("scenario('segv', step('boom', 'run', tools::pskill(Sys.getpid(), 11L)), step('ok', 'run', z <- 1))")
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, quiet = TRUE)
  res <- readRDS(file.path(d$work, "runs", "cand_a", "results.rds"))$scenarios$segv$steps
  expect_match(res$boom$error, "^R stopped in this step: segfault; R's report is in crash-segv__boom.txt$")
  report <- readLines(file.path(d$work, "runs", "cand_a", "crash-segv__boom.txt"))
  expect_true(any(grepl("caught segfault", report)))
  expect_null(res$ok$error)
})

test_that("a process that dies outside any step still stops the run", {
  skip_on_cran()
  d <- runs_dossier("scenario('fine', step('a', 'run', x <- 1))")
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  unlink(file.path(d$work, "lib-base", "udfixture"), recursive = TRUE)  # the runner cannot load it
  expect_error(run_scenarios(d, quiet = TRUE), "Run base_a failed")
})

test_that("tarball sources are copied into the work folder and installed", {
  skip_on_cran()
  work <- file.path(tempdir(), "ud-example-prepare")
  unlink(work, recursive = TRUE)
  vers <- prepare_versions(example_dossier(work = work), ask = FALSE, quiet = TRUE)
  expect_equal(c(vers$base$version, vers$cand$version), c("1.0.0", "1.1.0"))
  expect_true(file.exists(file.path(work, "src", "base", "udfixture_1.0.0.tar.gz")))
  expect_equal(vers$base$type, "tarball")
})

test_that("a missing package is named once, before the runs and in the problems", {
  skip_on_cran()
  d <- runs_dossier(c(
    "scenario('needs',",
    "  step('lib', 'run', library(notapkg.xyz)),",
    "  step('use', 'run', x <- notapkg_fit()),",
    "  step('fine', 'run', y <- 1))"
  ))
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  msgs <- capture_messages(run_scenarios(d))
  expect_true(any(grepl("Not installed, but used by the scenarios: notapkg.xyz (needs)", msgs, fixed = TRUE)))
  expect_true(any(grepl('install.packages(c("notapkg.xyz"))', msgs, fixed = TRUE)))
  cmp <- compare_runs(d)
  expect_equal(cmp$meta$missing_packages, list(needs = "notapkg.xyz"))
  out <- capture.output(print(cmp))
  expect_true(any(grepl("needs needs notapkg.xyz, which is not installed (2 steps)", out, fixed = TRUE)))
  expect_false(any(grepl("needs/", out, fixed = TRUE)))  # no other problems listed for this scenario
  expect_match(write_dossier_md(cmp), "needs notapkg.xyz, which is not installed (2 steps)", fixed = TRUE)
})

test_that("runs can go two at a time, with the same results and no timing labels", {
  skip_on_cran()
  d <- runs_dossier(rng_lines)
  d$order <- "abba"
  prepare_versions(d, ask = FALSE, quiet = TRUE)
  run_scenarios(d, force = TRUE, quiet = TRUE)
  one <- compare_runs(d)
  t0 <- Sys.time()
  plan <- run_scenarios(d, force = TRUE, workers = 2L, quiet = TRUE)
  expect_false(any(plan$reused))
  expect_true(all(plan$seconds > 0))
  expect_true(all(plan$overlapped))
  two <- compare_runs(d)
  expect_equal(two$meta$workers, 2L)
  expect_true(two$meta$parallel_runs)
  expect_equal(differences(two)[, c("kind", "path", "base", "cand")],
               differences(one)[, c("kind", "path", "base", "cand")])
  expect_true(any(grepl("Runs went up to 2 at a time", capture.output(print(two)), fixed = TRUE)))
  # reused by a later call with one worker, they still went two at a time
  again <- run_scenarios(d, quiet = TRUE)
  expect_true(all(again$reused))
  expect_true(compare_runs(d)$meta$parallel_runs)
  expect_false(one$meta$parallel_runs)
})
