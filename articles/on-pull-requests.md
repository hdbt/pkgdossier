# On pull requests

A dossier before a release finds what users would meet, but by then the
changes behind it are weeks old. Run on every pull request, it shows
each change’s effect while the change is still under review: a comment
lists what users of the release would meet if the pull request were
merged and released, and the check fails when a severe change is neither
announced in NEWS nor accepted.

## Set it up

pkgdossier ships a GitHub Actions workflow. Copy it into your package’s
repository:

``` r

file.copy(system.file("github", "pkgdossier.yaml", package = "pkgdossier"),
          ".github/workflows/pkgdossier.yaml")
```

Commit and push it; it runs on the next pull request. Until pkgdossier
is on CRAN, change `any::pkgdossier` in the workflow to
`github::hdbt/pkgdossier`.

## What it does

On each pull request the workflow:

1.  checks the pull request out into the folder `candidate`, and
    installs R, pandoc and the pull request’s dependencies;
2.  runs the dossier: the pull request’s code against the CRAN release,
    with the release’s vignettes and help-page examples, applying the
    rules in `candidate/dev/dossier/accepted.csv` if the file exists;
3.  uploads the HTML report as the artifact `dossier-page`;
4.  posts the summary as a comment on the pull request, and on later
    pushes updates that comment rather than adding another;
5.  fails the check when a severe difference is left that is neither
    accepted nor named by a NEWS bullet.

