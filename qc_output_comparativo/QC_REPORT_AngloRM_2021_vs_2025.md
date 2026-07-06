# QC comparativo — Mapa de Combustibles Kitral, Anglo American RM (temporada 2021-2022 vs 2025-2026)

**Fecha:** 2026-07-06
**Archivos evaluados:** `KitralFuelsDistribution_AngloRM.tif` (2021), `KitralFuelsDistribution_AngloRM_2025.tif` (2025)
**Scripts de QC:** `qc_compare_2021_2025.r`, `diag_change_vs_elevation.r` (`C:/No_nube/fuel-type-prediction-ml/`)
**Modelo:** `model_kitral_angloamerican.json` (mismo modelo en ambas inferencias, sin reentrenar; solo cambia el data cube de entrada)

## 1. Consistencia de pipeline

- Ambos rasters comparten grid exacto: 5261 x 6180 celdas, 30x30 m, EPSG:32718, mismo extent.
- Cobertura válida idéntica: 73.3% en ambos años (23.823.968 celdas en 2021, 23.817.917 en 2025).
- 32/32 clases Kitral presentes en ambos años. No aparecen ni desaparecen clases.

Esto confirma que la actualización del data cube (temporada 2025) no introdujo problemas de alineación ni de máscara respecto al cubo 2021.

## 2. Cambio de área por clase

Cambios más grandes (ver `class_distribution_2021_vs_2025.csv` para el detalle completo de las 32 clases):

| Clase | 2021 (ha) | 2025 (ha) | Cambio |
|---|---|---|---|
| BN03 (Arbolado Nativo Denso) | 138.177 | 226.019 | +63.6% |
| MT06 (Formaciones con Ulex spp.) | 5.030 | 60.672 | +1.106% |
| MT01 (Matorral mesomórfico denso) | 61.294 | 9.336 | -84.8% |
| PCH5 (Chacarería/Viñedos/Frutales) | 221.529 | 175.838 | -20.6% |
| BN04 (Arbolado Nativo densidad media) | 14.937 | 60.547 | +305.3% |
| SV02 (Cascos Urbanos) | 186.540 | 193.606 | +3.8% |

## 3. Matriz de transición pixel a pixel

- Píxeles comparables (válidos en ambos años): 23.803.233
- **Misma clase 2021→2025: 64.1%**
- **Cambio de clase 2021→2025: 35.9%**

Transiciones más frecuentes (ver `transition_matrix_2021_2025.csv`): predominan swaps entre clases vegetadas espectralmente próximas — `PL01↔MT02`, `MT01/MT02/MT07→BN03`, `PL01→BN03/BN04/MT06/SV03`. La transición `PCH5→SV02` (25.452 ha) es la más consistente con un cambio real de uso de suelo (expansión urbana/agrícola a urbano).

## 4. Hallazgo principal: el cambio de clase está fuertemente correlacionado con elevación, no es ruido disperso

El mapa de cambio (`change_map_2021_vs_2025.png`) no muestra un patrón disperso tipo sal-y-pimienta, sino una **división regional**: casi todo el cambio se concentra en la mitad oeste (valle y piedemonte) del dominio, mientras la mitad este (alta cordillera) permanece estable.

Diagnóstico adicional (`diag_change_vs_elevation.r`) confirma que esta división sigue el gradiente de elevación (correlación punto-biserial = -0.48):

| Elevación | % píxeles que cambiaron de clase |
|---|---|
| < 1.000 m | 55-70% |
| ~2.000 m | 34% |
| ~2.400 m | 14% |
| ~2.800 m | ~1% |
| > 3.000 m | ~0-1% |

**Interpretación:** por sobre ~2.800 m domina terreno desnudo/roca (`SV03`), espectralmente estable entre años (sin vegetación que varíe) → casi no cambia de clase. En el valle y piedemonte, donde predominan clases de vegetación (matorral, plantación, bosque nativo), el modelo es sensible a la variabilidad interanual de humedad/fenología entre las temporadas Sentinel-1/2 de 2021 y 2025, agravada por la confusión espectral entre `PL01`/`MT01`/`MT02`/`BN03` ya documentada en `QC_REPORT_AngloRM.md` (sección 5.3, sobreestimación de plantaciones sobre matorral denso).

**No se interpreta como un bug de pipeline** (la alineación, cobertura y conteo de clases son idénticos entre años — sección 1), sino como una **limitación real de estabilidad del clasificador ante cambios de condición hídrica/fenológica entre temporadas**, concentrada en las clases de vegetación que ya tenían confusión espectral conocida entre sí.

## 5. Conclusión

El data cube 2025 está correctamente alineado y es consistente en cobertura/clases con el cubo 2021, por lo que la actualización cumplió su objetivo técnico. Sin embargo, el 35.9% de cambio de clase pixel a pixel es alto para tratarse solo de cambio real de paisaje en 4 años, y el análisis espacial muestra que se concentra casi enteramente en zonas de vegetación de baja/media elevación, correlacionado con el gradiente topográfico y con las clases que el modelo ya confundía entre sí en el mapa 2021.

**Se documenta como limitación conocida del mapa preliminar 2025**, no como error a corregir ahora: el mapa 2025 debe usarse con la advertencia de que las clases de vegetación en el valle/piedemonte son menos estables temporalmente que las de alta cordillera, y que parte del "cambio" observado probablemente refleja variabilidad interanual del clasificador más que cambio real de cobertura. Cuantificar y corregir esta sensibilidad (p. ej. usando compuestos multi-temporales más robustos, o revisando la separabilidad espectral de PL01/MT01/MT02/BN03) queda diferido a la iteración del mapa "final", consistente con la decisión de alcance del 2026-07-02.
