import { defineStore } from 'pinia'
import { ref } from 'vue'
import client from '../api/client'

export const useFinanceStore = defineStore('finance', () => {
  const bo = ref(0)
  const de = ref(0)
  const debts = ref([])
  const loading = ref(false)
  const error = ref(null)

  async function fetchState() {
    loading.value = true
    error.value = null
    try {
      const { data } = await client.get('/finance/state')
      bo.value = data.bo
      de.value = data.de
      debts.value = data.debts
    } catch (e) {
      error.value = e.message
    } finally {
      loading.value = false
    }
  }

  return { bo, de, debts, loading, error, fetchState }
})
