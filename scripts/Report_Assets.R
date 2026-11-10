# Report_Assets.R ---------------------------------------------------------------------------------
# Runs the full analysis script in a clean session and exports everything the report needs:
#
#   report/figures/*.png        every figure the analysis displays (static maps and plots, 200 dpi),
#                               plus a few figures built for the report (study area, correlations, suitability by zone)
#   report/results/*.csv        the result tables quoted in the report
#   report/results/key_facts.json, session_info.txt, package_versions.csv, data_inventory.csv
#                               the reproducibility record (software, data versions, seeds, commit)
#
# How to run (from RStudio, with the project open):   source("scripts/Report_Assets.R")
# It takes about 10-20 minutes (the first run also reads the large RPI raster). Then knit report/Tsavo_HSM_Report.Rmd.
#
# Notes
#   - The analysis script is evaluated top to bottom, exactly as when knitting it, so the same data paths apply
#     (the RPI, PML_V2 and StudyPixels rasters are read from the paths written in that script).
#   - Interactive tmap views are switched to static plot mode so every map can be saved as a PNG.
#   - Titles, subtitles and captions inside ggplot figures are dropped from the PNGs; the report captions carry them.
#   - Set the environment variable REPORT_SKIP_FIGS=1 to evaluate the analysis without saving its figures (quick test of the rest).

if (!require("pacman")) install.packages("pacman")
pacman::p_load(here, knitr, ragg, jsonlite, tmap, magick, patchwork)

Analysis.Rmd <- here("scripts", "Mureithi_Tsavo_Habitat_Intelligence.Rmd")
Out.Fig      <- here("report", "figures")
Out.Res      <- here("report", "results")
dir.create(Out.Fig, recursive = TRUE, showWarnings = FALSE)
dir.create(Out.Res, recursive = TRUE, showWarnings = FALSE)
stopifnot(file.exists(Analysis.Rmd))

Fig.DPI    <- 200
Skip.Figs  <- identical(Sys.getenv("REPORT_SKIP_FIGS"), "1")
t.start    <- Sys.time()
lap        <- function(...) cat(sprintf("[%5.1f min] %s\n", as.numeric(difftime(Sys.time(), t.start, units = "mins")), paste0(...)))

# Static maps only: the analysis script switches tmap between "view" and "plot"; keep it in "plot"
tmap::tmap_mode("plot")
assign("tmap_mode", function(mode = "plot") invisible(tmap::tmap_mode("plot")), envir = globalenv())


# 1. Figure helpers --------------------------------------------------------------------------------

slugify <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", iconv(x, to = "ASCII//TRANSLIT"))
  x <- gsub("^_+|_+$", "", x)
  substr(x, 1, 70)
}

# A stable file name for each displayed figure: the object name if the chunk ends with a symbol,
# otherwise the map title (tmap) or the plot title (ggplot)
figure_name <- function(e, value) {
  if (is.name(e)) return(as.character(e))
  txt <- paste(deparse(e, width.cutoff = 500), collapse = " ")
  if (inherits(value, "ggplot") && !is.null(value$labels$title)) return(slugify(value$labels$title))
  m <- regmatches(txt, regexpr("tm_title\\(\\s*\"[^\"]+\"", txt))
  if (length(m) == 1) return(slugify(sub("tm_title\\(\\s*\"", "", m)))
  if (grepl("^tmap_arrange", txt)) return(slugify(paste0("arrange_", gsub("[(),=]|ncol|[0-9]", " ", sub("tmap_arrange\\(", "", txt)))))
  slugify(txt)
}

call_args_unnamed <- function(e) { a <- as.list(e)[-1]; nm <- names(a); if (is.null(nm)) a else a[nm == ""] }
call_arg_named    <- function(e, name, default) { a <- as.list(e)[-1]; if (!is.null(names(a)) && name %in% names(a)) eval(a[[name]]) else default }

# Canvas size (inches). Maps are trimmed to their content afterwards, so these only need to be generous enough
figure_size <- function(e, value) {
  txt <- paste(deparse(e, width.cutoff = 500), collapse = " ")
  if (grepl("^tmap_arrange", txt)) {
    n    <- length(call_args_unnamed(e))
    ncol <- call_arg_named(e, "ncol", default = 1)
    nrow <- ceiling(n / ncol)
    return(c(width = 4.0 * ncol + 1.6, height = 4.4 * nrow))
  }
  if (inherits(value, "ggplot")) {
    lab <- tolower(paste(value$labels$title, collapse = " "))
    if (grepl("correlation", lab)) return(c(width = 8.5, height = 4.6))
    return(c(width = 8.5, height = 5.4))
  }
  c(width = 6.8, height = 6.6)      # single tmap
}

