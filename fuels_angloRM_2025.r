# Inferencia combustibles Kitral — Área Anglo American (RM), temporada 2025-2026
# Modelo: model_kitral_angloamerican.json (eta=0.05, max_depth=12, nrounds=7000)
#         Accu=76.3%, F1=71.2% en test set 30% — mismo modelo que la inferencia 2021, sin reentrenar
#         (EVI no es predictor del modelo, así que el data cube 2025 solo renueva S1/S2/NDVI/NDBI/NDWI)
# Data cube: G:/Mi unidad/dc Anglo American 2025

# ── Configuración ─────────────────────────────────────────────────────────────
CLEAN_TEMP <- FALSE   # TRUE: elimina carpetas temp.csv / temp.r / temp.terra antes de correr

dc_path    <- "G:/Mi unidad/dc Anglo American 2025 EVIfix"   # cubo regenerado con fix-EVI (0.3b)
# Bandas de distancia (Fase 2b) para la grilla RM (misma grilla que el cubo 2025 EVIfix)
DIST_RM    <- "C:/No_nube/modelingFuelsKitral/pisos_vegetacionales/dist_rasters/rm"
DIST_BANDS <- c("dist_matorral", "dist_alerce", "dist_siempreverde", "dist_caducifolio")
model_path <- "C:/No_nube/modelingFuelsKitral/xgb_fuels_model/model_kitral_angloamerican.json"
output_lab <- "AngloRM_2025"
block_size <- 100

# Forzar Python correcto antes de que reticulate se inicialice.
# RETICULATE_PYTHON sobreescribe use_condaenv(); debe setearse aquí, antes de cualquier library().
Sys.setenv(RETICULATE_PYTHON = "C:/Users/felip/Miniconda3/envs/xgb_convert/python.exe")

setwd("C:/No_nube/fuel-type-prediction-ml")
# ──────────────────────────────────────────────────────────────────────────────


# ── Limpieza de carpetas temporales (opcional) ────────────────────────────────
if (CLEAN_TEMP) {
  message("Limpiando carpetas temporales...")
  for (d in c("temp.csv", "temp.r", "temp.terra")) {
    if (dir.exists(d)) {
      unlink(d, recursive = TRUE)
      message("  Eliminado: ", d)
    }
  }
  message("Limpieza completada.")
}
# ──────────────────────────────────────────────────────────────────────────────


# ── Librerías ─────────────────────────────────────────────────────────────────
library(terra)
library(raster)
library(data.table)
library(readr)
library(stringr)
library(parallel)
# ──────────────────────────────────────────────────────────────────────────────


# ── Opciones terra ────────────────────────────────────────────────────────────
dir.create("temp.terra", showWarnings = FALSE)
terraOptions(
  memfrac = 0.7,
  tempdir  = "temp.terra",
  progress = 3
)
# ──────────────────────────────────────────────────────────────────────────────


# ── Cargar data cube Anglo American 2025 ──────────────────────────────────────
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

# ── Agregar bandas de distancia a distribucion de especies (Fase 2b) ──────────
# Comparten grilla exacta con el cubo RM (2021/2025); se apilan directo.
dist_stack <- rast(lapply(DIST_BANDS, function(b) {
  x <- rast(file.path(DIST_RM, paste0(b, ".tif")))
  names(x) <- b
  x
}))
r_anglo <- c(r_anglo, dist_stack)
rm(dist_stack); gc()
# ──────────────────────────────────────────────────────────────────────────────

message("Stack listo. Capas: ", nlyr(r_anglo))
message("Nombres: ", paste(names(r_anglo), collapse = ", "))
# ──────────────────────────────────────────────────────────────────────────────


# ── Verificar modelo ──────────────────────────────────────────────────────────
if (!file.exists(model_path)) stop("Modelo no encontrado: ", model_path)
message("Modelo listo: ", basename(model_path))
# ──────────────────────────────────────────────────────────────────────────────


# ── Ejecutar inferencia ───────────────────────────────────────────────────────
source("fun_KitralFuelModel.r")

mlKitralFuelModel(
  model        = model_path,
  predictors   = r_anglo,
  file.out.lab = output_lab,
  blockSize    = block_size
)

message("Raster de salida: KitralFuelsDistribution_", output_lab, ".tif")
beepr::beep(2)
# ──────────────────────────────────────────────────────────────────────────────
