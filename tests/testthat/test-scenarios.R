test_that("sources and dossier() only describe; they touch nothing", {
  work <- file.path(tempdir(), "ud-never-created")
  d <- dossier("pkg", base = cran_version("1.0"), candidate = git_ref("repo", "main"), work = work)
  expect_s3_class(d, "pkgdossier_dossier")
  expect_false(dir.exists(work))
  expect_equal(d$repo, "repo")
  expect_equal(format(cran_release()), "CRAN release (current)")
  expect_match(format(tarball("x.tar.gz")), "tarball x.tar.gz")
  expect_output(print(d), "candidate: git repo @ main")
  expect_error(dossier("pkg", base = "1.0", candidate = local_path(".")), "must be a source")
  dc <- dossier("pkg", candidate = local_path("."), deps = deps_cran(), work = work)
  expect_equal(dc$deps, "cran")
  expect_output(print(dc), "deps: +current CRAN versions")
  expect_false(dir.exists(work))
  expect_error(dossier("pkg", candidate = local_path("."), scenarios = list(1)), "scenarios")

  # the defaults: the folder it is called from, against the CRAN release, with its
  # vignettes and examples; the folder is made absolute when described
  dd <- withr::with_dir(tempdir(), dossier("pkg", work = work))
  expect_equal(dd$candidate$path, normalizePath(tempdir(), winslash = "/"))
  expect_equal(dd$base$type, "cran")
  expect_equal(vapply(dd$scenarios, `[[`, "", "type"), c("vignettes", "examples"))
  expect_equal(dd$repo, dd$candidate$path)   # base_tag is looked up in the folder's repository
  expect_equal(dd$caps$max_rows, 200L)
  expect_equal(dossier("pkg", work = work, caps = list(max_rows = 5))$caps$max_rows, 5L)

  # settings that would be ignored or mistyped are errors
  expect_error(dossier("pkg", work = work, deps = "cran"), "use deps_cran\\(\\)")
  expect_error(dossier("pkg", work = work, deps = list()), "deps_shared\\(\\), deps_cran\\(\\) or deps_snapshot")
  expect_error(deps_snapshot("not a date"), "year-month-day")
  expect_error(deps_cran(c("a", "b")), "one repository")
  expect_error(dossier("pkg", work = work, caps = list(max_row = 1)), "Unknown cap")
  expect_error(dossier("pkg", work = work, reps = -1), "`reps`")
  expect_error(dossier("pkg", work = 3), "`work`")
  expect_error(dossier("pkg", candidate = tarball("x.tar.gz"), base_tag = "v1", work = work),
               "base_tag` needs the git repository")
  expect_equal(dossier("pkg", candidate = tarball("x.tar.gz"), base_tag = "v1", repo = "r", work = work)$repo, "r")
  expect_output(print(deps_snapshot("2025-06-10", repos = "https://example.org")),
                "CRAN as on 2025-06-10 from https://example.org")
  expect_output(print(deps_shared()), "shared, from the current library paths")
  expect_false(dir.exists(work))
})

test_that("step() keeps the code as written, one string per top-level expression", {
  s <- step("fit", "fit", {
    x <- 1:3
    y <- mean(x)
  })
  expect_equal(s$code, c("x <- 1:3", "y <- mean(x)"))
  expect_true(s$time)
  expect_false(step("p", "print", summary(x))$time)
  expect_error(step("p", "nonsense", 1), "should be one of")
  sc <- scenario("s 1", step("a", "run", 1), step("a", "run", 2))
  expect_equal(sc$id, "s_1")
  expect_equal(vapply(sc$steps, `[[`, "", "id"), c("a", "a_1"))
  expect_error(scenario("s", 1), "must be a step")
})

test_that("scenario files register every scenario they create, in order", {
  f <- tempfile(fileext = ".R")
  writeLines(c(
    "one <- scenario('one', step('a', 'run', x <- 1))",
    "scenarios <- list(one, scenario('two', step('b', 'print', x)))"
  ), f)
  sc <- pkgdossier:::file_scenarios(f)
  expect_equal(vapply(sc, `[[`, "", "id"), c("one", "two"))
  expect_equal(sc[[2]]$steps[[1]]$code, "x")
})

