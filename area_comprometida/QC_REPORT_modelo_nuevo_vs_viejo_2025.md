# QC comparativo: modelo NUEVO vs VIEJO (temporada 2025, area comprometida)

Ambos mapas usan las mismas imagenes satelitales 2025-2026; la unica diferencia
es el modelo (reentrenado con EVI + distancia a especies + CV espacial vs v1).
Area de pixel: 0.0900 ha. Fuente viejo: v1_model_backup/. Fuente nuevo: area_comprometida/.

## 1. Estabilidad global entre modelos

- Pixeles comparables: 4.757.253
- Misma clase viejo->nuevo: 1.227.534 (25.8%)
- Cambio de clase viejo->nuevo: 3.529.719 (74.2%)

## 2. Top 20 transiciones (excluyendo 'sin cambio')

| viejo | nuevo | area_ha | % del total |
|---|---|---:|---:|
| PCH5 | PCH1 | 29.117 | 6.80 |
| BN03 | MT01 | 27.320 | 6.38 |
| MT02 | PCH1 | 21.633 | 5.05 |
| PL01 | MT02 | 17.979 | 4.20 |
| SV02 | PCH1 | 14.041 | 3.28 |
| PL01 | PCH1 | 12.962 | 3.03 |
| BN03 | PCH1 | 11.324 | 2.64 |
| PCH2 | PCH1 | 9.913 | 2.32 |
| MT06 | PCH1 | 9.872 | 2.31 |
| PL01 | MT01 | 9.237 | 2.16 |
| BN03 | MT07 | 7.389 | 1.73 |
| BN04 | PCH1 | 7.104 | 1.66 |
| BN03 | MT02 | 6.905 | 1.61 |
| PCH5 | SV02 | 5.788 | 1.35 |
| BN04 | MT01 | 5.301 | 1.24 |
| MT02 | MT01 | 4.910 | 1.15 |
| MT06 | MT02 | 3.870 | 0.90 |
| PL06 | MT01 | 3.855 | 0.90 |
| SV03 | PCH1 | 3.705 | 0.87 |
| PCH2 | PCH5 | 3.619 | 0.85 |

## 3. Clases clave: area (ha) viejo vs nuevo

| clase | descripcion | viejo | nuevo | delta |
|---|---|---:|---:|---:|
| BN03 | Arbolado Nativo Denso | 67.878 | 9.383 | -58495 |
| MT01 | Matorrales y Arbustos Mesomorficos Densos | 3.057 | 61.110 | +58053 |
| PL01 | Plantaciones Coniferas Nuevas (0-3) sin Manejo | 46.709 | 865 | -45844 |
| BN01 | Formaciones con predominancia de Alerzales | 94 | 3.689 | +3595 |
| PCH1 | Pastizales Mesomorficos Densos | 8.790 | 134.232 | +125443 |
| PCH5 | Chacareria. Vinedos y Frutales | 80.560 | 58.171 | -22388 |
| MT02 | Matorrales y Arbustos Mesomorficos Medios y Ralos | 54.041 | 68.595 | +14554 |
| BN04 | Arbolado Nativo de Densidad Media | 21.400 | 152 | -21248 |
| MT06 | Formaciones con predominancia de Ulex spp | 16.203 | 0 | -16203 |
| SV03 | Terrenos Desnudos | 19.012 | 3.548 | -15464 |

## 4. BN01 (Alerce) en el modelo nuevo

En el area comprometida el Alerce no existe; dist_alerce deberia ser grande.

Pixeles que el modelo nuevo clasifica BN01, segun su clase en el modelo viejo:

| era (viejo) | area_ha nuevo=BN01 |
|---|---:|
| PCH5 | 717 |
| BN03 | 580 |
| PL01 | 474 |
| SV02 | 460 |
| MT02 | 440 |
| MT06 | 249 |
| BN04 | 209 |
| PCH2 | 108 |
| PCH1 | 84 |
| PL11 | 55 |

Distancia al Alerce (km) dentro del area comprometida:

- Todo el area: min 68.4, mediana 110.3, max 167.0
- Solo pixeles BN01 (nuevo): min 99.7, mediana 100.7, max 151.9

(Si la mediana de dist_alerce en los BN01 no es menor que en el resto,
la feature de distancia NO esta explicando el error: el modelo predice
Alerce a distancias grandes igual.)

## 5. PCH1 (Pastizales Densos): origen de la expansion

| era (viejo) | area_ha ganada por PCH1 |
|---|---:|
| PCH5 | 29.117 |
| MT02 | 21.633 |
| SV02 | 14.041 |
| PL01 | 12.962 |
| BN03 | 11.324 |
| PCH2 | 9.913 |
| MT06 | 9.872 |
| BN04 | 7.104 |
| SV03 | 3.705 |
| PL06 | 1.956 |

