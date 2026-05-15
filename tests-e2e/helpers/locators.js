/**
 * Helpers de localización reutilizables entre specs E2E.
 */

/**
 * Selecciona una opción de un BaseSelect (Headless UI Listbox).
 *
 * El `<label>` del componente no tiene `for=`, así que `getByLabel` no
 * resuelve. Usamos una regex con boundary sobre el texto del label para
 * evitar matchear textos parciales del topbar como "Mis cuentas" cuando
 * buscamos "Cuenta". Acepta `Label` o `Label *` (campos required).
 *
 * @param {import('@playwright/test').Page | import('@playwright/test').Locator} scope
 *   Page o Locator. Si es Locator, restringe la búsqueda a su subtree.
 * @param {string} labelText  Texto exacto del label, sin asterisco.
 * @param {RegExp} optionRegex  Regex para identificar la opción a seleccionar.
 */
export async function selectListbox(scope, labelText, optionRegex) {
  const labelRegex = new RegExp(`^\\s*${labelText}(\\s*\\*)?\\s*$`)
  const labelEl = scope.getByText(labelRegex).first()
  await labelEl.locator('..').getByRole('button').first().click()
  const page = typeof scope.page === 'function' ? scope.page() : scope
  await page.getByRole('option', { name: optionRegex }).first().click()
}
