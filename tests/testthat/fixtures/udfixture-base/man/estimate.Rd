\name{estimate}
\alias{estimate}
\title{Estimate the main quantity}
\usage{
estimate()
}
\value{A list with elements \code{main} and \code{small}.}
\description{Returns the estimates.}
\examples{
est <- estimate()
est$main
\donttest{
round(est$small)
}
\dontrun{
old_failure()
}
}
