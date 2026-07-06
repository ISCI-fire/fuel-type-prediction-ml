# QC comparativo - Mapa de combustibles Kitral Anglo American (RM)
# Compara temporada 2021-2022 vs 2025-2026: distribución de área por clase,
# matriz de transición pixel a pixel, y mapa de cambio espacial.

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(data.table)

TIF_2021    <- "KitralFuelsDistribution_AngloRM.tif"
TIF_2025    <- "KitralFuelsDistribution_AngloRM_2025.tif"
LOOKUP_PATH <- "kitral_lookup_table-modified.csv"

out_dir <- "qc_output_comparativo"
dir.create(out_dir, showWarnings = FALSE)

cat("=====================================================\n")
cat("1. VERIFICACION DE ALINEACION ENTRE AMBOS RASTERS\n")
cat("=====================================================\n")

r21 <- rast(TIF_2021)
r25 <- rast(TIF_2025)

cat("2021 ->", paste(dim(r21), collapse = " x "), "  res:", paste(res(r21), collapse = "x"), "  crs:", crs(r21, describe = TRUE)$code, "\n")
cat("2025 ->", paste(dim(r25), collapse = " x "), "  res:", paste(res(r25), collapse = "x"), "  crs:", crs(r25, describe = TRUE)$code, "\n")

same_grid <- compareGeom(r21, r25, stopOnError = FALSE)
cat("Mismo grid (extent/res/crs):", same_grid, "\n")
if (!same_grid) stop("Los rasters no comparten el mismo grid - resample necesario antes de comparar.")

px_area_ha <- prod(res(r21)) / 10000

lookup <- fread(LOOKUP_PATH)
lookup <- lookup[!is.na(grid_value)]

# ── 2. Distribución de área por clase, cada año ──────────────────────────────
cat("\n=====================================================\n")
cat("2. DISTRIBUCION DE CLASES POR ANIO\n")
cat("=====================================================\n")

get_dist <- function(r, label) {
  f <- as.data.table(freq(r))
  setnames(f, c("layer", "value", "count"))
  f <- merge(f, lookup[, .(grid_value, descriptive_name, fuel_type)],
             by.x = "value", by.y = "grid_value", all.x = TRUE)
  valid_cells <- sum(f$count)
  f[, area_ha := count * px_area_ha]
  f[, pct_of_valid := round(100 * count / valid_cells, 2)]
  setnames(f, c("count", "area_ha", "pct_of_valid"), paste0(c("count", "area_ha", "pct_of_valid"), "_", label))
  list(dist = f, valid_cells = valid_cells, total_cells = ncell(r))
}

d21 <- get_dist(r21, "2021")
d25 <- get_dist(r25, "2025")

cat(sprintf("Cobertura valida 2021: %d / %d celdas (%.1f%%)\n",
            d21$valid_cells, d21$total_cells, 100 * d21$valid_cells / d21$total_cells))
cat(sprintf("Cobertura valida 2025: %d / %d celdas (%.1f%%)\n",
            d25$valid_cells, d25$total_cells, 100 * d25$valid_cells / d25$total_cells))

comp <- merge(d21$dist[, .(value, fuel_type, descriptive_name, area_ha_2021, pct_of_valid_2021)],
              d25$dist[, .(value, area_ha_2025, pct_of_valid_2025)],
              by = "value", all = TRUE)
comp[is.na(area_ha_2021), area_ha_2021 := 0]
comp[is.na(pct_of_valid_2021), pct_of_valid_2021 := 0]
comp[is.na(area_ha_2025), area_ha_2025 := 0]
comp[is.na(pct_of_valid_2025), pct_of_valid_2025 := 0]
comp[, diff_ha := round(area_ha_2025 - area_ha_2021, 1)]
comp[, diff_pct_relative := ifelse(area_ha_2021 > 0, round(100 * diff_ha / area_ha_2021, 1), NA)]
comp[, diff_pct_points := round(pct_of_valid_2025 - pct_of_valid_2021, 2)]
comp <- comp[order(-abs(diff_ha))]

cat("\nCambio de area por clase (ordenado por magnitud del cambio absoluto):\n")
print(comp[, .(fuel_type, descriptive_name,
               area_ha_2021 = round(area_ha_2021, 1), area_ha_2025 = round(area_ha_2025, 1),
               diff_ha, diff_pct_relative, diff_pct_points)])

