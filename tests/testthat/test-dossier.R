# End-to-end: two versions of a fixture package with planted differences, built and
# installed from source into a temporary work folder (no network). Every planted
# difference must be found with the right kind, and nothing else.

# The fixture dossier comes from get_res() in helper-fixture.R.

test_that("every planted difference is found with the right kind, and nothing else", {
  cmp <- get_res()$cmp
  got <- differences(cmp)
  key <- paste(got$scenario, got$step, got$kind, got$path)
  expected <- c(
    "intro estimate value_moved est$main",
    "intro report output_changed printed",
    "intro draw plot_changed plot",
    "api result field_removed res$b",
    "api extended field_added ext$c",
    "api check error_new error",
    "api fixed error_fixed error",
    "api warn_new warning_new warning",
    "api warn_gone warning_gone warning",
    "api warn_class condition_class_changed warning",
    "api noisy unstable NA",
    "api progress output_changed console",
    "api err_class condition_class_changed error",
    "api label value_moved lab",
    "(namespace) draw argument_added col",
    "(namespace) report default_changed digits",
    "(namespace) warn_gone argument_removed verbose",
    "(namespace) extend_result argument_new_required keep",
    "(namespace) new_helper export_added new_helper"
  )
  # The two timing differences come from a 0.25 s sleep against a no-op. That gap is
  # wide, but timings on a loaded check machine can still cross it, so they are only
  # asserted outside CRAN; everything else is asserted everywhere.
  timing <- c("api slow slower time", "api quick faster time")
  if (identical(Sys.getenv("NOT_CRAN"), "true")) {
    expected <- c(expected, timing)
  } else {
    key <- setdiff(key, timing)
  }
  expect_setequal(key, expected)
  expect_equal(anyDuplicated(key), 0L)
})

test_that("the details of the planted differences are right", {
  cmp <- get_res()$cmp
  got <- differences(cmp)
  vm <- got[got$kind == "value_moved" & got$step == "estimate", ]
  expect_equal(vm$base, "0.5")
  expect_equal(vm$cand, "0.6")
  expect_equal(vm$rel_change, 0.2, tolerance = 1e-8)
  expect_equal(got$cand[got$kind == "error_new"], "`x` must be character")
  expect_equal(got$cand[got$kind == "warning_new"], "results may be unstable")
  cc <- got[got$kind == "condition_class_changed" & got$path == "warning", ]
  expect_match(cc$cand, "^slowWarning/")
  expect_match(cc$base, "^simpleWarning/")
  ce <- got[got$kind == "condition_class_changed" & got$path == "error", ]
  expect_equal(c(ce$base, ce$cand), c("simpleError/error/condition", "inputError/error/condition"))
  expect_equal(ce$detail, "bad input")
  expect_equal(got$severity[got$kind == "error_new"], 1L)
  expect_equal(got$severity[1], 0L)  # unstable first

  intro <- cmp$scenarios[[which(vapply(cmp$scenarios, `[[`, "", "id") == "intro")]]
  est <- intro$steps[[which(vapply(intro$steps, `[[`, "", "id") == "estimate")]]
  expect_equal(est$values$n_tiny, 1L)   # moved under the tolerance: counted, not listed
  expect_equal(est$values$n_changed, 1L)
  draw <- intro$steps[[which(vapply(intro$steps, `[[`, "", "id") == "draw")]]
  expect_length(draw$plot$files_base, 1L)
  expect_true(draw$plot$changed)
  expect_equal(c(draw$plot$w, draw$plot$h), c(6, 4))  # chunk fig.width, global fig.height
  expect_setequal(vapply(intro$not_run, `[[`, "", "id"), c("later", "conditional"))
})

