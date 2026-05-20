<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import {
  Dialog,
  DialogPanel,
  TransitionChild,
  TransitionRoot,
} from '@headlessui/vue'
import { Bars3Icon, XMarkIcon } from '@heroicons/vue/24/outline'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'

const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()
const router = useRouter()

// Estado del drawer mobile. Cualquier RouterLink dentro lo cierra al click
// para no dejar al user con el panel abierto tras navegar.
const mobileNavOpen = ref(false)
function closeMobileNav() {
  mobileNavOpen.value = false
}

// Lista única para evitar duplicar markup entre la nav desktop y el drawer.
const navItems = [
  { name: 'dashboard', label: 'Dashboard' },
  { name: 'accounts', label: 'Mis cuentas' },
  { name: 'categories', label: 'Categorías' },
  { name: 'entries', label: 'Movimientos' },
  { name: 'reports-by-category', label: 'Reportes' },
  { name: 'plan', label: 'Plan' },
]

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
      <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between gap-3">
        <div class="flex items-center gap-6 min-w-0">
          <RouterLink :to="{ name: 'dashboard' }" class="text-base font-semibold tracking-tight shrink-0">
            <span class="text-[color:var(--color-accent)]">Fin</span>Core
          </RouterLink>
          <nav class="hidden sm:flex items-center gap-4 text-sm">
            <RouterLink
              v-for="item in navItems"
              :key="item.name"
              :to="{ name: item.name }"
              class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
              active-class="text-[color:var(--color-text-primary)]"
            >
              {{ item.label }}
            </RouterLink>
          </nav>
        </div>

        <div class="flex items-center gap-3 text-sm">
          <span class="text-[color:var(--color-text-muted)] hidden sm:inline">
            {{ auth.user?.email }}
          </span>
          <button
            type="button"
            class="text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition hidden sm:inline"
            @click="handleLogout"
          >
            Cerrar sesión
          </button>

          <button
            type="button"
            class="sm:hidden p-1.5 rounded text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
            aria-label="Abrir menú"
            @click="mobileNavOpen = true"
          >
            <Bars3Icon class="h-6 w-6" />
          </button>
        </div>
      </div>
    </header>

    <main class="flex-1 max-w-6xl w-full mx-auto px-4 sm:px-6 py-6 sm:py-8">
      <slot />
    </main>

    <!-- Drawer mobile -->
    <TransitionRoot appear :show="mobileNavOpen" as="template">
      <Dialog as="div" class="relative z-50 sm:hidden" @close="closeMobileNav">
        <TransitionChild
          as="template"
          enter="duration-200 ease-out"
          enter-from="opacity-0"
          enter-to="opacity-100"
          leave="duration-150 ease-in"
          leave-from="opacity-100"
          leave-to="opacity-0"
        >
          <div class="fixed inset-0 bg-black/60 backdrop-blur-sm" />
        </TransitionChild>

        <div class="fixed inset-y-0 left-0 flex">
          <TransitionChild
            as="template"
            enter="transition-transform duration-250 ease-out"
            enter-from="-translate-x-full"
            enter-to="translate-x-0"
            leave="transition-transform duration-200 ease-in"
            leave-from="translate-x-0"
            leave-to="-translate-x-full"
          >
            <DialogPanel
              class="w-72 max-w-[80vw] bg-[color:var(--color-surface)] border-r border-[color:var(--color-border)] flex flex-col"
            >
              <header class="flex items-center justify-between px-5 py-4 border-b border-[color:var(--color-border)]">
                <span class="text-base font-semibold tracking-tight">
                  <span class="text-[color:var(--color-accent)]">Fin</span>Core
                </span>
                <button
                  type="button"
                  class="p-1 rounded text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
                  aria-label="Cerrar menú"
                  @click="closeMobileNav"
                >
                  <XMarkIcon class="h-5 w-5" />
                </button>
              </header>

              <nav class="flex-1 px-3 py-4 space-y-1 text-sm">
                <RouterLink
                  v-for="item in navItems"
                  :key="item.name"
                  :to="{ name: item.name }"
                  class="block px-3 py-2.5 rounded-md text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] hover:bg-[color:var(--color-surface-elevated)] transition"
                  active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
                  @click="closeMobileNav"
                >
                  {{ item.label }}
                </RouterLink>
              </nav>

              <footer class="border-t border-[color:var(--color-border)] px-5 py-4 space-y-3">
                <p class="text-xs text-[color:var(--color-text-muted)] truncate">
                  {{ auth.user?.email }}
                </p>
                <button
                  type="button"
                  class="w-full text-left text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-negative)] transition"
                  @click="handleLogout"
                >
                  Cerrar sesión
                </button>
              </footer>
            </DialogPanel>
          </TransitionChild>
        </div>
      </Dialog>
    </TransitionRoot>
  </div>
</template>