fwrite(comp, file.path(out_dir, "class_distribution_2021_vs_2025.csv"))

n_classes_21 <- nrow(d21$dist)
n_classes_25 <- nrow(d25$dist)
cat("\nClases presentes 2021:", n_classes_21, "/ 32 -- Clases presentes 2025:", n_classes_25, "/ 32\n")
appeared  <- setdiff(comp[area_ha_2025 > 0]$fuel_type, comp[area_ha_2021 > 0]$fuel_type)
disappeared <- setdiff(comp[area_ha_2021 > 0]$fuel_type, comp[area_ha_2025 > 0]$fuel_type)
if (length(appeared) > 0)    cat("Clases nuevas en 2025 (ausentes en 2021):", paste(appeared, collapse = ", "), "\n")
if (length(disappeared) > 0) cat("Clases desaparecidas en 2025 (presentes en 2021):", paste(disappeared, collapse = ", "), "\n")

# ── 3. Matriz de transicion pixel a pixel ────────────────────────────────────
cat("\n=====================================================\n")
cat("3. MATRIZ DE TRANSICION PIXEL A PIXEL (2021 -> 2025)\n")
cat("=====================================================\n")

stk <- c(r21, r25)
names(stk) <- c("y2021", "y2025")
ctab <- crosstab(stk, useNA = FALSE)
ctab_dt <- as.data.table(as.data.frame(ctab))
setnames(ctab_dt, c("value_2021", "value_2025", "count"))
ctab_dt[, value_2021 := as.integer(as.character(value_2021))]
ctab_dt[, value_2025 := as.integer(as.character(value_2025))]
ctab_dt <- merge(ctab_dt, lookup[, .(grid_value, fuel_2021 = fuel_type)], by.x = "value_2021", by.y = "grid_value", all.x = TRUE)
ctab_dt <- merge(ctab_dt, lookup[, .(grid_value, fuel_2025 = fuel_type)], by.x = "value_2025", by.y = "grid_value", all.x = TRUE)
ctab_dt[, area_ha := count * px_area_ha]
ctab_dt <- ctab_dt[order(-count)]

total_compared <- sum(ctab_dt$count)
same_class <- sum(ctab_dt[fuel_2021 == fuel_2025]$count)
changed_class <- total_compared - same_class

cat(sprintf("Pixeles comparables (validos en ambos anios): %d\n", total_compared))
cat(sprintf("Misma clase 2021->2025: %d (%.1f%%)\n", same_class, 100 * same_class / total_compared))
cat(sprintf("Cambio de clase 2021->2025: %d (%.1f%%)\n", changed_class, 100 * changed_class / total_compared))

cat("\nTop 15 transiciones de clase mas frecuentes (excluyendo 'sin cambio'):\n")
print(head(ctab_dt[fuel_2021 != fuel_2025, .(fuel_2021, fuel_2025, count, area_ha = round(area_ha, 1))], 15))

fwrite(ctab_dt, file.path(out_dir, "transition_matrix_2021_2025.csv"))

# ── 4. Mapa de cambio espacial ───────────────────────────────────────────────
cat("\n=====================================================\n")
cat("4. MAPA DE CAMBIO ESPACIAL\n")
cat("=====================================================\n")

change_r <- ifel(r21 == r25, 0L, 1L)
names(change_r) <- "changed"

png(file.path(out_dir, "change_map_2021_vs_2025.png"), width = 2000, height = 2400, res = 200)
plot(change_r, col = c("grey85", "firebrick"),
     type = "classes", levels = c("Sin cambio de clase", "Cambio de clase"),
     main = "Cambio de clase Kitral: 2021-2022 vs 2025-2026 (Anglo American RM)",
     plg = list(cex = 0.7))
dev.off()
cat("Mapa de cambio guardado en:", file.path(out_dir, "change_map_2021_vs_2025.png"), "\n")
cat("(Revision manual recomendada: contrastar zonas de cambio contra faenas mineras conocidas\n")
cat(" y limites de concesion, ya que este script no incorpora una capa de uso minero.)\n")

cat("\n=====================================================\n")
cat("QC COMPARATIVO COMPLETO. Resultados en:", out_dir, "\n")
cat("=====================================================\n")
