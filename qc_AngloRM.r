# QC del mapa de combustibles Kitral - Área Anglo American (RM)
# Verifica: distribución de clases, cobertura/máscara, visualización, chequeo espacial
# contra las 45 etiquetas digitalizadas de la RM (fotointerpretación Google Earth Pro).

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(sf)
library(data.table)

TIF_PATH    <- "KitralFuelsDistribution_AngloRM.tif"
LOOKUP_PATH <- "kitral_lookup_table-modified.csv"
LABELS_KML  <- "C:/No_nube/modelingFuelsKitral/fotointerpretacion_combustibles.kml"
BOUNDARY    <- "RM_SN_bf.gpkg"

out_dir <- "qc_output"
dir.create(out_dir, showWarnings = FALSE)

cat("=====================================================\n")
cat("1. INFO BÁSICA DEL RASTER\n")
cat("=====================================================\n")

r <- rast(TIF_PATH)
print(r)
cat("\nResolución:", paste(res(r), collapse = " x "), "m\n")
cat("CRS:", crs(r, describe = TRUE)$name, "\n")
cat("Dimensiones:", nrow(r), "x", ncol(r), "=", ncell(r), "celdas\n")

px_area_ha <- prod(res(r)) / 10000

# ── 2. Distribución de clases ────────────────────────────────────────────────
cat("\n=====================================================\n")
cat("2. DISTRIBUCIÓN DE CLASES (grid_value)\n")
cat("=====================================================\n")

f <- freq(r)
f <- as.data.table(f)
setnames(f, c("layer", "value", "count"))

lookup <- fread(LOOKUP_PATH)
lookup <- lookup[!is.na(grid_value)]

f <- merge(f, lookup[, .(grid_value, descriptive_name, fuel_type)],
           by.x = "value", by.y = "grid_value", all.x = TRUE)

total_cells   <- ncell(r)
valid_cells   <- sum(f$count)
na_cells      <- total_cells - valid_cells

f[, area_ha := count * px_area_ha]
f[, pct_of_valid := round(100 * count / valid_cells, 2)]
f <- f[order(-count)]

print(f[, .(fuel_type, descriptive_name, count, area_ha = round(area_ha, 1), pct_of_valid)])

fwrite(f, file.path(out_dir, "class_distribution.csv"))

cat("\n--- Cobertura de datos (máscara) ---\n")
cat("Celdas totales (extent):", total_cells, "\n")
cat("Celdas con predicción (no-NA):", valid_cells,
    sprintf(" (%.1f%%)", 100 * valid_cells / total_cells), "\n")
cat("Celdas NA (sin dato / fuera de máscara):", na_cells,
    sprintf(" (%.1f%%)", 100 * na_cells / total_cells), "\n")
cat("Área total válida:", round(valid_cells * px_area_ha, 0), "ha\n")

n_classes_present <- nrow(f)
cat("\nClases Kitral presentes en el mapa:", n_classes_present, "de 32 posibles\n")
if (n_classes_present < 32) {
  missing <- setdiff(lookup[grid_value <= 34]$fuel_type, f$fuel_type)
  cat("Clases NO presentes:", paste(missing, collapse = ", "), "\n")
}

# Clases con área sospechosamente pequeña (<0.05% del área válida)
rare <- f[pct_of_valid < 0.05]
if (nrow(rare) > 0) {
  cat("\n⚠️ Clases con área muy pequeña (<0.05% del mapa) — posible ruido/sal-y-pimienta:\n")
  print(rare[, .(fuel_type, descriptive_name, count, pct_of_valid)])
}

# ── 3. Visualización ─────────────────────────────────────────────────────────
cat("\n=====================================================\n")
cat("3. VISUALIZACIÓN\n")
cat("=====================================================\n")

lookup_present <- lookup[grid_value %in% f$value]
lookup_present <- lookup_present[order(grid_value)]

# Fallback colors for entries with missing RGB in the lookup CSV (SV01/SV02/SV03)
fallback_colors <- c(SV01 = "#3399FF", SV02 = "#CC0000", SV03 = "#C2A878")
missing_rgb <- is.na(lookup_present$r) | is.na(lookup_present$g) | is.na(lookup_present$b)
cols <- character(nrow(lookup_present))
cols[!missing_rgb] <- rgb(lookup_present$r[!missing_rgb], lookup_present$g[!missing_rgb],
                          lookup_present$b[!missing_rgb], maxColorValue = 255)
cols[missing_rgb] <- fallback_colors[lookup_present$fuel_type[missing_rgb]]

png(file.path(out_dir, "KitralFuelsDistribution_AngloRM_map.png"),
    width = 2000, height = 2400, res = 200)
plot(r, col = cols, breaks = c(lookup_present$grid_value - 0.5, max(lookup_present$grid_value) + 0.5),
     type = "classes", levels = lookup_present$descriptive_name,
     main = "Kitral Fuels Distribution - Anglo American RM",
     plg = list(cex = 0.5))
dev.off()
cat("Mapa guardado en:", file.path(out_dir, "KitralFuelsDistribution_AngloRM_map.png"), "\n")

# ── 4. Chequeo espacial contra etiquetas digitalizadas RM ────────────────────
cat("\n=====================================================\n")
cat("4. CHEQUEO ESPACIAL vs 45 ETIQUETAS DIGITALIZADAS (RM)\n")
cat("(NOTA: estos polígonos SÍ entraron al pool de entrenamiento/test,\n")
cat(" por lo tanto esto NO es una validación independiente,\n")
cat(" es un chequeo de consistencia espacial / ajuste.)\n")
cat("=====================================================\n")

labels <- st_read(LABELS_KML, quiet = TRUE)
labels <- st_zm(labels, drop = TRUE, what = "ZM")
labels <- st_transform(labels, crs(r))

cat("Polígonos digitalizados cargados:", nrow(labels), "\n")

labels_v <- vect(labels)

# Extraer valores predichos dentro de cada polígono
ext_vals <- terra::extract(r, labels_v, ID = TRUE)
names(ext_vals)[2] <- "pred_grid_value"

# Clase predicha mayoritaria por polígono
ext_dt <- as.data.table(ext_vals)
ext_dt <- merge(ext_dt, lookup[, .(grid_value, pred_fuel_type = fuel_type)],
                by.x = "pred_grid_value", by.y = "grid_value", all.x = TRUE)

majority <- ext_dt[!is.na(pred_fuel_type), .N, by = .(ID, pred_fuel_type)]
majority <- majority[order(ID, -N)]
majority <- majority[, .SD[1], by = ID]

labels_dt <- as.data.table(labels)
labels_dt[, ID := .I]

comparison <- merge(labels_dt[, .(ID, Name)], majority, by = "ID", all.x = TRUE)
comparison[, match := Name == pred_fuel_type]

cat("\nComparación etiqueta digitalizada vs clase mayoritaria predicha:\n")
print(comparison[, .(ID, Name, pred_fuel_type, N_pixels = N, match)])

n_match <- sum(comparison$match, na.rm = TRUE)
n_total <- sum(!is.na(comparison$pred_fuel_type))
cat(sprintf("\nCoincidencia polígono-mayoría: %d / %d (%.1f%%)\n",
            n_match, n_total, 100 * n_match / n_total))

fwrite(comparison, file.path(out_dir, "rm_labels_spatial_check.csv"))

cat("\n=====================================================\n")
cat("QC COMPLETO. Resultados en:", out_dir, "\n")
cat("=====================================================\n")
