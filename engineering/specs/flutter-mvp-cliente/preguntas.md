# Preguntas abiertas

## Restricciones

- ID: P-001
  Estado: respondida
  Pregunta: ¿`applicationId = io.github.gregori100.fincore`?
  Por que importa: en Play Store es inmutable una vez publicado. Mismo patrón que dogear (`io.github.gregori100.dogear`) que ya tiene validado el usuario.
  Impacto si cambia: cambia el namespace del package Android y todas las referencias en `build.gradle.kts`. Si se descubre tarde y la app ya está publicada, no hay vuelta atrás.
  Respuesta o decision: `io.github.gregori100.fincore`. Mismo patrón que dogear, decisión confirmada antes de planear. Integrado en S-001 y RF-002 de `spec.md`.

## Alcance

- ID: P-002
  Estado: respondida
  Pregunta: ¿La URL del API se configura solo en compile time (`--dart-define=FINCORE_API_URL=...`) o también desde una pantalla Settings runtime?
  Por que importa: hoy el usuario está en Tailscale (`https://loma-latitude-3540.tail285790.ts.net`). Cuando migre a hosting real, la URL cambia. Si solo es compile time, cada cambio exige rebuild + reinstalar APK. Si es runtime, hay una pantalla "Servidor" donde edita y persiste.
  Impacto si cambia: agrega ~2 horas a la implementación (pantalla + persistencia segura + validación de URL). No es bloqueante; se puede agregar como mejora futura.
  Respuesta o decision: solo compile time con `--dart-define=FINCORE_API_URL=...`. Pantalla Settings runtime queda como funcionalidad futura (spec aparte cuando se justifique). Integrado en S-002 y RF-003.

- ID: P-003
  Estado: respondida
  Pregunta: ¿Nombre de la carpeta del proyecto Flutter dentro del monorepo: `mobile/`, `app/` o `flutter/`?
  Por que importa: convención cosmética pero estable. Cambiarla después implica renombrar paths en docs y scripts.
  Impacto si cambia: ninguno técnico; solo nombre en docs.
  Respuesta o decision: `mobile/`. Describe el rol (cliente móvil) no el stack. Integrado en S-003, RF-001 y referenciado en Alcance/Estructura del repo.

- ID: P-005
  Estado: respondida
  Pregunta: ¿Necesitamos el flow de verification email visible en Flutter o asumimos que la cuenta ya está verificada?
  Por que importa: el backend requiere `verified` para acceder a `/api/finance/*`. Si la cuenta del usuario en uso ya está verificada (caso actual de Diego en dev), no necesitamos UI de verify. Si en algún momento crea una cuenta nueva desde la app, el backend devolvería 403 y la app debería mostrar "verifica tu email — revisa tu bandeja" + botón resend.
  Impacto si cambia: si se decide soportar, +2-3 horas (pantalla de "verifica tu email" + botón resend usando `/api/auth/email/verification-notification`).
  Respuesta o decision: SÍ, incluir pantalla de verify + botón resend. Cuando el backend devuelve 403 con `code: email_not_verified` (o response equivalente en el middleware `verified`), la app muestra una pantalla con mensaje "Verifica tu email" + botón "Reenviar correo" que llama `POST /api/auth/email/verification-notification`. Integrado como RF-017 nuevo y movido de "Fuera de alcance" a "Alcance".

## UX

- ID: P-004
  Estado: respondida
  Pregunta: ¿Tema oscuro idéntico al de la Vue web (paleta CSS variables, papel/gris/colores curados) o Material 3 con paleta similar generada por seed color?
  Por que importa: replicar la paleta exacta de Vue (CSS variables) requiere mapearlas a mano y romper algunos defaults de Material 3 (que no recomienda usar colores arbitrarios). Material 3 con seed (un color base) genera el resto automáticamente y se ve coherente pero no idéntico.
  Impacto si cambia: si el usuario quiere paridad exacta, +medio día de tema. Si acepta Material 3 con seed, salimos en ~2 horas.
  Respuesta o decision: replicar la paleta exacta de Vue. Mapear las CSS variables actuales (`frontend/src/style.css` `@theme` block) a un `ColorScheme` custom de Material 3, conservando colores curados del catálogo (`CategoryColors`) para los badges. Aceptamos el medio día extra de tema. Integrado en S-004 y RF-018 nuevo.
