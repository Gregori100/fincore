import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('@/api/auth', () => ({
  authApi: {
    login: vi.fn(),
    register: vi.fn(),
    logout: vi.fn(() => Promise.resolve({})),
    me: vi.fn(),
    resendVerification: vi.fn(),
  },
}))

import { useAuthStore } from '@/stores/auth'
import { authApi } from '@/api/auth'

describe('auth store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
    vi.clearAllMocks()
  })

  it('login guarda token y user; isAuthenticated reactivo', async () => {
    authApi.login.mockResolvedValue({
      data: {
        user: { id: 1, email: 'd@x.com', email_verified_at: '2026-01-01' },
        token: 'abc123',
      },
    })

    const auth = useAuthStore()
    expect(auth.isAuthenticated).toBe(false)

    await auth.login('d@x.com', 'secret')

    expect(auth.token).toBe('abc123')
    expect(auth.user.email).toBe('d@x.com')
    expect(auth.isAuthenticated).toBe(true)
    expect(auth.isVerified).toBe(true)
  })

  it('logout limpia sesión incluso si el endpoint falla', async () => {
    const auth = useAuthStore()
    auth.setSession({ user: { id: 1 }, token: 't' })
    authApi.logout.mockRejectedValueOnce(new Error('boom'))

    await auth.logout()

    expect(auth.token).toBe(null)
    expect(auth.user).toBe(null)
    expect(auth.isAuthenticated).toBe(false)
  })

  it('isVerified es false cuando email_verified_at es null', () => {
    const auth = useAuthStore()
    auth.setSession({ user: { id: 1, email_verified_at: null }, token: 't' })
    expect(auth.isVerified).toBe(false)
  })
})
