# Kitral Fuel Type Prediction — Inference Pipeline (Anglo American–SOFOFA)

## ¿Qué es este repositorio?

Este repositorio aplica el modelo XGBoost de tipos de combustible Kitral (entrenado en el repositorio [`modelingFuelsKitral`](../modelingFuelsKitral)) sobre un data cube de variables predictoras, para generar un mapa raster de distribución de combustibles sobre una nueva área de estudio. Es el lado de **inferencia/aplicación** del proyecto — el entrenamiento y ajuste del modelo vive en `modelingFuelsKitral`.

## Estructura

* `fun_KitralFuelModel.r` — función núcleo `mlKitralFuelModel()`: predice sobre rasters grandes, procesando por bloques.
* `run_example.r` — ejemplo original de uso (Ñuble), descarga data cube y modelo desde Google Drive.
* `run_local_nuble.r` — variante de validación end-to-end con data cube y modelo en rutas locales (sin Drive), sobre un recorte de 500x500 px.
* `fuels_angloRM.r` — script de inferencia a escala completa para el área Anglo American (RM), usando el modelo región-agnóstico entrenado en `modelingFuelsKitral`.
* `convert_model.py` / `convert_model_ubj.py` — utilitarios en Python para convertir el modelo XGBoost entre formatos (binario legacy → JSON → UBJSON).
* `kitral_lookup_table-modified.csv` — tabla de equivalencia entre clase predicha y `grid_value` Kitral (formato reconocido por Cell2Fire+W).
* `qc_AngloRM.r` + `qc_output/` — control de calidad del mapa generado para Anglo American (ver más abajo).

---

## `fun_KitralFuelModel.r`: la función de predicción

Define `mlKitralFuelModel()`, que predice tipos de combustible sobre áreas geográficas grandes procesando el raster de predictores en bloques (para no agotar la RAM).

### Lógica y pasos clave

1. **Verificaciones**: valida que `predictors` sea un `SpatRaster` y que contenga las **49 variables predictoras** requeridas, en el orden exacto de entrenamiento (`landform`, `aspect`, `slope`, `TPI`, y por cada período P1/P2/P3: `VH, VV, ndvi, ndbi, ndwi, red, green, blue, R1, R2, R3, nir, R4, swir1, swir2`). El modelo actual **no usa `region_code` ni variables EVI** (excluidas por outliers de escala DN sin corregir en el data cube). Verifica también que exista `kitral_lookup_table-modified.csv` y las librerías necesarias (incluye `reticulate`).
2. **Procesamiento en bloques**: lee el raster de a bloques horizontales (tamaño definido por `blockSize`), descarta filas con NA y escribe cada bloque como CSV en `temp.csv/`.
3. **Predicción vía Python/reticulate**: el modelo se carga y predice usando el `xgboost` de Python (no `xgb.load()` de R), porque **modelos >2GB fallan con el `readBin` de R**. Para cada bloque: arma un `numpy.array`, crea el `DMatrix` **pasando `feature_names = vars` explícitamente** (xgboost 3.x lo exige o lanza `ValueError: data did not contain feature names` si el array no trae nombres), predice, y convierte la matriz `(n_muestras, 32)` que retorna Python a la clase de mayor probabilidad. Mapea la clase numérica a `grid_value` vía la lookup table y escribe un `.tif` parcial en `temp.r/`.
4. **Mosaico final**: fusiona todos los `.tif` parciales en el raster de salida (`KitralFuelsDistribution_<label>.tif`) y limpia las carpetas temporales.

### Requisito de entorno

Requiere un entorno conda con `xgboost` instalado en Python (actualmente `xgb_convert`), activado vía `reticulate::use_condaenv()`. **`RETICULATE_PYTHON` debe fijarse ANTES de cualquier `library()` de la sesión R** — reticulate cachea el intérprete la primera vez que se inicializa, y si `RETICULATE_PYTHON` ya apunta a otro entorno (ej. `geo`, sin xgboost), `use_condaenv()` no lo sobreescribe. Si reticulate ya fue inicializado en la sesión, hay que reiniciar R.

