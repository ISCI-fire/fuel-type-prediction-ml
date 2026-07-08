# Recorta los mapas de combustibles Kitral Anglo American al area oficialmente
# comprometida en el proyecto (roi_suroeste + Santuario de la Naturaleza Los Nogales),
# en vez de la extension de trabajo ampliada (RM_SN_bf).

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(sf)
library(data.table)

AREA_BASE <- "G:/Mi unidad/F2A/[01] Proyectos y Postulaciones/[01] Proyectos/Anglo American - SOFOFA/datos/area_estudio"
LOOKUP_PATH <- "kitral_lookup_table-modified.csv"
out_dir <- "area_comprometida"
dir.create(out_dir, showWarnings = FALSE)

cat("=====================================================\n")
cat("1. CONSTRUYENDO EL LIMITE DEL AREA COMPROMETIDA\n")
cat("=====================================================\n")

roi <- st_read(file.path(AREA_BASE, "roi_suroeste.gpkg"), quiet = TRUE)
nogales <- st_read(file.path(AREA_BASE, "nogales.gpkg"), quiet = TRUE)

# Unir ambas geometrias en un solo poligono de area comprometida
area_comprometida <- st_union(st_geometry(roi), st_geometry(nogales))
area_comprometida <- st_make_valid(area_comprometida)
cat("Area comprometida (union roi_suroeste + nogales):", round(sum(as.numeric(st_area(area_comprometida))) / 10000, 1), "ha\n")

st_write(st_sf(geometry = area_comprometida), file.path(out_dir, "area_comprometida.gpkg"), quiet = TRUE, delete_dsn = TRUE)

lookup <- fread(LOOKUP_PATH)
lookup <- lookup[!is.na(grid_value)]

clip_and_summarize <- function(tif_path, label) {
  cat("\n=====================================================\n")
  cat("Procesando:", tif_path, "\n")
  cat("=====================================================\n")

  r <- rast(tif_path)
  area_v <- vect(st_transform(st_sf(geometry = area_comprometida), crs(r)))

  r_crop <- crop(r, area_v)
  r_clip <- mask(r_crop, area_v)

  out_tif <- file.path(out_dir, paste0("KitralFuelsDistribution_", label, "_areaComprometida.tif"))
  writeRaster(r_clip, out_tif, overwrite = TRUE)
  cat("Guardado:", out_tif, "\n")

  px_area_ha <- prod(res(r_clip)) / 10000
  f <- as.data.table(freq(r_clip))
  setnames(f, c("layer", "value", "count"))
  f <- merge(f, lookup[, .(grid_value, descriptive_name, fuel_type)], by.x = "value", by.y = "grid_value", all.x = TRUE)

  total_cells <- ncell(r_clip)
  valid_cells <- sum(f$count)
  f[, area_ha := count * px_area_ha]
  f[, pct_of_valid := round(100 * count / valid_cells, 2)]
  f <- f[order(-count)]

  cat(sprintf("Celdas totales (extent recortado): %d\n", total_cells))
  cat(sprintf("Celdas validas: %d (%.1f%% del extent)\n", valid_cells, 100 * valid_cells / total_cells))
  cat(sprintf("Area valida: %.0f ha\n", valid_cells * px_area_ha))
  cat("Clases presentes:", nrow(f), "de 32\n")
  print(f[, .(fuel_type, descriptive_name, area_ha = round(area_ha, 1), pct_of_valid)])

  fwrite(f, file.path(out_dir, paste0("class_distribution_", label, "_areaComprometida.csv")))
  invisible(f)
}

clip_and_summarize("KitralFuelsDistribution_AngloRM_2025.tif", "AngloRM_2025")
clip_and_summarize("KitralFuelsDistribution_AngloRM.tif", "AngloRM_2021")

cat("\n=====================================================\n")
cat("LISTO. Resultados en:", out_dir, "\n")
cat("=====================================================\n")