# Light-touch fixes so the PNGs stay legible at report width (applied to specific ggplot figures only)
tweak_ggplot <- function(p, name) {
  p <- p + ggplot2::labs(title = NULL, subtitle = NULL, caption = NULL)
  if (grepl("Shrub.Profiles", name)) p <- p + ggplot2::guides(x = ggplot2::guide_axis(n.dodge = 2))              # long class labels overlap
  if (grepl("Extended.Heatmap", name)) p <- p + ggplot2::coord_cartesian(clip = "off") +
                                                ggplot2::theme(plot.margin = ggplot2::margin(22, 6, 6, 6))      # group labels sit above the panel
  p
}

trim_png <- function(file, border = 24) {
  im <- magick::image_read(file)
  im <- magick::image_trim(im, fuzz = 2)
  im <- magick::image_border(im, "white", paste0(border, "x", border))
  magick::image_write(im, file, format = "png", density = paste0(Fig.DPI, "x", Fig.DPI))
}

Fig.Inventory <- data.frame()
used.names    <- character()
Fig.MD5       <- character()      # fingerprint of every figure written, so a figure the analysis displays twice is kept once

# Draw an object (ggplot or tmap) to a PNG. Returns list(ok, dup): dup names the earlier figure if this one is identical to it
write_png <- function(value, name, width, height, trim = FALSE, scale = 1) {
  file <- file.path(Out.Fig, paste0(name, ".png"))
  ragg::agg_png(file, width = width, height = height, units = "in", res = Fig.DPI)
  if (scale != 1) tmap::tmap_options(scale = scale)
  ok <- tryCatch({ print(value); TRUE }, error = function(err) { message("   could not draw ", name, ": ", conditionMessage(err)); FALSE })
  if (scale != 1) tmap::tmap_options(scale = 1)
  grDevices::dev.off()
  if (!ok) { unlink(file); return(list(ok = FALSE, dup = NA_character_)) }

  md5 <- unname(tools::md5sum(file))
  dup <- names(Fig.MD5)[Fig.MD5 == md5]
  if (length(dup) > 0) { unlink(file); return(list(ok = TRUE, dup = dup[1])) }
  Fig.MD5[name] <<- md5

  if (trim) trim_png(file)
  list(ok = TRUE, dup = NA_character_)
}

log_figure <- function(name, class, width, height, res, expression = "") {
  Fig.Inventory <<- rbind(Fig.Inventory, data.frame(
    order = nrow(Fig.Inventory) + 1, file = paste0(name, ".png"), class = class,
    width_in = width, height_in = height, saved = res$ok && is.na(res$dup), duplicate_of = res$dup, expression = substr(expression, 1, 120)))
  lap("figure ", nrow(Fig.Inventory), ": ", name,
      if (!res$ok) "  (FAILED)" else if (!is.na(res$dup)) paste0("  (identical to ", res$dup, "; not kept)") else "")
}

# Save a figure that the analysis script displays
save_figure <- function(value, e) {
  nm <- figure_name(e, value)
  if (nm %in% used.names) { k <- 2; while (paste0(nm, "_", k) %in% used.names) k <- k + 1; nm <- paste0(nm, "_", k) }
  used.names <<- c(used.names, nm)
  if (inherits(value, "ggplot")) value <- tweak_ggplot(value, nm)
  sz   <- figure_size(e, value)
  is.map <- inherits(value, c("tmap", "tmap_arrange"))
  res  <- write_png(value, nm, sz[["width"]], sz[["height"]], trim = is.map, scale = if (is.map && sz[["width"]] > 8) 0.9 * sz[["width"]] / 6.5 else 1)
  log_figure(nm, class(value)[1], sz[["width"]], sz[["height"]], res, paste(deparse(e, width.cutoff = 500), collapse = " "))
}

# Save a figure that is built here for the report
save_extra <- function(value, name, width, height, trim = FALSE) {
  used.names <<- c(used.names, name)
  res <- write_png(value, name, width, height, trim = trim)
  log_figure(name, class(value)[1], width, height, res, "(built for the report)")
}


# 2. Run the analysis script, saving each displayed figure ---------------------------------------------

tmp.R <- tempfile(fileext = ".R")
suppressMessages(knitr::purl(Analysis.Rmd, output = tmp.R, documentation = 0, quiet = TRUE))
Exprs <- parse(tmp.R, keep.source = FALSE)
lap("analysis script: ", length(Exprs), " top-level expressions", if (Skip.Figs) " (figures not saved: REPORT_SKIP_FIGS=1)" else "")

is_figure <- function(v) inherits(v, c("ggplot", "tmap", "tmap_arrange"))

