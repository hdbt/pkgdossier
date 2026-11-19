#' Run the scenarios under both versions
#'
#' Each run is a fresh R process (via callr) whose library path starts with that
#' version's library; the run checks that the package was loaded from there. With
#' `order = "abba"` the runs go base, candidate, candidate, base, so drift in machine
#' load hits both versions alike, and each version runs twice so that steps whose
#' results differ between two runs of the same version (unseeded randomness) are
#' found.
#'
#' Per step the run keeps the console transcript (output and messages, in order),
#' the printed form of visible values, warnings and errors with their classes, the
#' numbers and element names of the values (for steps with `values = TRUE`), plots
#' as PNG files at the step's figure size, the elapsed and CPU time of the captured
#' run and, for timed steps, `reps` more timings. The seed is set as the dossier's
#' `reseed` says, and timed repeats start from the random-number state of the step's
#' captured run.
#'
#' Scenarios run one after another in the same process, but each starts from the
#' same session state: options, attached packages, environment variables, the
#' colour palette, the random-number kind and the working directory that one
#' scenario sets are put back before the next. Graphics parameters cannot leak (each
#' step draws on its own device); namespaces a scenario loads stay loaded.
#'
#' Paths and memory addresses change from run to run: in what a step prints, warns
#' or returns as text, the session's temporary folder is written `<tempdir>`, the
#' run's folder `<run>`, a temporary file name (as [tempfile()] makes, also bare, as
#' `dir(tempdir())` lists it) `<tempfile>`, and an address (a formula's
#' `<environment: 0x55e7ad2f3268>`, or `0x` and 8 to 16 hex digits as
#' `tracemem()` and data.table's `address()` show them) `0x<address>`, so a step that
#' shows one still compares. A [system.time()] or [proc.time()] result a step shows as
#' its value, or keeps in a variable, is left out of its printed output and numbers:
#' it differs in every run, and the runner times each step itself. One printed inside
#' another object or with an explicit `print()`, and output a package prints about its
#' own timings, still differ, and the step is reported as unstable.
#'
#' Vignette scenarios run from a fresh copy of the baseline's `vignettes/` folder, so
#' code that reads a file shipped next to the vignette finds it; scenario-file
#' scenarios run from the run's own folder.
#'
#' The scenarios are resolved once (from the baseline's vignettes, help pages and
#' the scenario files) and saved in the work folder, so every run sees identical
#' code. A run whose results already exist is reused unless `force = TRUE`, as long
#' as nothing that shapes its results has changed: the installed version, the
#' scenarios' code, the dossier's run settings (`reps`, `seed`, `reseed`, `language`,
#' `width`, `dpi`, `caps`, `skip_classes`, `deps`), R, the versions of the packages
#' that version and its scenarios load (and of evaluate, which captures them), and
#' pkgdossier's runner. The installs must match the dossier: after changing its
#' dependencies, or R, call [prepare_versions()] first. After fixing the
#' candidate and calling [prepare_versions()] again, only the candidate's runs are
#' repeated. A run is also reused under a new `step_timeout` when its own limit was
#' the same, or lower with no step stopped by it.
#'
#' @param d A [dossier()]; its settings say how the runs are made.
#' @param force Repeat runs even when their results are up to date.
#' @param timeout Seconds one run (one version, all scenarios) may take before it is
#'   stopped, which stops `run_scenarios()` with the end of the run's log. (A step
#'   that crashes R is recorded and skipped; see below.)
#' @param step_timeout Seconds one execution of a step may take: its captured run,
#'   or one of its timed repeats. A step that takes longer is stopped and recorded as
#'   an error, "timed out after N s", and the run goes on with the next step: the
#'   run's process is stopped and started again from a fresh run folder, skipping
#'   that step, so every step before it runs again and the steps after it in its
#'   scenario run without what it would have created. The version's other run does
#'   not start the step again once this run has finished. A notice comes at half the
#'   limit. The default of 300 s is far beyond what a vignette chunk or an example
#'   normally takes, so it catches only steps that hang; `Inf` sets no limit.
#' A step during which the run's R process dies (a segfault in compiled code, a call
#' to [quit()]) is recorded as an error, "R stopped in this step", with the reason R
#' gave, and the run goes on the same way: the process is started again and the step
#' skipped. A step whose output pkgdossier itself fails to capture is recorded the
#' same way, with R's message. A process that dies outside any step stops the run with
#' the end of its log. The run plan lists, per run, the steps that timed out or
#' crashed, and how many runs went at once while it ran.
#'
#' @param workers How many runs may go at once (a whole number). Runs that went at the
#'   same time competed for the machine, so their timings are shown but no step is
#'   labelled `slower` or `faster`; use it when the timings do not matter (a quick
#'   check in CI, `reps = 0`). ABBA order is kept: base and candidate run together,
#'   then candidate and base.
#' @param quiet Suppress progress messages: a plan line, each run's end (and, after
#'   the first, an estimate of the time left), notices about slow steps, and outside
#'   an interactive session a line every minute.
#' @return The run plan (a data frame with one row per run), invisibly.
#' @examples
#' \donttest{
#' d <- example_dossier()
#' prepare_versions(d, quiet = TRUE)
#' run_scenarios(d)
#' }
#' @export
run_scenarios <- function(d, force = FALSE, timeout = Inf, step_timeout = 300, workers = 1L,
                          quiet = FALSE) {
  stopifnot(inherits(d, "pkgdossier_dossier"))
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) || workers < 1 ||
      workers != round(workers)) {
    stop("`workers` must be a whole number of at least 1.", call. = FALSE)
  }
  workers <- as.integer(workers)
  for (nm in c("timeout", "step_timeout")) {
    v <- get(nm)
    if (!is.numeric(v) || length(v) != 1L || is.na(v) || v <= 0) {
      stop("`", nm, "` must be a positive number of seconds (Inf for no limit).", call. = FALSE)
    }
  }
  vers <- read_versions(d)
  check_prepared(d, vers)
  scenarios <- resolve_scenarios(d, vers)
  scen_file <- work_path(d, "scenarios.rds")
  write_rds_atomic(scenarios, scen_file)
  scen_hash <- digest::digest(scenarios, algo = "sha256")
  runner <- system.file("runner", "runner.R", package = "pkgdossier", mustWork = TRUE)
  runner_md5 <- unname(tools::md5sum(runner))
  ctx <- deps_ctx(d, deps_date_of(d))
  libpaths <- shared_libpaths(d, ctx)
  missing <- missing_packages(scenarios, d$pkg, c(vers$base$lib, libpaths))
  if (length(missing)) say(missing_message(missing), quiet = quiet)
  needs_vignette_dir <- any(vapply(scenarios, function(s) identical(s$workdir, "vignettes"), logical(1)))
  # per version, the versions of what it and its scenarios load (and the runner's
  # evaluate), from wherever they are loaded: upgrading a dependency reruns the runs
  # of the versions that use it
  used <- lapply(vers[c("base", "cand")], dependency_versions, scenarios = scenarios, pkg = d$pkg,
                 libpaths = libpaths)

  # which call made a run: timings of runs from different calls are not labelled
  batch <- paste(format(Sys.time(), "%Y-%m-%d %H:%M:%OS3"), Sys.getpid())
  plan <- run_plan(d$order)
  plan$batch <- batch
  plan$reused <- FALSE
  plan$seconds <- NA_real_
  plan$timed_out <- ""
  plan$crashed <- ""
  plan$workers <- NA_integer_    # how many runs went at once while this one ran
  plan$overlapped <- NA
  load_before <- machine_load()
  n_steps <- sum(vapply(scenarios, function(sc) length(sc$steps), integer(1)))
  say(sprintf("Running %d scenario(s), %d steps, under %s %s and %s in %d runs (%s), %d timed repeats per timed step; %s",
              length(scenarios), n_steps, d$pkg, vers$base$version, vers$cand$version, nrow(plan),
              d$order, d$reps,
              if (is.finite(step_timeout)) sprintf("a step's run stops after %s s (step_timeout)", format(step_timeout))
              else "no time limit per step"), quiet = quiet)
  if (!is.null(load_before$r_processes)) {
    say(sprintf("Machine before: CPU %s%% busy, %d other R processes", load_before$cpu_busy,
                load_before$r_processes), quiet = quiet)
  }
  jobs <- list()
  for (i in seq_len(nrow(plan))) {
    v <- vers[[plan$role[i]]]
    out <- work_path(d, "runs", plan$run[i])
    res_file <- file.path(out, "results.rds")
    info_file <- file.path(out, "run.rds")
    args <- c(list(
      pkg = d$pkg, lib = v$lib, out = normalizePath(out, winslash = "/", mustWork = FALSE),
      label = plan$run[i], reps = d$reps, seed = d$seed, reseed = d$reseed,
      scenarios = normalizePath(scen_file, winslash = "/"), width = d$width, language = d$language,
      skip_classes = d$skip_classes, dpi = d$dpi, identity = v$identity, setup = v$setup,
      scenario_hash = scen_hash, deps = d$deps, packages = used[[plan$role[i]]],
      r = R.version.string, platform = R.version$platform,
      step_timeout = step_timeout, workers = as.integer(workers),
      host_tempdir = normalizePath(tempdir(), winslash = "/")
    ), d$caps)
    # everything that shapes a run's results, so a changed setting is never served
    # from an old run; the time limit is checked on its own (a looser one reuses)
    args$run_key <- digest::digest(
      list(args[setdiff(names(args), c("out", "label", "host_tempdir", "step_timeout", "workers"))], runner_md5),
      algo = "sha256")
    if (!force && file.exists(res_file) && file.exists(info_file)) {
      info <- readRDS(info_file)
      if (identical(info$run_key, args$run_key) && limit_covers(info, step_timeout)) {
        plan$reused[i] <- TRUE
        plan$seconds[i] <- info$seconds %||% NA_real_
        plan$timed_out[i] <- paste(info$timed_out, collapse = ", ")
        plan$crashed[i] <- paste(c(info$crashed, info$runner_failed), collapse = ", ")
        plan$workers[i] <- info$workers %||% NA_integer_
        plan$overlapped[i] <- info$overlapped %||% NA
        plan$batch[i] <- info$batch %||% NA_character_
        say(sprintf("[%d/%d] %s: up to date, reused", i, nrow(plan), plan$run[i]), quiet = quiet)
        next
      }
    }
    unlink(out, recursive = TRUE)
    dir.create(out, recursive = TRUE, showWarnings = FALSE)
    vignettes <- if (needs_vignette_dir) vers$base$unpacked
    if (!is.null(vignettes)) copy_vignette_dir(vignettes, file.path(out, "wd"))
    jobs[[length(jobs) + 1L]] <- list(i = i, run = plan$run[i], role = plan$role[i], runner = runner, args = args,
                                      libpath = c(v$lib, libpaths), env = child_env(d$language),
                                      out = out, log = file.path(out, "log.txt"), info = info_file,
                                      vignettes = vignettes)
  }
  fresh_done <- 0L
  # timeouts recorded in reused runs: their version's run made now does not restart them
  prior <- list()
  for (i in which(plan$reused & nzchar(plan$timed_out))) {
    prior[[plan$role[i]]] <- list(run = plan$run[i], steps = strsplit(plan$timed_out[i], ", ", fixed = TRUE)[[1]])
  }
  run_jobs(jobs, workers = workers, timeout = timeout, step_timeout = step_timeout, quiet = quiet,
           timed_out_in = prior,
           done = function(job, seconds, queued = 0L) {
             fresh_done <<- fresh_done + 1L
             info <- list(run_key = job$args$run_key, step_timeout = step_timeout, seconds = seconds,
                          timed_out = job$args$timed_out, crashed = names(job$args$crashed),
                          runner_failed = names(job$args$runner_failed),
                          workers = job$peak, overlapped = job$peak > 1L, batch = batch)
             write_rds_atomic(info, job$info)
             plan$seconds[job$i] <<- seconds
             plan$timed_out[job$i] <<- paste(info$timed_out, collapse = ", ")
             plan$crashed[job$i] <<- paste(c(info$crashed, info$runner_failed), collapse = ", ")
             plan$workers[job$i] <<- info$workers
             plan$overlapped[job$i] <<- info$overlapped
             left <- length(jobs) - fresh_done
             # the runs going now end about when this one did; the queued ones follow
             say(sprintf("[%d/%d] %s: done in %s%s", job$i, nrow(plan), job$run, fmt_duration(seconds),
                         if (fresh_done == 1L && left > 0L) {
                           sprintf("; about %s to go for the other %d run(s)",
                                   fmt_duration(seconds * max(1, ceiling(queued / workers))), left)
                         } else ""), quiet = quiet)
           })
  load_after <- machine_load()
  write_rds_atomic(list(plan = plan, reps = d$reps, order = d$order, recipe = run_recipe(d),
                        load_before = load_before, load_after = load_after, scenario_hash = scen_hash,
                        missing = missing, workers = max(c(1L, plan$workers), na.rm = TRUE)),
                   work_path(d, "runs", "runs.rds"))
  invisible(plan)
}