test_that("scenario files in the older list format are read", {
  f <- tempfile(fileext = ".R")
  writeLines(c(
    "S <- function(id, kind, expr, label = id, values = FALSE, time = FALSE, w = 7, h = 4.5)",
    "  list(id = id, kind = kind, expr = substitute(expr), label = label, values = values,",
    "       time = time || kind == 'fit', w = w, h = h)",
    "scenarios <- list(list(id = 'g', title = 'G', source = 'v',",
    "  steps = list(S('fit', 'fit', m <- lm(mpg ~ wt, mtcars)), S('p', 'plot', plot(1), h = 10))))"
  ), f)
  sc <- pkgdossier:::file_scenarios(f)
  expect_length(sc, 1L)
  expect_equal(sc[[1]]$steps[[1]]$code, "m <- lm(mpg ~ wt, mtcars)")
  expect_true(sc[[1]]$steps[[1]]$time)
  expect_equal(sc[[1]]$steps[[2]]$h, 10)
})

test_that("vignette chunks become steps with their options", {
  sc <- pkgdossier:::vignette_scenario(test_path("fixtures", "udfixture-base", "vignettes", "intro.Rmd"))
  expect_equal(sc$id, "intro")
  expect_equal(sc$title, "Getting started with udfixture")
  ids <- vapply(sc$steps, `[[`, "", "id")
  expect_equal(ids, c("setup", "chunk-02", "estimate", "report", "draw", "data", "expected", "later", "conditional"))
  expect_equal(sc$workdir, "vignettes")
  st <- setNames(sc$steps, ids)
  expect_equal(c(st$setup$w, st$setup$h), c(3, 3))          # html_vignette defaults
  expect_equal(c(st$estimate$w, st$estimate$h), c(5, 4))    # set by opts_chunk$set()
  expect_equal(c(st$draw$w, st$draw$h), c(6, 4))            # chunk option wins
  expect_false(st$later$eval)
  expect_true(st$conditional$eval)
  expect_equal(st$conditional$eval_expr, "exists(\"never_defined\")")
  expect_true(st$report$values)
})

test_that("help-page examples become one scenario per page, one step per expression", {
  pkg <- test_path("fixtures", "udfixture-base")
  sc <- pkgdossier:::example_scenarios(pkg, from_examples())
  expect_length(sc, 1L)
  ex <- sc[[1]]
  expect_equal(ex$id, "ex_estimate")
  expect_equal(ex$title, "Estimate the main quantity")
  expect_equal(vapply(ex$steps, `[[`, "", "code"), c("est <- estimate()", "est$main", "round(est$small)"))
  expect_equal(vapply(ex$steps, `[[`, "", "id"), c("ex-01", "ex-02", "ex-03"))
  expect_true(all(vapply(ex$steps, `[[`, logical(1), "values")))
  expect_false(any(vapply(ex$steps, `[[`, logical(1), "time")))
  expect_match(ex$notes, "dontrun")
  expect_null(ex$workdir)
  expect_error(pkgdossier:::example_scenarios(pkg, from_examples(which = "nope")), "No help-page examples")
  expect_equal(format(from_examples(which = "estimate")), "baseline help-page examples (estimate)")
})

