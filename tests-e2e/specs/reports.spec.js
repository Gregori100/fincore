import { expect, test } from '@playwright/test'
import { setupLoggedInUser } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

async function selectListbox(scope, labelText, optionRegex) {
  // Boundary regex para evitar matchear textos como "Mis cuentas" del topbar
  // cuando buscamos "Cuenta". Acepta "Cuenta" o "Cuenta *" (required).
  const labelRegex = new RegExp(`^\\s*${labelText}(\\s*\\*)?\\s*$`)
  const labelEl = scope.getByText(labelRegex).first()
  await labelEl.locator('..').getByRole('button').first().click()
  // scope puede ser Page o Locator. Page no tiene .page(); Locator sí.
  const page = typeof scope.page === 'function' ? scope.page() : scope
  await page.getByRole('option', { name: optionRegex }).first().click()
}

async function openDashboardForm(page, buttonName) {
  await page.getByRole('button', { name: buttonName }).click()
  return page.getByRole('dialog')
}

test.describe('Reportes', () => {
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('por defecto muestra gastos del mes en curso con sus categorías', async ({ page }) => {
    await setupLoggedInUser(page)

    // Ingreso 5000 + gasto $200 con categoría Comida.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await selectListbox(dialog, 'Categoría', /comida/i)
    await dialog.getByLabel(/^monto/i).fill('200')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    await page.goto('/reports')

    // Hero muestra total = $200.
    const totalTile = page.locator('article').filter({ hasText: /Total · Gastos/i })
    await expect(totalTile).toContainText('$200.00')

    // La lista detallada incluye "Comida" con 100%.
    await expect(page.getByText('Comida').first()).toBeVisible()
    await expect(page.getByText(/100\.0%/)).toBeVisible()
  })

  test('toggle a Ingresos cambia la perspectiva', async ({ page }) => {
    await setupLoggedInUser(page)

    // Ingreso 3000 con categoría Salario + gasto 500 con Comida.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await selectListbox(dialog, 'Categoría', /salario/i)
    await dialog.getByLabel(/^monto/i).fill('3000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await selectListbox(dialog, 'Categoría', /comida/i)
    await dialog.getByLabel(/^monto/i).fill('500')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    await page.goto('/reports')

    // Default = expense. Toggle a Ingresos.
    await page.getByRole('button', { name: /^ingresos$/i }).click()

    const totalTile = page.locator('article').filter({ hasText: /Total · Ingresos/i })
    await expect(totalTile).toContainText('$3,000.00')
    await expect(page.getByText('Salario').first()).toBeVisible()

    // Y "Comida" no debería aparecer en la lista de ingresos.
    await expect(page.getByText('Comida')).toHaveCount(0)
  })

  test('filtrar por cuenta acota el reporte a esa cuenta', async ({ page }) => {
    await setupLoggedInUser(page)

    // Crear una cuenta extra.
    await page.goto('/accounts')
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    const acctDialog = page.getByRole('dialog')
    await acctDialog.getByLabel(/^nombre/i).fill('Banamex Extra')
    await acctDialog.getByRole('button', { name: /^crear cuenta$/i }).click()
    await expect(page.getByRole('heading', { name: 'Banamex Extra', level: 3 })).toBeVisible()

    await page.goto('/dashboard')

    // Fondear ambas cuentas.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /banamex/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // Gasto $400 desde Bolsa, $600 desde Banamex.
    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await selectListbox(dialog, 'Categoría', /comida/i)
    await dialog.getByLabel(/^monto/i).fill('400')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /banamex/i)
    await selectListbox(dialog, 'Categoría', /comida/i)
    await dialog.getByLabel(/^monto/i).fill('600')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    await page.goto('/reports')

    // Sin filtro: total $1,000.
    const totalTile = page.locator('article').filter({ hasText: /Total · Gastos/i })
    await expect(totalTile).toContainText('$1,000.00')

    // Filtrar por Bolsa: total $400.
    await selectListbox(page, 'Cuenta', /bolsa/i)
    await expect(totalTile).toContainText('$400.00')
  })
})