for (i in seq_along(Exprs)) {
  e  <- Exprs[[i]]
  t1 <- Sys.time()
  r  <- tryCatch(withVisible(eval(e, envir = globalenv())),
                 error = function(err) stop("Analysis failed at expression ", i, " (", substr(paste(deparse(e), collapse = " "), 1, 90), "):\n  ",
                                            conditionMessage(err), call. = FALSE))
  dt <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
  if (dt > 30) lap(sprintf("slow step: expression %d took %.0f s  [%s]", i, dt, substr(paste(deparse(e)[1], collapse = " "), 1, 70)))
  if (!Skip.Figs && isTRUE(r$visible) && is_figure(r$value)) save_figure(r$value, e)
}
lap("analysis finished; ", nrow(Fig.Inventory), " figures saved")


# 3. Figures built for the report -------------------------------------------------------------------------

safely <- function(label, expr) tryCatch(expr, error = function(err) { message("   (skipped: ", label, " - ", conditionMessage(err), ")"); NULL })

to4326 <- function(x) sf::st_transform(sf::st_make_valid(x), 4326)

# 3a. Study area overview: Kenya, the Tsavo Conservation Area (cheetah) and Tsavo West with its zones (rhino)
safely("study area", {
  Cols <- c("Tsavo East NP" = "#e6ab02", "Tsavo West NP" = "#d95f02", "South Kitui NR" = "#a6761d", "Chyulu Hills NP" = "#66a61e", "TTWCA ranches" = "#7570b3")
  tca  <- to4326(HSM.Zones.Cheetah.sf); tca$NAME <- factor(tca$NAME, levels = names(Cols))
  aoi  <- to4326(HSM.AOI.Cheetah)
  tw   <- to4326(TsavoWest); ipz <- to4326(TsavoWestIPZ); ng <- to4326(NguliaSanctuary); excl <- to4326(TsavoWest.Excl.RhinoRange)
  ken  <- to4326(Kenya.Admin.Boundary)

  pA <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = ken, fill = "grey96", colour = "grey30", linewidth = 0.3) +
    ggplot2::geom_sf(data = to4326(Kenya.Terrestrial.PAs), fill = "#b7d7b0", colour = NA, alpha = 0.8) +
    ggplot2::geom_sf(data = aoi, fill = NA, colour = "#b2182b", linewidth = 0.7) +
    ggplot2::labs(subtitle = "(a) Kenya") + theme_rpi() + ggplot2::theme(axis.text = ggplot2::element_text(size = 7), plot.subtitle = ggplot2::element_text(face = "bold"))

  pB <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = tca, ggplot2::aes(fill = NAME), colour = "grey25", linewidth = 0.25, alpha = 0.85) +
    ggplot2::geom_sf(data = aoi, fill = NA, colour = "#b2182b", linewidth = 0.6, linetype = "dashed") +
    ggplot2::scale_fill_manual(values = Cols, name = NULL, drop = FALSE) +
    ggplot2::labs(subtitle = "(b) Tsavo Conservation Area (cheetah)") + theme_rpi() +
    ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(size = 7), axis.text = ggplot2::element_text(size = 7), plot.subtitle = ggplot2::element_text(face = "bold")) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 3))

  Zc <- c("Tsavo West (excl. Rhino Range)" = "#fdd9b5", "Intensive Protection Zone (Rhino Range)" = "#f4a261", "Ngulia Sanctuary" = "#9c4f0b")
  zones <- rbind(
    sf::st_sf(Zone = "Tsavo West (excl. Rhino Range)", geometry = sf::st_geometry(excl)),
    sf::st_sf(Zone = "Intensive Protection Zone (Rhino Range)", geometry = sf::st_geometry(sf::st_union(ipz))),
    sf::st_sf(Zone = "Ngulia Sanctuary", geometry = sf::st_geometry(sf::st_union(ng))))
  zones$Zone <- factor(zones$Zone, levels = names(Zc))
  pC <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = zones, ggplot2::aes(fill = Zone), colour = "grey20", linewidth = 0.3) +
    ggplot2::geom_sf(data = tw, fill = NA, colour = "black", linewidth = 0.6) +
    ggplot2::scale_fill_manual(values = Zc, name = NULL) +
    ggplot2::labs(subtitle = "(c) Tsavo West NP (rhino)") + theme_rpi() +
    ggplot2::theme(legend.position = "bottom", legend.text = ggplot2::element_text(size = 7), axis.text = ggplot2::element_text(size = 7), plot.subtitle = ggplot2::element_text(face = "bold")) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 3))

  save_extra(pA + pB + pC + patchwork::plot_layout(widths = c(1, 1.1, 0.9)), "Study_area_overview", 11, 5.6)
})