test_that("chunk headers, #| options, Rnw and stored-result flags are parsed", {
  f <- tempfile(fileext = ".Rmd")
  writeLines(c(
    "```{r first-one, fig.dim = c(4, 2), cache = TRUE}", "fit <- readRDS('fit.rds')", "```",
    "```{r}", "#| label: piped", "#| eval: false", "#| fig-width: 8", "1 + 1", "```",
    "```{python}", "print(1)", "```",
    "> ```{r quoted}", "> 2", "> ```"
  ), f)
  sc <- pkgdossier:::vignette_scenario(f)
  st <- setNames(sc$steps, vapply(sc$steps, `[[`, "", "id"))
  expect_equal(names(st), c("first-one", "piped", "chunk-03", "quoted"))
  expect_equal(c(st$`first-one`$w, st$`first-one`$h), c(4, 2))
  expect_false(st$piped$eval)
  expect_equal(st$piped$w, 8)
  expect_equal(st$piped$code, "1 + 1")
  expect_false(st$`chunk-03`$eval)
  expect_equal(st$quoted$code, "2")
  expect_true(any(grepl("cache = TRUE", sc$notes)))
  expect_true(any(grepl("reads stored results", sc$notes)))

  g <- tempfile(fileext = ".Rnw")
  writeLines(c("\\begin{document}", "<<setup, fig.width=4>>=", "x <- 1", "@", "\\end{document}"), g)
  sc2 <- pkgdossier:::vignette_scenario(g)
  expect_equal(sc2$steps[[1]]$id, "setup")
  expect_equal(sc2$steps[[1]]$w, 4)
})

test_that("line_diff pairs changed lines and value_diff applies the tolerance", {
  d <- pkgdossier:::line_diff(c("a", "b", "c"), c("a", "B", "c", "d"))
  expect_equal(vapply(d, `[[`, "", 1L), c("=", "~", "=", "+"))
  va <- data.frame(path = c("x", "y", "z", "t", "gone"), value = c(1, 1, 1, NA, 3),
                   text = c(NA, NA, NA, "a", NA), stringsAsFactors = FALSE)
  vb <- data.frame(path = c("x", "y", "z", "t", "new"), value = c(1.5, 1 + 1e-6, NA, NA, 4),
                   text = c(NA, NA, NA, "b", NA), stringsAsFactors = FALSE)
  v <- pkgdossier:::value_diff(va, vb, tol = 1e-4)
  expect_equal(vapply(v$changed, `[[`, "", 1L), c("x", "z"))
  expect_equal(v$n_tiny, 1L)
  expect_equal(v$text_changed[[1]][[1]], "t")
  expect_equal(v$only_base[[1]][[1]], "gone")
  expect_equal(v$only_cand[[1]][[1]], "new")
})

test_that("line_diff matches shared ends first and caps the quadratic part", {
  expect_equal(pkgdossier:::line_diff(c("x", "a", "b", "y"), c("x", "b", "y")),
               list(list("=", "x", "x"), list("-", "a", ""), list("=", "b", "b"), list("=", "y", "y")))
  expect_length(pkgdossier:::line_diff(character(), character()), 0L)
  expect_equal(vapply(pkgdossier:::line_diff(NULL, c("a", "b")), `[[`, "", 1L), c("+", "+"))

  # a full LCS of 10,000 lines would need a 10,000 x 10,000 table
  a <- paste("line", 1:10000)
  b <- a
  b[5000] <- "changed"
  ops <- vapply(pkgdossier:::line_diff(a, b), `[[`, "", 1L)
  expect_equal(sum(ops == "="), 9999L)
  expect_equal(which(ops == "~"), 5000L)

  big <- pkgdossier:::line_diff(paste("a", 1:3000), paste("b", 1:3000))
  expect_length(big, 3000L)
  expect_true(all(vapply(big, `[[`, "", 1L) == "~"))
})

test_that("a scenario's options, packages, env vars, palette and RNG kind do not leak", {
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  out <- tempfile("runner-")
  dir.create(file.path(out, "plots"), recursive = TRUE)
  a <- list(out = out, label = "t", seed = 1L, reseed = "step", reps = 0L, dpi = 50,
            skip_classes = default_skip_classes())
  sc <- pkgdossier:::new_scenario("leaky", list(pkgdossier:::new_step("set", "run", c(
    "options(pkgdossier.test = 1, digits = 3)",
    "suppressPackageStartupMessages(library(stats4))",
    "Sys.setenv(PKGDOSSIER_TEST = 'x')",
    "palette('R3')",
    "RNGkind('L\\'Ecuyer-CMRG')",
    "setwd(tempdir())"
  ))))
  attached <- "package:stats4" %in% search()
  before <- list(digits = getOption("digits"), palette = palette(), kind = RNGkind(), wd = getwd())
  res <- capture.output(r <- e$run_scenario(sc, a, file.path(out, "plots")))
  expect_null(r$steps$set$error)
  expect_null(getOption("pkgdossier.test"))
  expect_equal(getOption("digits"), before$digits)
  expect_equal("package:stats4" %in% search(), attached)
  expect_equal(Sys.getenv("PKGDOSSIER_TEST"), "")
  expect_equal(palette(), before$palette)
  expect_equal(RNGkind(), before$kind)
  expect_equal(getwd(), before$wd)
})

