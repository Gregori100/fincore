import client from './client'

export const authApi = {
  register: (payload) => client.post('/auth/register', payload),
  login: (payload) => client.post('/auth/login', payload),
  logout: () => client.post('/auth/logout'),
  logoutAll: () => client.post('/auth/logout-all'),
  me: () => client.get('/auth/me'),
  resendVerification: () => client.post('/auth/email/verification-notification'),
  forgotPassword: (email) => client.post('/auth/password/forgot', { email }),
  resetPassword: (payload) => client.post('/auth/password/reset', payload),
}
