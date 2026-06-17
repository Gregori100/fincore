# Clarificaciones

## 2026-06-12

- Pregunta: P-001
  Decision: `applicationId = io.github.gregori100.fincore` (mismo patrón que dogear). Inmutable post-Play Store.
  Impacto en spec: actualizado S-001 (sin "depende de P-001"), referenciado en RF-002.

- Pregunta: P-002
  Decision: URL del API solo configurable en compile time vía `--dart-define=FINCORE_API_URL=...`. Pantalla Settings runtime queda como spec futura.
  Impacto en spec: actualizado S-002, mantenido RF-003 ya consistente.

- Pregunta: P-003
  Decision: la carpeta del proyecto Flutter dentro del monorepo se llama `mobile/`.
  Impacto en spec: actualizado S-003, referenciado en Alcance/Estructura del repo y RF-001.

- Pregunta: P-004
  Decision: replicar la paleta exacta de la Vue web (mapeo manual de CSS variables del `@theme` de `frontend/src/style.css` a un `ColorScheme.dark` custom + constantes Dart paralelas para los 10 slugs de color del catálogo). Se acepta el costo extra (~medio día) sobre `ColorScheme.fromSeed`.
  Impacto en spec: actualizado S-004, agregado RF-018 explícito, sección Alcance ya menciona "tema único oscuro Material 3 con paleta coherente con la Vue web".

- Pregunta: P-005
  Decision: SÍ incluir flow de email verification visible. Cuando un endpoint protegido responde 403 por cuenta no verificada, la app muestra pantalla "Verifica tu email" con botón "Reenviar correo" (`POST /api/auth/email/verification-notification`) y botón "Ya verifiqué" para reintentar. El click del enlace del email abre la Vue web (flow ya existente del backend); Flutter no maneja deep links del verify en este MVP.
  Impacto en spec: actualizado S-005, agregado RF-017 explícito, movido de "Fuera de alcance" a "Alcance" (la línea de "fuera de alcance" se ajustó para mencionar que registro/forgot-reset siguen fuera, pero verify entra).
