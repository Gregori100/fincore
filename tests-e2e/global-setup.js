import { execSync } from 'node:child_process'

/**
 * Setup global ejecutado UNA vez antes de toda la suite E2E.
 *
 * Limpia el cache de Laravel (incluye los buckets del rate limiter) porque las
 * rutas de auth usan `throttle:6,1` y los E2E hacen >6 POSTs a /auth/register
 * y /auth/login. Sin esto los tests fallan de forma aleatoria al cruzar la
 * ventana de un minuto.
 *
 * Se ejecuta vía `docker compose exec` — requiere que el stack esté arriba.
 */
export default async function globalSetup() {
  try {
    execSync('docker compose exec -T api php artisan cache:clear', {
      cwd: new URL('..', import.meta.url).pathname,
      stdio: 'pipe',
    })
  } catch (e) {
    console.warn(
      '[e2e setup] No se pudo limpiar el cache de Laravel. ¿Stack arriba? Error:',
      e.message,
    )
  }
}
