library(terra)

setwd("C:/No_nube/fuel-type-prediction-ml")
before <- rast("area_comprometida/KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif")
after  <- rast("area_comprometida/KitralFuelsDistribution_AngloRM_2025_areaComprometida_filled.tif")

px_ha <- prod(res(before)) / 10000

n_before <- sum(!is.na(values(before)))
n_after  <- sum(!is.na(values(after)))

cat(sprintf("Celdas validas ANTES del relleno: %d (%.1f ha)\n", n_before, n_before * px_ha))
cat(sprintf("Celdas validas DESPUES del relleno: %d (%.1f ha)\n", n_after, n_after * px_ha))
cat(sprintf("Celdas rellenadas (dentro del area comprometida): %d (%.1f ha)\n", n_after - n_before, (n_after - n_before) * px_ha))

cat(sprintf("\nDimensiones raster: %s\n", paste(dim(before), collapse=" x ")))
cat(sprintf("CRS iguales: %s\n", crs(before) == crs(after)))
