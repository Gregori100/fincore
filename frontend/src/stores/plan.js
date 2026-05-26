import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import planApi from '@/api/plan'

export const usePlanStore = defineStore('plan', () => {
  const events = ref([])
  const projection = ref(null)
  const loading = ref(false)
  const error = ref(null)

  const isEmpty = computed(() => events.value.length === 0)

  async function fetchEvents() {
    loading.value = true
    error.value = null
    try {
      const { data } = await planApi.listEvents()
      events.value = data.events ?? []
    } catch (e) {
      error.value = e
      throw e
    } finally {
      loading.value = false
    }
  }

  async function fetchProjection() {
    loading.value = true
    try {
      const { data } = await planApi.projection()
      projection.value = data
    } finally {
      loading.value = false
    }
  }

  async function createEvent(payload) {
    const { data } = await planApi.createEvent(payload)
    events.value.push(data.event)
    await fetchProjection().catch(() => {})
    return data.event
  }

  async function bulkCreateEvents(events) {
    // La creación es lo que importa. Si el POST falla, propaga (lo maneja el form).
    const { data } = await planApi.bulkCreateEvents(events)
    // Refetch best-effort: un fallo aquí (red, timing) NO debe reportarse como
    // "no se pudieron crear los eventos" — ya se crearon.
    await Promise.allSettled([fetchEvents(), fetchProjection()])
    return data
  }

  async function updateEvent(id, payload) {
    const { data } = await planApi.updateEvent(id, payload)
    const idx = events.value.findIndex((e) => e.id === id)
    if (idx !== -1) events.value.splice(idx, 1, data.event)
    await fetchProjection().catch(() => {})
    return data
  }

  async function deleteEvent(id) {
    await planApi.deleteEvent(id)
    events.value = events.value.filter((e) => e.id !== id)
    await fetchProjection().catch(() => {})
  }

  async function clearAll() {
    await planApi.clearEvents()
    events.value = []
    await fetchProjection().catch(() => {})
  }

  async function createOverride(eventId, payload) {
    const { data } = await planApi.createOverride(eventId, payload)
    const event = events.value.find((e) => e.id === eventId)
    if (event) {
      event.overrides = [...(event.overrides ?? []), data.override]
    }
    await fetchProjection().catch(() => {})
    return data.override
  }

  async function updateOverride(id, payload) {
    const { data } = await planApi.updateOverride(id, payload)
    for (const event of events.value) {
      const idx = (event.overrides ?? []).findIndex((o) => o.id === id)
      if (idx !== -1) {
        event.overrides.splice(idx, 1, data.override)
        break
      }
    }
    await fetchProjection().catch(() => {})
    return data.override
  }

  async function deleteOverride(id) {
    await planApi.deleteOverride(id)
    for (const event of events.value) {
      if (!event.overrides) continue
      event.overrides = event.overrides.filter((o) => o.id !== id)
    }
    await fetchProjection().catch(() => {})
  }

  function reset() {
    events.value = []
    projection.value = null
    error.value = null
  }

  return {
    events,
    projection,
    loading,
    error,
    isEmpty,
    fetchEvents,
    fetchProjection,
    createEvent,
    bulkCreateEvents,
    updateEvent,
    deleteEvent,
    clearAll,
    createOverride,
    updateOverride,
    deleteOverride,
    reset,
  }
})
