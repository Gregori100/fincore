import client from './client'

export function hardReset(password, mode = 'full') {
  return client.post('/finance/reset', { password, mode })
}

export default {
  hardReset,
}
