# Test plan — flutter-local-hardening-v3

## Matriz de cobertura

| RF | Tipo | Archivo | Tests nuevos |
|----|------|---------|--------------|
| RF-001, RF-002 | Harness + smoke | `test/helpers/widget_test_harness_test.dart` | 1 |
| RF-003, RF-004 | Widget | `test/screens/entry_form_screen_test.dart` | 2 |
| RF-005 | Widget | `test/screens/dashboard_screen_test.dart` | 2 |
| RF-006 | Widget | `test/screens/entry_form_kinds_test.dart` | 5 |
| RF-007 | Widget | `test/screens/accounts_list_screen_test.dart` + `categories_list_screen_test.dart` | 4 |
| RF-008, RF-009 | Manual | `scripts/verify-apk.sh` | — |
| RF-010, RF-011, RF-012 | Unit | `test/data/financial_state_test.dart` | 1 |

**Total automatizado:** 15 tests nuevos. Suite final estimada: 93 + 15 = **108 tests verdes**.

## Smoke manual

- APK `0.3.7+39` instalado en Redmi.
- Dashboard abre, sin gray screen.
- Settings → "Acerca de" muestra `0.3.7+39`.
- `scripts/verify-apk.sh` valida el APK construido.

## Validación negativa (regresión gray screen)

Antes de commit final, validar que si se rompe la lógica del `PopScope` (ej. quitar el `if (_kind == null) return;`), el test del RF-003 falla.
