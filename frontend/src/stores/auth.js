import { computed } from 'vue'
import { defineStore } from 'pinia'
import { useStorage } from '@vueuse/core'
import { authApi } from '@/api/auth'

export const useAuthStore = defineStore('auth', () => {
  const token = useStorage('fincore_token', null)
  const user = useStorage('fincore_user', null, localStorage, {
    serializer: {
      read: (v) => (v ? JSON.parse(v) : null),
      write: (v) => JSON.stringify(v),
    },
  })

  const isAuthenticated = computed(() => !!token.value)
  const isVerified = computed(() => !!user.value?.email_verified_at)

  function setSession({ user: u, token: t }) {
    user.value = u
    token.value = t
  }

  function clear() {
    user.value = null
    token.value = null
  }

  async function login(email, password) {
    const { data } = await authApi.login({ email, password })
    setSession(data)
    return data
  }

  async function register(payload) {
    const { data } = await authApi.register(payload)
    setSession(data)
    return data
  }

  async function logout() {
    try {
      await authApi.logout()
    } catch {
      /* ignoramos: si el token ya estaba invalidado, igual queremos limpiar local */
    }
    clear()
  }

  async function fetchMe() {
    if (!token.value) return null
    const { data } = await authApi.me()
    user.value = data.user
    return data.user
  }

  async function resendVerification() {
    await authApi.resendVerification()
  }

  return {
    token,
    user,
    isAuthenticated,
    isVerified,
    setSession,
    clear,
    login,
    register,
    logout,
    fetchMe,
    resendVerification,
  }
})
