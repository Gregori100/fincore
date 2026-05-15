/**
 * Helpers de autenticación para tests E2E.
 *
 * Cada test crea su propio usuario con email único para evitar colisiones en
 * la BD compartida. No hay reset entre runs — la BD acumula users de test pero
 * cada test apunta a uno distinto, por lo que no se pisan.
 */
import { expect } from '@playwright/test'
import {
  extractVerificationLink,
  waitForVerificationEmail,
} from '../helpers/mailpit.js'

/** Genera un email único para este test. */
export function uniqueEmail(prefix = 'e2e') {
  const stamp = Date.now().toString(36)
  const rand = Math.random().toString(36).slice(2, 6)
  return `${prefix}-${stamp}-${rand}@fincore.test`
}

/**
 * Registra un usuario vía la UI: /register → completa el form → submit →
 * intercepta el link de verificación en Mailpit → lo visita → vuelve a /login.
 *
 * Termina con la sesión cerrada (sin token) listo para que el test haga login.
 */
export async function registerAndVerify(page, { email, password = 'password123', name } = {}) {
  email ??= uniqueEmail()
  name ??= 'E2E Tester'

  await page.goto('/register')
  await page.getByLabel(/nombre/i).fill(name)
  await page.getByLabel(/^email/i).fill(email)
  await page.locator('input[type="password"]').first().fill(password)
  await page.locator('input[type="password"]').nth(1).fill(password)
  await page.getByRole('button', { name: /crear cuenta|registrarme|registrar/i }).click()

  // Tras el registro, la app deja al user logueado pero unverified.
  // Esperamos llegar al dashboard (con banner de verificación) o a /login,
  // según el flujo del frontend.
  await page.waitForURL(/\/(dashboard|login|verify)/)

  // Recupera el correo y visita el link de verify (golpea el backend directo).
  const mail = await waitForVerificationEmail(email)
  const link = extractVerificationLink(mail)

  // Visitamos el link en otra navegación; el backend marca verified y redirige
  // al frontend (FRONTEND_URL/email-verified).
  await page.goto(link)
  await expect(page).toHaveURL(/\/(email-verified|login|dashboard)/)

  // El register dejó al user logueado. Limpiamos la sesión para que el test
  // que sigue pueda hacer login desde cero (sin que el guard requiresGuest
  // lo redirija al dashboard).
  await page.evaluate(() => {
    localStorage.removeItem('fincore_token')
    localStorage.removeItem('fincore_user')
  })

  return { email, password, name }
}

/**
 * Hace login vía UI y espera a estar en el dashboard.
 * No verifica nada del estado post-login — solo navega.
 */
export async function loginUI(page, { email, password }) {
  await page.goto('/login')
  await page.getByLabel(/email/i).fill(email)
  await page.getByLabel(/contraseña|password/i).fill(password)
  await page.getByRole('button', { name: /iniciar sesión|entrar|login/i }).click()
  await page.waitForURL('**/dashboard')
}

/**
 * Atajo: registra + verifica + login. Termina con la sesión activa en el
 * dashboard. Útil para specs cuyo foco no es la autenticación.
 */
export async function setupLoggedInUser(page, opts = {}) {
  const user = await registerAndVerify(page, opts)
  await loginUI(page, user)
  return user
}
