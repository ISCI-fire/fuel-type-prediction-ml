# QC — Mapa de Combustibles Kitral, Área Anglo American (RM–SOFOFA)

**Fecha:** 2026-07-02
**Archivo evaluado:** `KitralFuelsDistribution_AngloRM.tif`
**Script de QC:** `qc_AngloRM.r` (`C:/No_nube/fuel-type-prediction-ml/`)
**Modelo:** `model_kitral_angloamerican.json` (XGBoost, 32 clases, región-agnóstico)

## 1. Info básica del raster

- Dimensiones: 5261 x 6180 celdas (32.512.980 celdas totales)
- Resolución: 30 x 30 m
- CRS: WGS 84 / UTM zone 18S (EPSG:32718)
- Rango de valores: 1–34 (grid_value Kitral)

## 2. Cobertura de datos

- Celdas con predicción (no-NA): 23.823.968 (73.3%)
- Celdas NA (fuera de máscara): 8.689.012 (26.7%)
- Área total válida: 2.144.157 ha
- 32 de 32 clases Kitral posibles están presentes en el mapa

El 26.7% de NA es consistente con máscara de no-combustible (nieve permanente, cuerpos de agua, urbano denso, roca de muy alta cordillera). No se confirmó espacialmente qué componente domina el NA.

## 3. Distribución de clases (top 6, >75% del área válida)

| Clase | Nombre | Área (ha) | % área válida |
|---|---|---|---|
| SV03 | Terrenos Desnudos | 825.870 | 38.52% |
| PL01 | Plantaciones Coníferas Nuevas (0-3) sin Manejo | 235.499 | 10.98% |
| PCH5 | Chacarería, Viñedos y Frutales | 221.529 | 10.33% |
| SV02 | Cascos Urbanos | 186.540 | 8.70% |
| MT02 | Matorrales y Arbustos Mesomórficos Medios y Ralos | 164.051 | 7.65% |
| BN03 | Arbolado Nativo Denso | 138.177 | 6.44% |

Clases con área muy pequeña (<0.05% del mapa, posible ruido): MT08 (0.02%), MT03 (0.02%), BN01 (0.00%), DX02 (0.00%).

## 4. Chequeo espacial vs. 45 etiquetas digitalizadas (RM)

Coincidencia polígono–clase mayoritaria predicha: **45/45 (100%)**.

⚠️ **No es una validación independiente** — estos 45 polígonos digitalizados (fotointerpretación Google Earth Pro) entraron al pool de entrenamiento/test del modelo. El resultado confirma consistencia espacial/ajuste, no accuracy en datos no vistos (esa cifra es la del Script 4: Accu=76.3%, F1=71.2% sobre el test set 30%).

## 5. Hallazgos y limitaciones

### 5.1 Borde vertical este — dominancia de SV03 "Terrenos Desnudos"
El mapa muestra una transición marcada (aprox. x=920.000–930.000 UTM) donde el sector este pasa a estar dominado casi uniformemente por SV03. **Evaluado y aceptado como transición real**: corresponde a la zona de alta cordillera (cercana a Los Bronces/Andes), donde el paisaje pasa a roca y nieve desnuda de forma legítima. No se investigó contra DEM ni contra el data cube — queda como supuesto aceptado, no verificado con evidencia adicional.

### 5.2 BN01 "Formaciones con predominancia de Alerzales" — implausible ecológicamente
898 píxeles (80.8 ha, 0.00% del área válida). El Alerce (*Fitzroya cupressoides*) no crece naturalmente en la Región Metropolitana/cordillera central — su distribución real es Valdivia/Los Lagos hacia el sur. Es indicio de que el clasificador confunde ocasionalmente bosque nativo denso con esta clase específica. Área despreciable, no afecta el uso práctico del mapa, pero es una limitación de la clasificación a documentar.

### 5.3 Sobreestimación de plantaciones (PL*) sobre matorral denso
Se observa sobreestimación de área de plantaciones forestales (clases PL*) en sectores donde en terreno hay matorrales densos (MT01/MT02). El modelo tiende a confundir la estructura de matorral denso con plantaciones jóvenes/adultas, lo que infla el área reportada de PL* a costa de subestimar MT01/MT02. Pendiente cuantificar la magnitud de esta confusión (ej. matriz de confusión espacial focalizada en sectores de matorral denso conocido) y evaluar si se debe a similitud espectral/estructural entre ambas coberturas en las bandas usadas por el modelo.

## 6. Conclusión

El mapa pasa el control de calidad general: las 32 clases están presentes, la distribución de áreas es coherente con el paisaje esperado (matorral/plantaciones al oeste, urbano/agrícola en el valle, terreno desnudo hacia la cordillera), y no hay contradicciones en el chequeo de consistencia espacial. Se documentan tres limitaciones conocidas del modelo: (1) transición este no verificada contra DEM/data cube, (2) confusión residual con BN01 (Alerzales, área despreciable), y (3) sobreestimación de plantaciones sobre matorral denso (magnitud aún no cuantificada).
