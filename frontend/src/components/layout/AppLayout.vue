<script setup>
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'

const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()
const router = useRouter()

async function handleLogout() {
  await auth.logout()
  finance.reset()
  toast.success('Sesión cerrada')
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-full flex flex-col">
    <header
      class="border-b border-[color:var(--color-border)] bg-[color:var(--color-surface)]/80 backdrop-blur supports-[backdrop-filter]:bg-[color:var(--color-surface)]/60 sticky top-0 z-10"
    >
      <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
        <div class="flex items-center gap-6">
          <RouterLink :to="{ name: 'dashboard' }" class="text-base font-semibold tracking-tight">
            <span class="text-[color:var(--color-accent)]">Fin</span>Core
          </RouterLink>
          <nav class="hidden sm:flex items-center gap-4 text-sm">
            <RouterLink
              :to="{ name: 'dashboard' }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              Dashboard
            </RouterLink>
            <RouterLink
              :to="{ name: 'accounts' }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              Mis cuentas
            </RouterLink>
            <RouterLink
              :to="{ name: 'categories' }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              Categorías
            </RouterLink>
            <RouterLink
              :to="{ name: 'reports' }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              Reportes
            </RouterLink>
            <RouterLink
              :to="{ name: 'entries' }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              Movimientos
            </RouterLink>
          </nav>
        </div>

        <div class="flex items-center gap-4 text-sm">
          <span class="text-[color:var(--color-text-muted)] hidden sm:inline">
            {{ auth.user?.email }}
          </span>
          <button
            type="button"
            class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
            @click="handleLogout"
          >
            Cerrar sesión
          </button>
        </div>
      </div>
    </header>

    <main class="flex-1 max-w-6xl w-full mx-auto px-6 py-8">
      <slot />
    </main>
  </div>
</template>
