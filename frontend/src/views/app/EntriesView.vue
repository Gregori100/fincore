<script setup>
import { ref } from 'vue'
import { Menu, MenuButton, MenuItem, MenuItems } from '@headlessui/vue'
import {
  ArrowDownTrayIcon,
  ArrowsRightLeftIcon,
  ArrowUpTrayIcon,
  BanknotesIcon,
  ChevronDownIcon,
  CreditCardIcon,
  PlusIcon,
} from '@heroicons/vue/24/outline'
import { useAuthStore } from '@/stores/auth'
import AppLayout from '@/components/layout/AppLayout.vue'
import EntriesTable from '@/components/finance/EntriesTable.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import IncomeForm from '@/components/finance/IncomeForm.vue'
import ExpenseForm from '@/components/finance/ExpenseForm.vue'
import CreditExpenseForm from '@/components/finance/CreditExpenseForm.vue'
import PayCreditForm from '@/components/finance/PayCreditForm.vue'
import TransferForm from '@/components/finance/TransferForm.vue'

const auth = useAuthStore()
// 'income' | 'expense' | 'credit-expense' | 'pay-credit' | 'transfer' | null
const openModal = ref(null)
// Bump para forzar a EntriesTable a refrescar la página tras un éxito.
const tableKey = ref(0)

function close() {
  openModal.value = null
}

function onSuccess() {
  // El registro ya actualizó el store via finance.fetchState(); refrescamos la
  // tabla local del listado para que el nuevo entry aparezca sin requerir
  // navegación o reload manual.
  tableKey.value += 1
}

const actions = [
  { key: 'income', label: 'Ingreso', icon: ArrowDownTrayIcon },
  { key: 'expense', label: 'Gasto', icon: ArrowUpTrayIcon },
  { key: 'credit-expense', label: 'Cargo a tarjeta', icon: CreditCardIcon },
  { key: 'pay-credit', label: 'Pagar tarjeta', icon: BanknotesIcon },
  { key: 'transfer', label: 'Transferir', icon: ArrowsRightLeftIcon },
]
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Historial de movimientos</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Filtra, registra o cancela tus pólizas
          </p>
        </div>

        <div class="flex items-center gap-3">
          <RouterLink
            :to="{ name: 'dashboard' }"
            class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
          >
            ← Dashboard
          </RouterLink>

          <Menu as="div" class="relative inline-block text-left">
            <MenuButton
              class="inline-flex items-center gap-1.5 px-3 py-2 rounded-md text-sm font-medium bg-[color:var(--color-accent)] text-black hover:bg-[color:var(--color-accent-hover)] disabled:opacity-50 disabled:cursor-not-allowed focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--color-canvas)] transition"
              :disabled="!auth.isVerified"
              :title="auth.isVerified ? '' : 'Verifica tu email primero'"
            >
              <PlusIcon class="h-4 w-4" />
              Nuevo movimiento
              <ChevronDownIcon class="h-4 w-4" />
            </MenuButton>
            <transition
              enter-active-class="transition duration-100 ease-out"
              enter-from-class="transform scale-95 opacity-0"
              enter-to-class="transform scale-100 opacity-100"
              leave-active-class="transition duration-75 ease-in"
              leave-from-class="transform scale-100 opacity-100"
              leave-to-class="transform scale-95 opacity-0"
            >
              <MenuItems
                class="absolute right-0 mt-2 w-56 origin-top-right rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] shadow-lg shadow-black/40 focus:outline-none z-20 py-1"
              >
                <MenuItem
                  v-for="a in actions"
                  :key="a.key"
                  v-slot="{ active }"
                >
                  <button
                    type="button"
                    class="flex items-center gap-2 w-full px-3 py-2 text-sm text-left"
                    :class="active
                      ? 'bg-[color:var(--color-accent)]/15 text-[color:var(--color-text-primary)]'
                      : 'text-[color:var(--color-text-muted)]'"
                    @click="openModal = a.key"
                  >
                    <component :is="a.icon" class="h-4 w-4" />
                    {{ a.label }}
                  </button>
                </MenuItem>
              </MenuItems>
            </transition>
          </Menu>
        </div>
      </header>

      <EntriesTable :key="tableKey" />
    </div>

    <BaseModal :open="openModal === 'income'" title="Registrar ingreso" @close="close">
      <IncomeForm @close="close" @success="onSuccess" />
    </BaseModal>
    <BaseModal :open="openModal === 'expense'" title="Registrar gasto" @close="close">
      <ExpenseForm @close="close" @success="onSuccess" />
    </BaseModal>
    <BaseModal :open="openModal === 'credit-expense'" title="Cargo a tarjeta" @close="close">
      <CreditExpenseForm @close="close" @success="onSuccess" />
    </BaseModal>
    <BaseModal :open="openModal === 'pay-credit'" title="Pagar tarjeta" @close="close">
      <PayCreditForm @close="close" @success="onSuccess" />
    </BaseModal>
    <BaseModal :open="openModal === 'transfer'" title="Transferir entre cuentas" @close="close">
      <TransferForm @close="close" @success="onSuccess" />
    </BaseModal>
  </AppLayout>
</template>
