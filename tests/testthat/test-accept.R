test_that("glob_match handles wildcards, literal metacharacters and empty patterns", {
  g <- pkgdossier:::glob_match
  expect_equal(g("est$main", c("est$main", "estXmain")), c(TRUE, FALSE))
  expect_equal(g("fit_*", c("fit_a", "fit", "xfit_a")), c(TRUE, FALSE, FALSE))
  expect_equal(g("a?c", c("abc", "ac")), c(TRUE, FALSE))
  expect_equal(g("*", c("x", NA)), c(TRUE, TRUE))
  expect_equal(g("", c("x", NA)), c(TRUE, TRUE))
  expect_equal(g(NA, "x"), TRUE)
  expect_equal(g("x", NA), FALSE)
})

test_that("accepted differences are marked, left out of counts, and checked", {
  cmp <- get_res()$cmp
  d <- get_res()$d
  rules <- tempfile(fileext = ".csv")
  accept_differences(differences(cmp, kind = "plot_changed"), rules, reason = "new colour")
  accept_differences(differences(cmp, kind = "field_removed"), rules)
  accept_differences(data.frame(kind = "value_moved", scenario = "*", step = "nope", path = "",
                                cand = "*", stringsAsFactors = FALSE), rules)
  expect_equal(nrow(utils::read.csv(rules)), 3L)
  accept_differences(differences(cmp, kind = "plot_changed"), rules)  # duplicates are dropped
  expect_equal(nrow(utils::read.csv(rules)), 3L)

  acc <- compare_runs(d, accept = rules)
  a <- differences(acc, accepted = TRUE)
  expect_setequal(a$kind, c("plot_changed", "field_removed"))
  expect_equal(a$accepted_reason[a$kind == "plot_changed"], "new colour")
  expect_equal(a$accepted_reason[a$kind == "field_removed"], "accepted")
  expect_equal(nrow(differences(acc, accepted = FALSE)), nrow(differences(cmp)) - 2L)
  expect_equal(nrow(acc$meta$accept$unused), 1L)  # the rule for step "nope"
  out <- capture.output(print(acc))
  expect_true(any(grepl("2 difference(s) accepted by 3 rule(s)", out, fixed = TRUE)))
  expect_true(any(grepl("1 rule(s) match nothing now", out, fixed = TRUE)))
  expect_false(any(grepl("^  field_removed ", out)))
  expect_match(write_dossier_md(acc), "2 difference(s) accepted", fixed = TRUE)

  # a value accepted at 0.6 shows up again if the candidate's value changes
  rule <- data.frame(kind = "value_moved", scenario = "intro", step = "estimate", path = "est$main",
                     cand = "0.7", stringsAsFactors = FALSE)
  expect_false(any(differences(compare_runs(d, accept = rule))$accepted))
  rule$cand <- "0.6"
  expect_equal(sum(differences(compare_runs(d, accept = rule))$accepted), 1L)

  expect_error(check_differences(acc, max_severity = 1), "not accepted")
  expect_error(check_differences(cmp, max_severity = 1), "field_removed api/result res\\$b")
  expect_true(check_differences(acc, kind = c("plot_changed", "field_removed"), max_severity = 4))
  # a kind named is checked whatever its severity
  expect_error(check_differences(cmp, "output_changed"), "of kind output_changed are not accepted")
  expect_error(check_differences(cmp), "of severity 1 or more severe are not accepted")
  expect_error(compare_runs(d, accept = data.frame(kind = "x")), "lack the column")
})