# 3b. Predictor correlations (Spearman, 5,000 sampled cells) behind the collinearity filter
Cor.Tables <- list()
safely("correlation matrices", {    # evaluated at top level, so plain <- (not <<-) is needed inside
  cor_matrix <- function(Cells) {
    set.seed(42)
    vars <- setdiff(names(Cells), c("cell", "x", "y"))
    vars <- vars[vapply(Cells[vars], function(v) sd(v, na.rm = TRUE) > 0, logical(1))]
    S <- Cells[sample(nrow(Cells), min(5000, nrow(Cells))), vars, drop = FALSE]
    suppressWarnings(stats::cor(S, method = "spearman"))
  }
  Cor.Tables$rhino   <- cor_matrix(HSM.Cells.Rhino)
  Cor.Tables$cheetah <- cor_matrix(HSM.Cells.Cheetah)
  for (nm in names(Cor.Tables)) utils::write.csv(round(Cor.Tables[[nm]], 3), file.path(Out.Res, paste0("HSM_", nm, "_predictor_correlations.csv")))

  heat <- function(M, kept, title) {
    d <- as.data.frame(as.table(M)); names(d) <- c("A", "B", "r")
    ord <- colnames(M); d$A <- factor(d$A, levels = ord); d$B <- factor(d$B, levels = rev(ord))
    star <- function(x) ifelse(x %in% kept, x, paste0(x, " *"))        # * = removed by the collinearity filter or excluded by design
    ggplot2::ggplot(d, ggplot2::aes(A, B, fill = r)) +
      ggplot2::geom_tile(colour = "white") +
      ggplot2::geom_text(ggplot2::aes(label = sprintf("%.2f", r), colour = abs(r) > 0.5), size = 2.3) +
      ggplot2::scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "grey20"), guide = "none") +
      scico::scale_fill_scico(palette = "vik", limits = c(-1, 1), name = "Spearman r") +
      ggplot2::scale_x_discrete(position = "top", labels = star) + ggplot2::scale_y_discrete(labels = star) +
      ggplot2::labs(subtitle = title, x = NULL, y = NULL) + ggplot2::coord_cartesian(clip = "off") + theme_rpi() +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 0, size = 7), axis.text.y = ggplot2::element_text(size = 7),
                     panel.grid = ggplot2::element_blank(), legend.position = "none", plot.subtitle = ggplot2::element_text(face = "bold"),
                     plot.margin = ggplot2::margin(5.5, 42, 5.5, 5.5))      # room for the slanted column labels on the right
  }
  save_extra(heat(Cor.Tables$rhino, HSM.Vars.Rhino, "(a) Tsavo West (rhino)") + heat(Cor.Tables$cheetah, HSM.Vars.Cheetah, "(b) Tsavo Conservation Area (cheetah)"),
             "Predictor_correlations", 12, 6)
})

# 3c. Suitability by zone (rhino) and by management unit (cheetah)
safely("suitability by zone", {
  zone_values <- function(HSI, zones) {
    do.call(rbind, lapply(names(zones), function(z) {
      v <- terra::extract(HSI, terra::vect(sf::st_union(sf::st_transform(zones[[z]], terra::crs(HSI)))))[[2]]
      data.frame(Unit = z, HSI = v[!is.na(v)])
    }))
  }
  Zr <- zone_values(HSM.HSI.Rhino, HSM.Zones.Rhino[c("Tsavo West NP", "Rhino Range (Ngulia + IPZ)", "Ngulia Sanctuary", "Tsavo West (excl. Rhino Range)")])
  Zr$Unit <- factor(Zr$Unit, levels = c("Tsavo West NP", "Tsavo West (excl. Rhino Range)", "Rhino Range (Ngulia + IPZ)", "Ngulia Sanctuary"))
  Zc <- if (exists("Zone.Colours")) Zone.Colours else NULL
  p1 <- ggplot2::ggplot(Zr, ggplot2::aes(Unit, HSI, fill = Unit, colour = Unit)) +
    ggplot2::geom_violin(alpha = 0.35, linewidth = 0.4, scale = "width") +
    ggplot2::geom_boxplot(width = 0.12, fill = "white", colour = "grey20", outlier.shape = NA, linewidth = 0.35) +
    ggplot2::geom_hline(yintercept = HSM.Fit.Rhino$Threshold, linetype = "dashed", colour = "grey30") +
    ggplot2::scale_x_discrete(labels = function(x) stringr::str_wrap(x, 14)) +
    ggplot2::labs(subtitle = "(a) Black rhino (Tsavo West)", x = NULL, y = "Habitat suitability index (HSI)") + theme_rpi() +
    ggplot2::theme(legend.position = "none", plot.subtitle = ggplot2::element_text(face = "bold"))
  if (!is.null(Zc) && all(levels(Zr$Unit) %in% names(Zc))) p1 <- p1 + ggplot2::scale_fill_manual(values = Zc) + ggplot2::scale_colour_manual(values = Zc)

  Zk <- zone_values(HSM.HSI.Cheetah, HSM.Zones.Cheetah)
  Zk$Unit <- factor(Zk$Unit, levels = names(HSM.Zones.Cheetah))
  p2 <- ggplot2::ggplot(Zk, ggplot2::aes(Unit, HSI, fill = Unit, colour = Unit)) +
    ggplot2::geom_violin(alpha = 0.35, linewidth = 0.4, scale = "width") +
    ggplot2::geom_boxplot(width = 0.12, fill = "white", colour = "grey20", outlier.shape = NA, linewidth = 0.35) +
    ggplot2::geom_hline(yintercept = HSM.Thr.Cheetah, linetype = "dashed", colour = "grey30") +
    ggplot2::scale_fill_manual(values = c("#e6ab02", "#d95f02", "#a6761d", "#66a61e", "#7570b3")) +
    ggplot2::scale_colour_manual(values = c("#e6ab02", "#d95f02", "#a6761d", "#66a61e", "#7570b3")) +
    ggplot2::scale_x_discrete(labels = function(x) stringr::str_wrap(x, 12)) +
    ggplot2::labs(subtitle = paste0("(b) Cheetah (", HSM.Mode.Cheetah, " mode)"), x = NULL, y = "Habitat suitability index (HSI)") + theme_rpi() +
    ggplot2::theme(legend.position = "none", plot.subtitle = ggplot2::element_text(face = "bold"))
  save_extra(p1 + p2 + patchwork::plot_layout(widths = c(1, 1.15)), "HSI_by_zone", 10.5, 4.8)
})

