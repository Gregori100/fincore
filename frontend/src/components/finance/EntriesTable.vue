<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useRoute } from 'vue-router'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { financeApi } from '@/api/finance'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import CategoryBadge from '@/components/finance/CategoryBadge.vue'
import EntryEditForm from '@/components/finance/EntryEditForm.vue'
import { firstDayOfMonth, lastDayOfMonth, toISODate } from '@/utils/dates'
import { InboxIcon, ChevronLeftIcon, ChevronRightIcon, FunnelIcon, PencilSquareIcon, TrashIcon } from '@heroicons/vue/24/outline'

const props = defineProps({
  // Si está presente, fija el filtro de cuenta a este id (UUID) y oculta el
  // selector. Usado en /accounts/:uuid donde la tabla ya está acotada.
  accountId: { type: String, default: null },
  // Permite ocultar el selector de cuenta incluso sin accountId fijo (por
  // si en el futuro queremos mostrar la tabla sin ese filtro).
  showAccountFilter: { type: Boolean, default: true },
})

const finance = useFinanceStore()
const toast = useToastStore()

const KIND_LABELS = {
  income: 'Ingreso',
  expense: 'Gasto',
  credit_expense: 'Cargo crédito',
  debt_payment: 'Pago tarjeta',
  transfer: 'Transferencia',
  adjustment: 'Ajuste',
}

const KIND_COLORS = {
  income: 'text-[color:var(--color-positive)] bg-[color:var(--color-positive)]/10',
  expense: 'text-[color:var(--color-negative)] bg-[color:var(--color-negative)]/10',
  credit_expense: 'text-[color:var(--color-warning)] bg-[color:var(--color-warning)]/10',
  debt_payment: 'text-[color:var(--color-accent)] bg-[color:var(--color-accent)]/10',
  transfer: 'text-[color:var(--color-text-muted)] bg-[color:var(--color-surface-elevated)]',
  adjustment: 'text-[color:var(--color-text-muted)] bg-[color:var(--color-surface-elevated)]',
}

// Rango por default: mes en curso. El usuario rara vez quiere "toda la historia"
// como punto de partida; ver el mes actual es lo más común y se ajusta a mano.
const DEFAULT_FROM = firstDayOfMonth()
const DEFAULT_TO = lastDayOfMonth()

const filters = ref({
  account_id: null,
  category_id: null,
  kind: null,
  from: DEFAULT_FROM,
  to: DEFAULT_TO,
})

const editingEntry = ref(null)
const cancellingEntry = ref(null)
const cancellingState = ref(false)

const page = ref(1)
const data = ref({ data: [], current_page: 1, last_page: 1, total: 0, per_page: 25 })
const loading = ref(false)
const error = ref(null)

const showAccountSelector = computed(
  () => props.showAccountFilter && props.accountId === null,
)

const accountOptions = computed(() => [
  { value: null, label: 'Todas las cuentas' },
  ...finance.accounts.map((a) => ({ value: a.id, label: a.name })),
])

const categoryFilterOptions = computed(() => [
  { value: null, label: 'Todas las categorías' },
  ...finance.categories
    .filter((c) => !c.deleted_at)
    .map((c) => ({ value: c.id, label: c.name })),
])

const kindOptions = [
  { value: null, label: 'Todos los tipos' },
  ...Object.entries(KIND_LABELS).map(([value, label]) => ({ value, label })),
]

async function fetchEntries() {
  loading.value = true
  error.value = null
  try {
    const params = { page: page.value, per_page: 25 }
    // Si accountId está fijo (prop), prevalece sobre el filtro local.
    const effectiveAccountId = props.accountId ?? filters.value.account_id
    if (effectiveAccountId) params.account_id = effectiveAccountId
    if (filters.value.category_id) params.category_id = filters.value.category_id
    if (filters.value.kind) params.kind = filters.value.kind
    if (filters.value.from) params.from = filters.value.from
    if (filters.value.to) params.to = filters.value.to
    const response = await financeApi.entries(params)
    data.value = response.data
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudieron cargar los movimientos.')
  } finally {
    loading.value = false
  }
}

const route = useRoute()