# Packages the scenarios use that are not installed, each once with the scenarios
# that use it, and one install.packages() line for all.
missing_message <- function(missing) {
  pkgs <- unlist(missing, use.names = FALSE)
  by_pkg <- split(rep(names(missing), lengths(missing)), factor(pkgs, levels = unique(pkgs)))
  where <- vapply(by_pkg, function(sc) {
    sc <- unique(sc)
    paste0(paste(utils::head(sc, 3L), collapse = ", "),
           if (length(sc) > 3L) sprintf(" and %d more", length(sc) - 3L) else "")
  }, "")
  sprintf(paste("Not installed, but used by the scenarios: %s. Steps that need %s fail under both versions",
                "and are listed as scenario problems; to include them: install.packages(c(%s))."),
          paste(sprintf("%s (%s)", names(by_pkg), where), collapse = "; "),
          if (length(by_pkg) > 1L) "them" else "it",
          paste0("\"", names(by_pkg), "\"", collapse = ", "))
}

# A stored run made under `info$step_timeout` holds for a new limit when the limits
# are the same, or when the new one is looser and no step reached the old one.
limit_covers <- function(info, step_timeout) {
  old <- info$step_timeout
  if (is.null(old)) return(FALSE)
  identical(as.numeric(old), as.numeric(step_timeout)) || (!length(info$timed_out) && old <= step_timeout)
}

