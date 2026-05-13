import { ref } from 'vue'
import { defineStore } from 'pinia'

let nextId = 1

export const useToastStore = defineStore('toast', () => {
  const messages = ref([])

  function push({ kind = 'info', text, timeout = 4000 }) {
    const id = nextId++
    messages.value.push({ id, kind, text })
    if (timeout > 0) {
      setTimeout(() => dismiss(id), timeout)
    }
    return id
  }

  function success(text, opts = {}) {
    return push({ kind: 'success', text, ...opts })
  }

  function error(text, opts = {}) {
    return push({ kind: 'error', text, ...opts })
  }

  function dismiss(id) {
    messages.value = messages.value.filter((m) => m.id !== id)
  }

  return { messages, push, success, error, dismiss }
})