test_that("NEWS candidates are attached and missing ones flagged", {
  cmp <- get_res()$cmp
  got <- differences(cmp)
  news_of <- function(step) got$news[got$step == step & got$scenario != "(namespace)"][1]
  expect_match(news_of("estimate"), "`estimate()` returns a main estimate of 0.6", fixed = TRUE)
  expect_match(news_of("check"), "requires character input and errors otherwise", fixed = TRUE)
  expect_match(news_of("report"), "print.ud_report()", fixed = TRUE)  # via the printed value's class
  # make_result() is named only in the 1.0.0 section, which the baseline already had
  expect_true(got$no_news[got$step == "result"])
  expect_equal(nrow(differences(cmp, no_news = FALSE)), 3L)
  expect_equal(nrow(differences(cmp, no_news = TRUE)), nrow(got) - 3L)
  expect_equal(cmp$meta$news$file, "NEWS.md")
  expect_equal(nrow(cmp$meta$news$bullets), 3L)
  expect_true(any(grepl("[no NEWS]", capture.output(print(cmp)), fixed = TRUE)))
})

test_that("changed plots report their share of differing pixels and plot_tol", {
  skip_if_not_installed("png")
  r <- get_res()
  draw <- function(cmp) {
    intro <- cmp$scenarios[[which(vapply(cmp$scenarios, `[[`, "", "id") == "intro")]]
    intro$steps[[which(vapply(intro$steps, `[[`, "", "id") == "draw")]]
  }
  share <- draw(r$cmp)$plot$pixel_share
  expect_length(share, 1L)
  expect_true(share > 0 && share < 1)
  pc <- differences(r$cmp, kind = "plot_changed")
  expect_match(pc$detail, "^[0-9.]+% of pixels differ$")

  loose <- compare_runs(r$d, plot_tol = 1)
  expect_equal(nrow(differences(loose, kind = "plot_changed")), 0L)
  expect_true(draw(loose)$plot$below_tol)
  expect_false(draw(loose)$plot$changed)
  expect_equal(loose$meta$plot_tol, 1)
  expect_error(compare_runs(r$d, plot_tol = 2))
})

test_that("signature changes and coverage are reported", {
  cmp <- get_res()$cmp
  got <- differences(cmp)
  ns <- got[got$scenario == "(namespace)", ]
  expect_equal(ns$base[ns$kind == "default_changed"], "2")
  expect_equal(ns$cand[ns$kind == "default_changed"], "3")
  expect_equal(ns$cand[ns$kind == "argument_new_required"], "(required)")
  expect_equal(ns$severity[ns$kind == "argument_removed"], 1L)
  cv <- cmp$meta$coverage
  expect_equal(cv$unused, "new_helper")
  expect_equal(cv$exported, 18L)
  expect_length(cv$news_unmatched, 0L)
  expect_true(any(grepl("Coverage: the scenarios use 17 of 18 exported functions. Not used: new_helper.",
                        capture.output(print(cmp)), fixed = TRUE)))
  expect_match(write_dossier_md(cmp), "Not used: `new_helper`.", fixed = TRUE)
  expect_equal(nrow(differences(compare_runs(get_res()$d, api = FALSE), kind = "export_added")), 0L)
})

