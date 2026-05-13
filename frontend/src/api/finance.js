import client from './client'

export const financeApi = {
  state: () => client.get('/finance/state'),
  accounts: () => client.get('/finance/accounts'),
  createAccount: (payload) => client.post('/finance/accounts', payload),
  updateAccount: (id, payload) => client.patch(`/finance/accounts/${id}`, payload),
  deleteAccount: (id) => client.delete(`/finance/accounts/${id}`),

  entries: (params = {}) => client.get('/finance/entries', { params }),

  income: (payload) => client.post('/finance/income', payload),
  expense: (payload) => client.post('/finance/expense', payload),
  creditExpense: (payload) => client.post('/finance/credit-expense', payload),
  payCredit: (payload) => client.post('/finance/pay-credit', payload),
  transfer: (payload) => client.post('/finance/transfer', payload),
}
