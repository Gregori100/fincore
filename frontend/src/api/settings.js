import client from './client'

export function hardReset(password) {
  return client.post('/finance/reset', { password })
}

export default {
  hardReset,
}