test_that("summary and print describe the comparison", {
  cmp <- get_res()$cmp
  s <- summary(cmp)
  expect_true(all(c("scenario", "step", "status", "kinds", "n") %in% names(s)))
  expect_equal(s$status[s$step == "check"], "error_new")
  expect_equal(s$status[s$step == "noisy"], "unstable")
  expect_equal(s$status[s$step == "unchanged"], "same")
  expect_equal(s$status[s$step == "data"], "same")  # reads a file shipped next to the vignette
  expect_equal(s$status[s$step == "digits"], "same")  # printed digits moved within tol
  expect_equal(s$status[s$step == "tmp"], "same")     # temporary paths differ in every run
  expect_equal(s$status[s$step == "formula"], "same") # prints its environment's address
  expect_equal(s$status[s$step == "meta"], "same")    # the package's own DESCRIPTION
  expect_equal(s$status[s$step == "expected"], "same") # an error the vignette shows on purpose
  # Version at least; Packaged too, unless both versions were built in the same second
  expect_true(cmp$meta$own_metadata >= 1L)
  kept <- differences(compare_runs(get_res()$d, keep_metadata = TRUE))
  expect_true("info$Version" %in% kept$path)
  expect_equal(s$status[s$step == "err_class"], "error_both")
  api <- cmp$scenarios[[which(vapply(cmp$scenarios, `[[`, "", "id") == "api")]]
  dg <- api$steps[[which(vapply(api$steps, `[[`, "", "id") == "digits")]]
  expect_true(dg$transcript_digits_only)
  lab <- differences(cmp, kind = "value_moved")
  expect_equal(lab$detail[lab$step == "label"], "text")
  expect_equal(c(lab$base[lab$step == "label"], lab$cand[lab$step == "label"]), c("alpha", "beta"))
  expect_equal(sort(s$step[s$status == "not_run"]), c("conditional", "later"))
  out <- capture.output(print(cmp))
  expect_match(out[1], "udfixture 1.0.0 -> 1.1.0", fixed = TRUE)
  expect_true(any(grepl("error_new", out)))
  expect_equal(nrow(differences(cmp, kind = "plot_changed")), 1L)
  expect_equal(nrow(differences(cmp, max_severity = 1)), 5L)  # 3 from runs, 2 from signatures
  expect_error(differences(cmp, kind = "nonsense"), "Unknown kind")
})

test_that("the runs record provenance and isolation", {
  r <- get_res()
  vers <- readRDS(file.path(r$d$work, "versions.rds"))
  expect_equal(vers$base$version, "1.0.0")
  expect_equal(vers$cand$version, "1.1.0")
  expect_match(vers$base$sha256, "^[0-9a-f]{64}$")
  expect_true(file.exists(file.path(r$d$work, "versions.json")))
  m <- r$cmp$meta
  expect_equal(m$base$pkg_version, "1.0.0")
  expect_equal(m$cand$pkg_version, "1.1.0")
  expect_true(startsWith(tolower(m$base$pkg_path), tolower(vers$base$lib)))
  expect_equal(m$base$language, "en")
  expect_true(m$determinism_checked)
  expect_equal(m$runs$run, c("base_a", "cand_a", "cand_b", "base_b"))
})

test_that("unchanged versions and scenarios are reused, not rebuilt or rerun", {
  r <- get_res()
  msgs <- capture_messages(prepare_versions(r$d, ask = FALSE))
  expect_equal(sum(grepl("unchanged, reusing", msgs)), 2L)
  plan <- run_scenarios(r$d, quiet = TRUE)
  expect_true(all(plan$reused))
})

test_that("the Markdown summary lists kinds, the most severe differences and NEWS", {
  cmp <- get_res()$cmp
  md <- write_dossier_md(cmp, report_url = "https://example.org/run/1")
  lines <- strsplit(md, "\n", fixed = TRUE)[[1]]
  expect_equal(lines[1], "<!-- pkgdossier -->")
  expect_equal(lines[2], "### pkgdossier: udfixture 1.0.0 -> 1.1.0")
  expect_true("| error_new | 1 | 1 | 1 |" %in% lines)
  expect_true(any(grepl("^\\| field_removed \\| api/result `res\\$b` \\| - \\| - \\| none \\|$", lines)))
  expect_true(any(grepl("^\\| value_moved \\| intro/estimate `est\\$main` \\| 0.5 \\| 0.6 \\| `estimate\\(\\)`", lines)))
  expect_true("[Full report](https://example.org/run/1)" %in% lines)
  expect_true(any(grepl("api/noisy", lines)))  # the determinism note
  f <- tempfile(fileext = ".md")
  expect_equal(write_dossier_md(cmp, f, report_url = "https://example.org/run/1"), f)
  expect_equal(paste(readLines(f), collapse = "\n"), md)
  expect_false(any(grepl("Full report", write_dossier_md(cmp))))
  expect_equal(pkgdossier:::md_cell("a | b"), "a \\| b")
})

