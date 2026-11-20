# Figures for the site's homepage, drawn from a real run of example_dossier().
#
# pkgdossier draws no plots of its own, so the gallery shows what its report shows for
# the bundled example: a tiny package, udfixture, in two versions with one planted
# difference of each kind. The script runs that dossier, draws each figure as an SVG
# on a white background, captures the Differences section of the HTML report for the
# hero image, and copies everything into pkgdown/assets/gallery/, which pkgdown copies
# to the site root as gallery/.
#
# Run it from the package root after a change to the comparison or the report, then
# rebuild the site:
#
#   Rscript pkgdown/gallery.R
#
# Needs pkgload and png; the hero image also needs chromote and a Chrome or Chromium.

stopifnot(file.exists("DESCRIPTION"), dir.exists("pkgdown"))
pkgload::load_all(".", quiet = TRUE)

work <- file.path(tempdir(), "pkgdossier-gallery")
unlink(work, recursive = TRUE)
fig_dir <- file.path(work, "figures")
page_dir <- file.path(work, "page")
dir.create(fig_dir, recursive = TRUE)

d <- example_dossier(work = file.path(work, "dossier"))
cmp <- run_dossier(d, html = page_dir, open = FALSE, quiet = TRUE)
diffs <- differences(cmp)
steps <- summary(cmp)
pkg <- cmp$meta$pkg
lab <- cmp$meta$labels

# The logo's colours, as the report uses them: the baseline in blue, the candidate in
# orange, and the report's colours for the severities (0 and 1 break code, 2 moves
# results, 3 output, plots and time, 4 additions and fixes).
col <- list(
  ink = "#17202c", muted = "#5B6775", line = "#E3E8EE", faint = "#F3F6F9",
  base = "#2c5ea8", base_soft = "#e2eaf6", cand = "#b04f16", cand_soft = "#f8e7dc",
  sev = c("0" = "#b3261e", "1" = "#b3261e", "2" = "#b04f16", "3" = "#2c5ea8", "4" = "#2b6a39")
)
sev_text <- c("0" = "unstable", "1" = "breaks code", "2" = "moves results",
              "3" = "output, plots, time", "4" = "additions, fixes")
kind_sev <- tapply(diffs$severity, diffs$kind, min)
nice <- function(x) gsub("_", " ", x, fixed = TRUE)

# Each figure: 9 x 5.6 inches unless said otherwise, white background, sans text. The
# size sets how large the full-size SVG opens; the gallery shows it scaled down.
mono <- if (.Platform$OS.type == "windows") "Consolas" else "mono"
figure <- function(name, code, width = 9, height = 5.6) {
  grDevices::svg(file.path(fig_dir, paste0(name, ".svg")), width = width, height = height,
                 pointsize = 14, bg = "white")
  on.exit(grDevices::dev.off())
  graphics::par(col = col$ink, col.axis = col$muted, col.lab = col$muted, fg = col$muted,
                las = 1, mgp = c(2, 0.35, 0), tcl = -0.2, xpd = NA)
  force(code)
  invisible()
}
# A title and a subtitle over the figure, aligned with its left edge.
title_left <- function(main, sub = NULL) {
  x <- graphics::grconvertX(0.012, from = "ndc", to = "user")
  graphics::mtext(main, side = 3, line = if (is.null(sub)) 0.9 else 1.7, adj = 0, at = x,
                  font = 2, cex = 0.98, col = col$ink)
  if (!is.null(sub)) {
    graphics::mtext(sub, side = 3, line = 0.6, adj = 0, at = x, cex = 0.8, col = col$muted)
  }
}


# 1. The differences, by kind -------------------------------------------------------

k <- as.data.frame(table(kind = diffs$kind), stringsAsFactors = FALSE)
names(k)[2] <- "n"
k$severity <- kind_sev[k$kind]
k <- k[order(-k$severity, k$n, decreasing = FALSE), ]
figure("differences-by-kind", {
  graphics::par(mar = c(2, 10.5, 3.2, 1.2))
  y <- graphics::barplot(k$n, horiz = TRUE, names.arg = nice(k$kind), border = NA,
                         col = col$sev[as.character(k$severity)], space = 0.4,
                         xlim = c(0, max(k$n) + 0.5), axes = FALSE, cex.names = 0.74)
  graphics::abline(v = 0:max(k$n), col = col$line, xpd = FALSE)
  graphics::barplot(k$n, horiz = TRUE, border = NA, col = col$sev[as.character(k$severity)],
                    space = 0.4, axes = FALSE, add = TRUE, names.arg = rep("", nrow(k)))
  graphics::axis(1, at = 0:max(k$n), cex.axis = 0.72, lwd = 0, line = -0.6)
  title_left(sprintf("%d differences a %s %s user meets in %s, by kind", nrow(diffs), pkg,
                     lab$base, lab$cand),
             "each labelled mechanically; the colour is the severity the report sorts by")
  sevs <- c("1", "2", "3", "4")
  graphics::legend("bottomright", legend = paste0(sev_text[sevs], c(" (or unstable)", "", "", "")),
                   fill = col$sev[sevs], border = NA, bty = "n", cex = 0.72, inset = c(0, 0.02),
                   text.col = col$ink)
})


