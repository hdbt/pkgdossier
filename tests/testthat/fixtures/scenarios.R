# Scenario file for the pkgdossier tests: the planted differences not covered by
# the vignette, one step each.
scenario("api", title = "API checks: fields, errors, warnings, timing",
  source = "test scenario file",
  step("result", "run", res <- make_result(), values = TRUE),
  step("extended", "run", ext <- extend_result(), values = TRUE),
  step("check", "run", y <- check_input(2)),
  step("fixed", "run", z <- old_failure()),
  step("warn_new", "run", w1 <- warn_new()),
  step("warn_gone", "run", w2 <- warn_gone()),
  step("warn_class", "run", w3 <- warn_class()),
  step("slow", "fit", slow()),
  step("quick", "fit", quick()),
  step("noisy", "print", noisy(), values = TRUE),
  step("unchanged", "print", summary(c(1, 2, 3, 10)), values = TRUE),
  step("progress", "run", progress()),
  step("digits", "run", noise_print()),
  step("err_class", "run", err_class()),
  step("label", "run", lab <- label_of(), values = TRUE),
  step("tmp", "run", {
    tmp <- tempfile(fileext = ".csv")
    message("writing to ", tmp, " in ", getwd())
  }, values = TRUE),
  step("formula", "print", local(y ~ x)),
  step("meta", "run", info <- utils::packageDescription("udfixture"), values = TRUE)
)