# The dossier's settings that shape the runs, as compare_runs() checks them against
# the stored runs.
run_recipe <- function(d) {
  d[c("reps", "order", "seed", "reseed", "language", "width", "dpi", "caps", "skip_classes",
      "deps", "deps_repos", "deps_date")]
}

# Package -> version for everything one version of the package and the scenarios
# load, recursively, and evaluate (which the runner captures with), as found in the
# library paths the runs use (the first library holding a package wins, as for
# library()).
dependency_versions <- function(v, scenarios, pkg, libpaths) {
  ip <- utils::installed.packages(lib.loc = libpaths, fields = character())
  ip <- ip[!duplicated(ip[, "Package"]), , drop = FALSE]
  rownames(ip) <- ip[, "Package"]
  f <- file.path(v$unpacked %||% "", "DESCRIPTION")
  dd <- if (file.exists(f)) read_desc(f) else list()
  direct <- rbind(dep_table(dd$Depends), dep_table(dd$Imports), dep_table(dd$LinkingTo),
                  dep_table(dd$Suggests))$name
  used <- unlist(lapply(scenarios, function(sc) {
    lapply(sc$steps, function(st) code_packages(paste(st$code, collapse = "\n")))
  }))
  direct <- intersect(setdiff(unique(c(direct, used, "evaluate")), c("R", pkg)), rownames(ip))
  all <- unique(c(direct, unlist(tools::package_dependencies(direct, db = ip,
    which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE), use.names = FALSE)))
  all <- sort(intersect(setdiff(all, pkg), rownames(ip)))
  stats::setNames(unname(ip[all, "Version"]), all)
}

