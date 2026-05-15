import { expect, test } from '@playwright/test'
import { setupLoggedInUser } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

test.describe('Sesión expirada', () => {
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('token inválido → toast "sesión expiró" y redirige a /login', async ({ page }) => {
    await setupLoggedInUser(page)

    // Corrompemos el token persistido. El siguiente request protegido devolverá
    // 401; el interceptor de axios dispara el toast y limpia la sesión.
    await page.evaluate(() => {
      localStorage.setItem('fincore_token', 'token-invalido-para-forzar-401')
    })

    await page.goto('/dashboard')

    await expect(page).toHaveURL(/\/login/)
    await expect(page.getByRole('alert')).toContainText(/sesión expiró|sesion expiro/i)

    // El token y user fueron limpiados.
    const remaining = await page.evaluate(() => ({
      token: localStorage.getItem('fincore_token'),
      user: localStorage.getItem('fincore_user'),
    }))
    expect(remaining.token).toBeNull()
    expect(remaining.user).toBeNull()
  })

  test('navegar al dashboard sin sesión previa solo redirige (sin toast)', async ({ page }) => {
    // Sin login previo, localStorage está vacío. El router guard de
    // requiresAuth redirige a /login antes de que se dispare ningún request,
    // por lo que NO debe aparecer el toast de "sesión expiró".
    await page.goto('/dashboard')

    await expect(page).toHaveURL(/\/login(\?redirect=.*)?$/)
    // La región de notificaciones existe pero está vacía.
    await expect(page.getByRole('alert')).toHaveCount(0)
  })
})
