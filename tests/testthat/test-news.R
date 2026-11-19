test_that("NEWS.md sections after the baseline are read, bullets joined", {
  lines <- c(
    "# pkg (development version)", "", "* `new_fn()` added.", "",
    "# pkg 1.2.0", "", "## Bug fixes", "", "* `fit()` no longer drops", "  the last row.",
    "- second bullet with pkg::other(x)", "",
    "# pkg 1.1.0", "", "* old news about fit()."
  )
  all <- pkgdossier:::parse_news(lines)
  expect_equal(all$version, c(NA, "1.2.0", "1.2.0", "1.1.0"))
  expect_equal(all$text[2], "`fit()` no longer drops the last row.")
  keep <- pkgdossier:::news_after(all$version, "1.1.0")
  expect_equal(keep, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("plain-text NEWS headings and bullets are read", {
  lines <- c(
    "Changes in version 2.0-1", "------------------------", "",
    "  o summary.myfit() reports the variance basis.", "",
    "Changes in version 2.0-0", "", "  o everything else"
  )
  all <- pkgdossier:::parse_news(lines, md = FALSE)
  expect_equal(all$version, c("2.0-1", "2.0-0"))
  expect_equal(pkgdossier:::news_after(all$version, "2.0-0"), c(TRUE, FALSE))
})

test_that("numbered items are bullets (data.table's NEWS.md)", {
  lines <- c(
    "## data.table news and updates", "",
    "## data.table [v1.18.6.1](https://example.org/47) 22 August 2026", "", "### NEW FEATURES", "",
    "1. Rows can now be deleted by reference using `DT[i, .ROW := NULL]`.", "",
    "### BUG FIXES", "", "1. `rbindlist()` no longer raises an error", "   upon very wide lists.",
    "2) a second fix in 1.2.3.", "",
    "## data.table [v1.18.4](https://example.org/45)", "", "1. older fix."
  )
  all <- pkgdossier:::parse_news(lines)
  expect_equal(all$version, c("1.18.6.1", "1.18.6.1", "1.18.6.1", "1.18.4"))
  expect_equal(all$text[2], "`rbindlist()` no longer raises an error upon very wide lists.")
  expect_equal(sum(pkgdossier:::news_after(all$version, "1.18.4")), 3L)
  # in a plain NEWS file a numbered item is not taken for a version heading
  plain <- pkgdossier:::parse_news(c("Changes in 2.0", "", "1. fixed a bug from 1.9.1"), md = FALSE)
  expect_equal(plain$version, "2.0")
})

test_that("functions a step uses and the bullets that name them", {
  ns <- c("fit", "report", "print.ud_report", "summary.myfit", "data_prep")
  expect_setequal(pkgdossier:::step_functions("m <- pkg::fit(d)\nreport(m)", "lm", ns),
                  c("fit", "report"))
  expect_setequal(pkgdossier:::step_functions("report(3)", "ud_report", ns),
                  c("report", "print.ud_report"))
  m <- pkgdossier:::mentions_function
  expect_true(m("`fit()` changed", "fit"))
  expect_true(m("fit (x) changed", "fit"))
  expect_true(m("pkg::fit(x) changed", "fit"))
  expect_true(m("the `fit` argument", "fit"))
  expect_false(m("a better fit for small data", "fit"))   # a bare English word is not a mention
  expect_false(m("refit() is new", "fit"))
  expect_true(m("summary.myfit reports more", "summary.myfit"))
  expect_true(m("data_prep is faster", "data_prep"))
})

test_that("read_news() reports a missing NEWS file", {
  dir <- tempfile("nonews")
  dir.create(dir)
  n <- pkgdossier:::read_news(dir, "1.0.0")
  expect_null(n$bullets)
  expect_match(n$note, "no NEWS file")
})

test_that("functions are traced through the objects they produce", {
  ns <- c("fit_model", "prep", "summary.dfit")
  tr <- pkgdossier:::trace_step
  s1 <- tr("d <- prep(raw)\nfit <- fit_model(d)", character(), ns, list())
  expect_setequal(s1$functions, c("prep", "fit_model"))
  expect_equal(s1$creators$d, "prep")
  expect_setequal(s1$creators$fit, c("fit_model", "prep"))   # d came from prep()
  s2 <- tr("fit$coef", character(), ns, s1$creators)
  expect_setequal(s2$functions, c("fit_model", "prep"))
  s3 <- tr("summary(fit)", "dfit", ns, s1$creators)
  expect_setequal(s3$functions, c("summary.dfit", "fit_model", "prep"))
  s4 <- tr("x <- 1\ny <- x + 1", character(), ns, list())
  expect_length(s4$functions, 0L)
  expect_equal(s4$creators$y, character())
})

test_that("api_diff labels every kind of signature change", {
  sig <- function(args, defaults) list(type = "function", args = args, defaults = defaults)
  base <- list(gone = sig("x", NA), f = sig(c("a", "b", "c"), c(NA, "1", "TRUE")),
               g = sig(c("x", "y"), c(NA, NA)), data_obj = list(type = "data.frame", args = character(), defaults = character()))
  cand <- list(f = sig(c("a", "c", "d", "e"), c(NA, "FALSE", "2", NA)),
               g = sig(c("y", "x"), c(NA, NA)), new = sig("z", NA),
               data_obj = list(type = "data.frame", args = character(), defaults = character()))
  d <- pkgdossier:::api_diff(base, cand)
  key <- paste(d$step, d$kind, d$path)
  expect_setequal(key, c("gone export_removed gone", "new export_added new",
                         "f argument_removed b", "f argument_added d", "f argument_new_required e",
                         "f default_changed c", "g arguments_reordered g"))
  expect_equal(d$base[d$kind == "default_changed"], "TRUE")
  expect_equal(d$cand[d$kind == "default_changed"], "FALSE")
  expect_null(pkgdossier:::api_diff(base, base))
  expect_null(pkgdossier:::api_diff(NULL, cand))
})

test_that("an export that stops being a function is a removed export", {
  base <- list(f = list(type = "function", args = "x", defaults = NA_character_))
  cand <- list(f = list(type = "data.frame", args = character(), defaults = character()))
  d <- pkgdossier:::api_diff(base, cand)
  expect_equal(d$kind, "export_removed")
  expect_equal(d$detail, "the export changed type")
  expect_match(pkgdossier:::read_news(NULL, "1.0")$note, "not available")
  expect_equal(nrow(pkgdossier:::parse_news(c("no bullets here", "at all"))), 0L)
})

test_that("each difference keeps the three bullets most about it", {
  b <- c("`fit()` is faster.", "`fit()` gains `weights`.", "`fit()` reports whether the model converged.",
         "`fit()` plots get a subtitle.", "`fit()` checks its input.")
  r <- pkgdossier:::rank_news
  expect_equal(r(b, "value_moved", "m$diagnostics$converged")[1], b[3])
  expect_length(r(b, "value_moved", "m$diagnostics$converged"), 3L)
  expect_equal(r(b, "plot_changed", "plot")[1], b[4])
  expect_equal(r(b, "slower", "time")[1], b[1])
  expect_equal(r(b, "output_changed", "printed"), b[1:3])   # nothing specific: NEWS order
  expect_equal(r(b[2], "value_moved", "m$x"), b[2])          # one bullet
  expect_length(r(character(), "value_moved", "m$x"), 0L)
  # the object's own name is not a token: m$fit$coef ranks "coef", not "fit"
  expect_equal(r(c("`fit()` changed.", "coef now unnamed"), "value_moved", "fit$coef")[1], "coef now unnamed")
})

test_that("inst/NEWS.Rd is read through the installed news database", {
  skip_on_cran()
  src <- file.path(tempfile("udnews-"), "udnews")
  dir.create(file.path(src, "R"), recursive = TRUE)
  dir.create(file.path(src, "inst"))
  writeLines(c("Package: udnews", "Version: 1.1.0", "Title: News Fixture",
               "Description: A package whose NEWS is in Rd.",
               "Authors@R: person('Test', 'Fixture', role = c('aut', 'cre'), email = 'fixture@example.org')",
               "License: MIT + file LICENSE"), file.path(src, "DESCRIPTION"))
  writeLines(c("YEAR: 2026", "COPYRIGHT HOLDER: pkgdossier authors"), file.path(src, "LICENSE"))
  writeLines("export(f)", file.path(src, "NAMESPACE"))
  writeLines("f <- function() 2", file.path(src, "R", "f.R"))
  writeLines(c("\\name{NEWS}", "\\title{News for Package 'udnews'}",
               "\\section{Changes in version 1.1.0}{", "  \\itemize{",
               "    \\item \\code{f()} now returns 2.", "    \\item Faster start-up.", "  }", "}",
               "\\section{Changes in version 1.0.0}{", "  \\itemize{", "    \\item First release.", "  }", "}"),
             file.path(src, "inst", "NEWS.Rd"))
  lib <- tempfile("udnews-lib")
  dir.create(lib)
  pkgdossier:::rcmd_or_stop("INSTALL", c(paste0("--library=", lib), src), wd = dirname(src))
  n <- pkgdossier:::read_news(src, "1.0.0", pkg = "udnews", lib = lib)
  expect_equal(n$file, file.path("inst", "NEWS.Rd"))
  expect_equal(n$bullets$text, c("f() now returns 2.", "Faster start-up."))
  expect_match(n$note, "2 bullet(s) in inst/NEWS.Rd after 1.0.0", fixed = TRUE)
  expect_true(pkgdossier:::mentions_function(n$bullets$text[1], "f"))
  expect_match(pkgdossier:::read_news(src, "1.0.0")$note, "not read")  # no library given
})

test_that("long values are shortened with an ellipsis the session can print", {
  long <- strrep("x", 60)
  withr::with_locale(c(LC_CTYPE = "C"), expect_equal(pkgdossier:::trim(long, 10), "xxxxxxx..."))
})

test_that("assignments wrapped in parentheses are traced", {
  ns <- c("glmer")
  s1 <- pkgdossier:::trace_step("(gm1 <- glmer(y ~ x, d))", character(), ns, list())
  expect_equal(s1$creators$gm1, "glmer")
  expect_equal(pkgdossier:::trace_step("anova(gm1)", character(), ns, s1$creators)$functions, "glmer")
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  expect_equal(e$assigned_names("(x <- 1)\n((y <- 2))"), c("x", "y"))
})
