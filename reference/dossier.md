# Describe an upgrade dossier

A dossier runs the code users learned from a released version (the
baseline) unchanged under that version and under a candidate, each
installed in its own library, and compares everything the code produces.
`dossier()` only describes the comparison; the stages do the work, each
usable alone and each caching its results in the work folder:

## Usage

``` r
dossier(
  pkg,
  base = cran_release(),
  candidate = local_path("."),
  scenarios = list(from_vignettes(), from_examples()),
  work = file.path(tempdir(), paste0("pkgdossier-", pkg)),
  reps = 3L,
  order = c("abba", "ab"),
  seed = 20261027L,
  reseed = c("step", "scenario"),
  language = "en",
  width = 80L,
  dpi = 100,
  caps = list(),
  skip_classes = default_skip_classes(),
  deps = deps_shared(),
  base_tag = NULL,
  repo = NULL
)
```

## Arguments

- pkg:

  Package name.

- base, candidate:

  Sources, see
  [sources](https://hdbt.github.io/pkgdossier/reference/sources.md): the
  release users have (baseline) and the version they would upgrade to
  (candidate). The candidate defaults to the package folder this is
  called from, `local_path(".")`; a folder's path is made absolute here,
  so a later [`setwd()`](https://rdrr.io/r/base/getwd.html) does not
  change which folder is meant.

- scenarios:

  A scenario source or a list of them:
  [`from_vignettes()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
  (the baseline's vignettes),
  [`from_examples()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md)
  (its help-page examples), both by default, and
  [`scenario_file()`](https://hdbt.github.io/pkgdossier/reference/from_vignettes.md).

- work:

  Work folder holding downloads, builds, libraries, runs and results.
  Defaults to a folder in
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). A work folder
  inside a
  [`local_path()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  candidate must be listed in its `.Rbuildignore`, or `R CMD build`
  would copy it into the build.

- reps:

  Timed repeats per timed step in each run. `0` times nothing beyond the
  captured run (a quick smoke run).

- order:

  `"abba"` runs base, candidate, candidate, base, so that drift in
  machine load hits both versions alike and each version runs twice
  (which is how unseeded steps are found). `"ab"` runs each version
  once.

- seed:

  Seed set at the start of every scenario and, with `reseed = "step"`,
  before every step.

- reseed:

  `"step"` sets the seed before every step, so a change in how many
  random numbers one step draws does not move the numbers of later
  steps: each difference stays where it arises. `"scenario"` sets it
  once per scenario, so a vignette that calls
  [`set.seed()`](https://rdrr.io/r/base/Random.html) in one chunk and
  draws in the next gives the numbers its readers saw. Timed repeats
  always start from the random-number state of the step's captured run.

- language:

  Value of the `LANGUAGE` environment variable in the child processes,
  so that messages and warnings compare across locales. `NULL` leaves it
  alone.

- width:

  Console width (`options(width)`) in the child processes.

- dpi:

  Resolution of the PNG plots.

- caps:

  Size caps for collecting numbers, any of `max_depth` (nesting depth
  for visible values, default 6), `assign_depth` (for assigned objects,
  3), `max_rows` (data-frame rows, 200), `max_length` (vector
  length, 200) and `max_cells` (matrix cells, 400). What a cap skips is
  reported.

- skip_classes:

  Classes whose objects are not walked when collecting numbers and
  element names (heavy model fits, plots, environments). See
  [`default_skip_classes()`](https://hdbt.github.io/pkgdossier/reference/default_skip_classes.md).

- deps:

  Where the dependencies come from:
  [`deps_shared()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  (the current library paths, the default),
  [`deps_cran()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  (current CRAN versions, in the work folder) or
  [`deps_snapshot()`](https://hdbt.github.io/pkgdossier/reference/deps.md)
  (CRAN as on the baseline's release date). See
  [deps](https://hdbt.github.io/pkgdossier/reference/deps.md).

- base_tag:

  Optional: a git tag to check the baseline's `R/` folder against (line
  endings ignored), and to count the candidate's commits since.

- repo:

  The git repository holding `base_tag`. Defaults to the candidate's: a
  [`git_ref()`](https://hdbt.github.io/pkgdossier/reference/sources.md)'s
  repository, or the git work tree around a
  [`local_path()`](https://hdbt.github.io/pkgdossier/reference/sources.md)
  (for a package in a subfolder of its repository, that subfolder is
  compared). Set it for a tarball or CRAN candidate.

## Value

An object of class `pkgdossier_dossier`.

## Details

1.  [`prepare_versions()`](https://hdbt.github.io/pkgdossier/reference/prepare_versions.md)
    fetches, builds and installs both versions;

2.  [`run_scenarios()`](https://hdbt.github.io/pkgdossier/reference/run_scenarios.md)
    runs the scenarios under each version;

3.  [`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md)
    compares the runs and labels every difference;

4.  [`write_dossier_html()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_html.md),
    [`write_dossier_json()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_json.md)
    and
    [`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
    write the results.

[`run_dossier()`](https://hdbt.github.io/pkgdossier/reference/run_dossier.md)
calls them all. Everything that shapes the runs is set here, so
`print(d)` shows all of it and the stages take only how they run (time
limits, workers, whether to ask); the comparison's tolerances belong to
[`compare_runs()`](https://hdbt.github.io/pkgdossier/reference/compare_runs.md),
which is cheap to call again on stored runs.

## Examples

``` r
# describing a dossier reads and downloads nothing
dossier("MAIHDA",
  base = cran_version("0.2.1"),
  candidate = git_ref("path/to/MAIHDA", "main"),
  work = file.path(tempdir(), "dossier-0.3.0")
)
#> <pkgdossier dossier> MAIHDA
#>   base:      CRAN version 0.2.1
#>   candidate: git path/to/MAIHDA @ main
#>   scenarios: baseline vignettes; baseline help-page examples
#>   runs:      abba, 3 timed repeats per timed step, seed 20261027 set per step
#>   capture:   width 80, 100 dpi, LANGUAGE en
#>   collect:   default caps; default skipped classes
#>   deps:      shared, from the current library paths
#>   work:      /tmp/RtmpLetcBC/dossier-0.3.0

# the whole pipeline, on the small package bundled for examples
# \donttest{
d <- example_dossier()
prepare_versions(d)
#> base: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.0.0.tar.gz unchanged, reusing the installed copy
#> cand: tarball /home/runner/work/_temp/Library/pkgdossier/extdata/udfixture_1.1.0.tar.gz unchanged, reusing the installed copy
#> base udfixture 1.0.0  sha256 fd0de4ff9fef  packaged 2026-11-06 15:33:45 UTC; root
#> cand udfixture 1.1.0  sha256 0eaefa1ba295  packaged 2026-11-06 15:33:45 UTC; root
run_scenarios(d)
#> Running 3 scenario(s), 30 steps, under udfixture 1.0.0 and 1.1.0 in 4 runs (abba), 3 timed repeats per timed step; a step's run stops after 300 s (step_timeout)
#> Machine before: CPU 0% busy, 0 other R processes
#> [1/4] base_a: up to date, reused
#> [2/4] cand_a: up to date, reused
#> [3/4] cand_b: up to date, reused
#> [4/4] base_b: up to date, reused
cmp <- compare_runs(d)
cmp
#> <pkgdossier comparison> udfixture 1.0.0 -> 1.1.0
#> 3 scenario(s), 28 step(s) compared, 2 not run; abba runs, 3 timed repeats per timed step
#> Verdict: 4 severe changes (field_removed, error_new, argument_new_required, argument_removed); 19 other differences; 1 unstable step; 1 scenario problem.
#> 
#> Differences by kind (severity):
#>   unstable                  0     1 in 1 step(s)
#>   error_new                 1     1 in 1 step(s)
#>   field_removed             1     1 in 1 step(s)
#>   argument_removed          1     1 in 1 step(s)
#>   argument_new_required     1     1 in 1 step(s)
#>   condition_class_changed   2     2 in 2 step(s)
#>   value_moved               2     4 in 4 step(s), 3 distinct
#>   warning_new               2     1 in 1 step(s)
#>   default_changed           2     1 in 1 step(s)
#>   output_changed            3     3 in 3 step(s)
#>   plot_changed              3     1 in 1 step(s)
#>   slower                    3     1 in 1 step(s)
#>   faster                    3     1 in 1 step(s)
#>   warning_gone              4     1 in 1 step(s)
#>   field_added               4     1 in 1 step(s)
#>   error_fixed               4     1 in 1 step(s)
#>   argument_added            4     1 in 1 step(s)
#>   export_added              4     1 in 1 step(s)
#> 
#> NEWS candidates (3 bullet(s) in NEWS.md after 1.0.0): 18 of 24 difference(s) in steps no NEWS bullet names.
#> 
#> 2 difference(s) in udfixture's own DESCRIPTION fields (Version, Packaged, ...), as an example printing sessionInfo() shows them, are not listed.
#> 
#> Coverage: the scenarios use 17 of 18 exported functions. Not used: new_helper.
#> 
#> Scenario problems (error under both versions): api/err_class
#> 
#> Most severe (severity 0-2), identical changes once:
#>   unstable                 api/noisy : differs between runs -> differs between runs  [no NEWS]
#>   field_removed            api/result res$b  [no NEWS]
#>   error_new                api/check error: - -> `x` must be character
#>   argument_new_required    (namespace)/extend_result keep: - -> (required)  [no NEWS]
#>   argument_removed         (namespace)/warn_gone verbose: TRUE -> -  [no NEWS]
#>   value_moved              est$main (2 steps): 0.5 -> 0.6
#>   value_moved              ex_estimate/ex-02 (value): 0.5 -> 0.6
#>   warning_new              api/warn_new warning: - -> results may be unstable  [no NEWS]
#>   condition_class_changed  api/warn_class warning: simpleWarning/warning/condition -> slowWarning/warning/condition  [no NEWS]
#>   condition_class_changed  api/err_class error: simpleError/error/condition -> inputError/error/condition  [no NEWS]
#>   value_moved              api/label lab: alpha -> beta  [no NEWS]
#>   default_changed          (namespace)/report digits: 2 -> 3  [no NEWS]
write_dossier_html(cmp, dir = file.path(tempdir(), "dossier-page"))
# }
```