# The installs must be the ones the dossier describes: made under this R, with its
# dependency setup, against the LinkingTo versions there now.
check_prepared <- function(d, vers) {
  date <- NULL
  for (role in c("base", "cand")) {
    v <- vers[[role]]
    f <- file.path(v$unpacked %||% "", "DESCRIPTION")
    if (!file.exists(f)) stop("The installed versions are incomplete; run prepare_versions(d).", call. = FALSE)
    desc <- read_desc(f)
    if (identical(d$deps, "snapshot")) date <- d$deps_date %||% date %||% snapshot_date(desc)
    if (!identical(v$setup, install_setup(d, date, desc, deps_ctx(d, date)))) {
      stop("The ", if (role == "base") "baseline" else "candidate", " was installed under another R, ",
           "dependency setup or LinkingTo version than the dossier and this session have now; ",
           "run prepare_versions(d) first.", call. = FALSE)
    }
  }
  invisible(TRUE)
}

# A fresh copy per run: code a vignette runs may write next to itself, and each run
# must start from the folder as the baseline ships it.
copy_vignette_dir <- function(unpacked, dest) {
  src <- file.path(unpacked, "vignettes")
  unlink(dest, recursive = TRUE)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(src)) {
    file.copy(src, dest, recursive = TRUE)
  } else {
    dir.create(file.path(dest, "vignettes"))
  }
  invisible(dest)
}

