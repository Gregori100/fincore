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
      class="border-b border-[color:var(--color-border)] bg-[color:var(--color-surface)]"
    >
      <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
        <h1 class="text-lg font-semibold tracking-tight">
          FinCore
        </h1>

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
