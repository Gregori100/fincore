import axios from 'axios'

const client = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})

// Inyección perezosa de stores y router para evitar el ciclo
// stores ↔ client ↔ stores que ocurriría al importar directo.
let authStoreFactory = null
let toastStoreFactory = null
let routerInstance = null

export function bindAuth(factory) {
  authStoreFactory = factory
}

export function bindToast(factory) {
  toastStoreFactory = factory
}

export function bindRouter(instance) {
  routerInstance = instance
}

client.interceptors.request.use((config) => {
  if (!authStoreFactory) return config
  const token = authStoreFactory().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

client.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status
    const url = error.config?.url ?? ''
    const isAuthRequest = url.includes('/auth/login') || url.includes('/auth/register')

    if (status === 401 && !isAuthRequest && authStoreFactory) {
      // Capturamos si realmente había sesión antes del clear: distingue entre
      // "el token expiró" (queremos avisar) y "request sin auth" (no hay nada que avisar).
      const hadToken = !!authStoreFactory().token
      authStoreFactory().clear()
      if (hadToken && toastStoreFactory) {
        toastStoreFactory().error(
          'Tu sesión expiró. Inicia sesión nuevamente.',
          { timeout: 6000 },
        )
      }
      if (routerInstance) {
        routerInstance.push({ name: 'login' })
      }
    }

    // 403 con "email not verified" tiene un mensaje accionable en español.
    // Centralizamos aquí para no repetirlo en cada form.
    const msg = error.response?.data?.message ?? ''
    if (status === 403 && /not verified|no.*verificad/i.test(msg) && toastStoreFactory) {
      toastStoreFactory().error(
        'Necesitas verificar tu email antes de operar. Revisa tu bandeja (o Mailpit en localhost:8025 en dev) y haz click en el link de verificación.',
      )
    }

    return Promise.reject(error)
  },
)

export default client
