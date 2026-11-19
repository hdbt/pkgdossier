# Version 1.1.0 of the fixture, with one planted difference per function.
estimate <- function() list(main = 0.6, small = 10 * (1 + 1e-7))  # value_moved; tiny move under tol
report <- function(x, digits = 3) structure(list(value = x), class = "ud_report")  # default_changed
print.ud_report <- function(x, ...) {
  cat("Report (1.1)\n")                                            # output_changed
  cat("value:", x$value, "\n")
  invisible(x)
}
draw <- function(col = "red") graphics::plot(1:10, col = col, main = "points")  # plot_changed; argument_added
make_result <- function() list(a = 1, nested = list(x = 1))        # field_removed: b
extend_result <- function(keep) list(a = 1, c = 3)                 # field_added: c; argument_new_required
check_input <- function(x) {
  if (!is.character(x)) stop("`x` must be character")              # error_new
  x
}
old_failure <- function() 1                                        # error_fixed
warn_new <- function() {
  warning("results may be unstable")                               # warning_new
  1
}
warn_gone <- function() 1                                          # warning_gone; argument_removed
warn_class <- function() {
  warning(structure(class = c("slowWarning", "warning", "condition"),  # condition_class_changed
                    list(message = "convergence is slow", call = NULL)))
  1
}
slow <- function() {
  Sys.sleep(0.25)                                                  # slower
  invisible(NULL)
}
quick <- function() invisible(NULL)                                # faster
noisy <- function() {                                              # unstable (both versions)
  set.seed(NULL)
  stats::runif(1)
}
new_helper <- function(x) x                                        # export_added
progress <- function() {
  message("Fitting 3 models (done)")                               # output_changed: console
  invisible(1)
}
noise_print <- function() print(1.23456799, digits = 9)            # digits within tol: no difference
err_class <- function() {                                          # condition_class_changed: error
  stop(structure(class = c("inputError", "error", "condition"), list(message = "bad input", call = NULL)))
}
label_of <- function() "beta"                                      # value_moved: text