test_that("the runner flattens values, keys rows, walks S4 and reports caps", {
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  a <- list(skip_classes = default_skip_classes(), max_rows = 3L, max_length = 200L, max_cells = 400L)
  df <- data.frame(id = c("b", "a"), v = c(2, 1), stringsAsFactors = FALSE)
  f <- e$flatten_values(list(tab = df, n = c(x = 1, y = 2), s = "hi", fit = lm(mpg ~ wt, mtcars)), "", 6L, a)
  expect_equal(f$values$path, c("tab$v[b]", "tab$v[a]", "n[x]", "n[y]", "s"))
  big <- e$flatten_values(list(big = data.frame(v = 1:5)), "res", 6L, a)
  expect_equal(nrow(big$values), 0L)
  expect_match(big$capped, "res\\$big: data frame with 5 rows")
  setClass("UdThing", representation(a = "numeric", b = "list"), where = globalenv())
  on.exit(removeClass("UdThing", where = globalenv()))
  obj <- new("UdThing", a = 1, b = list(c = 2))
  expect_equal(e$flatten_values(obj, "o", 6L, a)$values$path, c("o@a", "o@b$c"))
  expect_equal(e$struct_paths(obj, "o", character()), c("o@a", "o@b", "o@b$c"))
  expect_equal(e$struct_paths(list(d = df, l = list(k = 1)), "", character()),
               c("d", "d$id", "d$v", "l", "l$k"))
  expect_equal(e$assigned_names("x <- 1\ny = 2\nz[1] <- 3\nprint(x)"), c("x", "y"))
})

test_that("repeated element names give distinct paths and no false changes", {
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  a <- list(skip_classes = character(), max_rows = 200L, max_length = 200L, max_cells = 400L)
  x <- list(a = 1, a = 2, v = c(x = 1, x = 5))
  f <- e$flatten_values(x, "", 6L, a)$values
  expect_equal(f$path, c("a", "a#2", "v[x]", "v[x]#2"))
  v <- pkgdossier:::value_diff(f, f, 1e-4)
  expect_equal(v$n_changed, 0L)
  expect_equal(v$n_compared, 4L)
  y <- e$flatten_values(list(a = 1, a = 3, v = c(x = 1, x = 5)), "", 6L, a)$values
  moved <- pkgdossier:::value_diff(f, y, 1e-4)$changed
  expect_equal(vapply(moved, `[[`, "", 1L), "a#2")
  # duplicates that reach value_diff from elsewhere are numbered there too
  raw <- data.frame(path = c("p", "p"), value = c(1, 2), text = NA_character_, stringsAsFactors = FALSE)
  expect_equal(pkgdossier:::value_diff(raw, raw, 1e-4)$n_changed, 0L)
})

test_that("printed changes confined to digits within tol are recognised", {
  ld <- pkgdossier:::line_diff
  only <- pkgdossier:::digits_only
  expect_true(only(ld(c("Estimate  1.23456", "n = 20"), c("Estimate  1.23457", "n = 20")), 1e-4))
  expect_true(only(ld("x  0.99999  -2.5e-03", "x  1.00000  -2.5e-03"), 1e-4))  # widths move
  expect_false(only(ld("Estimate 0.5", "Estimate 0.6"), 1e-4))                    # a real move
  expect_false(only(ld("Iteration 12", "Iteration 13"), 1e-4))
  expect_false(only(ld("value: 1.23456", "Value: 1.23457"), 1e-4))               # text changed
  expect_false(only(ld("a 1", c("a 1", "b 2")), 1e-4))                            # a line added
  expect_false(only(ld("a 1 2", "a 1"), 1e-4))
  expect_false(only(ld("same", "same"), 1e-4))
})

