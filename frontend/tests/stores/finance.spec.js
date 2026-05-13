import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('@/api/finance', () => ({
  financeApi: {
    state: vi.fn(),
    income: vi.fn(),
    expense: vi.fn(),
    creditExpense: vi.fn(),
    payCredit: vi.fn(),
    transfer: vi.fn(),
    createAccount: vi.fn(),
  },
}))

import { useFinanceStore } from '@/stores/finance'
import { financeApi } from '@/api/finance'

describe('finance store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  it('fetchState popula state, accounts y recentEntries', async () => {
    financeApi.state.mockResolvedValue({
      data: {
        bo: 1500,
        de: 200,
        cr: 9800,
        burn_rate: 50,
        credit_usage_pct: 2,
        accounts: [{ id: 1, type: 'cash', name: 'Bolsa', balance: 1500 }],
        recent_entries: [{ id: 10, kind: 'income' }],
      },
    })

    const finance = useFinanceStore()
    await finance.fetchState()

    expect(finance.state.bo).toBe(1500)
    expect(finance.state.de).toBe(200)
    expect(finance.accounts).toHaveLength(1)
    expect(finance.recentEntries).toHaveLength(1)
  })

  it('cashAndDebitAccounts filtra correctamente', async () => {
    financeApi.state.mockResolvedValue({
      data: {
        bo: 0, de: 0, cr: 0, burn_rate: 0, credit_usage_pct: 0,
        accounts: [
          { id: 1, type: 'cash', name: 'Bolsa' },
          { id: 2, type: 'debit', name: 'Banamex' },
          { id: 3, type: 'credit', name: 'Visa' },
        ],
        recent_entries: [],
      },
    })

    const finance = useFinanceStore()
    await finance.fetchState()

    expect(finance.cashAndDebitAccounts).toHaveLength(2)
    expect(finance.creditAccounts).toHaveLength(1)
  })

  it('reset limpia el estado', () => {
    const finance = useFinanceStore()
    finance.state.bo = 1000
    finance.accounts = [{ id: 1 }]

    finance.reset()

    expect(finance.state.bo).toBe(0)
    expect(finance.accounts).toEqual([])
  })
})
