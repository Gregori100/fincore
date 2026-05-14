<script setup>
import { onMounted, ref, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { useShortcuts } from '@/composables/useShortcuts'
import AppLayout from '@/components/layout/AppLayout.vue'
import StateSummary from '@/components/finance/StateSummary.vue'
import AccountList from '@/components/finance/AccountList.vue'
import RecentEntries from '@/components/finance/RecentEntries.vue'
import DashboardSkeleton from '@/components/finance/DashboardSkeleton.vue'
import ShortcutsHelp from '@/components/finance/ShortcutsHelp.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import AccountForm from '@/components/finance/AccountForm.vue'
import AccountEditForm from '@/components/finance/AccountEditForm.vue'
import IncomeForm from '@/components/finance/IncomeForm.vue'
import ExpenseForm from '@/components/finance/ExpenseForm.vue'
import CreditExpenseForm from '@/components/finance/CreditExpenseForm.vue'
import PayCreditForm from '@/components/finance/PayCreditForm.vue'
import TransferForm from '@/components/finance/TransferForm.vue'
import {
  ArrowDownTrayIcon,
  ArrowUpTrayIcon,
  CreditCardIcon,
  BanknotesIcon,
  ArrowsRightLeftIcon,
  EnvelopeIcon,
  QuestionMarkCircleIcon,
} from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()

const openModal = ref(null) // 'account' | 'edit-account' | 'delete-account' | 'income' | 'expense' | 'credit-expense' | 'pay-credit' | 'transfer' | 'shortcuts' | null
const hasLoadedOnce = ref(false)
const editingAccount = ref(null)
const deletingAccount = ref(null)
const deletingState = ref(false)

function fmtMxn(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
  }).format(Number(n ?? 0))
}

function handleEditAccount(account) {
  editingAccount.value = account
  openModal.value = 'edit-account'
}

function handleDeleteAccount(account) {
  // Check client-side: si la cuenta tiene saldo/deuda, ni siquiera abrimos el
  // modal — toast directo con instrucción. El backend valida lo mismo de
  // todos modos (defensa en profundidad).
  const balance = Number(account.balance ?? 0)
  if (Math.abs(balance) > 0.005) {
    toast.error(
      account.type === 'credit'
        ? `Esta tarjeta tiene deuda de ${fmtMxn(balance)}. Págala antes de archivar.`
        : `Esta cuenta tiene saldo de ${fmtMxn(balance)}. Transfiérelo o gástalo antes de archivar.`,
    )
    return
  }
  deletingAccount.value = account
  openModal.value = 'delete-account'
}

async function confirmDeleteAccount() {
  if (!deletingAccount.value) return
  deletingState.value = true
  try {
    await finance.deleteAccount(deletingAccount.value.id)
    toast.success(`Cuenta "${deletingAccount.value.name}" archivada`)
    openModal.value = null
    deletingAccount.value = null
  } catch (e) {
    const status = e.response?.status
    const payload = e.response?.data
    if (status === 404) {
      toast.error('La cuenta ya no existe (¿la archivaste en otra sesión?)')
      openModal.value = null
      deletingAccount.value = null
      await finance.fetchState()
    } else {
      toast.error(payload?.error ?? 'No se pudo archivar la cuenta')
    }
  } finally {
    deletingState.value = false
  }
}

// Atajos de teclado. Solo abrir modales si el user está verificado (excepto ?).
function openIfVerified(name) {
  if (auth.isVerified) openModal.value = name
}
useShortcuts({
  i: () => openIfVerified('income'),
  g: () => openIfVerified('expense'),
  c: () => openIfVerified('credit-expense'),
  p: () => openIfVerified('pay-credit'),
  t: () => openIfVerified('transfer'),
  n: () => openIfVerified('account'),
  '?': () => { openModal.value = 'shortcuts' },
})

// Mostramos skeleton mientras se hace la primera carga; los refresh
// posteriores no parpadean (la UI se actualiza en vivo).
const showSkeleton = computed(() => finance.loading && !hasLoadedOnce.value)

// Mostramos UI de error si la primera carga falló por causa que no sea
// 403 (email no verificado), que tiene su propio banner.
const isVerificationError = computed(
  () => finance.errorStatus === 403,
)
const showErrorState = computed(
  () => finance.error && !hasLoadedOnce.value && !isVerificationError.value,
)

function close() {
  openModal.value = null
}

async function handleResend() {
  try {
    await auth.resendVerification()
    toast.success('Email de verificación reenviado')
  } catch {
    toast.error('No se pudo reenviar el email')
  }
}

async function loadState() {
  try {
    await finance.fetchState()
    hasLoadedOnce.value = true
  } catch (e) {
    // 403 (email no verificado) lo maneja el banner, no es un "error" para UI.
    if (e.response?.status === 403) {
      hasLoadedOnce.value = true
    }
    // El resto (network, 500, etc.) queda como finance.error para mostrar retry.
  }
}

onMounted(async () => {
  await loadState()

  if (auth.isAuthenticated && !auth.user) {
    await auth.fetchMe().catch(() => {})
  }
})

const ACTIONS = [
  { key: 'income', label: 'Ingreso', icon: ArrowDownTrayIcon, color: 'text-[color:var(--color-positive)]' },
  { key: 'expense', label: 'Gasto', icon: ArrowUpTrayIcon, color: 'text-[color:var(--color-negative)]' },
  { key: 'credit-expense', label: 'Cargo crédito', icon: CreditCardIcon, color: 'text-[color:var(--color-warning)]' },
  { key: 'pay-credit', label: 'Pagar tarjeta', icon: BanknotesIcon, color: 'text-[color:var(--color-accent)]' },
  { key: 'transfer', label: 'Transferir', icon: ArrowsRightLeftIcon, color: 'text-[color:var(--color-text-muted)]' },
]
</script>

