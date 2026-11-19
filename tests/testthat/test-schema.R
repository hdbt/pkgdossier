test_that("the JSON matches the shipped schema", {
  r <- get_res()
  f <- tempfile(fileext = ".json")
  write_dossier_json(r$cmp, f)
  doc <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  expect_equal(validate_json(doc, dossier_schema()), character())

  # with accepted differences and their rules
  rules <- data.frame(kind = "plot_changed", scenario = "*", step = "*", path = "", cand = "*",
                      stringsAsFactors = FALSE)
  write_dossier_json(compare_runs(r$d, accept = rules), f)
  expect_equal(validate_json(jsonlite::fromJSON(f, simplifyVector = FALSE), dossier_schema()), character())
})

test_that("the schema check finds what is wrong", {
  f <- tempfile(fileext = ".json")
  write_dossier_json(get_res()$cmp, f)
  doc <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  doc$meta$coverage$unused <- "new_helper"      # a one-element array written as a string
  doc$differences[[1]]$kind <- "nonsense"
  doc$scenarios[[1]]$steps[[1]]$status <- NULL
  doc$meta$base$api$estimate$args <- "x"
  errs <- validate_json(doc, dossier_schema())
  expect_length(errs, 4L)
  expect_true(any(grepl("^/meta/coverage/unused: is not of type array", errs)))
  expect_true(any(grepl("^/differences/0/kind: nonsense is not an allowed value", errs)))
  expect_true(any(grepl("^/scenarios/0/steps/0: lacks status", errs)))
  expect_true(any(grepl("^/meta/base/api/estimate/args: is not of type array", errs)))
})