# 3d. Spread of the rhino HSI across the 10 repetitions (a measure of model uncertainty)
safely("HSI uncertainty map", {
  p <- ggplot2::ggplot() +
    tidyterra::geom_spatraster(data = HSM.Fit.Rhino$HSI.SD) +
    ggplot2::scale_fill_viridis_c(option = "magma", na.value = NA, name = "SD of HSI\n(10 runs)") +
    ggplot2::geom_sf(data = sf::st_transform(TsavoWest, 32737), fill = NA, colour = "black", linewidth = 0.4) +
    ggplot2::geom_sf(data = sf::st_transform(sf::st_union(TsavoWest.Rhino.Range), 32737), fill = NA, colour = "white", linewidth = 0.5) +
    ggplot2::labs(x = NULL, y = NULL) + theme_rpi() + ggplot2::theme(axis.text = ggplot2::element_text(size = 7))
  save_extra(p, "Rhino_HSI_uncertainty", 6.2, 6.4, trim = TRUE)

  # How large the spread is inside each zone (zone_values() is defined in the previous block)
  Zs <- zone_values(HSM.Fit.Rhino$HSI.SD, HSM.Zones.Rhino[c("Tsavo West NP", "Tsavo West (excl. Rhino Range)", "Rhino Range (Ngulia + IPZ)")])
  Sd.Tab <- do.call(rbind, lapply(split(Zs$HSI, Zs$Unit), function(v)
    data.frame(Mean.SD = mean(v), P90.SD = unname(quantile(v, 0.9)), Max.SD = max(v), Pct.SD.below.0.10 = mean(v < 0.10) * 100, Pct.SD.above.0.20 = mean(v > 0.20) * 100)))
  utils::write.csv(cbind(Unit = rownames(Sd.Tab), Sd.Tab), file.path(Out.Res, "HSM_Rhino_HSI_SD_by_zone.csv"), row.names = FALSE)
})

write.csv(Fig.Inventory, file.path(Out.Fig, "_figure_inventory.csv"), row.names = FALSE)
lap("figures done: ", nrow(Fig.Inventory))


# 4. Result tables ----------------------------------------------------------------------------------------

export_table <- function(obj.name, file = paste0(obj.name, ".csv")) {
  if (!exists(obj.name, envir = globalenv())) { message("   (not found) ", obj.name); return(invisible(FALSE)) }
  x <- get(obj.name, envir = globalenv())
  utils::write.csv(as.data.frame(x), file.path(Out.Res, file), row.names = FALSE)
  invisible(TRUE)
}

Tables <- c(
  "RPI.Zone.Overall.Summary", "RPI.Zone.Annual.Summary", "Unified.Zone.Profile", "IGBP.All.Zones",
  "RPI.Zone.Trends", "RPI.Gap.Annual", "RPI.Gap.Trend.Summary", "RPI.Pixel.Trend.Summary",
  "Spearman.Correlations", "Spearman.Extended", "Terrain.Zone.Summary",
  "HSM.Summary.Rhino", "HSM.Summary.Cheetah", "Candidate.Summary", "Cheetah.Prior"
)
for (nm in Tables) export_table(nm)

# Model tables held inside lists
utils::write.csv(HSM.Fit.Rhino$Metrics,    file.path(Out.Res, "HSM_Rhino_Metrics_by_run.csv"), row.names = FALSE)
utils::write.csv(HSM.Fit.Rhino$Importance, file.path(Out.Res, "HSM_Rhino_Importance.csv"),     row.names = FALSE)
utils::write.csv(HSM.PDP.Rhino,            file.path(Out.Res, "HSM_Rhino_Response_curves.csv"), row.names = FALSE)
utils::write.csv(HSM.Clean.Rhino$steps,    file.path(Out.Res, "HSM_Rhino_GBIF_cleaning.csv"),   row.names = FALSE)
utils::write.csv(HSM.Clean.Cheetah$steps,  file.path(Out.Res, "HSM_Cheetah_GBIF_cleaning.csv"), row.names = FALSE)

