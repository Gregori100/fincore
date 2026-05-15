import client from './client'

export const financeApi = {
  state: () => client.get('/finance/state'),
  accounts: ({ includeArchived = false } = {}) =>
    client.get('/finance/accounts', {
      params: includeArchived ? { include_archived: 1 } : {},
    }),
  createAccount: (payload) => client.post('/finance/accounts', payload),
  updateAccount: (id, payload) => client.patch(`/finance/accounts/${id}`, payload),
  deleteAccount: (id) => client.delete(`/finance/accounts/${id}`),

  entries: (params = {}) => client.get('/finance/entries', { params }),
  updateEntry: (id, payload) => client.patch(`/finance/entries/${id}`, payload),
  cancelEntry: (id) => client.delete(`/finance/entries/${id}`),

  listCategories: ({ includeArchived = false, appliesTo = null } = {}) =>
    client.get('/finance/categories', {
      params: {
        ...(includeArchived ? { include_archived: 1 } : {}),
        ...(appliesTo ? { applies_to: appliesTo } : {}),
      },
    }),
  createCategory: (payload) => client.post('/finance/categories', payload),
  updateCategory: (id, payload) => client.patch(`/finance/categories/${id}`, payload),
  archiveCategory: (id) => client.delete(`/finance/categories/${id}`),

  reportByCategory: (params) => client.get('/finance/reports/by-category', { params }),
  reportCashflowMonthly: (params) => client.get('/finance/reports/cashflow-monthly', { params }),
  reportMonthComparison: (params) => client.get('/finance/reports/month-comparison', { params }),
  reportCreditCards: () => client.get('/finance/reports/credit-cards'),

  income: (payload) => client.post('/finance/income', payload),
  expense: (payload) => client.post('/finance/expense', payload),
  creditExpense: (payload) => client.post('/finance/credit-expense', payload),
  payCredit: (payload) => client.post('/finance/pay-credit', payload),
  transfer: (payload) => client.post('/finance/transfer', payload),
}