# 2. The plot pair --------------------------------------------------------------------

plot_steps <- unlist(lapply(cmp$scenarios, function(sc) {
  lapply(Filter(function(s) !is.null(s$plot) && isTRUE(s$plot$changed), sc$steps),
         function(s) c(s, list(scenario_source = sc$source)))
}), recursive = FALSE)
ps <- plot_steps[[1]]
img_a <- png::readPNG(ps$plot$files_base[1])[, , 1:3]
img_b <- png::readPNG(ps$plot$files_cand[1])[, , 1:3]
differ <- apply(abs(img_a - img_b) > 0, c(1, 2), any)
# Where they differ: the baseline drawing faded, the differing pixels in the candidate's
# orange, each widened by one pixel so they survive the scaling down.
grow <- differ
for (dr in -1:1) for (dc in -1:1) {
  rows <- pmin(pmax(seq_len(nrow(differ)) + dr, 1), nrow(differ))
  cols <- pmin(pmax(seq_len(ncol(differ)) + dc, 1), ncol(differ))
  grow <- grow | differ[rows, cols]
}
grey <- (img_a[, , 1] + img_a[, , 2] + img_a[, , 3]) / 3
img_d <- array(1 - (1 - grey) * 0.22, dim(img_a))
orange <- grDevices::col2rgb(col$cand)[, 1] / 255
for (ch in 1:3) img_d[, , ch][grow] <- orange[ch]
# Crop the three images alike to what either version drew, leaving a little margin.
ink <- apply(img_a < 0.98, c(1, 2), any) | apply(img_b < 0.98, c(1, 2), any)
pad <- 8
rr <- range(which(rowSums(ink) > 0)) + c(-pad, pad)
cc <- range(which(colSums(ink) > 0)) + c(-pad, pad)
rr <- seq(max(rr[1], 1), min(rr[2], nrow(ink)))
cc <- seq(max(cc[1], 1), min(cc[2], ncol(ink)))
panels <- lapply(list(img_a, img_b, img_d), function(m) m[rr, cc, , drop = FALSE])
# What else the comparison says about this step and its function.
fn <- strsplit(ps$code, "(", fixed = TRUE)[[1]][1]
sig <- diffs[diffs$scenario == "(namespace)" & diffs$step == fn, ]
plot_row <- diffs[diffs$kind == "plot_changed" & diffs$label == ps$label, ][1, ]
notes <- c(
  sprintf("plot changed: %.2f%% of pixels differ", 100 * ps$plot$pixel_share),
  if (nrow(sig)) sprintf("%s(): %s %s%s", fn, nice(sig$kind[1]), sig$path[1],
                         if (!is.na(sig$cand[1])) paste0(" = ", sig$cand[1]) else ""),
  if (isTRUE(plot_row$no_news)) sprintf("no NEWS bullet names %s()", fn) else
    sprintf("NEWS: %s", plot_row$news)
)
figure("plot-pair", width = 9, height = 6, {
  graphics::par(mar = c(0.3, 0.2, 3.3, 0.2))
  graphics::plot.new()
  W <- graphics::par("pin")[1]
  H <- graphics::par("pin")[2]
  # User coordinates in inches from the top-left corner of the plot region.
  graphics::plot.window(xlim = c(0, W), ylim = c(-H, 0), xaxs = "i", yaxs = "i")
  asp <- length(rr) / length(cc)
  gap <- 0.35
  head <- 0.32
  ph <- min((H - 2 * head - 0.2) / 2, (W - gap) / 2 * asp)
  pw <- ph / asp
  x0 <- c(0, pw + gap, 0)
  y0 <- c(-head, -head, -2 * head - ph - 0.2)
  heads <- c(lab$base, lab$cand, "where they differ")
  head_col <- c(col$base, col$cand, col$ink)
  for (i in 1:3) {
    graphics::rasterImage(panels[[i]], x0[i], y0[i] - ph, x0[i] + pw, y0[i], interpolate = TRUE)
    graphics::rect(x0[i], y0[i] - ph, x0[i] + pw, y0[i], border = col$line, lwd = 1)
    graphics::text(x0[i], y0[i] + 0.1, heads[i], adj = c(0, 0), cex = 0.8, font = 2, col = head_col[i])
  }
  xt <- pw + gap
  graphics::text(xt, y0[3] + 0.1, sprintf("%s / %s", ps$scenario_source, ps$label), adj = c(0, 0),
                 cex = 0.8, font = 2, col = col$ink)
  for (i in seq_along(notes)) {
    yt <- y0[3] - 0.25 - (i - 1) * 0.42
    graphics::points(xt + 0.06, yt, pch = 15, cex = 0.7, col = c(col$sev["3"], col$sev["4"], col$cand)[i])
    graphics::text(xt + 0.22, yt, notes[i], adj = c(0, 0.5), cex = 0.74, col = col$ink)
  }
  title_left(sprintf("A changed plot: %s, from the %s", ps$code, ps$scenario_source),
             "the same code under each version, drawn to PNG at the step's figure size")
})