---

## `run_example.r`: ejemplo de ejecución (Ñuble)

Ejemplo de referencia del pipeline completo, dividido en dos partes:

**Parte 1 — Preparación de predictores**: autentica con Google Drive, descarga el data cube de una región (excluyendo `.aux.xml` y variables climáticas), arma el `SpatRaster` combinado y lo guarda como `regionDC.tif`.

**Parte 2 — Predicción**: carga `fun_KitralFuelModel.r`, descarga el modelo entrenado desde Drive, y llama a `mlKitralFuelModel()` con el raster de predictores, un label de salida (ej. `"Nuble"`) y un `blockSize` para controlar el uso de memoria.

⚠️ **Estado conocido**: esta ruta de inferencia para Ñuble está bloqueada por problemas al cargar el modelo guardado (falla con `xgb.load()` de R — es obsoleto/pesa más de 2GB). El mismo problema afecta a `run_local_nuble.r` (ver abajo). Usar el puente Python/reticulate de `fun_KitralFuelModel.r` (o migrar estos scripts al mismo patrón que `fuels_angloRM.r`) para desbloquearlos.

## `run_local_nuble.r`: validación local end-to-end

Variante de `run_example.r` sin dependencia de Google Drive: carga el data cube y el modelo XGBoost desde rutas locales, recorta un subconjunto pequeño (500x500 px, esquina superior izquierda) e intenta correr `mlKitralFuelModel()` sobre ese recorte. Pensado para validar el pipeline de inferencia de punta a punta antes de correr sobre un área completa, pero **también bloqueado por el mismo problema de carga del modelo local** (`.ubj` antiguo) descrito arriba.

## `fuels_angloRM.r`: inferencia de producción — Anglo American (RM)

Script principal usado para generar el mapa de combustibles del área de estudio Anglo American–SOFOFA, con el modelo región-agnóstico (`model_kitral_angloamerican.json`, eta=0.05, max_depth=12, nrounds=7000, Accu=76.3%, F1=71.2% en test set 30%).

* Carga el data cube desde `G:/Mi unidad/dc Anglo American`.
* Fija `RETICULATE_PYTHON` al entorno `xgb_convert` **antes** de cargar cualquier librería (ver nota de entorno arriba).
* Corre `mlKitralFuelModel()` con `blockSize=100` sobre el área completa.
* Salida: `KitralFuelsDistribution_AngloRM.tif`.

## `convert_model.py` / `convert_model_ubj.py`

Utilitarios de una sola pasada para convertir modelos XGBoost entre formatos: binario legacy → `.json` → `.ubj` (UBJSON). Se usan para preparar modelos guardados en formatos antiguos de forma que puedan cargarse desde el puente Python/reticulate en `fun_KitralFuelModel.r`.

## `qc_AngloRM.r` y `qc_output/`: control de calidad del mapa

Script de QC sobre `KitralFuelsDistribution_AngloRM.tif`: info básica del raster, distribución de clases y cobertura de la máscara, visualización (`qc_output/KitralFuelsDistribution_AngloRM_map.png`), y un chequeo de consistencia espacial contra las 45 etiquetas digitalizadas de la RM (**no es validación independiente** — esos polígonos entraron al pool de entrenamiento/test).

Hallazgos documentados en `qc_output/QC_REPORT_AngloRM.md`:
* Transición marcada hacia "Terrenos Desnudos" en el sector este del área — evaluada como consistente con la zona de alta cordillera, no verificada contra DEM/data cube.
* Confusión residual con la clase BN01 (Alerzales), ecológicamente atípica para la RM — área despreciable (<0.01%).
* Sobreestimación de plantaciones (PL*) en sectores con matorral denso (MT01/MT02) — magnitud aún no cuantificada.