test_that("output-format figure defaults, YAML sizes and option forms are read", {
  rmd <- function(yaml, chunk) {
    f <- tempfile(fileext = ".Rmd")
    writeLines(c("---", yaml, "---", chunk, "x <- 1", "```"), f)
    pkgdossier:::vignette_scenario(f)$steps[[1]]
  }
  st <- rmd("output: html_document", "```{r a}")
  expect_equal(c(st$w, st$h), c(7, 5))
  st <- rmd("output: pdf_document", "```{r a}")
  expect_equal(c(st$w, st$h), c(6.5, 4.5))
  st <- rmd(c("output:", "  html_document:", "    fig_width: 9", "    fig_height: 2"), "```{r a}")
  expect_equal(c(st$w, st$h), c(9, 2))
  st <- rmd("title: 'T'", "```{r, label = \"named\", eval = TRUE}")
  expect_equal(st$id, "named")
  expect_true(st$eval)
  f <- tempfile(fileext = ".Rmd")
  writeLines(c("```{r}", "#| eval: yes", "#| fig-cap: 'a caption'", "1", "```"), f)
  expect_true(pkgdossier:::vignette_scenario(f)$steps[[1]]$eval)
  # #| options are YAML: a bare label with hyphens is a string, not R code
  # (stringr's vignettes), `!expr` marks R code, `[w, h]` a vector
  ch <- pkgdossier:::parse_chunk("r", c("#| label: stringr-base-r-diff", "#| fig-dim: [4, 3]",
                                        "#| eval: !expr nzchar('x')", "#| error: true",
                                        "#| fig-cap: \"Plot #1\"", "#| echo = FALSE", "1"), FALSE)
  expect_equal(ch$label, "stringr-base-r-diff")
  expect_equal(ch$opts$fig.dim, c(4, 3))
  expect_true(is.language(ch$opts$eval))
  expect_true(ch$opts$error)
  expect_equal(ch$opts$fig.cap, "Plot #1")
  expect_false(ch$opts$echo)
  expect_equal(ch$code, "1")
  # R-form lines with several options, or one option over two lines; a quoted YAML
  # value ends at its quote, and a flow list splits at commas outside quotes
  r_form <- pkgdossier:::parse_chunk("r", c("#| label = 'dl', eval = FALSE", "#| fig.cap = paste('a',",
                                            "#|   'b')", "#| fig-alt: \"scatter\" # main figure",
                                            "#| out-extra: [a, \"b, c\"]", "1"), FALSE)
  expect_equal(r_form$label, "dl")
  expect_false(r_form$opts$eval)
  expect_equal(deparse(r_form$opts$fig.cap), "paste(\"a\", \"b\")")
  expect_equal(r_form$opts$fig.alt, "scatter")
  expect_equal(r_form$opts$out.extra, c("a", "b, c"))
  expect_error(pkgdossier:::vignette_scenarios(tempdir(), from_vignettes(which = "none")),
               "No vignette sources found .* matching none")
})

test_that("print methods describe sources, scenario sources and scenarios", {
  expect_output(print(git_ref("repo", "v1", subdir = "pkg")), "<pkgdossier source> git repo @ v1 \\(pkg\\)")
  expect_output(print(from_examples()), "<pkgdossier scenario source> baseline help-page examples")
  expect_output(print(scenario_file("s.R")), "scenario file s.R")
  sc <- scenario("s", list(step("a", "run", 1), step("b", "plot", plot(1))))
  expect_length(sc$steps, 2L)   # a list of steps is accepted too
  expect_output(print(sc), "<pkgdossier scenario> s: s \\(2 steps\\)")
})

test_that("a failing R CMD build stops with its output", {
  bad <- file.path(tempfile("badpkg"), "badpkg")
  dir.create(bad, recursive = TRUE)
  writeLines(c("Package: badpkg", "this line is not a field"), file.path(bad, "DESCRIPTION"))
  expect_error(pkgdossier:::build_tarball(bad, tempfile("out"), "badpkg", "en"), "R CMD build failed")
})