// Precarga de filtros desde query params al montar. Usado por el drill-down
// de los reportes para abrir /entries ya filtrado a un bucket.
function applyQueryToFilters() {
  const q = route.query
  if (!q || !Object.keys(q).length) return
  if (q.account_id) filters.value.account_id = String(q.account_id)
  if (q.category_id) filters.value.category_id = String(q.category_id)
  if (q.kind) filters.value.kind = String(q.kind)
  if (q.from) filters.value.from = String(q.from)
  if (q.to) filters.value.to = String(q.to)
  // year_month es atajo del drill-down; aquí lo traducimos a from/to si no vinieron.
  // Usamos `toISODate` (local) para evitar el corrimiento de un día que `toISOString()`
  // introduce en zonas horarias positivas.
  if (q.year_month && !q.from && !q.to) {
    const [y, m] = String(q.year_month).split('-').map(Number)
    if (y && m) {
      filters.value.from = toISODate(new Date(y, m - 1, 1))
      filters.value.to = toISODate(new Date(y, m, 0))
    }
  }
}

onMounted(async () => {
  applyQueryToFilters()
  if (!finance.accounts.length) {
    try {
      await finance.fetchState()
    } catch {
      // El interceptor 401 redirige solo si la auth falla.
    }
  }
  await fetchEntries()
})

// Reset a página 1 cada vez que cambia un filtro local.
watch(
  () => [
    filters.value.account_id,
    filters.value.category_id,
    filters.value.kind,
    filters.value.from,
    filters.value.to,
  ],
  () => {
    page.value = 1
    fetchEntries()
  },
)

// Si cambia el accountId fijo (navegando entre detalles), recargar.
watch(
  () => props.accountId,
  () => {
    page.value = 1
    fetchEntries()
  },
)

function changePage(p) {
  if (p < 1 || p > data.value.last_page || p === page.value) return
  page.value = p
  fetchEntries()
}

function clearFilters() {
  // "Limpiar" vuelve al rango default (mes en curso), no a vacío. Si el usuario
  // realmente quiere ver toda la historia, borra a mano los inputs de fecha.
  filters.value = {
    account_id: null,
    category_id: null,
    kind: null,
    from: DEFAULT_FROM,
    to: DEFAULT_TO,
  }
}

async function onEditSuccess() {
  await fetchEntries()
}

