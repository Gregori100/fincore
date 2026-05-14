<script setup>
import { onMounted, ref, computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import AccountEditForm from '@/components/finance/AccountEditForm.vue'
import EntriesTable from '@/components/finance/EntriesTable.vue'
import { PencilSquareIcon, ArchiveBoxXMarkIcon, LockClosedIcon } from '@heroicons/vue/20/solid'

const route = useRoute()
const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()

const account = ref(null)
const loading = ref(false)
const notFound = ref(false)
const openModal = ref(null)
const deletingState = ref(false)

const TYPE_LABEL = {
  cash: 'Efectivo',
  debit: 'Débito',
  credit: 'Crédito',
}

const TYPE_COLOR = {
  cash: 'text-[color:var(--color-positive)]',
  debit: 'text-[color:var(--color-accent)]',
  credit: 'text-[color:var(--color-warning)]',
}

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function fmtPct(n) {
  if (n === null || n === undefined || n === '') return '—'
  return `${(Number(n) * 100).toFixed(2)}%`
}

const isArchived = computed(() => Boolean(account.value?.deleted_at))
const isCredit = computed(() => account.value?.type === 'credit')
const isProtected = computed(() => Boolean(account.value?.is_protected))
const canEdit = computed(() => account.value && !isProtected.value && !isArchived.value)
const canArchive = computed(() => canEdit.value && Math.abs(Number(account.value?.balance ?? 0)) <= 0.005)

async function fetchAccount() {
  const uuid = route.params.uuid
  loading.value = true
  notFound.value = false
  try {
    const { data } = await financeApi.accounts({ includeArchived: true })
    const found = (data.accounts ?? []).find((a) => a.id === uuid)
    if (!found) {
      notFound.value = true
      account.value = null
    } else {
      account.value = found
    }
  } catch {
    notFound.value = true
    account.value = null
  } finally {
    loading.value = false
  }
}

function close() {
  openModal.value = null
}

function handleEdit() {
  openModal.value = 'edit-account'
}

function handleDelete() {
  if (!canArchive.value) {
    const balance = Number(account.value?.balance ?? 0)
    toast.error(
      isCredit.value
        ? `Esta tarjeta tiene deuda de ${fmt(balance)}. Págala antes de archivar.`
        : `Esta cuenta tiene saldo de ${fmt(balance)}. Transfiérelo o gástalo antes de archivar.`,
    )
    return
  }
  openModal.value = 'delete-account'
}

async function confirmDelete() {
  deletingState.value = true
  try {
    await finance.deleteAccount(account.value.id)
    toast.success(`Cuenta "${account.value.name}" archivada`)
    openModal.value = null
    await fetchAccount()
  } catch (e) {
    const status = e.response?.status
    const payload = e.response?.data
    if (status === 404) {
      toast.error('La cuenta ya no existe.')
      openModal.value = null
      await fetchAccount()
    } else {
      toast.error(payload?.error ?? 'No se pudo archivar la cuenta')
    }
  } finally {
    deletingState.value = false
  }
}

async function onEditSuccess() {
  await fetchAccount()
}

onMounted(fetchAccount)
watch(() => route.params.uuid, fetchAccount)
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header>
        <RouterLink
          :to="{ name: 'accounts' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition inline-flex items-center gap-1"
        >
          ← Mis cuentas
        </RouterLink>
      </header>

      <!-- Loading -->
      <div v-if="loading && !account" class="space-y-4">
        <BaseSkeleton height="h-16" rounded="rounded-xl" />
        <BaseSkeleton height="h-48" rounded="rounded-xl" />
      </div>

      <!-- Not found -->
      <div
        v-else-if="notFound"
        class="rounded-xl border border-[color:var(--color-border)] p-12 text-center"
      >
        <p class="font-medium">Cuenta no encontrada</p>
        <p class="text-sm text-[color:var(--color-text-muted)] mt-1">
          La cuenta que buscas no existe o no tienes acceso a ella.
        </p>
        <RouterLink
          :to="{ name: 'accounts' }"
          class="inline-block mt-4 text-sm text-[color:var(--color-accent)] hover:underline"
        >
          Volver a mis cuentas
        </RouterLink>
      </div>

      <!-- Contenido -->
      <template v-else-if="account">
        <!-- Card principal con metadata -->
        <section
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-6"
          :class="isArchived && 'opacity-80'"
        >
          <div class="flex items-start justify-between gap-4 flex-wrap">
            <div class="min-w-0 flex-1">
              <h1 class="text-2xl font-semibold tracking-tight flex items-center gap-2 flex-wrap">
                {{ account.name }}
                <LockClosedIcon
                  v-if="isProtected"
                  class="h-4 w-4 text-[color:var(--color-text-subtle)]"
                  title="Cuenta protegida"
                />
                <span
                  v-if="isArchived"
                  class="text-xs font-medium tracking-normal text-[color:var(--color-text-muted)] bg-[color:var(--color-surface-elevated)] px-2 py-0.5 rounded"
                >
                  archivada
                </span>
              </h1>
              <p class="text-xs uppercase tracking-[0.08em] font-semibold mt-1" :class="TYPE_COLOR[account.type]">
                {{ TYPE_LABEL[account.type] ?? account.type }}
              </p>
              <p class="text-3xl font-semibold tabular-nums tracking-tight mt-4">
                {{ fmt(account.balance) }}
              </p>
              <p v-if="isCredit" class="text-sm text-[color:var(--color-text-muted)] mt-1">
                Deuda actual ·
                <span class="text-[color:var(--color-accent)]">
                  Disponible {{ fmt(account.available_credit) }}
                </span>
              </p>
            </div>

            <div v-if="canEdit" class="flex items-center gap-2">
              <BaseButton variant="secondary" @click="handleEdit">
                <PencilSquareIcon class="h-4 w-4" />
                Editar
              </BaseButton>
              <BaseButton
                variant="danger"
                :disabled="!canArchive"
                :title="canArchive ? '' : 'La cuenta debe tener balance 0 para archivarse'"
                @click="handleDelete"
              >
                <ArchiveBoxXMarkIcon class="h-4 w-4" />
                Archivar
              </BaseButton>
            </div>
          </div>

          <!-- Metadata de crédito -->
          <div
            v-if="isCredit"
            class="mt-6 pt-6 border-t border-[color:var(--color-border)] grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm"
          >
            <div>
              <p class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em]">Límite</p>
              <p class="font-medium tabular-nums mt-0.5">{{ fmt(account.credit_limit) }}</p>
            </div>
            <div>
              <p class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em]">Día corte</p>
              <p class="font-medium tabular-nums mt-0.5">{{ account.closing_day ?? '—' }}</p>
            </div>
            <div>
              <p class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em]">Día pago</p>
              <p class="font-medium tabular-nums mt-0.5">{{ account.payment_day ?? '—' }}</p>
            </div>
            <div>
              <p class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em]">Tasa mensual</p>
              <p class="font-medium tabular-nums mt-0.5">{{ fmtPct(account.interest_rate) }}</p>
            </div>
          </div>

          <!-- Descripción -->
          <div
            v-if="account.description"
            class="mt-6 pt-6 border-t border-[color:var(--color-border)]"
          >
            <p class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em] mb-1">Descripción</p>
            <p class="text-sm text-[color:var(--color-text-muted)] whitespace-pre-wrap">
              {{ account.description }}
            </p>
          </div>
        </section>

        <!-- Movimientos -->
        <section>
          <h2 class="text-lg font-medium mb-3">Movimientos de esta cuenta</h2>
          <EntriesTable :account-id="account.id" />
        </section>
      </template>
    </div>

    <BaseModal
      :open="openModal === 'edit-account'"
      :title="account ? `Editar ${account.name}` : 'Editar cuenta'"
      @close="close"
    >
      <AccountEditForm
        v-if="account"
        :account="account"
        @close="close"
        @success="onEditSuccess"
      />
    </BaseModal>
    <BaseConfirm
      :open="openModal === 'delete-account'"
      :title="`Archivar ${account?.name ?? 'cuenta'}`"
      message="Esta cuenta dejará de aparecer en el dashboard. Su historial seguirá visible."
      confirm-label="Archivar"
      variant="danger"
      :loading="deletingState"
      @confirm="confirmDelete"
      @cancel="close"
    />
  </AppLayout>
</template>