# Runs the runner for each job in a background R process, `workers` at a time, and
# watches their logs. The runner writes "<scenario>/<step>: starting" before a step
# and ": finished" after it; a step running longer than step_timeout gets its
# process stopped and the run started again, from a fresh run folder, with that step
# listed in args$timed_out, which the runner records as an error without running
# it. A process that dies in a step is started again the same way, with the step in
# args$crashed, or in args$runner_failed when pkgdossier's runner itself raised an
# R error there. A run over `timeout` (counted from its first start) stops
# everything, as does an interrupt.
run_jobs <- function(jobs, workers, timeout, step_timeout, quiet, done, timed_out_in = list()) {
  procs <- new.env(parent = emptyenv())
  finished <- character()
  complete <- FALSE
  on.exit({
    for (p in as.list(procs)) if (p$is_alive()) p$kill()
    # stopped part way (an interrupt, a run over `timeout`): what is kept
    if (!complete && length(finished) && length(finished) < length(jobs)) {
      say(sprintf("Stopped. The finished run(s) %s are kept, and a next call (without force) reuses them.",
                  paste(finished, collapse = ", ")), quiet = quiet)
    }
  }, add = TRUE)
  # a step that timed out in a version's finished run (in this call, or a reused one)
  # is not started again in that version's later run: it would only time out again
  heartbeat <- !interactive() && !quiet
  launch <- function(job) {
    # a restart begins from the run folder as a first start finds it: what the
    # stopped attempt wrote would otherwise meet the steps that run again
    if (!is.null(job$t0)) reset_run(job)
    if (is.null(job$t0)) {
      earlier <- timed_out_in[[job$role %||% ""]]
      skip <- setdiff(earlier$steps, job$args$timed_out)
      if (length(skip)) {
        say(sprintf("%s: not starting %s, which timed out in %s", job$run, paste(skip, collapse = ", "),
                    earlier$run), quiet = quiet)
        job$args$timed_out <- c(job$args$timed_out, skip)
        job$args$skipped_from[skip] <- earlier$run
      }
    }
    job$p <- callr::r_bg(
      function(runner, args) {
        e <- new.env(parent = globalenv())
        sys.source(runner, envir = e, keep.source = FALSE)
        e$run_version(args)
      },
      args = list(runner = job$runner, args = job$args), libpath = job$libpath, env = job$env,
      stdout = job$log, stderr = "2>&1", wd = job$out
    )
    assign(job$run, job$p, envir = procs)
    job$step <- NULL
    job$exec <- NULL
    job$since <- NULL
    job$log_size <- NA
    if (is.null(job$t0)) job$t0 <- Sys.time()
    if (is.null(job$beat)) job$beat <- Sys.time()
    job
  }
  secs <- function(t) as.numeric(difftime(Sys.time(), t, units = "secs"))
  stop_all <- function(jobs) for (a in jobs) if (a$p$is_alive()) a$p$kill()
  queue <- lapply(jobs, function(j) {
    j$args$timed_out <- character()
    j$args$crashed <- stats::setNames(character(), character())
    j$args$runner_failed <- stats::setNames(character(), character())
    j$args$skipped_from <- stats::setNames(character(), character())
    j$peak <- 1L
    j
  })
  active <- list()
  while (length(queue) || length(active)) {
    while (length(active) < workers && length(queue)) {
      active[[length(active) + 1L]] <- launch(queue[[1L]])
      queue <- queue[-1L]
    }
    # runs that went at the same time competed for the machine: their timings are
    # not ones to label
    for (k in seq_along(active)) active[[k]]$peak <- max(active[[k]]$peak, length(active))
    active[[1L]]$p$wait(250)
    still <- list()
    for (i in seq_along(active)) {
      job <- active[[i]]
      if (job$p$is_alive()) {
        if (secs(job$t0) > timeout) {
          stop_all(c(still, active))
          run_failed(structure(class = c("callr_timeout_error", "error", "condition"),
                               list(message = "timed out", call = NULL)), job$run, job$log, timeout)
        }
        # the log is read again only when it has grown
        size <- file.size(job$log)
        if (!identical(size, job$log_size)) {
          job$pos <- log_position(job$log)
          job$log_size <- size
        }
        pos <- job$pos %||% log_position(job$log)
        if (!identical(pos$exec, job$exec)) {
          # a new execution (a step's captured run, or one of its timed repeats)
          job$exec <- pos$exec
          job$step <- pos$step
          job$since <- Sys.time()
        } else if (!is.null(job$step) && is.finite(step_timeout)) {
          took <- secs(job$since)
          if (took > step_timeout) {
            job$p$kill()
            say(sprintf("%s: step %s took more than %s s (step_timeout); stopped, running %s again without it",
                        job$run, job$step, format(step_timeout), job$run), quiet = quiet)
            job$args$timed_out <- c(job$args$timed_out, job$step)
            job <- launch(job)
          } else if (!identical(job$noticed, job$step) && step_timeout >= 60 && took > step_timeout / 2) {
            # once per step, not for each of its timed repeats
            say(sprintf("%s: one execution of step %s has run for %s; it is stopped at %s s (step_timeout)",
                        job$run, job$step, fmt_duration(took), format(step_timeout)), quiet = quiet)
            job$noticed <- job$step
          }
        }
        # outside an interactive session (CI), a line now and then shows it is alive
        if (heartbeat && secs(job$beat) >= 60) {
          say(sprintf("%s: %d step(s) done, %s, after %s", job$run, pos$done,
                      if (is.null(pos$step)) "between steps" else paste("now", pos$step),
                      fmt_duration(secs(job$t0))), quiet = quiet)
          job$beat <- Sys.time()
        }
        still[[length(still) + 1L]] <- job
        next
      }
      res <- tryCatch(job$p$get_result(), error = function(e) e)
      if (inherits(res, "error")) {
        in_step <- current_step(job$log)
        seen <- c(names(job$args$crashed), names(job$args$runner_failed))
        if (!is.null(in_step) && !in_step %in% seen) {
          if (!is.null(res$parent)) {
            # pkgdossier's runner raised an R error while capturing the step (the
            # process did not die): say so, with R's message, and go on without it
            msg <- gsub("\\s+", " ", conditionMessage(res$parent))
            say(sprintf("%s: pkgdossier could not capture step %s (%s); running %s again without it",
                        job$run, in_step, msg, job$run), quiet = quiet)
            job$args$runner_failed[[in_step]] <- msg
          } else {
            # the process died inside the step (a segfault in compiled code, a call
            # to quit()): record the step as crashed and run again without it, as for
            # a step over step_timeout
            reason <- crash_reason(job$log, job$p)
            # the restart starts a new log: keep this one's account of the crash
            kept <- file.path(job$out, paste0("crash-", gsub("[/\\\\]", "__", in_step), ".txt"))
            crash_log <- tryCatch(readLines(job$log, warn = FALSE), error = function(e) character())
            start <- utils::tail(grep(": starting$", crash_log), 1L)
            writeLines(if (length(start)) crash_log[seq.int(start, length(crash_log))] else crash_log, kept)
            reason <- sprintf("%s; R's report is in %s", reason, basename(kept))
            say(sprintf("%s: R stopped in step %s (%s); running %s again without it",
                        job$run, in_step, reason, job$run), quiet = quiet)
            job$args$crashed[[in_step]] <- reason
          }
          still[[length(still) + 1L]] <- launch(job)
          next
        }
        stop_all(c(still, active))
        run_failed(res, job$run, job$log, timeout)
      }
      if (length(job$args$timed_out)) timed_out_in[[job$role %||% ""]] <- list(run = job$run, steps = job$args$timed_out)
      finished <- c(finished, job$run)
      done(job, secs(job$t0), queued = length(queue))
    }
    active <- still
  }
  complete <- TRUE
  invisible()
}