# Pixel counts per zone (the pixels behind the zone statistics) and how much of each zone the RPI raster covers.
# The RPI raster has a rectangular strip of no data running north-south through the Rhino Range, so coverage is below 100%.
Zone.List <- list("Tsavo West NP" = TsavoWest, "Tsavo West (excl. Rhino Range)" = TsavoWest.Excl.RhinoRange,
                  "Rhino Range (Ngulia + IPZ)" = TsavoWest.Rhino.Range, "Ngulia Sanctuary" = NguliaSanctuary, "Intensive Protection Zone" = TsavoWestIPZ)
safely("RPI coverage", {
  cs  <- terra::cellSize(RPI[[1]], unit = "km")
  has <- terra::ifel(is.na(RPI[[1]]), 0, 1)
  cov <- do.call(rbind, lapply(names(Zone.List), function(z) {
    v   <- terra::vect(sf::st_union(sf::st_transform(sf::st_make_valid(Zone.List[[z]]), terra::crs(RPI))))     # dissolved: Ngulia lies inside the IPZ
    tot <- terra::extract(cs, v, fun = sum, na.rm = TRUE, ID = FALSE)[[1]]
    got <- terra::extract(cs * has, v, fun = sum, na.rm = TRUE, ID = FALSE)[[1]]
    data.frame(ZONE = z, Cells.km2.expected = round(sum(tot), 1), Cells.km2.with.RPI = round(sum(got), 1), RPI.Coverage.Pct = round(sum(got) / sum(tot) * 100, 1))
  }))
  pix <- as.data.frame(table(ZONE = RPI.Pixel.Mean$ZONE), responseName = "N.Pixels")
  utils::write.csv(merge(cov, pix, by = "ZONE", sort = FALSE), file.path(Out.Res, "Zone_RPI_coverage.csv"), row.names = FALSE)
})
# Quality of the GBIF records that were downloaded (cached by the analysis script): how many are precise enough for a 500 m model
safely("GBIF quality", {
  gbif_quality <- function(file, species) {
    d <- utils::read.csv(file, na.strings = c("", "NA"), stringsAsFactors = FALSE)
    data.frame(
      Species = species, Records = nrow(d), Year.Min = min(d$year, na.rm = TRUE), Year.Max = max(d$year, na.rm = TRUE),
      With.Uncertainty = sum(!is.na(d$unc)), Median.Uncertainty.m = median(d$unc, na.rm = TRUE),
      Uncertainty.le.1000m = sum(d$unc <= 1000, na.rm = TRUE),
      Coordinates.Rounded = sum(grepl("COORDINATE_ROUNDED", d$issues)), Location.Withheld = sum(!is.na(d$withheld)),
      iNaturalist = sum(grepl("iNaturalist", d$dataset, ignore.case = TRUE)))
  }
  utils::write.csv(rbind(gbif_quality(file.path(HSM.Dir.Species, "gbif_rhino.csv"),   "Black rhino"),
                         gbif_quality(file.path(HSM.Dir.Species, "gbif_cheetah.csv"), "Cheetah")),
                   file.path(Out.Res, "HSM_GBIF_quality.csv"), row.names = FALSE)
})
lap("tables written")


# 5. Sensitivity of the rhino result to the water layer ------------------------------------------------------
# Section 5 uses distance to JRC surface water when the GEE exports are present. Section 4B uses the WhiteboxTools stream network.
# Here the rhino model is refitted with the stream-network distance to see how much the candidate expansion area depends on that choice.