test_that("paths that change from run to run are masked", {
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  out <- tempfile("run-")
  dir.create(file.path(out, "plots"), recursive = TRUE)
  out <- normalizePath(out, winslash = "/")
  a <- list(out = out, label = "t", seed = 1L, reseed = "step", reps = 0L, dpi = 50,
            skip_classes = default_skip_classes(), max_depth = 6L, assign_depth = 3L,
            max_rows = 200L, max_length = 200L, max_cells = 400L)
  sc <- pkgdossier:::new_scenario("paths", list(pkgdossier:::new_step("p", "run", c(
    "tmp <- tempfile(pattern = 'data', fileext = '.json')",
    "message('to ', tmp)",
    "print(file.path(tempdir(), 'fixed.txt'))",
    "warning('run folder ', getwd())"
  ), values = TRUE)))
  old <- setwd(out)
  on.exit(setwd(old), add = TRUE)
  invisible(capture.output(r <- e$run_scenario(sc, a, file.path(out, "plots"))))
  st <- r$steps$p
  expect_equal(st$values$text[st$values$path == "tmp"], "<tempdir>/<tempfile>.json")
  expect_true("to <tempdir>/<tempfile>.json" %in% st$transcript)
  expect_true(any(grepl("<tempdir>/fixed.txt", st$transcript, fixed = TRUE)))  # no hex run: name kept
  expect_equal(st$warnings, "run folder <run>")
  expect_equal(e$mask_volatile(c("C:\\\\Users\\\\x", NA), a), c("C:\\\\Users\\\\x", NA))
  expect_equal(e$mask_volatile(c("<environment: 0x55e7ad2f3268>", "<bytecode: 0x1a2B>",
                                 "<environment: namespace:stats>", "0x1f is hex"), a),
               c("<environment: 0x<address>>", "<bytecode: 0x<address>>",
                 "<environment: namespace:stats>", "0x1f is hex"))
  # addresses as packages print them (data.table::address(), tracemem()) and bare
  # tempfile() names (dir(tempdir()))
  expect_equal(e$mask_volatile(c('[1] "0x55741db108e8"', "tracemem[0x5574220ca908 -> 0x55741f5234b8]: f",
                                 '[1] "<0x5574220ca908>"', "id 0x1234567 and a0x55741db108e8",
                                 '[1] "file20e8538bf05f.csv" "libloc_179_a2409ae81d6f7f51.rds"',
                                 "profile20e8538bf05f stays"), a),
               c('[1] "0x<address>"', "tracemem[0x<address> -> 0x<address>]: f", '[1] "<0x<address>>"',
                 "id 0x1234567 and a0x55741db108e8",
                 '[1] "<tempfile>.csv" "libloc_179_a2409ae81d6f7f51.rds"', "profile20e8538bf05f stays"))
  # names of different lengths pad print()'s columns differently; masked, they compare
  expect_equal(e$mask_volatile(c('[1] "file20e8538bf05f.csv"   "x.rds"', '[1] "file212e208df6ea9.csv"  "x.rds"',
                                 "  kept    as   is"), a),
               c('[1] "<tempfile>.csv" "x.rds"', '[1] "<tempfile>.csv" "x.rds"', "  kept    as   is"))
})

