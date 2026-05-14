import { ref, computed } from 'vue'

/**
 * Maneja errores combinados client-side (validación local) y server-side
 * (validation errors de Laravel) con la convención:
 *
 *   - Antes del primer submit: solo se muestran errores del backend.
 *   - Tras el primer intento de submit: validación client live también.
 *
 * Uso:
 *   const validate = () => {
 *     const e = {}
 *     if (!form.amount) e.amount = 'Ingresa un monto'
 *     return e
 *   }
 *   const { errors, hasValidationErrors, submit } = useFormErrors(validate)
 *
 *   async function handleSubmit() {
 *     await submit(async () => {
 *       await store.action(form)
 *     })
 *   }
 */
export function useFormErrors(validateFn) {
  const serverErrors = ref({})
  const submitAttempted = ref(false)
  const submitting = ref(false)
  // Tras un submit exitoso, ignoramos validate() porque las dependencias
  // reactivas del store (balances/saldos) ya cambiaron y mostrarían errores
  // falsos justo antes de que el modal se cierre.
  const submitSucceeded = ref(false)

  const validationErrors = computed(() => validateFn() ?? {})

  const hasValidationErrors = computed(
    () => Object.keys(validationErrors.value).length > 0,
  )

  const errors = computed(() => {
    if (submitSucceeded.value) return {}
    if (!submitAttempted.value) return { ...serverErrors.value }
    return { ...validationErrors.value, ...serverErrors.value }
  })

  function setServerErrorsFromResponse(error) {
    const payload = error?.response?.data
    if (payload?.errors) {
      serverErrors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    }
  }

  /**
   * Ejecuta el callback de submit con manejo uniforme:
   *  - Marca submitAttempted (errores live a partir de ahora).
   *  - Si hay errores client-side, NO llama al callback.
   *  - Limpia serverErrors antes de cada intento.
   *  - Setea submitting durante la ejecución.
   *  - Captura errores 422 y los mapea a serverErrors.
   *  - Re-lanza el error para que el caller decida si mostrar toast genérico.
   */
  async function submit(callback) {
    submitAttempted.value = true
    if (hasValidationErrors.value) {
      return { ok: false, reason: 'validation' }
    }
    serverErrors.value = {}
    submitting.value = true
    try {
      await callback()
      submitSucceeded.value = true
      return { ok: true }
    } catch (e) {
      setServerErrorsFromResponse(e)
      return { ok: false, reason: 'server', error: e }
    } finally {
      submitting.value = false
    }
  }

  return {
    errors,
    submitting,
    hasValidationErrors,
    submit,
  }
}