# 3. Every step, scenario by scenario ------------------------------------------------

worst <- function(kinds) {
  ks <- trimws(strsplit(kinds, ",", fixed = TRUE)[[1]])
  ks <- ks[nzchar(ks)]
  if (!length(ks)) return(NA_integer_)
  min(c(kind_sev[ks[ks %in% names(kind_sev)]], 4L))
}
figure("steps-map", {
  graphics::par(mar = c(0.4, 0.4, 3.2, 0.4))
  graphics::plot.new()
  ncol_max <- max(table(steps$scenario))
  graphics::plot.window(xlim = c(0, ncol_max), ylim = c(-14.2, 0), xaxs = "i", yaxs = "i")
  y <- 0
  for (sc in cmp$scenarios) {
    s <- steps[steps$scenario == sc$id, ]
    graphics::text(0, y - 0.35, sprintf("%s  ·  %s", sc$title, sc$source), adj = c(0, 0.5),
                   cex = 0.72, font = 2, col = col$ink)
    for (i in seq_len(nrow(s))) {
      x <- i - 1
      top <- y - 0.75
      sev <- worst(s$kinds[i])
      if (s$status[i] == "not_run") {
        graphics::rect(x + 0.06, top - 0.88, x + 0.94, top, col = "white", border = col$muted, lty = 3)
      } else if (is.na(sev)) {
        graphics::rect(x + 0.06, top - 0.88, x + 0.94, top, col = col$line, border = NA)
      } else {
        graphics::rect(x + 0.06, top - 0.88, x + 0.94, top, col = col$sev[as.character(sev)], border = NA)
      }
      graphics::text(x + 0.5, top - 1.0, s$label[i], srt = 90, adj = c(1, 0.5), cex = 0.5, col = col$muted)
    }
    y <- y - 4.05
  }
  title_left(sprintf("Every step of the %d scenarios, %s against %s", length(cmp$scenarios),
                     lab$cand, lab$base),
             "coloured by the most severe difference in the step")
  sevs <- c("1", "2", "3", "4")
  graphics::legend(0, y + 0.1, bty = "n", cex = 0.62, horiz = FALSE, ncol = 3,
                   legend = c(paste0(sev_text[sevs], c(" (or unstable)", "", "", "")), "no difference", "not run"),
                   fill = c(col$sev[sevs], col$line, "white"), border = c(rep(NA, 5), col$muted),
                   text.col = col$ink)
})


# 4. What a user reads ----------------------------------------------------------------

