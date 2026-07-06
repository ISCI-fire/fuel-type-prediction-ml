# Diagnostico rapido: la frontera este/oeste del cambio de clase 2021->2025,
# es coincidencia con gradiente de elevacion (DEM)?

setwd("C:/No_nube/fuel-type-prediction-ml")

library(terra)
library(data.table)

r21 <- rast("KitralFuelsDistribution_AngloRM.tif")
r25 <- rast("KitralFuelsDistribution_AngloRM_2025.tif")
change_r <- ifel(r21 == r25, 0L, 1L)

dem <- rast("G:/Mi unidad/dc Anglo American/nasadem_variables.tif")
elev <- dem[[1]]
names(elev) <- "elevation"
elev <- resample(elev, r21, method = "near")

stk <- c(change_r, elev)
names(stk) <- c("changed", "elevation")
dt <- as.data.table(as.data.frame(stk, na.rm = TRUE))

cat("Correlacion punto-biserial (changed vs elevation):", cor(dt$changed, dt$elevation), "\n\n")

dt[, elev_bin := cut(elevation, breaks = seq(0, ceiling(max(elevation)/200)*200, by = 200))]
summary_tab <- dt[, .(pct_changed = round(100 * mean(changed), 1), n = .N), by = elev_bin]
summary_tab <- summary_tab[order(elev_bin)]
print(summary_tab)

# También: coordenada X (easting) vs % cambio, para ver si es un corte vertical limpio
dt2 <- as.data.table(as.data.frame(stk, xy = TRUE, na.rm = TRUE))
dt2[, x_bin := cut(x, breaks = 20)]
summary_x <- dt2[, .(pct_changed = round(100 * mean(changed), 1), mean_elev = round(mean(elevation),0), n = .N), by = x_bin]
summary_x <- summary_x[order(x_bin)]
cat("\nPorcentaje de cambio y elevacion promedio por franja de longitud (este-oeste):\n")
print(summary_x)
