import { expect, test } from '@playwright/test'
import { loginUI, registerAndVerify, uniqueEmail } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

test.describe('Autenticación', () => {
  // Cada test hace al menos 1 POST /auth/register y a veces 1 POST /auth/login;
  // ambos endpoints comparten throttle:6,1. Limpiar el cache antes de cada test
  // garantiza que cada uno arranque con el cupo lleno y los tests sean
  // independientes del orden de ejecución.
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('registro + verificación de email + login termina en el dashboard', async ({ page }) => {
    const user = await registerAndVerify(page)
    await loginUI(page, user)

    // El topbar muestra el email del usuario y los 3 links de navegación.
    await expect(page.getByText(user.email)).toBeVisible()
    await expect(page.getByRole('link', { name: 'Dashboard' })).toBeVisible()
    await expect(page.getByRole('link', { name: 'Mis cuentas' })).toBeVisible()
    await expect(page.getByRole('link', { name: 'Movimientos' })).toBeVisible()

    // La Bolsa (cuenta singleton) se crea automáticamente en el registro.
    await expect(page.getByRole('heading', { name: 'Bolsa', level: 3 })).toBeVisible()
  })

  test('login con contraseña incorrecta muestra error y se queda en /login', async ({ page }) => {
    const user = await registerAndVerify(page)

    await page.goto('/login')
    await page.getByLabel(/email/i).fill(user.email)
    await page.getByLabel(/contraseña/i).fill('contrasena-equivocada')
    await page.getByRole('button', { name: /iniciar sesión/i }).click()

    // Laravel devuelve 422 con errors.email = ["Credenciales inválidas."]; el
    // frontend lo renderiza inline bajo el campo, no como toast.
    await expect(page.getByText(/credenciales inválidas/i)).toBeVisible()
    await expect(page).toHaveURL(/\/login/)
  })

  test('logout regresa a /login y limpia la sesión', async ({ page }) => {
    const user = await registerAndVerify(page)
    await loginUI(page, user)

    await page.getByRole('button', { name: /cerrar sesión/i }).click()
    await page.waitForURL('**/login')

    // El token debe haber sido limpiado de localStorage.
    const token = await page.evaluate(() => localStorage.getItem('fincore_token'))
    expect(token).toBeNull()
  })

  test('un email duplicado en registro muestra error de validación', async ({ page }) => {
    const email = uniqueEmail('dup')
    await registerAndVerify(page, { email })

    // Intento registrar otro usuario con el mismo email.
    await page.goto('/register')
    await page.getByLabel(/nombre/i).fill('Otro Usuario')
    await page.getByLabel(/^email/i).fill(email)
    await page.locator('input[type="password"]').first().fill('password123')
    await page.locator('input[type="password"]').nth(1).fill('password123')
    await page.getByRole('button', { name: /crear cuenta/i }).click()

    // El backend valida unique:users,email y devuelve 422 con el error
    // bajo errors.email; el form lo muestra debajo del campo.
    await expect(page.locator('text=/ya.*registrad|ya.*tomado|taken|usado/i').first()).toBeVisible({ timeout: 5000 })
    await expect(page).toHaveURL(/\/register/)
  })
})