<template>
  <AppLayout>
    <div class="space-y-8">
      <!-- Banner: email no verificado -->
      <div
        v-if="auth.isAuthenticated && !auth.isVerified"
        class="flex items-start gap-3 rounded-lg border border-[color:var(--color-warning)]/40 bg-[color:var(--color-warning)]/10 p-4"
        role="alert"
      >
        <EnvelopeIcon class="h-5 w-5 mt-0.5 text-[color:var(--color-warning)] shrink-0" />
        <div class="flex-1 text-sm">
          <p class="font-medium text-[color:var(--color-text-primary)]">
            Verifica tu email para empezar a registrar movimientos
          </p>
          <p class="text-[color:var(--color-text-muted)] mt-0.5">
            Enviamos un correo a <strong class="text-[color:var(--color-text-primary)]">{{ auth.user?.email }}</strong> con un link.
            Mientras no hagas click en él, los botones de "Nueva cuenta" y "Registrar movimiento" estarán deshabilitados.
          </p>
          <p class="text-[color:var(--color-text-subtle)] text-xs mt-1">
            En desarrollo, revisa Mailpit en
            <a href="http://localhost:8025" target="_blank" rel="noopener" class="underline text-[color:var(--color-accent)]">
              localhost:8025
            </a>.
          </p>
        </div>
        <BaseButton variant="secondary" @click="handleResend">Reenviar email</BaseButton>
      </div>

      <!-- Skeleton durante la primera carga -->
      <DashboardSkeleton v-if="showSkeleton" />

      <!-- Estado de error con retry (errores de red / 5xx) -->
      <div
        v-else-if="showErrorState"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="font-medium text-[color:var(--color-text-primary)]">
          No pudimos cargar tu estado financiero
        </p>
        <p class="text-sm text-[color:var(--color-text-muted)] mt-1">
          {{ finance.error }}
        </p>
        <BaseButton variant="secondary" class="mt-4" @click="loadState">
          Reintentar
        </BaseButton>
      </div>

      <!-- Contenido real -->
      <template v-else>
        <!-- Estado financiero -->
        <StateSummary :state="finance.state" />

        <!-- Acciones rápidas (deshabilitadas hasta verificar email) -->
        <section
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4"
        >
          <div class="flex items-center justify-between mb-3">
            <p class="text-xs font-medium uppercase tracking-wide text-[color:var(--color-text-subtle)]">
              Registrar movimiento
              <span v-if="!auth.isVerified" class="text-[color:var(--color-warning)] normal-case font-normal ml-2">
                · disponible tras verificar email
              </span>
            </p>
            <button
              type="button"
              class="text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-text-primary)] transition"
              aria-label="Ver atajos de teclado"
              title="Atajos de teclado (?)"
              @click="openModal = 'shortcuts'"
            >
              <QuestionMarkCircleIcon class="h-4 w-4" />
            </button>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="a in ACTIONS"
              :key="a.key"
              type="button"
              class="inline-flex items-center gap-2 px-3 py-2 rounded-md border border-[color:var(--color-border)] bg-[color:var(--color-surface-elevated)] hover:border-[color:var(--color-accent)] text-sm transition disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:border-[color:var(--color-border)]"
              :disabled="!auth.isVerified"
              :title="!auth.isVerified ? 'Verifica tu email primero' : ''"
              @click="openModal = a.key"
            >
              <component :is="a.icon" class="h-4 w-4" :class="a.color" />
              {{ a.label }}
            </button>
          </div>
        </section>

        <!-- Cuentas -->
        <AccountList
          :accounts="finance.accounts"
          :can-create="auth.isVerified"
          :highlighted-ids="finance.lastAffectedAccountIds"
          @create="openModal = 'account'"
          @edit="handleEditAccount"
          @delete="handleDeleteAccount"
        />

        <!-- Últimos movimientos -->
        <RecentEntries :entries="finance.recentEntries" />
      </template>
    </div>

    <!-- Modales -->
    <BaseModal :open="openModal === 'account'" title="Nueva cuenta" @close="close">
      <AccountForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'income'" title="Registrar ingreso" @close="close">
      <IncomeForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'expense'" title="Registrar gasto" @close="close">
      <ExpenseForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'credit-expense'" title="Cargo a tarjeta" @close="close">
      <CreditExpenseForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'pay-credit'" title="Pagar tarjeta" @close="close">
      <PayCreditForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'transfer'" title="Transferir entre cuentas" @close="close">
      <TransferForm @close="close" />
    </BaseModal>
    <BaseModal :open="openModal === 'shortcuts'" title="Atajos de teclado" @close="close">
      <ShortcutsHelp />
    </BaseModal>
    <BaseModal
      :open="openModal === 'edit-account'"
      :title="editingAccount ? `Editar ${editingAccount.name}` : 'Editar cuenta'"
      @close="close"
    >
      <AccountEditForm
        v-if="editingAccount"
        :account="editingAccount"
        @close="close"
      />
    </BaseModal>
    <BaseConfirm
      :open="openModal === 'delete-account'"
      :title="`Archivar ${deletingAccount?.name ?? 'cuenta'}`"
      message="Esta cuenta dejará de aparecer en el dashboard. Su historial seguirá visible en el registro de movimientos."
      confirm-label="Archivar"
      variant="danger"
      :loading="deletingState"
      @confirm="confirmDeleteAccount"
      @cancel="close"
    />
  </AppLayout>
</template>