# How long, for people: "40 s", "6 min", "1.5 h".
fmt_duration <- function(s) {
  if (!is.finite(s)) return("?")
  if (s < 90) return(sprintf("%.0f s", s))
  if (s < 5400) return(sprintf("%.0f min", s / 60))
  sprintf("%.1f h", s / 3600)
}

# Empties a run's folder for a restart, keeping the accounts of earlier crashes, and
# copies the vignettes folder in again.
reset_run <- function(job) {
  files <- list.files(job$out, all.files = TRUE, no.. = TRUE)
  files <- files[!grepl("^crash-.*\\.txt$", files) & files != basename(job$log)]
  unlink(file.path(job$out, files), recursive = TRUE)
  if (!is.null(job$vignettes)) copy_vignette_dir(job$vignettes, file.path(job$out, "wd"))
  invisible()
}

# Why the process died, from its log after the step's "starting" line: R's own
# report of a caught signal, else the exit status.
crash_reason <- function(log, p) {
  lines <- tryCatch(readLines(log, warn = FALSE), error = function(e) character())
  start <- utils::tail(grep(": starting$", lines), 1L)
  after <- if (length(start)) lines[seq.int(start, length(lines))] else lines
  caught <- regmatches(after, regexpr("caught (segfault|illegal operation|bus error|SIGPIPE)", after))
  if (length(caught)) return(sub("^caught ", "", caught[1]))
  status <- tryCatch(p$get_exit_status(), error = function(e) NA_integer_)
  if (is.null(status) || is.na(status)) "the R process ended" else sprintf("the R process ended with exit status %d", status)
}

