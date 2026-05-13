import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'

vi.mock('@/api/auth', () => ({ authApi: {} }))

describe('router guards', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('redirige a /login si la ruta requiere auth y no hay token', async () => {
    const { default: router } = await import('@/router')

    const result = await router.push('/dashboard')
    // Tras la navegación, la ruta resuelta debe ser /login
    expect(router.currentRoute.value.name).toBe('login')
  })

  it('redirige a /dashboard cuando ya está autenticado y va a /login', async () => {
    const auth = useAuthStore()
    auth.setSession({ user: { id: 1 }, token: 't' })

    // forzamos re-import para que router instancie con auth ya hidratado
    vi.resetModules()
    const { default: router } = await import('@/router')

    await router.push('/login')
    expect(router.currentRoute.value.name).toBe('dashboard')
  })
})
