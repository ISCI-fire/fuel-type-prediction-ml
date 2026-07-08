# QC — Mapas de Combustibles Kitral recortados al área oficialmente comprometida (Anglo American–SOFOFA)

**Fecha:** 2026-07-07
**Área:** unión de `roi_suroeste.gpkg` (9 comunas, 416.646 ha) + `nogales.gpkg` (Santuario de la Naturaleza Los Nogales, 10.895 ha) = **427.541 ha**
**Archivos:** `KitralFuelsDistribution_AngloRM_2025_areaComprometida.tif`, `KitralFuelsDistribution_AngloRM_2021_areaComprometida.tif`
**Scripts:** `clip_to_area_comprometida.r`, `qc_compare_areaComprometida.r`

## 1. Recorte y cobertura

Ambos mapas (2021-2022 y 2025-2026, generados previamente sobre la extensión de trabajo ampliada `RM_SN_bf`) fueron recortados a la unión de `roi_suroeste` + `nogales`.

- Área válida 2025-2026: 428.161 ha (99.9%~100% del polígono de 427.541 ha; la pequeña diferencia es un efecto de rasterización en el borde).
- Área válida 2021-2022: 428.340 ha.
- **A diferencia de la extensión de trabajo ampliada (73.3% de cobertura válida), dentro del área comprometida la cobertura es prácticamente completa.** El 26.7% de celdas sin predicción de la extensión ampliada correspondía casi en su totalidad a la zona de alta cordillera excluida del área comprometida. En consecuencia, **el post-proceso de relleno de NA (sección II.5 del informe) no es necesario para esta entrega**; sigue siendo relevante únicamente para la extensión ampliada `RM_SN`, de uso futuro fuera de este proyecto.

## 2. Distribución de clases 2025-2026 (área comprometida)

Ver `class_distribution_AngloRM_2025_areaComprometida.csv`. Clases dominantes: PCH5 (Chacarería/Viñedos/Frutales, 18.8%), BN03 (Arbolado Nativo Denso, 15.9%), MT02 (Matorral mesomórfico medio/ralo, 12.6%), SV02 (Cascos Urbanos, 11.1%), PL01 (Plantaciones nuevas, 10.9%). A diferencia de la extensión ampliada (dominada 40% por SV03 "Terrenos Desnudos" de alta cordillera), el área comprometida —de menor altitud— está dominada por coberturas agrícolas, urbanas, matorral y bosque nativo, consistente con el paisaje de valle/piedemonte descrito en el anexo técnico del proyecto.

## 3. Estabilidad temporal 2021-2022 vs 2025-2026 (área comprometida)

- Píxeles comparables: 4.752.899
- **Cambio de clase 2021→2025: 55.8%** (mayor que el 35.9% calculado sobre la extensión ampliada).
- Correlación cambio–elevación: **-0.089** (débil; rango de elevación en el área comprometida: -10 a 3.820 msnm).

**Diferencia clave respecto al análisis anterior (extensión ampliada):** en la extensión ampliada, el cambio de clase se concentraba en las zonas bajas mientras la alta cordillera (SV03, estable) actuaba de "ancla" que bajaba el porcentaje global de cambio. Al excluir esa zona estable, el área comprometida completa queda compuesta casi enteramente por las clases de vegetación inestables entre temporadas, por lo que el porcentaje de cambio global sube y la correlación con elevación se debilita — **la inestabilidad temporal ya no es un fenómeno acotado a un sub-sector del mapa, sino una característica que afecta a la totalidad del área que se entrega en este proyecto.**

Transiciones más frecuentes (ver `transition_matrix_areaComprometida_2021_2025.csv`): `PCH5→SV02` (11.372 ha, posible expansión urbana real), `PL01↔MT02` (11.231 + 10.877 ha, swap bidireccional entre las mismas clases), `PL01/MT01/MT02/MT07→BN03` (8.900–10.953 ha cada una, confirma la sobreestimación de BN03 sobre MT01 documentada en el informe), `PCH5↔PCH2/SV02/MT06` (~4.000–6.700 ha cada una).

## 4. Conclusión

El recorte al área comprometida no cambia la validez del pipeline (mismo modelo, mismo procedimiento), pero sí cambia la lectura de dos hallazgos del informe general:

1. El relleno de celdas NA deja de ser un paso pendiente urgente para esta entrega (cobertura ya ~100%).
2. La sensibilidad interanual del clasificador pasa de ser una limitación de una porción del mapa (zonas bajas) a ser una limitación que afecta a la totalidad del área entregada — se eleva su prioridad en la lista de limitaciones del informe.
