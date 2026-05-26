import client from './client'

export function hardReset(password, mode = 'full') {
  return client.post('/finance/reset', { password, mode })
}

export function exportBackup() {
  return client.get('/finance/backup/export')
}

export function importBackup(password, backup) {
  return client.post('/finance/backup/import', { password, backup })
}

export default {
  hardReset,
  exportBackup,
  importBackup,
}
