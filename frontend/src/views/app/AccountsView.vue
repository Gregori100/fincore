<script setup>
import { onMounted, ref, computed } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import AccountCard from '@/components/finance/AccountCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import AccountForm from '@/components/finance/AccountForm.vue'
import AccountEditForm from '@/components/finance/AccountEditForm.vue'
import { PlusIcon, ArchiveBoxIcon, MagnifyingGlassIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()

// Lista local: incluye activas y archivadas (la del store sólo trae activas).
const allAccounts = ref([])
const loading = ref(false)
const error = ref(null)
const openModal = ref(null)
const editingAccount = ref(null)
const deletingAccount = ref(null)
const deletingState = ref(false)
const searchQuery = ref('')

function fmtMxn(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
  }).format(Number(n ?? 0))
}

// Filtro por nombre case-insensitive. También busca en description si existe.
const filteredAccounts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return allAccounts.value
  return allAccounts.value.filter((a) => {
    const name = (a.name ?? '').toLowerCase()
    const description = (a.description ?? '').toLowerCase()
    return name.includes(q) || description.includes(q)
  })
})

const activeAccounts = computed(() =>
  filteredAccounts.value.filter((a) => !a.deleted_at),
)
const archivedAccounts = computed(() =>
  filteredAccounts.value.filter((a) => a.deleted_at),
)
const hasResults = computed(
  () => activeAccounts.value.length > 0 || archivedAccounts.value.length > 0,
)

async function fetchAll() {
  loading.value = true
  error.value = null
  try {
    const { data } = await financeApi.accounts({ includeArchived: true })
    allAccounts.value = data.accounts ?? []
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudieron cargar las cuentas.')
  } finally {
    loading.value = false
  }
}

function close() {
  openModal.value = null
}

function handleEdit(account) {
  editingAccount.value = account
  openModal.value = 'edit-account'
}

function handleDelete(account) {
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

async function confirmDelete() {
  if (!deletingAccount.value) return
  deletingState.value = true
  try {
    await finance.deleteAccount(deletingAccount.value.id)
    toast.success(`Cuenta "${deletingAccount.value.name}" archivada`)
    openModal.value = null
    deletingAccount.value = null
    await fetchAll()
  } catch (e) {
    const status = e.response?.status
    const payload = e.response?.data
    if (status === 404) {
      toast.error('La cuenta ya no existe.')
      openModal.value = null
      deletingAccount.value = null
      await fetchAll()
    } else {
      toast.error(payload?.error ?? 'No se pudo archivar la cuenta')
    }
  } finally {
    deletingState.value = false
  }
}

async function onMutationSuccess() {
  // AccountForm/AccountEditForm ya llaman a finance.fetchState() — sólo
  // necesitamos resincronizar la lista local con archivadas incluidas.
  await fetchAll()
}

onMounted(async () => {
  // Carga inicial del store si el dashboard nunca cargó (atajo directo a /accounts).
  if (!finance.accounts.length) {
    try {
      await finance.fetchState()
    } catch {
      // El interceptor 401 redirige solo.
    }
  }
  await fetchAll()
})
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Mis cuentas</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Todas tus cuentas, activas y archivadas
          </p>
        </div>
        <div class="flex items-center gap-3">
          <RouterLink
            :to="{ name: 'dashboard' }"
            class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
          >
            ← Dashboard
          </RouterLink>
          <BaseButton
            variant="secondary"
            :disabled="!auth.isVerified"
            :title="auth.isVerified ? '' : 'Verifica tu email primero'"
            @click="openModal = 'account'"
          >
            <PlusIcon class="h-4 w-4" />
            Nueva cuenta
          </BaseButton>
        </div>
      </header>

      <!-- Loading -->
      <div v-if="loading && !allAccounts.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <BaseSkeleton v-for="n in 6" :key="n" height="h-32" rounded="rounded-xl" />
      </div>

      <!-- Error -->
      <div
        v-else-if="error && !allAccounts.length"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm text-[color:var(--color-text-primary)]">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchAll">Reintentar</BaseButton>
      </div>

      <template v-else>
        <!-- Búsqueda: aparece solo si hay suficientes cuentas para que importe -->
        <div v-if="allAccounts.length > 3" class="relative max-w-md">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[color:var(--color-text-subtle)] pointer-events-none" />
          <input
            v-model="searchQuery"
            type="search"
            placeholder="Buscar por nombre o descripción..."
            class="w-full pl-9 pr-3 py-2 rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] text-[color:var(--color-text-primary)] placeholder:text-[color:var(--color-text-subtle)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] focus-visible:border-transparent transition text-sm"
          />
        </div>

        <!-- Sin resultados -->
        <div
          v-if="searchQuery && !hasResults"
          class="rounded-xl border border-[color:var(--color-border)] p-8 text-center"
        >
          <p class="text-sm text-[color:var(--color-text-muted)]">
            Ninguna cuenta coincide con
            <span class="text-[color:var(--color-text-primary)] font-medium">"{{ searchQuery }}"</span>
          </p>
        </div>

        <!-- Activas -->
        <section v-if="activeAccounts.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3">
            Activas <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ activeAccounts.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <AccountCard
              v-for="a in activeAccounts"
              :key="a.id"
              :account="a"
              linkable
              @edit="handleEdit"
              @delete="handleDelete"
            />
          </div>
        </section>

        <!-- Archivadas -->
        <section v-if="archivedAccounts.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3 flex items-center gap-2">
            <ArchiveBoxIcon class="h-3.5 w-3.5" />
            Archivadas <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ archivedAccounts.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <AccountCard
              v-for="a in archivedAccounts"
              :key="a.id"
              :account="a"
              linkable
            />
          </div>
        </section>
      </template>
    </div>

    <BaseModal :open="openModal === 'account'" title="Nueva cuenta" @close="close">
      <AccountForm @close="close" @success="onMutationSuccess" />
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
        @success="onMutationSuccess"
      />
    </BaseModal>
    <BaseConfirm
      :open="openModal === 'delete-account'"
      :title="`Archivar ${deletingAccount?.name ?? 'cuenta'}`"
      message="Esta cuenta dejará de aparecer en el dashboard. Su historial seguirá visible en el registro de movimientos."
      confirm-label="Archivar"
      variant="danger"
      :loading="deletingState"
      @confirm="confirmDelete"
      @cancel="close"
    />
  </AppLayout>
</template>
