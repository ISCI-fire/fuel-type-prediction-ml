# Inferencia combustibles Kitral — INTENTO-2 (mitigación PCH1), temporada 2025-2026
# RECORTADA AL ÁREA COMPROMETIDA (roi_suroeste + Los Nogales) para respuesta rápida
# (~20% de los píxeles de RM_SN_bf → ~1,5h en vez de ~6,5h). El extent de entrega
# ES el área comprometida, así que esta corrida genera directamente lo que se entrega.
#
# Modelo: model_kitral_angloamerican.json — REENTRENADO 2026-07-17 (Fase 4b, intento-2)
#         eta=0.05, max_depth=12, mcw=1, best_iter=1440, 65 predictores + 20 polígonos
#         RM nuevos (SV02/PCH5/MT02) para mitigar sobre-predicción de PCH1.
# Data cube: G:/Mi unidad/dc Anglo American 2025 EVIfix
# Diferencia vs fuels_angloRM_2025.r: crop+mask del stack al polígono antes de predecir.

# ── Configuración ─────────────────────────────────────────────────────────────
CLEAN_TEMP <- TRUE   # arranque limpio (evita append a temp.csv de corridas previas)

dc_path    <- "G:/Mi unidad/dc Anglo American 2025 EVIfix"
DIST_RM    <- "C:/No_nube/modelingFuelsKitral/pisos_vegetacionales/dist_rasters/rm"
DIST_BANDS <- c("dist_matorral", "dist_alerce", "dist_siempreverde", "dist_caducifolio")
model_path <- "C:/No_nube/modelingFuelsKitral/xgb_fuels_model/model_kitral_angloamerican.json"
AREA_GPKG  <- "area_comprometida/area_comprometida.gpkg"   # union roi_suroeste + nogales (32718)
output_lab <- "AngloRM_2025_areaComp_i2"                    # nombre distinto (no pisa intento-1)
block_size <- 100

Sys.setenv(RETICULATE_PYTHON = "C:/Users/felip/Miniconda3/envs/xgb_convert/python.exe")
setwd("C:/No_nube/fuel-type-prediction-ml")
# ──────────────────────────────────────────────────────────────────────────────

if (CLEAN_TEMP) {
  for (d in c("temp.csv", "temp.r", "temp.terra")) if (dir.exists(d)) unlink(d, recursive = TRUE)
}

library(terra)
library(raster)
library(data.table)
library(readr)
library(stringr)
library(parallel)

dir.create("temp.terra", showWarnings = FALSE)
terraOptions(memfrac = 0.7, tempdir = "temp.terra", progress = 3)

# ── Cargar data cube ──────────────────────────────────────────────────────────
if (!dir.exists(dc_path)) stop("Data cube no encontrado: ", dc_path)
archivos <- list.files(dc_path, full.names = TRUE)
archivos <- archivos[!str_detect(archivos, "aux\\.xml")]
archivos <- archivos[!str_detect(archivos, "climate_variables")]
archivos <- archivos[!str_detect(archivos, "\\.ini$")]
message("Archivos a apilar: ", length(archivos))
if (length(archivos) == 0) stop("No se encontraron archivos raster en: ", dc_path)

out <- lapply(seq_along(archivos), function(i) {
  message("Cargando raster ", i, " de ", length(archivos), ": ", basename(archivos[i]))
  rast(archivos[i])
})
r_anglo <- rast(out)
rm(out); gc()

# ── Bandas de distancia (Fase 2b) ─────────────────────────────────────────────
dist_stack <- rast(lapply(DIST_BANDS, function(b) {
  x <- rast(file.path(DIST_RM, paste0(b, ".tif")))
  names(x) <- b
  x
}))
r_anglo <- c(r_anglo, dist_stack)
rm(dist_stack); gc()
message("Stack completo. Capas: ", nlyr(r_anglo))

# ── RECORTE Y MÁSCARA AL ÁREA COMPROMETIDA (lo nuevo) ─────────────────────────
if (!file.exists(AREA_GPKG)) stop("Polígono de área comprometida no encontrado: ", AREA_GPKG)
area_v <- vect(AREA_GPKG)
area_v <- project(area_v, crs(r_anglo))
message("Área comprometida: ", round(sum(expanse(area_v, unit = "ha")), 1), " ha")
r_anglo <- crop(r_anglo, area_v)
r_anglo <- mask(r_anglo, area_v)
message("Stack recortado al área comprometida. Dim: ", paste(dim(r_anglo), collapse = " x "))
gc()
# ──────────────────────────────────────────────────────────────────────────────

if (!file.exists(model_path)) stop("Modelo no encontrado: ", model_path)
message("Modelo: ", basename(model_path))

# ── Inferencia ────────────────────────────────────────────────────────────────
source("fun_KitralFuelModel.r")
mlKitralFuelModel(
  model        = model_path,
  predictors   = r_anglo,
  file.out.lab = output_lab,
  blockSize    = block_size,
  id.fuel      = "C:/No_nube/modelingFuelsKitral/id_fuel.csv"
)
message("Raster de salida: KitralFuelsDistribution_", output_lab, ".tif")