test_that("system.time() output and the host session's temporary folder do not vary", {
  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  out <- tempfile("run-")
  dir.create(file.path(out, "plots"), recursive = TRUE)
  host <- normalizePath(tempfile("host-tmp-"), winslash = "/", mustWork = FALSE)
  a <- list(out = normalizePath(out, winslash = "/"), host_tempdir = host, label = "t", seed = 1L,
            reseed = "step", reps = 0L, dpi = 50, skip_classes = default_skip_classes(),
            max_depth = 6L, assign_depth = 3L, max_rows = 200L, max_length = 200L, max_cells = 400L)
  st <- pkgdossier:::new_step("t", "run", c("system.time(for (i in 1:10) i)",
                                            sprintf("cat('%s/callr-scr-100c3af4f182\\n')", host)),
                              values = TRUE)
  r <- e$capture_step(st, new.env(), file.path(out, "plots"), "t", a)
  expect_true(r$timing_shown)
  expect_length(r$printed, 0L)
  expect_equal(nrow(r$values), 0L)
  expect_equal(r$transcript, "<tempdir>/<tempfile>")
  # nor are timings kept in a variable collected as numbers
  kept <- pkgdossier:::new_step("k", "run", c("t1 <- system.time(for (i in 1:10) i)", "n <- 2"),
                                values = TRUE)
  r3 <- e$capture_step(kept, new.env(), file.path(out, "plots"), "k", a)
  expect_equal(r3$values$path, "n")

  # padding print() adds for a path's length is trimmed with it
  pad <- pkgdossier:::new_step("p", "print", sprintf("c('-f', '%s/callr-scr-1a2b3c4d5e')", host))
  r2 <- withr::with_options(list(width = 30), e$capture_step(pad, new.env(), file.path(out, "plots"), "p", a))
  expect_equal(r2$printed, c('[1] "-f"', '[2] "<tempdir>/<tempfile>"'))
})

test_that("example calls that add to a plot stay in the step that drew it", {
  rd <- tempfile(fileext = ".Rd")
  writeLines(c("\\name{f}", "\\alias{f}", "\\title{F}", "\\description{F.}", "\\examples{",
               "plot(1:3)", "abline(h = 2, col = 2)", "graphics::lines(1:3)",
               "x <- 1", "curve(sin, add = TRUE)", "curve(cos, 0, 1)",
               "fit <- lm(dist ~ speed, data = cars)", "abline(fit)", "y <- 2", "}"), rd)
  sc <- pkgdossier:::rd_example_scenario(rd)
  codes <- vapply(sc$steps, `[[`, "", "code")
  # an addition after other expressions joins the step that drew, with them
  expect_equal(codes, c("plot(1:3)\nabline(h = 2, col = 2)\ngraphics::lines(1:3)\nx <- 1\ncurve(sin, add = TRUE)",
                        "curve(cos, 0, 1)\nfit <- lm(dist ~ speed, data = cars)\nabline(fit)", "y <- 2"))
  expect_false(pkgdossier:::adds_to_plot("abline <- 1"))
  expect_false(pkgdossier:::adds_to_plot("not valid ("))
})

test_that("packages a scenario's code needs are found", {
  cp <- pkgdossier:::code_packages
  expect_setequal(cp("library(gamm4)\nrequire('mgcv')\nx <- splines::ns(1:3, 2)\nstats:::C"),
                  c("gamm4", "mgcv", "splines", "stats"))
  expect_setequal(cp("if (requireNamespace('ggplot2', quietly = TRUE)) ggplot2::ggplot()"), "ggplot2")
  expect_equal(cp("p <- 'x'; library(p, character.only = TRUE)"), character())
  expect_equal(cp("library(package = 'lattice')"), "lattice")
  expect_equal(cp("not valid ("), character())
  sc <- list(pkgdossier:::new_scenario("s", list(pkgdossier:::new_step("a", "run", "library(notapkg.xyz); stats::sd(1:3)"))))
  expect_equal(pkgdossier:::missing_packages(sc, "udfixture", .libPaths()), list(s = "notapkg.xyz"))
  if (isTRUE(l10n_info()[["UTF-8"]])) {  # R writes curly quotes only in a UTF-8 session
    expect_equal(pkgdossier:::missing_package_in("there is no package called \u2018gamm4\u2019"), "gamm4")
  }
  expect_equal(pkgdossier:::missing_package_in("there is no package called 'gamm4'"), "gamm4")
  expect_true(is.na(pkgdossier:::missing_package_in("object 'x' not found")))
})

