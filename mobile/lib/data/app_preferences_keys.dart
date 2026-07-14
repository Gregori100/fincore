// Claves canónicas para entradas en la tabla `app_preferences`.
// Sprint `flutter-onboarding-for-testers-v1`.
//
// Centralizadas acá para evitar typos mágicos en strings repartidos por
// la codebase. Si se agregan claves nuevas en sprints futuros, sumarlas
// a este archivo manteniendo la convención `kPref<Nombre>`.

/// Flag `'true'` cuando el usuario ya vio el flujo de onboarding (o lo
/// saltó). Cuando la clave no existe, se asume `false` (no visto).
const String kPrefOnboardingSeen = 'onboarding_seen';

/// Timestamp ISO 8601 del último export exitoso (cuando
/// `Share.shareXFiles` retornó `ShareResultStatus.success`). Cuando la
/// clave no existe, el usuario nunca exportó respaldo.
const String kPrefLastExportAt = 'last_export_at';

/// Día de inicio de la semana para el planeador de presupuestos
/// (sprint `flutter-weekly-budgets-v1`). Valor string `'1'`..`'7'`
/// con estándar ISO 8601: 1=Lunes, 2=Martes, ..., 7=Domingo. Cuando
/// la clave no existe, el default operativo es `5` (viernes) —
/// caso de uso primario. Solo actúa como sugerido inicial del
/// picker de fecha; no fuerza restricción dura al crear presupuesto
/// (RN-B02 / RN-B10 del sprint).
const String kPrefWeekStartDow = 'week_start_dow';
