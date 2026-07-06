# Retoma la corrida de fuels_angloRM_2025.r que fue interrumpida durante el mosaico final.
# La preparación (temp.csv) y predicción (temp.r, 53 chunks) ya están completas en disco;
# este script solo repite el paso de mosaico + guardado + limpieza de fun_KitralFuelModel.r.

setwd("C:/No_nube/fuel-type-prediction-ml")
library(terra)

fold.name   <- "temp.csv"
fold.name.t <- "temp.terra"
fold.name.r <- "temp.r"
filename.out <- "KitralFuelsDistribution_AngloRM_2025.tif"

files.h <- list.files(path = fold.name.r)
message("Chunks encontrados en temp.r: ", length(files.h))
if (length(files.h) == 0) stop("No hay chunks en temp.r para mosaiquear.")

for (j in seq_along(files.h)) {
  message(paste("Doing final mosaic. Working on raster", j, "of", length(files.h)))
  d.h <- rast(file.path(fold.name.r, files.h[j]))
  if (j == 1) { r.out <- d.h } else { r.out <- mosaic(r.out, d.h, fun = "sum") }
}

message("Saving raster with final mosaic")
writeRaster(r.out, filename = filename.out, overwrite = TRUE)

message("Removing temporal files and folders")
for (d in c(fold.name.r, fold.name, fold.name.t)) {
  if (dir.exists(d)) unlink(d, recursive = TRUE)
}

message("Done! The output raster is saved as ", filename.out)
beepr::beep(2)
