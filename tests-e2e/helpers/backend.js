import { execSync } from 'node:child_process'

/**
 * Limpia el cache de Laravel (incluye los buckets del rate limiter de
 * `throttle:6,1` sobre /auth/*). Se invoca antes de cada test E2E para que
 * cada uno arranque con cupo limpio.
 *
 * Lanza por dentro `docker compose exec` — requiere que el stack esté arriba.
 */
export function clearLaravelCache() {
  execSync('docker compose exec -T api php artisan cache:clear', {
    cwd: new URL('../..', import.meta.url).pathname,
    stdio: 'pipe',
  })
}
