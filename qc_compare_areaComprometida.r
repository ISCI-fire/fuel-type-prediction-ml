# QC comparativo 2021 vs 2025, restringido al area oficialmente comprometida.

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(data.table)

r21 <- rast("area_comprometida/KitralFuelsDistribution_AngloRM_2021_areaComprometida.tif")
r25 <- rast("area_comprometida/KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif")

px_area_ha <- prod(res(r21)) / 10000

lookup <- fread("kitral_lookup_table-modified.csv")
lookup <- lookup[!is.na(grid_value)]

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

cat(sprintf("Pixeles comparables: %d\n", total_compared))
cat(sprintf("Misma clase 2021->2025: %d (%.1f%%)\n", same_class, 100 * same_class / total_compared))
cat(sprintf("Cambio de clase 2021->2025: %d (%.1f%%)\n", changed_class, 100 * changed_class / total_compared))

cat("\nTop 15 transiciones mas frecuentes (excluyendo 'sin cambio'):\n")
print(head(ctab_dt[fuel_2021 != fuel_2025, .(fuel_2021, fuel_2025, count, area_ha = round(area_ha, 1))], 15))

fwrite(ctab_dt, "area_comprometida/transition_matrix_areaComprometida_2021_2025.csv")

# Cambio vs elevacion, si el DEM esta disponible
dem_path <- "G:/Mi unidad/dc Anglo American/nasadem_variables.tif"
if (file.exists(dem_path)) {
  change_r <- ifel(r21 == r25, 0L, 1L)
  dem <- rast(dem_path)
  elev <- dem[[1]]
  names(elev) <- "elevation"
  elev <- resample(crop(elev, r21), r21, method = "near")
  stk2 <- c(change_r, elev)
  names(stk2) <- c("changed", "elevation")
  dt <- as.data.table(as.data.frame(stk2, na.rm = TRUE))
  cat("\nRango de elevacion en el area comprometida (msnm):", round(min(dt$elevation)), "-", round(max(dt$elevation)), "\n")
  cat("Correlacion cambio vs elevacion:", round(cor(dt$changed, dt$elevation), 3), "\n")
}