# The step the runner is in: the last "starting" line in the log when no "finished"
# line follows it, else NULL.
current_step <- function(log) log_position(log)$step

# Where the runner is, from its log: the step it is in (NULL between steps), the
# execution within it ("<step> starting" for the captured run, "<step> repeat 2" for
# a timed repeat), and how many steps it has finished.
log_position <- function(log) {
  none <- list(step = NULL, exec = NULL, done = 0L)
  if (!file.exists(log)) return(none)
  lines <- tryCatch(readLines(log, warn = FALSE), error = function(e) character())
  marks <- regmatches(lines, regexec("^\\[[^]]*\\] (\\S+): (starting|finished|repeat [0-9]+)$", lines, perl = TRUE))
  marks <- marks[lengths(marks) == 3L]
  if (!length(marks)) return(none)
  done <- sum(vapply(marks, function(m) m[3] == "finished", logical(1)))
  last <- marks[[length(marks)]]
  if (last[3] == "finished") return(list(step = NULL, exec = NULL, done = done))
  list(step = last[2], exec = paste(last[2], last[3]), done = done)
}

run_failed <- function(e, run, log, timeout) {
  what <- if (inherits(e, "callr_timeout_error")) {
    sprintf("timed out after %s s", format(timeout))
  } else {
    paste0("failed: ", conditionMessage(e))
  }
  tail <- if (file.exists(log)) utils::tail(readLines(log, warn = FALSE), 15L) else character()
  stop("Run ", run, " ", what,
       if (length(tail)) paste0("\nLast lines of ", log, ":\n", paste(tail, collapse = "\n")),
       call. = FALSE)
}

run_plan <- function(order) {
  if (order == "abba") {
    data.frame(run = c("base_a", "cand_a", "cand_b", "base_b"),
               role = c("base", "cand", "cand", "base"), stringsAsFactors = FALSE)
  } else {
    data.frame(run = c("base_a", "cand_a"), role = c("base", "cand"), stringsAsFactors = FALSE)
  }
}

# CPU share busy over half a second and the number of other R processes, when the ps
# package is available: how noisy the elapsed times are likely to be.
machine_load <- function() {
  if (!requireNamespace("ps", quietly = TRUE)) return(list())
  tryCatch({
    busy <- function(t) sum(t) - t[["idle"]]
    t1 <- unlist(ps::ps_system_cpu_times())
    Sys.sleep(0.5)
    t2 <- unlist(ps::ps_system_cpu_times())
    total <- sum(t2) - sum(t1)
    procs <- ps::ps()
    r_names <- c("R", "Rscript", "Rterm", "Rgui", "R.exe", "Rscript.exe", "Rterm.exe", "Rgui.exe")
    list(
      cpu_busy = if (total > 0) round(100 * (busy(t2) - busy(t1)) / total) else NA_real_,
      r_processes = sum(procs$name %in% r_names) - 1L,
      time = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    )
  }, error = function(e) list())
}
