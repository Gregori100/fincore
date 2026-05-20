import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/auth/LoginView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/views/auth/RegisterView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/email-verified',
    name: 'email-verified',
    component: () => import('@/views/auth/EmailVerifiedView.vue'),
  },
  {
    path: '/forgot-password',
    name: 'forgot-password',
    component: () => import('@/views/auth/ForgotPasswordView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/reset-password',
    name: 'reset-password',
    component: () => import('@/views/auth/ResetPasswordView.vue'),
  },
  {
    path: '/dashboard',
    name: 'dashboard',
    component: () => import('@/views/app/DashboardView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/entries',
    name: 'entries',
    component: () => import('@/views/app/EntriesView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/accounts',
    name: 'accounts',
    component: () => import('@/views/app/AccountsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/accounts/:uuid',
    name: 'account-detail',
    component: () => import('@/views/app/AccountDetailView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/categories',
    name: 'categories',
    component: () => import('@/views/app/CategoriesView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports',
    redirect: { name: 'reports-by-category' },
  },
  {
    path: '/reports/by-category',
    name: 'reports-by-category',
    component: () => import('@/views/app/ReportsByCategoryView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports/cashflow',
    name: 'reports-cashflow',
    component: () => import('@/views/app/ReportsCashflowView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports/month-comparison',
    name: 'reports-month-comparison',
    component: () => import('@/views/app/ReportsMonthComparisonView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports/credit-cards',
    name: 'reports-credit-cards',
    component: () => import('@/views/app/ReportsCreditCardsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports/budgets',
    name: 'reports-budgets',
    component: () => import('@/views/app/ReportsBudgetsView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/plan',
    name: 'plan',
    component: () => import('@/views/app/PlanView.vue'),
    meta: { requiresAuth: true },
  },
  { path: '/', redirect: { name: 'dashboard' } },
  { path: '/:pathMatch(.*)*', redirect: { name: 'dashboard' } },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to) => {
  const auth = useAuthStore()

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.meta.requiresGuest && auth.isAuthenticated) {
    return { name: 'dashboard' }
  }
})

export default router