read_kinds <- c("error_new", "warning_new", "output_changed", "warning_gone", "error_fixed")
r <- diffs[diffs$kind %in% read_kinds, ]
r <- r[order(match(r$kind, read_kinds)), ]
figure("printed-output", {
  graphics::par(mar = c(0.4, 0.4, 3.2, 0.4))
  graphics::plot.new()
  n <- nrow(r)
  graphics::plot.window(xlim = c(0, 1), ylim = c(-n - 0.2, 1), xaxs = "i", yaxs = "i")
  xs <- c(0, 0.315, 0.66)
  w <- 0.33
  graphics::text(xs[1], 0.45, "step", adj = c(0, 0.5), cex = 0.72, col = col$muted)
  graphics::text(xs[2] + 0.012, 0.45, lab$base, adj = c(0, 0.5), cex = 0.78, font = 2, col = col$base)
  graphics::text(xs[3] + 0.012, 0.45, lab$cand, adj = c(0, 0.5), cex = 0.78, font = 2, col = col$cand)
  shorten <- function(x, n = 30) ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "…"), x)
  for (i in seq_len(n)) {
    y <- -i + 0.5
    graphics::segments(0, y + 0.5, 1, y + 0.5, col = col$line)
    graphics::text(xs[1], y + 0.14, paste(r$scenario[i], "/", r$label[i]), adj = c(0, 0.5),
                   cex = 0.72, family = mono, col = col$ink)
    graphics::text(xs[1], y - 0.2, paste(nice(r$kind[i]), "·", r$path[i]), adj = c(0, 0.5),
                   cex = 0.6, col = col$sev[as.character(r$severity[i])])
    for (side in c("base", "cand")) {
      v <- r[[side]][i]
      x <- if (side == "base") xs[2] else xs[3]
      if (is.na(v) || !nzchar(v)) {
        graphics::text(x + 0.012, y, "—", adj = c(0, 0.5), cex = 0.72, col = col$muted)
      } else {
        graphics::rect(x, y - 0.3, x + w, y + 0.3, border = NA,
                       col = if (side == "base") col$base_soft else col$cand_soft)
        graphics::text(x + 0.012, y, shorten(v), adj = c(0, 0.5), cex = 0.68, family = mono,
                       col = col$ink)
      }
    }
  }
  title_left("What a user reads after upgrading",
             "printed output, console messages, errors and warnings that changed between the versions")
})


# 5. NEWS against the differences -----------------------------------------------------

nn <- table(factor(diffs$severity, levels = 0:4), factor(diffs$no_news, levels = c(FALSE, TRUE)))
nn <- nn[rowSums(nn) > 0, , drop = FALSE]
figure("news-coverage", {
  graphics::par(mar = c(2.2, 9.5, 3.2, 1.2))
  m <- t(nn[rev(seq_len(nrow(nn))), , drop = FALSE])
  y <- graphics::barplot(m, horiz = TRUE, border = NA, col = c(col$base, col$cand_soft), space = 0.45,
                         names.arg = sev_text[colnames(m)], cex.names = 0.76, axes = FALSE,
                         xlim = c(0, max(colSums(m)) + 3.2))
  graphics::abline(v = seq(0, max(colSums(m)), 2), col = col$line, xpd = FALSE)
  graphics::barplot(m, horiz = TRUE, border = NA, col = c(col$base, col$cand_soft), space = 0.45,
                    names.arg = rep("", ncol(m)), axes = FALSE, add = TRUE)
  graphics::axis(1, at = seq(0, max(colSums(m)), 2), cex.axis = 0.72, lwd = 0, line = -0.6)
  graphics::text(colSums(m), y, sprintf("%d of %d without NEWS", m[2, ], colSums(m)), pos = 4,
                 cex = 0.68, col = col$muted)
  title_left(sprintf("%d of %d differences are in steps no NEWS bullet names",
                     sum(diffs$no_news, na.rm = TRUE), nrow(diffs)),
             sprintf("the bullets of %s's NEWS after %s, matched to the functions each step uses", pkg, lab$base))
  graphics::legend("topright", bty = "n", cex = 0.72, inset = c(0, -0.02),
                   legend = c("a NEWS bullet names the step", "no NEWS bullet names it"),
                   fill = c(col$base, col$cand_soft), border = NA, text.col = col$ink)
})


# 6. Run time per step ------------------------------------------------------------------

