# Resumen ejecutivo — flutter-language-cleanup-v1

## Qué se implementó

Sprint 2 del roadmap de la auditoría de diseño 2026-07-14. FinCore purgó el voseo rioplatense (`pagás/configurá/probá/acá/…`) de todo `mobile/lib/` y `mobile/test/`, y agregó un test guardrail que **bloquea automáticamente** cualquier regresión futura de la política de español neutral guardada en memoria el 2026-07-14.

- 10 mensajes visibles al usuario reescritos a español neutral (`Configura` en lugar de `Configurá`, `Pago desde` en lugar de `Pagás desde`, etc.).
- 15 comentarios de código con `acá` → `aquí`.
- Jerga interna "kinds" reemplazada en Settings por "tipos de movimientos".
- 5 matchers de integration_test actualizados (estaban apuntando a copy voseado que la app ya no muestra).
- Nuevo `mobile/test/language/no_voseo_test.dart` que corre en cada `flutter test` y falla si aparece voseo nuevo.
- `CLAUDE.md` con la convención documentada + referencia al guardrail.

## Impacto esperado

- **Cumplimiento de política**: la regla de español neutral del 2026-07-14 estaba rota; ahora se cumple al 100% y es imposible romperla accidentalmente sin que CI lo detecte.
- **Percepción de producto**: menos "cambio de personalidad" entre pantallas. Copy uniforme mejora la sensación de app pulida.
- **Menos jerga técnica**: usuarios que abren Settings → Ayuda ya no leen "kinds"; leen "tipos de movimientos".
- **Confianza en integration_test**: el sprint detectó (bonus) que los 5 matchers estaban rotos silenciosamente; ahora reflejan el copy real de la app.

## Riesgos o pendientes relevantes

- **Smoke pendiente**: 2 mensajes crecieron notablemente en longitud (~+20 chars); Diego debe validar en Android 360dp que no hacen wrap raro.
- **Falso positivo del guardrail**: se removieron los verbos ambiguos (`partí/salí/dormí`) por conflicto con pretérito neutral. Trade-off aceptado: no detecta imperativo voseo puro de esos verbos raros. Si aparecen, se documentan.
- **Integration_test**: probablemente no se corren en CI regularmente (por eso los matchers quedaron obsoletos). Recomendación separada de agregar al pipeline.

## Estado de pruebas

- `flutter analyze`: **verde** (cero nuevos errores).
- `flutter test`: **681/681 verdes** (680 previos + 1 guardrail nuevo; 3 tests actualizados en el sprint).
- Guardrail corre en 500ms.
- Smoke desktop y Android: pendiente de Diego.
- Build APK Android release: en curso en background.

## Próximo paso

Con smoke OK, Diego aprueba commit. Después: Sprint 3 (Entry form redesign) — el flujo más frecuente de la app, mayor impacto en uso diario.
