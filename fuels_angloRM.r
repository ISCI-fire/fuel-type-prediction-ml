# Inferencia combustibles Kitral — Área Anglo American (RM)
# Modelo: model_kitral_angloamerican.json (eta=0.05, max_depth=12, nrounds=7000)
#         Accu=76.3%, F1=71.2% en test set 30%
# Data cube: G:/Mi unidad/dc Anglo American

# ── Configuración ─────────────────────────────────────────────────────────────
CLEAN_TEMP <- FALSE   # TRUE: elimina carpetas temp.csv / temp.r / temp.terra antes de correr

dc_path    <- "G:/Mi unidad/dc Anglo American"
model_path <- "C:/No_nube/modelingFuelsKitral/xgb_fuels_model/model_kitral_angloamerican.json"
output_lab <- "AngloRM"
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


# ── Cargar data cube Anglo American ───────────────────────────────────────────
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
