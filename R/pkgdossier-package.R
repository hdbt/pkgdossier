#' @keywords internal
"_PACKAGE"

# evaluate is used by the runner script in inst/runner, sourced in the child
# processes; this import declares the use to R CMD check.
#' @importFrom evaluate evaluate
NULL
