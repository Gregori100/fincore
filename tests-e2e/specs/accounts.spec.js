import { expect, test } from '@playwright/test'
import { setupLoggedInUser } from '../fixtures/auth.js'
import { clearLaravelCache } from '../helpers/backend.js'

/**
 * Helper: rellena el form (modal) de cuenta y lo envía. Sirve para creación
 * y para edición, ya que ambos modales comparten labels. Scope-ado al dialog
 * para no chocar con el aria-label "Ver detalle de Nombre original" que las
 * cards ponen en el overlay clickeable.
 */
async function fillAccountModal(page, { name, description } = {}) {
  // No usamos expect(dialog).toBeVisible() porque el <div role="dialog"> raíz
  // de Headless UI es un wrapper de tamaño 0; el contenido visible está en
  // el <DialogPanel>. Confiamos en el auto-wait que hace fill() sobre el input.
  const dialog = page.getByRole('dialog')
  if (name !== undefined) {
    await dialog.getByLabel(/^nombre/i).fill(name)
  }
  if (description !== undefined) {
    await dialog.getByLabel(/^descripción/i).fill(description)
  }
}

test.describe('Cuentas', () => {
  test.beforeEach(() => {
    clearLaravelCache()
  })

  test('crear una cuenta de débito con descripción aparece en /accounts', async ({ page }) => {
    await setupLoggedInUser(page)

    await page.goto('/accounts')
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, {
      name: 'Banamex Débito',
      description: 'Cuenta de nómina · alias 4321',
    })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()

    await expect(page.getByRole('status').or(page.getByRole('alert'))).toContainText(/creada/i)
    await expect(page.getByRole('heading', { name: 'Banamex Débito', level: 3 })).toBeVisible()
  })

  test('el detalle muestra nombre, descripción y tabla de movimientos vacía', async ({ page }) => {
    await setupLoggedInUser(page)

    await page.goto('/accounts')
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, { name: 'Cuenta de prueba', description: 'Notas de la cuenta' })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()

    const card = page.locator('article', {
      has: page.getByRole('heading', { name: 'Cuenta de prueba', level: 3 }),
    })
    await expect(card).toBeVisible()
    await card.getByRole('link', { name: /ver detalle/i }).click()

    await expect(page).toHaveURL(/\/accounts\/[0-9a-f-]+/)
    await expect(page.getByRole('heading', { name: 'Cuenta de prueba' })).toBeVisible()
    await expect(page.getByText('Notas de la cuenta')).toBeVisible()
  })

  test('editar nombre y descripción persiste los cambios', async ({ page }) => {
    await setupLoggedInUser(page)

    await page.goto('/accounts')
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, { name: 'Nombre original', description: 'Descripción original' })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()

    const card = page.locator('article', {
      has: page.getByRole('heading', { name: 'Nombre original', level: 3 }),
    })
    await expect(card).toBeVisible()

    // Hover para revelar los botones de acción (están opacity-0 hasta hover).
    await card.hover()
    await card.getByRole('button', { name: /editar cuenta/i }).click()

    await fillAccountModal(page, { name: 'Nombre editado', description: 'Descripción editada' })
    await page.getByRole('dialog').getByRole('button', { name: /guardar cambios/i }).click()

    await expect(page.getByRole('heading', { name: 'Nombre editado', level: 3 })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Nombre original', level: 3 })).toHaveCount(0)
  })

  test('archivar una cuenta vacía la mueve a la sección Archivadas', async ({ page }) => {
    await setupLoggedInUser(page)

    await page.goto('/accounts')
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, { name: 'Cuenta a archivar' })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()

    const card = page.locator('article', {
      has: page.getByRole('heading', { name: 'Cuenta a archivar', level: 3 }),
    })
    await expect(card).toBeVisible()

    await card.hover()
    await card.getByRole('button', { name: /archivar cuenta/i }).click()

    // BaseConfirm aparece con "Archivar" como label de confirmación.
    await page.getByRole('button', { name: /^archivar$/i }).click()

    // Aparece bajo el heading "Archivadas" con badge "archivada".
    await expect(page.getByRole('heading', { name: /archivadas/i })).toBeVisible()
    const archivedCard = page.locator('article', {
      has: page.getByRole('heading', { name: 'Cuenta a archivar', level: 3 }),
    })
    await expect(archivedCard.getByText(/archivada/i)).toBeVisible()
  })

  test('crear cuenta con nombre duplicado muestra error de validación', async ({ page }) => {
    await setupLoggedInUser(page)

    await page.goto('/accounts')

    // Primera cuenta — éxito.
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, { name: 'Repetida' })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()
    await expect(page.getByRole('heading', { name: 'Repetida', level: 3 })).toBeVisible()

    // Segunda con el mismo nombre — rechazada por la validación local del form.
    await page.getByRole('button', { name: /nueva cuenta/i }).click()
    await fillAccountModal(page, { name: 'Repetida' })
    await page.getByRole('dialog').getByRole('button', { name: /^crear cuenta$/i }).click()
    await expect(page.getByText(/ya tienes una cuenta con ese nombre/i)).toBeVisible()
  })
})