test_that("error = TRUE chunks run on and show their errors as output", {
  f <- tempfile(fileext = ".Rmd")
  writeLines(c("```{r setup}", "knitr::opts_chunk$set(error = TRUE)", "```",
               "```{r a}", "stop('x')", "```", "```{r b, error = FALSE}", "1", "```"), f)
  st <- pkgdossier:::vignette_scenario(f)$steps
  expect_equal(vapply(st, `[[`, logical(1), "expect_error"), c(FALSE, TRUE, FALSE))

  e <- new.env()
  sys.source(system.file("runner", "runner.R", package = "pkgdossier"), envir = e)
  out <- tempfile("run-")
  dir.create(file.path(out, "plots"), recursive = TRUE)
  a <- list(out = normalizePath(out, winslash = "/"), label = "t", seed = 1L, reseed = "step", reps = 0L,
            dpi = 50, skip_classes = default_skip_classes(), max_depth = 6L, assign_depth = 3L,
            max_rows = 200L, max_length = 200L, max_cells = 400L)
  cap <- function(code, expect = TRUE) {
    e$capture_step(pkgdossier:::new_step("s", "chunk", code, values = TRUE, expect_error = expect),
                   new.env(), file.path(out, "plots"), "s", a)
  }
  # as knitr runs it: on after the error, which is part of the output
  r <- cap(c("cat('before\\n')", "log(-1:'a')", "x <- 5", "x"))
  expect_null(r$error)
  expect_equal(r$transcript, c("before", "Error: NA/NaN argument"))
  expect_equal(r$printed, "[1] 5")
  expect_equal(r$shown_errors, "NA/NaN argument")
  # a package that is not installed stays an error: a problem, not the vignette's output
  r <- cap("library(notapkg.xyz)")
  expect_match(r$error, "there is no package called")
  # without error = TRUE the first error stops the step
  r <- cap(c("stop('bad')", "y <- 1"), expect = FALSE)
  expect_equal(r$error, "bad")
  expect_false("y" %in% r$values$path)
  # text that is not valid UTF-8 is captured, not a failure
  r <- cap("cat(rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9))), '\\n')", expect = FALSE)
  expect_null(r$error)
  expect_length(r$transcript, 1L)

  # comparison: shown errors are output; R stopping under one version only is a change
  rec <- function(...) utils::modifyList(list(id = "s", kind = "chunk", label = "s", code = "f()",
    elapsed = 0.01, cpu = 0.01, transcript = character(), printed = character()), list(...))
  opts <- list(tol = 1e-4, min_time = 0.03, min_ratio = 1.2, min_timings = 5L, png = FALSE)
  moved <- pkgdossier:::compare_step(rec(transcript = "Error: bad input", shown_errors = "bad input"), NULL,
                                     rec(transcript = "Error: input must be numeric", shown_errors = "input must be numeric"),
                                     NULL, opts)
  expect_equal(moved$diffs$kind, "output_changed")
  expect_true(moved$expected_error)
  plain <- rec(error = "bad", error_class = c("simpleError", "error", "condition"))
  crash <- rec(error = "R stopped in this step: segfault", error_class = c("pkgdossier_crash", "error", "condition"))
  timeout <- rec(error = "timed out after 10 s", error_class = c("pkgdossier_timeout", "error", "condition"))
  expect_equal(pkgdossier:::compare_step(plain, NULL, plain, NULL, opts)$status, "error_both")
  new_crash <- pkgdossier:::compare_step(plain, NULL, crash, NULL, opts)
  expect_equal(new_crash$status, "error_new")
  expect_equal(new_crash$diffs$kind, "error_new")
  expect_equal(pkgdossier:::compare_step(timeout, NULL, plain, NULL, opts)$status, "error_fixed")
  expect_equal(pkgdossier:::compare_step(crash, NULL, timeout, NULL, opts)$status, "error_both")
})

test_that("a source with nothing to offer gives no scenarios unless asked by name", {
  empty <- tempfile("emptypkg")
  dir.create(empty)
  expect_message(sc <- pkgdossier:::vignette_scenarios(empty, from_vignettes()), "has no vignettes")
  expect_length(sc, 0L)
  expect_message(sc <- pkgdossier:::example_scenarios(empty, from_examples()), "has no help-page examples")
  expect_length(sc, 0L)
  expect_error(pkgdossier:::vignette_scenarios(empty, from_vignettes(which = "intro")), "matching intro")
})