The comment is the text
[`write_dossier_md()`](https://hdbt.github.io/pkgdossier/reference/write_dossier_md.md)
writes. For the example dossier bundled with pkgdossier it reads:

``` r

d <- example_dossier()
cmp <- run_dossier(d, html = NULL, json = NULL, open = FALSE, quiet = TRUE)
cat(write_dossier_md(cmp))
```

    <!-- pkgdossier -->
    ### pkgdossier: udfixture 1.0.0 -> 1.1.0

    3 scenario(s), 28 step(s) compared, 2 not run. **24 difference(s)** in 23 step(s). 18 of them in steps no NEWS bullet names.

    | Kind | Severity | Differences | Steps |
    |---|---:|---:|---:|
    | unstable | 0 | 1 | 1 |
    | error_new | 1 | 1 | 1 |
    | field_removed | 1 | 1 | 1 |
    | argument_removed | 1 | 1 | 1 |
    | argument_new_required | 1 | 1 | 1 |
    | condition_class_changed | 2 | 2 | 2 |
    | value_moved | 2 | 4 | 4 |
    | warning_new | 2 | 1 | 1 |
    | default_changed | 2 | 1 | 1 |
    | output_changed | 3 | 3 | 3 |
    | plot_changed | 3 | 1 | 1 |
    | slower | 3 | 1 | 1 |
    | faster | 3 | 1 | 1 |
    | warning_gone | 4 | 1 | 1 |
    | field_added | 4 | 1 | 1 |
    | error_fixed | 4 | 1 | 1 |
    | argument_added | 4 | 1 | 1 |
    | export_added | 4 | 1 | 1 |

    #### Most severe (severity 0-2)

    Identical changes in several steps are listed once, with the number of steps.

    | Kind | Where | 1.0.0 | 1.1.0 | NEWS |
    |---|---|---|---|---|
    | unstable | api/noisy | differs between runs | differs between runs | none |
    | field_removed | api/result `res$b` | - | - | none |
    | error_new | api/check `error` | - | `x` must be character | `check_input()` now requires character input and errors o... |
    | argument_new_required | (namespace)/extend_result `keep` | - | (required) | none |
    | argument_removed | (namespace)/warn_gone `verbose` | TRUE | - | none |
    | value_moved | `est$main` in 2 steps | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
    | value_moved | ex_estimate/ex-02 `(value)` | 0.5 | 0.6 | `estimate()` returns a main estimate of 0.6 (was 0.5). |
    | warning_new | api/warn_new `warning` | - | results may be unstable | none |
    | condition_class_changed | api/warn_class `warning` | simpleWarning/warning/condition | slowWarning/warning/condition | none |
    | condition_class_changed | api/err_class `error` | simpleError/error/condition | inputError/error/condition | none |
    | value_moved | api/label `lab` | alpha | beta | none |
    | default_changed | (namespace)/report `digits` | 2 | 3 | none |

    Coverage: the scenarios use 17 of 18 exported functions. Not used: `new_helper`.

    Scenario problems (error under both versions): api/err_class.

    Not compared, because two runs of one version disagree: 1.0.0 api/noisy; 1.1.0 api/noisy.

    <sub>pkgdossier 0.1.0, R version 4.6.2 (2026-10-29), abba runs, 3 timed repeat(s) per timed step.</sub>

In the workflow it ends with a link to the run, where the report can be
downloaded.

## The baseline

The workflow compares each pull request with the CRAN release. The
comment answers “what will the next release do to its users?”, so it
also lists changes merged before this pull request. Accept those once
they are settled (see below), and each pull request’s comment shows what
is new.

To see only what one pull request changes, or for a package not on CRAN
yet, compare with the main branch instead: check out with
`fetch-depth: 0` and give the dossier
`base = git_ref("candidate", "origin/main")`. The scenarios are then the
main branch’s vignettes and examples.

## Accept on the pull request

When the check fails, each difference it lists is a bug to fix, a NEWS
bullet to write in the same pull request, or a change to accept.
Accepted differences are rules in `dev/dossier/accepted.csv`, committed
with the pull request, so reviewers see what was accepted and why in the
diff.

Write the rules with
[`accept_differences()`](https://hdbt.github.io/pkgdossier/reference/accept_differences.md)
after running the dossier on the pull request’s branch (see [Before a
release](https://hdbt.github.io/pkgdossier/articles/before-a-release.md)),
or by hand, from the comment. A rule has six columns. The first five are
matched against a difference, and an empty field or `*` matches
anything:

``` r

rules <- file.path(tempdir(), "accepted.csv")   # in your repository: dev/dossier/accepted.csv
writeLines(c(
  "kind,scenario,step,path,cand,reason",
  "unstable,api,noisy,,*,noisy() re-seeds from the clock",
  "argument_removed,(namespace),warn_gone,verbose,*,verbose had no effect"
), rules)
```

With these rules, the workflow’s last step still fails, for the two
severe changes left:

``` r

cmp <- compare_runs(d, accept = rules)
check_differences(cmp, max_severity = 1, no_news = TRUE)
#> Error:
#> ! 2 difference(s) of severity 1 or more severe and that no NEWS bullet names are not accepted:
#>   field_removed api/result res$b
#>   argument_new_required (namespace)/extend_result keep
#> Accept the intended ones with accept_differences().
```

Keep the file in a folder that `.Rbuildignore` excludes and that git
tracks: if your `.gitignore` lists `dev/`, choose another folder and
change the path in the workflow.

After a release, the release is the new baseline and the old rules match
nothing. The summary then says how many rules may be stale; empty the
file.

## The check

The workflow’s last step is

``` r

pkgdossier::check_differences(cmp, max_severity = 1, no_news = TRUE)
```

It fails for severe changes (and unstable steps) that are neither
accepted nor in a step a NEWS bullet names. It runs after the comment,
so the report and the comment are there either way. To be stricter, use
`max_severity = 2`, so that moved numbers and new warnings fail it too,
or drop `no_news = TRUE`, so that a NEWS bullet alone does not pass a
change. To report without failing, remove the step.

## Adjusting the run

The dossier step is a few lines of R in the workflow; change them as you
would at the console.

- **Scenario files**: the pull request is checked out in `candidate`, so
  a scenario file in your repository is
  `scenario_file("candidate/dev/dossier/scenarios.R")`, added to the
  dossier’s `scenarios` (see [Writing
  scenarios](https://hdbt.github.io/pkgdossier/articles/writing-scenarios.md)).
- **Time**: the dossier installs two versions and runs every vignette
  and example four times. The workflow gives the whole run an hour
  (`timeout = 3600`) and each step five minutes. For a faster run,
  `dossier(..., reps = 0)` makes no timed repeats and
  `run_dossier(..., workers = 2)` makes two runs at once; both leave
  steps unlabelled `slower` or `faster`.
- **Dependencies**: both versions run against the packages installed for
  the pull request. If the release needs one the pull request no longer
  does, the run stops and names it; add it to `extra-packages`.

## Pull requests from forks

GitHub does not give workflows started from forks write access to the
pull request, so for those the comment is skipped. The report is still
uploaded and the check still runs.
