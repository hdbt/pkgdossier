# Run the scenarios under both versions

Each run is a fresh R process (via callr) whose library path starts with
that version's library; the run checks that the package was loaded from
there. With `order = "abba"` the runs go base, candidate, candidate,
base, so drift in machine load hits both versions alike, and each
version runs twice so that steps whose results differ between two runs
of the same version (unseeded randomness) are found.

## Usage

``` r
run_scenarios(
  d,
  force = FALSE,
  timeout = Inf,
  step_timeout = 300,
  workers = 1L,
  quiet = FALSE
)
```

## Arguments

- d:

  A
  [`dossier()`](https://hdbt.github.io/pkgdossier/reference/dossier.md);
  its settings say how the runs are made.

- force:

  Repeat runs even when their results are up to date.

- timeout:

  Seconds one run (one version, all scenarios) may take before it is
  stopped, which stops `run_scenarios()` with the end of the run's log.
  (A step that crashes R is recorded and skipped; see below.)

- step_timeout:

  Seconds one execution of a step may take: its captured run, or one of
  its timed repeats. A step that takes longer is stopped and recorded as
  an error, "timed out after N s", and the run goes on with the next
  step: the run's process is stopped and started again from a fresh run
  folder, skipping that step, so every step before it runs again and the
  steps after it in its scenario run without what it would have created.
  The version's other run does not start the step again once this run
  has finished. A notice comes at half the limit. The default of 300 s
  is far beyond what a vignette chunk or an example normally takes, so
  it catches only steps that hang; `Inf` sets no limit. A step during
  which the run's R process dies (a segfault in compiled code, a call to
  [`quit()`](https://rdrr.io/r/base/quit.html)) is recorded as an error,
  "R stopped in this step", with the reason R gave, and the run goes on
  the same way: the process is started again and the step skipped. A
  step whose output pkgdossier itself fails to capture is recorded the
  same way, with R's message. A process that dies outside any step stops
  the run with the end of its log. The run plan lists, per run, the
  steps that timed out or crashed, and how many runs went at once while
  it ran.

- workers:

  How many runs may go at once (a whole number). Runs that went at the
  same time competed for the machine, so their timings are shown but no
  step is labelled `slower` or `faster`; use it when the timings do not
  matter (a quick check in CI, `reps = 0`). ABBA order is kept: base and
  candidate run together, then candidate and base.

- quiet:

  Suppress progress messages: a plan line, each run's end (and, after
  the first, an estimate of the time left), notices about slow steps,
  and outside an interactive session a line every minute.

## Value

The run plan (a data frame with one row per run), invisibly.

## Details

Per step the run keeps the console transcript (output and messages, in
order), the printed form of visible values, warnings and errors with
their classes, the numbers and element names of the values (for steps
with `values = TRUE`), plots as PNG files at the step's figure size, the
elapsed and CPU time of the captured run and, for timed steps, `reps`
more timings. The seed is set as the dossier's `reseed` says, and timed
repeats start from the random-number state of the step's captured run.

Scenarios run one after another in the same process, but each starts
from the same session state: options, attached packages, environment
variables, the colour palette, the random-number kind and the working
directory that one scenario sets are put back before the next. Graphics
parameters cannot leak (each step draws on its own device); namespaces a
scenario loads stay loaded.

Paths and memory addresses change from run to run: in what a step
prints, warns or returns as text, the session's temporary folder is
written `<tempdir>`, the run's folder `<run>`, a temporary file name (as
[`tempfile()`](https://rdrr.io/r/base/tempfile.html) makes, also bare,
as `dir(tempdir())` lists it) `<tempfile>`, and an address (a formula's
`<environment: 0x55e7ad2f3268>`, or `0x` and 8 to 16 hex digits as
[`tracemem()`](https://rdrr.io/r/base/tracemem.html) and data.table's
`address()` show them) `0x<address>`, so a step that shows one still
compares. A [`system.time()`](https://rdrr.io/r/base/system.time.html)
or [`proc.time()`](https://rdrr.io/r/base/proc.time.html) result a step
shows as its value, or keeps in a variable, is left out of its printed
output and numbers: it differs in every run, and the runner times each
step itself. One printed inside another object or with an explicit
[`print()`](https://rdrr.io/r/base/print.html), and output a package
prints about its own timings, still differ, and the step is reported as
unstable.

Vignette scenarios run from a fresh copy of the baseline's `vignettes/`
folder, so code that reads a file shipped next to the vignette finds it;
scenario-file scenarios run from the run's own folder.

The scenarios are resolved once (from the baseline's vignettes, help
pages and the scenario files) and saved in the work folder, so every run
sees identical code. A run whose results already exist is reused unless
`force = TRUE`, as long as nothing that shapes its results has changed:
the installed version, the scenarios' code, the dossier's run settings
(`reps`, `seed`, `reseed`, `language`, `width`, `dpi`, `caps`,
`skip_classes`, `deps`), R, the versions of the packages that version
and its scenarios load (and of evaluate, which captures them), and
pkgdossier's runner. The installs must match the dossier: after changing
its dependencies, or R, call
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
first. After fixing the candidate and calling
[`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
again, only the candidate's runs are repeated. A run is also reused
under a new `step_timeout` when its own limit was the same, or lower
with no step stopped by it.

## Examples

``` r
# \donttest{
d <- example_dossier()
prepare_versions(d, quiet = TRUE)
run_scenarios(d)
#> Running 3 scenario(s), 30 steps, under udfixture 1.0.0 and 1.1.0 in 4 runs (abba), 3 timed repeats per timed step; a step's run stops after 300 s (step_timeout)
#> Machine before: CPU 0% busy, 0 other R processes
#> [1/4] base_a: up to date, reused
#> [2/4] cand_a: up to date, reused
#> [3/4] cand_b: up to date, reused
#> [4/4] base_b: up to date, reused
# }
```