test_that("the GitHub Actions template ships and uses run_dossier()", {
  yaml <- system.file("github", "pkgdossier.yaml", package = "pkgdossier")
  expect_true(nzchar(yaml))
  txt <- readLines(yaml)
  expect_true(any(grepl("run_dossier(d", txt, fixed = TRUE)))
  expect_true(any(grepl("write_dossier_md(cmp", txt, fixed = TRUE)))
})

test_that("run_dossier() runs every stage and writes the report and JSON", {
  r <- get_res()
  page <- file.path(tempdir(), "ud-run-dossier-page")
  json <- file.path(tempdir(), "ud-run-dossier", "dossier.json")
  unlink(c(page, dirname(json)), recursive = TRUE)
  msgs <- capture_messages(cmp <- run_dossier(r$d, html = page, json = json, ask = FALSE, open = FALSE))
  expect_s3_class(cmp, "pkgdossier_comparison")
  expect_equal(nrow(differences(cmp)), nrow(differences(r$cmp)))
  expect_true(file.exists(file.path(page, "dossier.html")))
  expect_true(file.exists(json))
  expect_true(any(grepl("up to date, reused", msgs)))  # every stage reused its cache
  # settings given to the wrong function are named with their home
  expect_error(run_dossier(r$d, reps = 0), "`reps` is set in dossier\\(\\)")
  expect_error(run_dossier(r$d, report = page), "the report folder is `html`")
  expect_error(run_dossier(r$d, tol = 1e-3, max_rows = 5), "`max_rows` belongs to write_dossier_md\\(\\)")
  expect_error(differences(cmp, kinds = "plot_changed"), "no argument `kinds`")
})

test_that("the report and the JSON are written", {
  r <- get_res()
  page <- file.path(r$d$work, "page")
  html <- write_dossier_html(r$cmp, dir = page)
  expect_true(file.exists(html))
  expect_true(all(file.exists(file.path(page, c("data.js", "notes.js")))))
  expect_length(list.files(file.path(page, "img")), 2L)
  txt <- paste(readLines(html, encoding = "UTF-8"), collapse = "\n")
  expect_match(txt, "udfixture 1.0.0", fixed = TRUE)
  expect_false(grepl("__PKG__|__BASE_VERSION__|__CAND_VERSION__", txt))
  expect_false(grepl("https?://", txt))  # opens offline: no fonts or scripts fetched

  jf <- file.path(r$d$work, "dossier.json")
  write_dossier_json(r$cmp, jf)
  j <- jsonlite::fromJSON(jf, simplifyVector = FALSE)
  expect_equal(j$schema, "pkgdossier")
  expect_length(j$differences, nrow(r$cmp$differences))
  api <- j$scenarios[[which(vapply(j$scenarios, `[[`, "", "id") == "api")]]
  wn <- api$steps[[which(vapply(api$steps, `[[`, "", "id") == "warn_new")]]
  expect_type(wn$warnings$cand, "list")          # arrays stay arrays with one element
  intro <- j$scenarios[[which(vapply(j$scenarios, `[[`, "", "id") == "intro")]]
  dr <- intro$steps[[which(vapply(intro$steps, `[[`, "", "id") == "draw")]]
  expect_match(dr$plot$base[[1]], "^runs/base_a/plots/")
})

