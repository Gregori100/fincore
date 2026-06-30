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
