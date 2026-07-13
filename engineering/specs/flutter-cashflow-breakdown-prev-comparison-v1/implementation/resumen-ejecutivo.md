# Resumen ejecutivo — flutter-cashflow-breakdown-prev-comparison-v1

## Qué se implementó

Al abrir el bottom sheet del desglose mensual del cashflow ahora cada
categoría y cada total (Ingresos/Gastos/Neto) muestra un chip
pequeño de delta % vs el mes calendario inmediato anterior. El chip
usa iconos ▲/▼/— y colores con semántica "impacto en bolsillo":
verde si el cambio te beneficia (más ingreso, menos gasto, más neto)
y rojo si te perjudica. Bucket sin data previa → `—` en gris.

## Impacto esperado

- Diego responde "¿por qué gasté más este mes?" bucket-por-bucket en
  el mismo tap donde ya abrió el desglose. Cero fricción adicional.
- El sheet se convierte de "snapshot del mes" a "snapshot +
  tendencia inmediata" — 2x el valor por segundo de uso.
- Base para features futuros: comparación 3 meses, delta año vs
  año, alertas ("gastaste 40% más en Comida este mes").

## Riesgos o pendientes relevantes

- **Divergencia timezone R6** (heredada del sprint padre): el tab
  base del cashflow agrupa por UTC mientras el sheet usa localtime.
  Dentro del sheet ambos meses son coherentes entre sí.
- **Signo del neto que salta** (déficit → superávit o viceversa): la
  decisión conservadora es `null` cuando `previous <= 0`. Alternativa
  futura: tooltip con montos previo/actual explícitos.
- **Smokes SM-01..05 pendientes en cel real** — Diego los hará en
  batch acumulado con los ~12 pendientes de sprints anteriores.
- **`branch-quality-review`** pendiente antes del commit final.

## Estado de pruebas

- **571/571 tests verdes** (560 baseline + 11 nuevos: 9 UT servicio +
  2 widget).
- `flutter analyze` limpio.
- APK release compilado y verificado con
  `versionCode 2090 / versionName 0.18.0`.

Sprint apto para smoke con Diego + branch-quality-review previo al
commit final.
