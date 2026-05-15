import { expect, test } from '@playwright/test'
import { setupLoggedInUser } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

/**
 * Selecciona una opción de un BaseSelect (Headless UI Listbox).
 * Su <label> no tiene `for=`, por eso no podemos usar getByLabel — buscamos
 * el button cuya inmediato sibling es el label con el texto pedido.
 */
async function selectListbox(scope, labelText, optionRegex) {
  const labelEl = scope.getByText(labelText, { exact: false }).first()
  await labelEl.locator('..').getByRole('button').first().click()
  await scope.page().getByRole('option', { name: optionRegex }).first().click()
}

/**
 * Abre el modal del dashboard correspondiente al kind y devuelve su locator.
 */
async function openDashboardForm(page, buttonName) {
  await page.getByRole('button', { name: buttonName }).click()
  return page.getByRole('dialog')
}

/**
 * Crea una cuenta extra (débito o crédito) desde /accounts. Para tests que
 * necesitan más cuentas además de la Bolsa.
 */
async function createExtraAccount(page, { name, type = 'debit', creditLimit } = {}) {
  await page.goto('/accounts')
  await page.getByRole('button', { name: /nueva cuenta/i }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByLabel(/^nombre/i).fill(name)
  if (type === 'credit') {
    await selectListbox(dialog, 'Tipo', /crédito/i)
    await dialog.getByLabel(/^límite/i).fill(String(creditLimit ?? 25000))
  }
  await dialog.getByRole('button', { name: /^crear cuenta$/i }).click()
  await expect(page.getByRole('heading', { name, level: 3 })).toBeVisible()
}

test.describe('Movimientos', () => {
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('registrar un ingreso aumenta BO y aparece en /entries', async ({ page }) => {
    await setupLoggedInUser(page)

    const dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByLabel(/^descripción/i).fill('Nómina mayo')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // BO se actualiza a $5,000 en el dashboard.
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$5,000.00')

    // El entry aparece en /entries.
    await page.getByRole('link', { name: /ver historial|movimientos/i }).first().click()
    await expect(page).toHaveURL(/\/entries/)
    await expect(page.getByText('Nómina mayo')).toBeVisible()
  })

  test('un ingreso seguido de un gasto deja el saldo neto correcto', async ({ page }) => {
    await setupLoggedInUser(page)

    // Ingreso $5,000 a Bolsa.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$5,000.00')

    // Gasto $1,200 desde Bolsa.
    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('1200')
    await dialog.getByLabel(/^descripción/i).fill('Supermercado')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    // Saldo neto: 5000 - 1200 = 3800.
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$3,800.00')
  })

  test('transferir entre cuentas mueve dinero sin alterar BO', async ({ page }) => {
    await setupLoggedInUser(page)

    await createExtraAccount(page, { name: 'Banamex Débito', type: 'debit' })

    // Ingreso a Bolsa para tener fondos.
    await page.goto('/dashboard')
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // Transfer $2,000 de Bolsa a Banamex.
    dialog = await openDashboardForm(page, /^transferir$/i)
    await selectListbox(dialog, 'Desde', /bolsa/i)
    await selectListbox(dialog, 'Hacia', /banamex/i)
    await dialog.getByLabel(/^monto/i).fill('2000')
    await dialog.getByRole('button', { name: /^transferir$/i }).click()

    // BO total: 5000 - 2000 (de Bolsa) + 2000 (a Banamex) = 5000.
    // La métrica BO suma cash + debit, así que el total no cambia.
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$5,000.00')
    // Pero el saldo individual de la Bolsa baja a $3,000.
    await expect(
      page.locator('article').filter({ has: page.getByRole('heading', { name: 'Bolsa', level: 3 }) }),
    ).toContainText('$3,000.00')
    await expect(
      page.locator('article').filter({ has: page.getByRole('heading', { name: 'Banamex Débito', level: 3 }) }),
    ).toContainText('$2,000.00')
  })

  test('flujo completo de crédito: cargar y pagar la tarjeta', async ({ page }) => {
    await setupLoggedInUser(page)

    await createExtraAccount(page, { name: 'Visa Oro', type: 'credit', creditLimit: 30000 })

    await page.goto('/dashboard')

    // Ingreso a Bolsa para poder pagar luego.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // Cargo a la tarjeta: deuda sube a $1,500.
    dialog = await openDashboardForm(page, /^cargo crédito$/i)
    await selectListbox(dialog, 'Tarjeta', /visa/i)
    await dialog.getByLabel(/^monto/i).fill('1500')
    await dialog.getByRole('button', { name: /cargar a tarjeta/i }).click()
    await expect(page.locator('article').filter({ hasText: 'Deudas (DE)' })).toContainText('$1,500.00')

    // Pago de $1,000 desde Bolsa → deuda baja a $500.
    dialog = await openDashboardForm(page, /^pagar tarjeta$/i)
    await selectListbox(dialog, 'Pagar desde', /bolsa/i)
    await selectListbox(dialog, 'Pagar a', /visa/i)
    await dialog.getByLabel(/^monto/i).fill('1000')
    await dialog.getByRole('button', { name: /pagar tarjeta/i }).click()
    await expect(page.locator('article').filter({ hasText: 'Deudas (DE)' })).toContainText('$500.00')
  })

  test('cancelar un movimiento revierte el saldo', async ({ page }) => {
    await setupLoggedInUser(page)

    // Ingreso 5000 a Bolsa.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('5000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // Gasto 1500.
    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('1500')
    await dialog.getByLabel(/^descripción/i).fill('Compra a cancelar')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$3,500.00')

    // Ir a /entries y cancelar el gasto.
    await page.goto('/entries')
    const row = page.locator('tr', { hasText: 'Compra a cancelar' })
    await row.hover()
    await row.getByRole('button', { name: /cancelar movimiento/i }).click()

    // Confirmar en el BaseConfirm (un botón "Cancelar movimiento" en el modal).
    await page.getByRole('button', { name: /^cancelar movimiento$/i }).click()

    // El gasto desapareció de la tabla.
    await expect(page.getByText('Compra a cancelar')).toHaveCount(0)

    // BO volvió a 5000.
    await page.goto('/dashboard')
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$5,000.00')
  })

  test('se puede registrar un movimiento desde /entries usando el menú', async ({ page }) => {
    await setupLoggedInUser(page)

    // Fondear desde el dashboard primero.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('2000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    // Ir a /entries y registrar un gasto desde el menú "Nuevo movimiento".
    await page.goto('/entries')
    await page.getByRole('button', { name: /nuevo movimiento/i }).click()
    await page.getByRole('menuitem', { name: /^gasto$/i }).click()

    dialog = page.getByRole('dialog')
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('350')
    await dialog.getByLabel(/^descripción/i).fill('Compra desde entries')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    // La nueva entry aparece en la tabla sin recargar.
    await expect(page.getByText('Compra desde entries')).toBeVisible()
  })

  test('cancelar un ingreso ya gastado deja saldo negativo con badge', async ({ page }) => {
    await setupLoggedInUser(page)

    // Ingreso 1000 a Bolsa, gasto 500.
    let dialog = await openDashboardForm(page, /^ingreso$/i)
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('1000')
    await dialog.getByLabel(/^descripción/i).fill('Ingreso a cancelar')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()

    dialog = await openDashboardForm(page, /^gasto$/i)
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('500')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    // Cancelar el ingreso.
    await page.goto('/entries')
    const row = page.locator('tr', { hasText: 'Ingreso a cancelar' })
    await row.hover()
    await row.getByRole('button', { name: /cancelar movimiento/i }).click()
    await page.getByRole('button', { name: /^cancelar movimiento$/i }).click()

    // En el dashboard, la Bolsa muestra balance negativo + badge.
    await page.goto('/dashboard')
    const bolsaCard = page.locator('article').filter({ has: page.getByRole('heading', { name: 'Bolsa', level: 3 }) })
    await expect(bolsaCard).toContainText('-$500.00')
    await expect(bolsaCard.getByText(/saldo negativo/i)).toBeVisible()
  })
})