safely("water-layer sensitivity", {
  cell.km2 <- (HSM.Config$Grain.m / 1000)^2

  Water.WBT <- to_grid(TsavoWest.DistToWater, HSM.Template.Rhino)
  names(Water.WBT) <- "Dist_Water_km"
  Pred.WBT <- HSM.Pred.Rhino
  Pred.WBT[["Dist_Water_km"]] <- Water.WBT
  Pred.WBT <- terra::mask(Pred.WBT, HSM.Template.Rhino)
  Cells.WBT <- as.data.frame(Pred.WBT, cells = TRUE, xy = TRUE, na.rm = TRUE)

  set.seed(42)
  Vars.WBT <- drop_collinear(Cells.WBT, setdiff(HSM.Priority, c("Pop_log10", "rain_annual_mm", "rain_dry_mm", "rain_cv")), HSM.Config$Corr.Max)
  Pres.WBT <- intersect(range_proxy_cells(TsavoWest.Rhino.Range, HSM.Template.Rhino), Cells.WBT$cell)
  Fit.WBT  <- fit_hsm_rf(Cells.WBT, Pres.WBT, Vars.WBT, HSM.Template.Rhino, block_km = 5, cfg = HSM.Config, pa_method = "random")

  summarise_water <- function(label, Fit, Water.km) {
    HSI.E <- terra::mask(Fit$HSI, Expansion.Zone, touches = FALSE)      # same rule as Step 12 of the analysis script
    top20 <- quantile(terra::values(HSI.E), 0.80, na.rm = TRUE)[[1]]
    ok    <- Water.km <= 5
    range_like <- sum(terra::values(HSI.E >= Fit$Threshold & ok), na.rm = TRUE)
    best20     <- sum(terra::values(HSI.E >= top20 & ok & HSI.E < Fit$Threshold), na.rm = TRUE)
    data.frame(
      Water.Layer = label, Predictors = paste(Fit$Vars, collapse = ", "),
      AUC.ROC = mean(Fit$Metrics$AUC.ROC), AUC.PR = mean(Fit$Metrics$AUC.PR), Threshold = Fit$Threshold,
      Mean.HSI.Expansion.Zone = mean(terra::values(HSI.E), na.rm = TRUE),
      Expansion.Zone.above.threshold.km2 = sum(terra::values(HSI.E >= Fit$Threshold), na.rm = TRUE) * cell.km2,
      Candidate.RangeLike.km2 = range_like * cell.km2, Candidate.Best20.km2 = best20 * cell.km2,
      Cells.within.5km.of.water.in.expansion.zone.km2 = sum(terra::values(terra::mask(ok, Expansion.Zone, touches = FALSE)), na.rm = TRUE) * cell.km2)
  }
  Sens <- rbind(
    summarise_water("JRC surface water (Section 5 default)", HSM.Fit.Rhino, HSM.Pred.Rhino[["Dist_Water_km"]]),
    summarise_water("WhiteboxTools stream network (Section 4B)", Fit.WBT, Pred.WBT[["Dist_Water_km"]]))
  utils::write.csv(Sens, file.path(Out.Res, "HSM_Rhino_water_sensitivity.csv"), row.names = FALSE)

  # How far each zone lies from water under the two definitions (this is what drives the difference in candidate area)
  zone_water <- function(label, Water.km) {
    do.call(rbind, lapply(names(HSM.Zones.Rhino), function(z) {
      v <- terra::extract(Water.km, terra::vect(sf::st_union(sf::st_transform(HSM.Zones.Rhino[[z]], terra::crs(Water.km)))))[[2]]
      v <- v[!is.na(v)]
      data.frame(Water.Layer = label, Unit = z, Cells = length(v), Mean.Dist.km = mean(v), Median.Dist.km = median(v),
                 Pct.Within.2km = mean(v <= 2) * 100, Pct.Within.5km = mean(v <= 5) * 100)
    }))
  }
  utils::write.csv(rbind(zone_water("JRC surface water (Section 5 default)", HSM.Pred.Rhino[["Dist_Water_km"]]),
                         zone_water("WhiteboxTools stream network (Section 4B)", Pred.WBT[["Dist_Water_km"]])),
                   file.path(Out.Res, "HSM_Rhino_water_by_zone.csv"), row.names = FALSE)
  print(Sens[, c("Water.Layer", "AUC.ROC", "Candidate.RangeLike.km2", "Candidate.Best20.km2")])
})
lap("sensitivity done")


# 6. Key facts (numbers quoted in the text) -----------------------------------------------------------------

area_km2 <- function(x) round(as.numeric(sf::st_area(sf::st_union(sf::st_make_valid(sf::st_transform(x, 32737))))) / 1e6)

