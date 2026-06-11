# Inferencia local Ñuble — validación pipeline end-to-end
# Usa data cube y modelo desde rutas locales (sin descarga Google Drive)

library(terra)
library(raster)
library(data.table)
library(readr)
library(stringr)
library(parallel)
library(xgboost)

setwd("C:/No_nube/fuel-type-prediction-ml")

# Directorio temporal para terra
dir.create("temp.terra", showWarnings = FALSE)
terraOptions(
  memfrac = 0.6,
  tempdir  = "temp.terra",
  progress = 3
)

# -------------------------------------------------------
# Cargar data cube Ñuble desde ruta local
# -------------------------------------------------------
dc_path <- "G:/Mi unidad/F2A/[01] Proyectos y Postulaciones/[01] Proyectos/Desafios/Combustibles/DataCube/Archivos Ñuble"

archivos <- list.files(dc_path, full.names = TRUE)
archivos <- archivos[!str_detect(archivos, "aux\\.xml")]
(archivos <- archivos[!str_detect(archivos, "climate_variables")])
(archivos <- archivos[!str_detect(archivos, ".ini$")])

message("Archivos a apilar: ", length(archivos))

out <- lapply(seq_along(archivos), function(i) {
  message("Cargando raster ", i, " de ", length(archivos), ": ", basename(archivos[i]))
  rast(archivos[i])
})
r_nuble <- rast(out)

message("Stack listo. Capas: ", nlyr(r_nuble))
message("Nombres: ", paste(names(r_nuble), collapse = ", "))

# -------------------------------------------------------
# Subconjunto 500x500 px (esquina superior izquierda)
# -------------------------------------------------------
e_full  <- ext(r_nuble)
x_mid   <- (e_full[1] + e_full[2]) / 2
y_mid   <- (e_full[3] + e_full[4]) / 2
half    <- 250 * res(r_nuble)[1]  # 250 px * 30 m = 7500 m
e_sub   <- ext(x_mid - half, x_mid + half, y_mid - half, y_mid + half)
(r_nuble <- crop(r_nuble, e_sub))
message("Subconjunto: ", nrow(r_nuble), " filas x ", ncol(r_nuble), " cols")
beepr::beep(2)

# -------------------------------------------------------
# Cargar modelo XGBoost local
# -------------------------------------------------------
model_name <- "xgb_model_optimized2_hpeta_0.01max_depth_12min_child_weight_6lambda_1alpha_0subsample_0.7colsample_bytree_0.7gamma_1.ubj"

if (!file.exists(model_name)) stop("Modelo UBJ no encontrado: ", model_name)
message("Modelo listo: ", model_name)
beepr::beep(2)

# -------------------------------------------------------
# Ejecutar inferencia
# -------------------------------------------------------
source("fun_KitralFuelModel.r")

mlKitralFuelModel(
  model       = model_name,
  predictors  = r_nuble,
  file.out.lab = "Nuble_local",
  blockSize   = 100
)
beepr::beep(2)
