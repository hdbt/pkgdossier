# Version 1.0.0 of the fixture. Each function has a counterpart in 1.1.0 that
# differs in exactly one planted way (see the comments there).
estimate <- function() list(main = 0.5, small = 10)
report <- function(x, digits = 2) structure(list(value = x), class = "ud_report")
print.ud_report <- function(x, ...) {
  cat("Report\n")
  cat("value:", x$value, "\n")
  invisible(x)
}
draw <- function() graphics::plot(1:10, col = "black", main = "points")
make_result <- function() list(a = 1, b = 2, nested = list(x = 1))
extend_result <- function() list(a = 1)
check_input <- function(x) x * 2
old_failure <- function() stop("not implemented yet")
warn_new <- function() 1
warn_gone <- function(verbose = TRUE) {
  warning("argument `k` is deprecated")
  1
}
warn_class <- function() {
  warning("convergence is slow")
  1
}
slow <- function() invisible(NULL)
quick <- function() {
  Sys.sleep(0.25)
  invisible(NULL)
}
noisy <- function() {
  set.seed(NULL)
  stats::runif(1)
}
progress <- function() {
  message("Fitting 3 models")
  invisible(1)
}
noise_print <- function() print(1.23456789, digits = 9)
err_class <- function() stop("bad input")
label_of <- function() "alpha"
