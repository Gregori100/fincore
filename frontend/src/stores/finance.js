import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { financeApi } from '@/api/finance'

export const useFinanceStore = defineStore('finance', () => {
  const state = ref({
    bo: 0,
    de: 0,
    cr: 0,
    burn_rate: 0,
    credit_usage_pct: 0,
  })
  const accounts = ref([])
  const recentEntries = ref([])
  const loading = ref(false)

  const cashAndDebitAccounts = computed(() =>
    accounts.value.filter((a) => a.type === 'cash' || a.type === 'debit'),
  )
  const creditAccounts = computed(() =>
    accounts.value.filter((a) => a.type === 'credit'),
  )

  async function fetchState() {
    loading.value = true
    try {
      const { data } = await financeApi.state()
      state.value = {
        bo: Number(data.bo),
        de: Number(data.de),
        cr: Number(data.cr),
        burn_rate: Number(data.burn_rate),
        credit_usage_pct: Number(data.credit_usage_pct),
      }
      accounts.value = data.accounts ?? []
      recentEntries.value = data.recent_entries ?? []
    } finally {
      loading.value = false
    }
  }

  async function createAccount(payload) {
    await financeApi.createAccount(payload)
    await fetchState()
  }

  async function registerIncome(payload) {
    await financeApi.income(payload)
    await fetchState()
  }

  async function registerExpense(payload) {
    await financeApi.expense(payload)
    await fetchState()
  }

  async function registerCreditExpense(payload) {
    await financeApi.creditExpense(payload)
    await fetchState()
  }

  async function payCredit(payload) {
    await financeApi.payCredit(payload)
    await fetchState()
  }

  async function transfer(payload) {
    await financeApi.transfer(payload)
    await fetchState()
  }

  function reset() {
    state.value = { bo: 0, de: 0, cr: 0, burn_rate: 0, credit_usage_pct: 0 }
    accounts.value = []
    recentEntries.value = []
  }

  return {
    state,
    accounts,
    recentEntries,
    loading,
    cashAndDebitAccounts,
    creditAccounts,
    fetchState,
    createAccount,
    registerIncome,
    registerExpense,
    registerCreditExpense,
    payCredit,
    transfer,
    reset,
  }
})
