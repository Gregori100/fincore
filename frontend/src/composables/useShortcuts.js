import { onBeforeUnmount, onMounted } from 'vue'

/**
 * Registra atajos de teclado globales mientras el componente que lo usa
 * está montado. Ignora la tecla si el foco está en un input, textarea o
 * select (no roba teclas mientras el usuario escribe).
 *
 * @param {Record<string, (e: KeyboardEvent) => void>} bindings
 *   Mapa { tecla → handler }. Las teclas son lo que `KeyboardEvent.key`
 *   devuelve en lowercase (ej. "i", "?", "escape").
 *
 * Ejemplo:
 *   useShortcuts({
 *     i: () => openModal('income'),
 *     '?': () => openModal('shortcuts'),
 *   })
 */
export function useShortcuts(bindings) {
  function isEditableTarget(target) {
    if (!target) return false
    const tag = target.tagName
    if (!tag) return false
    if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return true
    if (target.isContentEditable) return true
    return false
  }

  function onKeyDown(e) {
    // Si el usuario está escribiendo en un campo, no robamos la tecla.
    if (isEditableTarget(e.target)) return
    // Modificadores: por simplicidad, los atajos son sin modifiers.
    if (e.ctrlKey || e.metaKey || e.altKey) return

    const key = e.key.toLowerCase()
    const handler = bindings[key]
    if (handler) {
      e.preventDefault()
      handler(e)
    }
  }

  onMounted(() => {
    window.addEventListener('keydown', onKeyDown)
  })

  onBeforeUnmount(() => {
    window.removeEventListener('keydown', onKeyDown)
  })
}
