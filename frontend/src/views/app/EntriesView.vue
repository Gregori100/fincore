<script setup>
import { computed, onMounted, ref } from 'vue'
import {
  ArrowDownTrayIcon,
  ArrowsRightLeftIcon,
  ArrowUpTrayIcon,
  BanknotesIcon,
  CreditCardIcon,
} from '@heroicons/vue/24/outline'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import EntriesTable from '@/components/finance/EntriesTable.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import IncomeForm from '@/components/finance/IncomeForm.vue'
import ExpenseForm from '@/components/finance/ExpenseForm.vue'
import CreditExpenseForm from '@/components/finance/CreditExpenseForm.vue'
import PayCreditForm from '@/components/finance/PayCreditForm.vue'
import TransferForm from '@/components/finance/TransferForm.vue'

const auth = useAuthStore()
const finance = useFinanceStore()
// 'income' | 'expense' | 'credit-expense' | 'pay-credit' | 'transfer' | null
const openModal = ref(null)
// Bump para forzar a EntriesTable a refrescar la página tras un éxito.
const tableKey = ref(0)

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const boIsNegative = computed(() => Number(finance.state.bo) < 0)

// Si el usuario entra directo a /entries (link compartido, recarga), el store
// puede no tener state cargado. fetchState es idempotente y barato.
onMounted(() => {
  finance.fetchState().catch(() => {})
})

function close() {
  openModal.value = null
}

function onSuccess() {
  // El registro ya actualizó el store via finance.fetchState(); refrescamos la
  // tabla local del listado para que el nuevo entry aparezca sin requerir
  // navegación o reload manual.
  tableKey.value += 1
}

// Mismo set y misma paleta que el card de "Registrar movimiento" del dashboard
// — es deliberado: el usuario aprende un único patrón de quick-actions.
const actions = [
  { key: 'income', label: 'Ingreso', icon: ArrowDownTrayIcon, color: 'text-[color:var(--color-positive)]' },
  { key: 'expense', label: 'Gasto', icon: ArrowUpTrayIcon, color: 'text-[color:var(--color-negative)]' },
  { key: 'credit-expense', label: 'Cargo crédito', icon: CreditCardIcon, color: 'text-[color:var(--color-warning)]' },
  { key: 'pay-credit', label: 'Pagar tarjeta', icon: BanknotesIcon, color: 'text-[color:var(--color-accent)]' },
  { key: 'transfer', label: 'Transferir', icon: ArrowsRightLeftIcon, color: 'text-[color:var(--color-text-muted)]' },
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

        <RouterLink
          :to="{ name: 'dashboard' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
        >
          ← Dashboard
        </RouterLink>
      </header>

      <section class="grid grid-cols-3 gap-2 sm:gap-4">
        <article
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-lg px-3 sm:px-4 py-3"
        >
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Bolsa (BO)
          </p>
          <p
            class="text-base sm:text-2xl font-semibold mt-1 tabular-nums tracking-tight"
            :class="boIsNegative ? 'text-[color:var(--color-negative)]' : 'text-[color:var(--color-positive)]'"
          >
            {{ fmt(finance.state.bo) }}
          </p>
        </article>
        <article
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-lg px-3 sm:px-4 py-3"
        >
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Deudas (DE)
          </p>
          <p class="text-base sm:text-2xl font-semibold mt-1 tabular-nums tracking-tight text-[color:var(--color-negative)]">
            {{ fmt(finance.state.de) }}
          </p>
        </article>
        <article
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-lg px-3 sm:px-4 py-3"
        >
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Crédito (CR)
          </p>
          <p class="text-base sm:text-2xl font-semibold mt-1 tabular-nums tracking-tight text-[color:var(--color-accent)]">
            {{ fmt(finance.state.cr) }}
          </p>
        </article>
      </section>

      <!-- Quick actions: mismo card que el dashboard. Acceso de un click vs dos
           del dropdown anterior. -->
      <section
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4"
      >
        <p class="text-xs font-medium uppercase tracking-wide text-[color:var(--color-text-subtle)] mb-3">
          Registrar movimiento
          <span v-if="!auth.isVerified" class="text-[color:var(--color-warning)] normal-case font-normal ml-2">
            · disponible tras verificar email
          </span>
        </p>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="a in actions"
            :key="a.key"
            type="button"
            class="inline-flex items-center gap-2 px-3 py-2 rounded-md border border-[color:var(--color-border)] bg-[color:var(--color-surface-elevated)] hover:border-[color:var(--color-accent)] text-sm transition disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:border-[color:var(--color-border)]"
            :disabled="!auth.isVerified"
            :title="!auth.isVerified ? 'Verifica tu email primero' : ''"
            @click="openModal = a.key"
          >
            <component :is="a.icon" :class="['h-4 w-4', a.color]" />
            {{ a.label }}
          </button>
        </div>
      </section>

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