test_that("print and the Markdown summary handle the rarer cases", {
  cmp <- get_res()$cmp
  none <- cmp
  none$differences <- cmp$differences[0, ]
  expect_true(any(grepl("^No differences\\.$", capture.output(print(none)))))
  expect_match(write_dossier_md(none), "**No differences.**", fixed = TRUE)

  nonews <- cmp
  nonews$meta$news <- list(file = NA_character_, note = "the candidate has no NEWS file")
  expect_true(any(grepl("NEWS candidates not checked: the candidate has no NEWS file",
                        capture.output(print(nonews)), fixed = TRUE)))
  expect_match(write_dossier_md(nonews), "NEWS not checked: the candidate has no NEWS file", fixed = TRUE)

  unmatched <- cmp
  unmatched$meta$coverage$news_unmatched <- paste("bullet", 1:7)
  expect_true(any(grepl("7 NEWS bullet(s) match no step", capture.output(print(unmatched)), fixed = TRUE)))
  md <- write_dossier_md(unmatched, max_rows = 2L)
  expect_match(md, "- bullet 5\n- and 2 more", fixed = TRUE)
  expect_match(md, "more not shown.", fixed = TRUE)
  expect_match(md, "Scenario problems (error under both versions): api/err_class.", fixed = TRUE)
  expect_true(any(grepl("Scenario problems (error under both versions): api/err_class",
                        capture.output(print(cmp)), fixed = TRUE)))

  severe <- cmp$differences[cmp$differences$severity <= 2L, ]
  copies <- do.call(rbind, rep(list(severe), 3))
  same <- cmp
  same$differences <- copies   # the same changes three times: grouped, still listed once each
  expect_false(any(grepl("more; see differences", capture.output(print(same)), fixed = TRUE)))
  copies$base <- paste0(copies$base, rep(1:3, each = nrow(severe)))
  many <- cmp
  many$differences <- copies   # now distinct
  expect_true(any(grepl("more; see differences(group = TRUE)", capture.output(print(many)), fixed = TRUE)))

  expect_equal(unique(differences(cmp, scenario = "intro")$scenario), "intro")
  expect_equal(pkgdossier:::version_labels(list(base = list(version = "1.0"), cand = list(version = "1.0"))),
               list(base = "1.0 (baseline)", cand = "1.0 (candidate)"))
})

test_that("identical changes in several steps group into one row", {
  d <- data.frame(
    scenario = c("s1", "s1", "s2", "s2", "s2"), step = c("a", "b", "c", "c", "d"),
    label = c("a", "b", "c", "c", "d"),
    kind = c("field_added", "field_added", "field_added", "value_moved", "output_changed"),
    severity = c(4L, 4L, 4L, 2L, 3L),
    path = c("m1$summary$se", "m2$summary$se", "fit$summary$se", "fit$coef", "printed"),
    base = c(NA, NA, NA, "1", "x"), cand = c(NA, NA, NA, "2", "y"), rel_change = NA_real_,
    detail = NA_character_, news = c(NA, "`fit()` adds se", NA, NA, NA),
    no_news = c(TRUE, FALSE, TRUE, TRUE, TRUE), accepted = FALSE, accepted_reason = NA_character_,
    stringsAsFactors = FALSE)
  g <- pkgdossier:::group_differences(d)
  expect_equal(nrow(g), 3L)
  fa <- g[g$kind == "field_added", ]
  expect_equal(c(fa$path, fa$n, fa$steps), c("*$summary$se", "3", "3"))
  expect_equal(fa$where, "s1/a, s1/b, s2/c")
  expect_equal(fa$news, "`fit()` adds se")
  expect_false(fa$no_news)  # one occurrence has a NEWS candidate
  expect_equal(g$path[g$kind == "value_moved"], "fit$coef")   # one occurrence: the real path
  expect_equal(g$path[g$kind == "output_changed"], "printed") # not a path inside an object
  expect_equal(g$kind, c("value_moved", "output_changed", "field_added"))  # by severity
  expect_equal(nrow(pkgdossier:::group_differences(d[0, ])), 0L)
  expect_equal(nrow(differences(get_res()$cmp, group = TRUE)), nrow(differences(get_res()$cmp)))
})

test_that("timing labels need enough timings per version", {
  r <- get_res()
  few <- compare_runs(r$d, min_timings = 7L)   # the fixture has 6 per version
  expect_equal(nrow(differences(few, kind = c("slower", "faster"))), 0L)
  expect_true(few$meta$timing_unlabelled > 0L)
  expect_true(any(grepl("too few to label slower or faster", capture.output(print(few)), fixed = TRUE)))
  expect_equal(r$cmp$meta$timing_unlabelled, 0L)
})
