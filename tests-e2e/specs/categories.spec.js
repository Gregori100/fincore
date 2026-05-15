import { expect, test } from '@playwright/test'
import { setupLoggedInUser } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

/**
 * Helper para seleccionar de un BaseSelect (Headless UI Listbox) por label.
 * El <label> no usa `for=`, así que buscamos el div contenedor con el texto
 * exacto del label y disparamos el button.
 */
async function selectListbox(scope, labelText, optionRegex) {
  const labelEl = scope.getByText(labelText, { exact: false }).first()
  await labelEl.locator('..').getByRole('button').first().click()
  await scope.page().getByRole('option', { name: optionRegex }).first().click()
}

test.describe('Categorías', () => {
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('el usuario recibe 10 categorías default al registrarse', async ({ page }) => {
    await setupLoggedInUser(page)
    await page.goto('/categories')

    // Las 10 default cubren gastos, ingresos y "ambos".
    await expect(page.getByRole('heading', { name: 'Comida' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Salario' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Reembolsos' })).toBeVisible()
  })

  test('crear una categoría custom aparece en /categories', async ({ page }) => {
    await setupLoggedInUser(page)
    await page.goto('/categories')

    await page.getByRole('button', { name: /nueva categoría/i }).click()
    const dialog = page.getByRole('dialog')
    await dialog.getByLabel(/^nombre/i).fill('Café especial')
    // applies_to es 'expense' por default; lo dejamos así.
    // Los pickers de color e icono ya tienen default (blue, shopping-bag).
    await dialog.getByRole('button', { name: /^crear categoría$/i }).click()

    await expect(page.getByRole('heading', { name: 'Café especial' })).toBeVisible()
  })

  test('registrar un gasto con categoría muestra el badge en /entries', async ({ page }) => {
    await setupLoggedInUser(page)

    // Necesitamos fondos en la Bolsa para gastar.
    await page.getByRole('button', { name: /^ingreso$/i }).click()
    let dialog = page.getByRole('dialog')
    await selectListbox(dialog, 'Cuenta destino', /bolsa/i)
    await dialog.getByLabel(/^monto/i).fill('1000')
    await dialog.getByRole('button', { name: /registrar ingreso/i }).click()
    // Espera explícita: el modal se cierra y BO actualiza.
    await expect(page.locator('article').filter({ hasText: 'Bolsa (BO)' })).toContainText('$1,000.00')

    // Ahora un gasto categorizado.
    await page.getByRole('button', { name: /^gasto$/i }).click()
    dialog = page.getByRole('dialog')
    await selectListbox(dialog, 'Cuenta origen', /bolsa/i)
    await selectListbox(dialog, 'Categoría', /comida/i)
    await dialog.getByLabel(/^monto/i).fill('250')
    await dialog.getByLabel(/^descripción/i).fill('Almuerzo')
    await dialog.getByRole('button', { name: /registrar gasto/i }).click()

    // Verificar en /entries: el badge "Comida" aparece en la fila.
    await page.goto('/entries')
    const row = page.locator('tr', { hasText: 'Almuerzo' })
    await expect(row.getByText('Comida').first()).toBeVisible()
  })

  test('archivar una categoría la excluye del select pero conserva entries', async ({ page }) => {
    await setupLoggedInUser(page)
    await page.goto('/categories')

    // Crear una categoría que vamos a archivar después.
    await page.getByRole('button', { name: /nueva categoría/i }).click()
    let dialog = page.getByRole('dialog')
    await dialog.getByLabel(/^nombre/i).fill('Temporal')
    await dialog.getByRole('button', { name: /^crear categoría$/i }).click()
    await expect(page.getByRole('heading', { name: 'Temporal' })).toBeVisible()

    // Archivarla desde la card.
    const card = page.locator('article', {
      has: page.getByRole('heading', { name: 'Temporal' }),
    })
    await card.hover()
    await card.getByRole('button', { name: /archivar categoría/i }).click()
    await page.getByRole('button', { name: /^archivar$/i }).click()

    // Aparece en la sección "Archivadas".
    await expect(page.getByRole('heading', { name: /archivadas/i })).toBeVisible()

    // En el form de gasto, el select de categoría ya no la lista.
    await page.goto('/dashboard')

    // Necesitamos al menos $1 en la Bolsa para abrir el modal de gasto sin warning;
    // pero el modal abre incluso sin fondos. Verificamos directamente.
    await page.getByRole('button', { name: /^gasto$/i }).click()
    dialog = page.getByRole('dialog')
    await dialog.getByText('Categoría', { exact: false }).first().locator('..').getByRole('button').first().click()
    // Lista de opciones del listbox abierto: la archivada NO debe aparecer.
    await expect(page.getByRole('option', { name: 'Temporal' })).toHaveCount(0)
  })
})