api <- cmp$scenarios[[length(cmp$scenarios)]]
tm <- do.call(rbind, lapply(api$steps, function(s) {
  t <- s$time
  if (is.null(t$base$n) || is.null(t$cand$n) || !t$base$n || !t$cand$n) return(NULL)
  data.frame(step = s$label, b_med = t$base$elapsed, b_min = t$base$min, b_max = t$base$max,
             c_med = t$cand$elapsed, c_min = t$cand$min, c_max = t$cand$max,
             n_b = t$base$n, n_c = t$cand$n, kinds = paste(s$kinds, collapse = ","))
}))
tm <- tm[rev(seq_len(nrow(tm))), ]
figure("timings", {
  graphics::par(mar = c(2.6, 6.2, 3.2, 4.2))
  ms <- 1000
  xmax <- max(c(tm$b_max, tm$c_max)) * ms * 1.05
  graphics::plot(NA, xlim = c(0, xmax), ylim = c(0.5, nrow(tm) + 0.5), axes = FALSE, xlab = "", ylab = "",
                 xaxs = "i", yaxs = "i")
  graphics::abline(v = pretty(c(0, xmax)), col = col$line, xpd = FALSE)
  yy <- seq_len(nrow(tm))
  graphics::segments(tm$b_min * ms, yy + 0.16, tm$b_max * ms, yy + 0.16, col = col$base, lwd = 2.2, lend = 1)
  graphics::segments(tm$c_min * ms, yy - 0.16, tm$c_max * ms, yy - 0.16, col = col$cand, lwd = 2.2, lend = 1)
  graphics::points(tm$b_med * ms, yy + 0.16, pch = 21, bg = col$base, col = "white", cex = 0.95, lwd = 0.8)
  graphics::points(tm$c_med * ms, yy - 0.16, pch = 21, bg = col$cand, col = "white", cex = 0.95, lwd = 0.8)
  graphics::axis(2, at = yy, labels = tm$step, cex.axis = 0.68, lwd = 0, family = mono, col.axis = col$ink)
  graphics::axis(1, at = pretty(c(0, xmax)), cex.axis = 0.7, lwd = 0, line = -0.7)
  graphics::mtext("elapsed time, ms", side = 1, line = 1.2, cex = 0.7, col = col$muted)
  flag <- grepl("slower|faster", tm$kinds)
  graphics::text(graphics::par("usr")[2], yy[flag], sub(".*(slower|faster).*", "\\1", tm$kinds[flag]),
                 pos = 4, cex = 0.7, font = 2, col = ifelse(grepl("slower", tm$kinds[flag]), col$cand, "#2b6a39"))
  title_left(sprintf("Run time per step of the %s scenario", api$id),
             sprintf("median and range of each version's timings, %s in blue and %s in orange", lab$base, lab$cand))
})


# 7. The hero image: the Differences section of the report ----------------------------

hero <- file.path(fig_dir, "report-differences.png")
if (requireNamespace("chromote", quietly = TRUE)) {
  # A tall viewport, so the whole section is on screen when it is captured.
  b <- chromote::ChromoteSession$new(width = 1100, height = 5000)
  page <- normalizePath(file.path(page_dir, "dossier.html"), winslash = "/")
  loaded <- b$Page$loadEventFired(wait_ = FALSE)
  b$Page$navigate(paste0("file:///", sub("^/", "", page)), wait_ = FALSE)
  b$wait_for(loaded)
  Sys.sleep(1)
  # From the section's top to the bottom of the last table row that ends within 720px.
  rect <- b$Runtime$evaluate(paste0(
    "(() => { const s = document.querySelector('#differences').getBoundingClientRect();",
    " const top = s.top + scrollY; let bottom = top + 300;",
    " for (const tr of document.querySelectorAll('#differences tr')) {",
    "   const r = tr.getBoundingClientRect(); const b = r.bottom + scrollY;",
    "   if (b - top <= 720) bottom = b; }",
    " return JSON.stringify([s.left + scrollX, top, s.width, bottom - top + 12]); })()"))$result$value
  r <- jsonlite::fromJSON(rect)
  b$screenshot(hero, cliprect = r, scale = 2, show = FALSE)
  invisible(b$close())
} else {
  message("chromote is not installed: the hero image is not redrawn.")
}


# Copy into pkgdown/assets/gallery/ ---------------------------------------------------
# The site serves pkgdown/assets/ at its root; re-copy every time the figures are
# redrawn, removing figures that are no longer drawn.

dest <- file.path("pkgdown", "assets", "gallery")
dir.create(dest, recursive = TRUE, showWarnings = FALSE)
new <- list.files(fig_dir, full.names = TRUE)
if (!file.exists(hero)) new <- c(new, file.path(dest, "report-differences.png"))
old <- setdiff(list.files(dest, full.names = TRUE), file.path(dest, basename(new)))
unlink(old)
invisible(file.copy(list.files(fig_dir, full.names = TRUE), dest, overwrite = TRUE))
message("Copied ", length(list.files(fig_dir)), " figure(s) to ", dest, ": ",
        paste(list.files(fig_dir), collapse = ", "))
