import client from './client'

export function listEvents() {
  return client.get('/finance/plan/events')
}

export function createEvent(payload) {
  return client.post('/finance/plan/events', payload)
}

export function updateEvent(id, payload) {
  return client.patch(`/finance/plan/events/${id}`, payload)
}

export function deleteEvent(id) {
  return client.delete(`/finance/plan/events/${id}`)
}

export function clearEvents() {
  return client.delete('/finance/plan/events')
}

export function createOverride(eventId, payload) {
  return client.post(`/finance/plan/events/${eventId}/overrides`, payload)
}

export function updateOverride(id, payload) {
  return client.patch(`/finance/plan/overrides/${id}`, payload)
}

export function deleteOverride(id) {
  return client.delete(`/finance/plan/overrides/${id}`)
}

export function projection() {
  return client.get('/finance/plan/projection')
}

export default {
  listEvents,
  createEvent,
  updateEvent,
  deleteEvent,
  clearEvents,
  createOverride,
  updateOverride,
  deleteOverride,
  projection,
}
