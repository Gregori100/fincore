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
  // Mensaje de error de la última fetchState (red caída, 5xx, etc.).
  // 403/401 NO se guardan aquí: los maneja el interceptor / banner de email.
  const error = ref(null)
  const errorStatus = ref(null)
  // IDs de cuentas afectadas por la última mutación. UI las resalta brevemente.
  const lastAffectedAccountIds = ref(new Set())
  let affectedTimeout = null
  function markAffected(ids) {
    lastAffectedAccountIds.value = new Set(ids.filter(Boolean))
    if (affectedTimeout) clearTimeout(affectedTimeout)
    affectedTimeout = setTimeout(() => {
      lastAffectedAccountIds.value = new Set()
    }, 1800)
  }

  const cashAndDebitAccounts = computed(() =>
    accounts.value.filter((a) => a.type === 'cash' || a.type === 'debit'),
  )
  const creditAccounts = computed(() =>
    accounts.value.filter((a) => a.type === 'credit'),
  )

  async function fetchState() {
    loading.value = true
    error.value = null
    errorStatus.value = null
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
    } catch (e) {
      errorStatus.value = e.response?.status ?? null
      // 401 lo maneja el interceptor (logout + redirect).
      // 403 (email no verificado) tiene su propio banner; no es error de carga.
      if (errorStatus.value !== 401 && errorStatus.value !== 403) {
        error.value =
          e.response?.data?.message
          ?? (e.message?.includes('Network')
            ? 'No hay conexión con el servidor. Verifica tu red.'
            : 'Ocurrió un error inesperado. Reintenta.')
      }
      throw e
    } finally {
      loading.value = false
    }
  }

  async function createAccount(payload) {
    const { data } = await financeApi.createAccount(payload)
    await fetchState()
    markAffected([data?.account?.id])
  }

  async function registerIncome(payload) {
    await financeApi.income(payload)
    await fetchState()
    markAffected([payload.account_id])
  }

  async function registerExpense(payload) {
    await financeApi.expense(payload)
    await fetchState()
    markAffected([payload.account_id])
  }

  async function registerCreditExpense(payload) {
    await financeApi.creditExpense(payload)
    await fetchState()
    markAffected([payload.account_id])
  }

  async function payCredit(payload) {
    await financeApi.payCredit(payload)
    await fetchState()
    markAffected([payload.origin_id, payload.credit_account_id])
  }

  async function transfer(payload) {
    await financeApi.transfer(payload)
    await fetchState()
    markAffected([payload.origin_id, payload.destination_id])
  }

  function reset() {
    state.value = { bo: 0, de: 0, cr: 0, burn_rate: 0, credit_usage_pct: 0 }
    accounts.value = []
    recentEntries.value = []
    error.value = null
    errorStatus.value = null
    lastAffectedAccountIds.value = new Set()
    if (affectedTimeout) clearTimeout(affectedTimeout)
  }

  return {
    state,
    accounts,
    recentEntries,
    loading,
    error,
    errorStatus,
    lastAffectedAccountIds,
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