async function confirmCancel() {
  if (!cancellingEntry.value) return
  const id = cancellingEntry.value.id
  cancellingState.value = true
  try {
    await finance.cancelEntry(id)
    toast.success('Movimiento cancelado')
    cancellingEntry.value = null
    await fetchEntries()
  } catch (e) {
    const status = e.response?.status
    if (status === 404) {
      // Otro tab ya lo canceló — sólo refrescamos.
      toast.error('Ese movimiento ya no existe.')
      cancellingEntry.value = null
      await fetchEntries()
    } else {
      const payload = e.response?.data
      toast.error(payload?.error ?? 'No se pudo cancelar el movimiento')
    }
  } finally {
    cancellingState.value = false
  }
}

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function fmtDate(d) {
  if (!d) return ''
  return new Date(d).toLocaleString('es-MX', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

const hasActiveFilters = computed(
  () =>
    filters.value.account_id !== null
    || filters.value.category_id !== null
    || filters.value.kind !== null
    || filters.value.from !== DEFAULT_FROM
    || filters.value.to !== DEFAULT_TO,
)
</script>

<template>
  <div class="space-y-4">
    <!-- Filtros -->
    <section
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4"
    >
      <div class="flex items-center justify-between mb-3">
        <p class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] flex items-center gap-2">
          <FunnelIcon class="h-3.5 w-3.5" />
          Filtros
        </p>
        <button
          v-if="hasActiveFilters"
          type="button"
          class="text-xs text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
          @click="clearFilters"
        >
          Limpiar
        </button>
      </div>
      <div
        class="grid grid-cols-1 gap-3"
        :class="showAccountSelector ? 'sm:grid-cols-2 lg:grid-cols-5' : 'sm:grid-cols-2 lg:grid-cols-4'"
      >
        <BaseSelect
          v-if="showAccountSelector"
          v-model="filters.account_id"
          label="Cuenta"
          :options="accountOptions"
        />
        <BaseSelect v-model="filters.category_id" label="Categoría" :options="categoryFilterOptions" />
        <BaseSelect v-model="filters.kind" label="Tipo" :options="kindOptions" />
        <BaseInput v-model="filters.from" type="date" label="Desde" />
        <BaseInput v-model="filters.to" type="date" label="Hasta" />
      </div>
    </section>

    <!-- Tabla -->
    <section
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl overflow-hidden"
    >
      <div v-if="loading" class="p-4 space-y-2" aria-busy="true">
        <BaseSkeleton v-for="n in 6" :key="n" height="h-10" rounded="rounded-md" />
      </div>

      <div v-else-if="error" class="py-12 text-center">
        <p class="text-sm text-[color:var(--color-negative)]">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-3" @click="fetchEntries">Reintentar</BaseButton>
      </div>

      <div v-else-if="!data.data.length" class="py-12 text-center">
        <InboxIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          No hay movimientos con esos filtros.
        </p>
        <p v-if="hasActiveFilters" class="text-xs text-[color:var(--color-text-subtle)] mt-1">
          Intenta limpiar los filtros para ver el historial completo.
        </p>
      </div>

      <template v-else>
        <!-- Tabla densa: tablets en horizontal y desktop. -->
        <table class="hidden md:table w-full text-sm">
          <thead class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em] border-b border-[color:var(--color-border)]">
            <tr>
              <th class="text-left px-4 py-3 font-semibold">Tipo</th>
              <th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Categoría</th>
              <th class="text-left px-4 py-3 font-semibold">Movimiento</th>
              <th class="text-left px-4 py-3 font-semibold hidden md:table-cell">Descripción</th>
              <th class="text-right px-4 py-3 font-semibold">Monto</th>
              <th class="text-right px-4 py-3 font-semibold hidden sm:table-cell">Fecha</th>
              <th class="w-10 px-2"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="e in data.data"
              :key="e.id"
              class="group border-b border-[color:var(--color-border)] last:border-0 hover:bg-[color:var(--color-surface-elevated)]/40 transition-colors"
            >
              <td class="px-4 py-3">
                <span
                  class="inline-block px-2 py-0.5 rounded text-xs font-medium"
                  :class="KIND_COLORS[e.kind]"
                >
                  {{ KIND_LABELS[e.kind] ?? e.kind }}
                </span>
              </td>
              <td class="px-4 py-3 hidden lg:table-cell">
                <CategoryBadge v-if="e.category" :category="e.category" />
                <span v-else class="text-[color:var(--color-text-subtle)]">—</span>
              </td>
              <td class="px-4 py-3">
                <span class="text-[color:var(--color-text-muted)]">
                  {{ e.origin?.name ?? '—' }}
                  <span
                    v-if="e.origin?.deleted_at"
                    class="ml-1 text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]"
                  >
                    (archivada)
                  </span>
                </span>
                <span class="text-[color:var(--color-text-subtle)] mx-1.5">→</span>
                <span class="text-[color:var(--color-text-muted)]">
                  {{ e.destination?.name ?? '—' }}
                  <span
                    v-if="e.destination?.deleted_at"
                    class="ml-1 text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]"
                  >
                    (archivada)
                  </span>
                </span>
              </td>
              <td class="px-4 py-3 text-[color:var(--color-text-muted)] hidden md:table-cell max-w-xs truncate">
                {{ e.description ?? '—' }}
              </td>
              <td class="px-4 py-3 text-right font-medium tabular-nums">
                {{ fmt(e.amount) }}
              </td>
              <td class="px-4 py-3 text-right text-xs text-[color:var(--color-text-subtle)] hidden sm:table-cell whitespace-nowrap">
                {{ fmtDate(e.occurred_at) }}
              </td>
              <td class="px-2 py-3 text-right">
                <div class="flex items-center justify-end gap-1 sm:opacity-0 sm:group-hover:opacity-100 focus-within:opacity-100 transition">
                  <button
                    type="button"
                    class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-accent)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] transition"
                    aria-label="Editar movimiento"
                    title="Editar categoría o descripción"
                    @click="editingEntry = e"
                  >
                    <PencilSquareIcon class="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-negative)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-negative)] transition"
                    aria-label="Cancelar movimiento"
                    title="Cancelar este movimiento"
                    @click="cancellingEntry = e"
                  >
                    <TrashIcon class="h-4 w-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- Cards verticales: mobile (<md). Cada entry es una card propia. -->
        <ul class="md:hidden divide-y divide-[color:var(--color-border)]">
          <li
            v-for="e in data.data"
            :key="e.id"
            class="px-4 py-3 space-y-2"
          >
            <div class="flex items-center justify-between gap-2 flex-wrap">
              <span
                class="inline-block px-2 py-0.5 rounded text-xs font-medium"
                :class="KIND_COLORS[e.kind]"
              >
                {{ KIND_LABELS[e.kind] ?? e.kind }}
              </span>
              <CategoryBadge v-if="e.category" :category="e.category" />
            </div>

            <p class="text-sm text-[color:var(--color-text-muted)]">
              <span>
                {{ e.origin?.name ?? '—' }}
                <span
                  v-if="e.origin?.deleted_at"
                  class="text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]"
                >
                  (arch.)
                </span>
              </span>
              <span class="text-[color:var(--color-text-subtle)] mx-1.5">→</span>
              <span>
                {{ e.destination?.name ?? '—' }}
                <span
                  v-if="e.destination?.deleted_at"
                  class="text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]"
                >
                  (arch.)
                </span>
              </span>
            </p>

            <p
              v-if="e.description"
              class="text-xs text-[color:var(--color-text-subtle)] truncate"
            >
              {{ e.description }}
            </p>

            <div class="flex items-end justify-between gap-2 pt-1">
              <div>
                <p class="text-base font-semibold tabular-nums">{{ fmt(e.amount) }}</p>
                <p class="text-[11px] text-[color:var(--color-text-subtle)] mt-0.5 whitespace-nowrap">
                  {{ fmtDate(e.occurred_at) }}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  class="p-1.5 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-accent)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] transition"
                  aria-label="Editar movimiento"
                  @click="editingEntry = e"
                >
                  <PencilSquareIcon class="h-4 w-4" />
                </button>
                <button
                  type="button"
                  class="p-1.5 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-negative)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-negative)] transition"
                  aria-label="Cancelar movimiento"
                  @click="cancellingEntry = e"
                >
                  <TrashIcon class="h-4 w-4" />
                </button>
              </div>
            </div>
          </li>
        </ul>
      </template>

      <footer
        v-if="!loading && !error && data.data.length"
        class="flex items-center justify-between px-4 py-3 border-t border-[color:var(--color-border)] text-sm"
      >
        <p class="text-[color:var(--color-text-muted)]">
          Página <span class="text-[color:var(--color-text-primary)] font-medium">{{ data.current_page }}</span>
          de <span class="text-[color:var(--color-text-primary)] font-medium">{{ data.last_page }}</span>
          <span class="text-[color:var(--color-text-subtle)] hidden sm:inline">
            · {{ data.total }} movimientos en total
          </span>
        </p>
        <div class="flex gap-1">
          <button
            type="button"
            class="p-1.5 rounded border border-[color:var(--color-border)] hover:border-[color:var(--color-accent)] disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:border-[color:var(--color-border)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
            :disabled="data.current_page <= 1"
            aria-label="Página anterior"
            @click="changePage(data.current_page - 1)"
          >
            <ChevronLeftIcon class="h-4 w-4" />
          </button>
          <button
            type="button"
            class="p-1.5 rounded border border-[color:var(--color-border)] hover:border-[color:var(--color-accent)] disabled:opacity-40 disabled:cursor-not-allowed disabled:hover:border-[color:var(--color-border)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
            :disabled="data.current_page >= data.last_page"
            aria-label="Página siguiente"
            @click="changePage(data.current_page + 1)"
          >
            <ChevronRightIcon class="h-4 w-4" />
          </button>
        </div>
      </footer>
    </section>

    <BaseModal
      :open="editingEntry !== null"
      title="Editar movimiento"
      @close="editingEntry = null"
    >
      <EntryEditForm
        v-if="editingEntry"
        :entry="editingEntry"
        @close="editingEntry = null"
        @success="onEditSuccess"
      />
    </BaseModal>

    <BaseConfirm
      :open="cancellingEntry !== null"
      title="Cancelar movimiento"
      message="El movimiento se eliminará del historial y el saldo de la cuenta se recalculará. Esta acción no se puede deshacer."
      confirm-label="Cancelar movimiento"
      variant="danger"
      :loading="cancellingState"
      @confirm="confirmCancel"
      @cancel="cancellingEntry = null"
    />
  </div>
</template>
