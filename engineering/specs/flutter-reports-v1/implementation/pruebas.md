# Pruebas — flutter-reports-v1

## Tests ejecutados

### Suite completa final

```
flutter test
→ 153/153 tests verdes en ~13s
→ 0 regresiones sobre la suite previa de 126 tests
```

Distribución de los **27 tests nuevos**:

- `test/data/reports_test.dart`: **22 tests** (vs ≥12 del plan).
- `test/screens/reports_screen_test.dart`: **4 tests** (vs ≥3 del plan).
- `test/screens/dashboard_screen_test.dart`: **1 test extra** (RF-017 — icono Reportes).

### `flutter analyze` final

```
0 errores, 0 warnings, 4 hints info preexistentes
(entry_form_screen.dart líneas 285/286/288 + skeleton.dart línea 75)
```

Ningún hint nuevo introducido por el sprint.

## Cobertura por RN del spec

| RN | Cobertura test | Resultado |
|----|----------------|-----------|
| RN-R01 (kind expense/credit_expense) | UT-05 `expense + credit_expense ambos cuentan`, WT-02 | ✓ |
| RN-R02 (excluye transfer/debt_payment/income) | UT-06 `transfer + debt_payment + income: ninguno cuenta` | ✓ |
| RN-R03 (categoryId null → "Sin categoría") | UT-07, WT-03 | ✓ |
| RN-R04 (categoría archivada → "Sin categoría") | UT-08, IT-02 `archivar categoría con DAO` | ✓ |
| RN-R05 (rango inclusivo) | UT-12 `from exacto`, UT-13 `to exacto`, UT-14 `from == to` | ✓ |
| RN-R06 (from > to bloqueado UI) | Validado en código (`_pickFrom`/`_pickTo`); test UI diferido a smoke manual | parcial |
| RN-R07 (soft-delete excluido) | UT-15 `Entry soft-deleted no cuenta`, IT-01 `Cancelar entry con DAO` | ✓ |
| RN-R08 (color/icon Sin categoría) | UT-07 `colorSlug null`, IT-02 | ✓ |

## Cobertura por RF

| RF | Cobertura | Resultado |
|----|-----------|-----------|
| RF-001 a RF-005 (`ReportsService`) | 22 tests data | ✓ |
| RF-006, RF-007 (ruta + scaffold) | WT-01 `find ReportsScreen + Tab` | ✓ |
| RF-008 a RF-011 (tab spending) | WT-01, WT-02, WT-03, WT-04 | ✓ |
| RF-012 (rango inválido SnackBar) | Lógica en código; UI test diferido a SM-04 | parcial |
| RF-013 (icono Dashboard) | WT-05 `Tap del icono Reportes navega a /reports` | ✓ |
| RF-014 (`fl_chart`) | **Cancelado** — Desviación-1 (barras nativas) | N/A |
| RF-015 (tests data ≥10) | 22 tests data | ✓ (+10) |
| RF-016 (widget tests ≥3) | 4 tests | ✓ (+1) |
| RF-017 (widget test Dashboard) | 1 test | ✓ |
| RF-018, RF-019 (release) | bump + verify-apk.sh exit 0 | ✓ |

## Pruebas diferidas

| ID | Razón | Cobertura compensatoria |
|----|-------|-------------------------|
| WT-04 (cambio de fecha repega query) | DatePicker cuelga `pumpAndSettle` (Desviación-3/5) | UT-11 a UT-17 + smoke manual SM-05 |
| WT-05 (SnackBar from > to) | DatePicker cuelga `pumpAndSettle` | smoke manual SM-04 |

## Smoke manual pendiente

A ejecutar por Diego tras instalar el APK `0.4.0+43`:

- **SM-01**: Settings → "Acerca de" muestra `0.4.0+43`.
- **SM-02**: Dashboard → AppBar tiene icono `bar_chart` con tooltip "Reportes".
- **SM-03**: Tap icono → navega a Reportes con tab "Gasto por categoría" activa.
- **SM-04**: Default = primer día del mes corriente → hoy. Confirmar visualmente.
- **SM-05**: Cambiar "Desde" a una fecha posterior a "Hasta" → debe mostrar SnackBar warning "El rango no es válido" + preservar el rango.
- **SM-06**: Cambiar "Desde" al primer día del mes anterior y "Hasta" al último día → ver reporte del mes pasado.
- **SM-07**: Verificar que ningún `transfer`/`debt_payment`/`income` aparece en el chart.
- **SM-08**: Registrar un movimiento nuevo desde Dashboard → volver a Reportes → confirmar que ya aparece sin re-tap del rango (reactividad del Stream).

## Comandos para reproducir localmente

```bash
cd mobile

# Solo tests data del reporte:
flutter test test/data/reports_test.dart

# Solo widget tests del reporte:
flutter test test/screens/reports_screen_test.dart

# Suite completa:
flutter test

# Lint:
flutter analyze

# Build release:
flutter build apk --release --split-per-abi

# Validar APK:
../scripts/verify-apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