Facts <- list(
  generated    = format(Sys.time(), "%Y-%m-%d %H:%M"),
  analysis     = basename(Analysis.Rmd),
  analysis_md5 = unname(tools::md5sum(Analysis.Rmd)),
  git_commit   = tryCatch(system("git rev-parse --short HEAD", intern = TRUE, ignore.stderr = TRUE), error = function(e) NA_character_),
  git_dirty    = tryCatch(length(system("git status --porcelain", intern = TRUE, ignore.stderr = TRUE)) > 0, error = function(e) NA),   # TRUE = uncommitted changes when the report was generated
  zone_area_km2 = list(
    tsavo_west = area_km2(TsavoWest), ngulia = area_km2(NguliaSanctuary), ipz = area_km2(TsavoWestIPZ),
    rhino_range = area_km2(TsavoWest.Rhino.Range), tw_excl_rhino_range = area_km2(TsavoWest.Excl.RhinoRange),
    cheetah_study_area = area_km2(HSM.AOI.Cheetah),
    cheetah_units = lapply(HSM.Zones.Cheetah, area_km2)
  ),
  rpi = list(layers = terra::nlyr(RPI), resolution_deg = terra::res(RPI)[1], first_layer = names(RPI)[1], last_layer = names(RPI)[terra::nlyr(RPI)]),
  gbif = list(
    rhino_file   = tryCatch(format(file.info(file.path(HSM.Dir.Species, "gbif_rhino.csv"))$mtime, "%Y-%m-%d"), error = function(e) NA_character_),
    cheetah_file = tryCatch(format(file.info(file.path(HSM.Dir.Species, "gbif_cheetah.csv"))$mtime, "%Y-%m-%d"), error = function(e) NA_character_)
  ),
  hsm = list(
    config         = HSM.Config[setdiff(names(HSM.Config), "Seeds")],
    seeds          = HSM.Config$Seeds,
    rhino = list(
      cells_complete = nrow(HSM.Cells.Rhino), cells_study_area = as.integer(terra::global(!is.na(HSM.Template.Rhino), "sum")[[1]]),
      presence_cells = length(HSM.Pres.Rhino), predictors_available = setdiff(names(HSM.Cells.Rhino), c("cell", "x", "y")), predictors_kept = HSM.Vars.Rhino,
      threshold = HSM.Fit.Rhino$Threshold, top20_cutoff = Top20.Threshold
    ),
    cheetah = list(
      cells_complete = nrow(HSM.Cells.Cheetah), cells_study_area = as.integer(terra::global(!is.na(HSM.Template.Cheetah), "sum")[[1]]),
      precise_presences = length(HSM.Pres.Cheetah), mode = HSM.Mode.Cheetah, predictors_available = setdiff(names(HSM.Cells.Cheetah), c("cell", "x", "y")),
      predictors_kept = HSM.Vars.Cheetah, threshold = HSM.Thr.Cheetah
    )
  )
)
if (!is.null(HSM.Clean.Cheetah$points) && nrow(HSM.Clean.Cheetah$points) > 0) {
  at.pts <- terra::extract(HSM.HSI.Cheetah, terra::vect(HSM.Clean.Cheetah$points))[[2]]
  Facts$hsm$cheetah$reality_check <- list(n = sum(!is.na(at.pts)), mean_percentile = round(mean(ecdf(terra::values(HSM.HSI.Cheetah))(at.pts), na.rm = TRUE) * 100))
}
jsonlite::write_json(Facts, file.path(Out.Res, "key_facts.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")


# 7. Reproducibility record ----------------------------------------------------------------------------------

writeLines(capture.output(sessionInfo()), file.path(Out.Res, "session_info.txt"))

pk <- sort(loadedNamespaces())
utils::write.csv(data.frame(package = pk, version = vapply(pk, function(p) as.character(utils::packageVersion(p)), "")),
                 file.path(Out.Res, "package_versions.csv"), row.names = FALSE)

# Input data: every file the analysis reads, with size and MD5 so readers can check they hold the same versions
analysis.text <- readLines(Analysis.Rmd, warn = FALSE, encoding = "UTF-8")
ext.rasters   <- unique(unlist(regmatches(analysis.text, gregexpr("(?<=rast\\(\")[^\"]+(?=\")", analysis.text, perl = TRUE))))
ext.rasters   <- ext.rasters[file.exists(ext.rasters)]
project.files <- c(
  list.files(here("data", "gee_exports"), pattern = "\\.tif$", full.names = TRUE),
  here("data", "Country_Borders", c("africa_country_boundaries_simplified_wgs84.shp", "kenya_admin_boundary_wgs84.shp",
                                    "kenya_terrestrial_protected_areas_wgs84.shp", "ken_pd_2020_1km.tif")),
  list.files(here("data", "TsavoWest_Rhino_Zones"), pattern = "\\.shp$", full.names = TRUE),
  list.files(here("data", "Tsavo_Conservation_Areas"), pattern = "^(TCAFInal|RanchesTTWCA)\\.shp$", full.names = TRUE),
  list.files(here("data", "WDPA_Amboseli_Tsavo"), pattern = "(19564|19563).*polygons\\.shp$", recursive = TRUE, full.names = TRUE),
  list.files(here("data", "Terrain"), pattern = "\\.tif$", full.names = TRUE, recursive = TRUE)
)
all.files <- unique(c(ext.rasters, project.files[file.exists(project.files)]))
utils::write.csv(data.frame(
  file    = ifelse(startsWith(all.files, here()), substring(all.files, nchar(here()) + 2), basename(all.files)),
  in_repo = startsWith(all.files, here()),
  size_MB = round(file.size(all.files) / 1e6, 2),
  md5     = unname(tools::md5sum(all.files))
), file.path(Out.Res, "data_inventory.csv"), row.names = FALSE)
lap("reproducibility record written")

lap("DONE: ", nrow(Fig.Inventory), " figures in ", Out.Fig, "; results in ", Out.Res)
