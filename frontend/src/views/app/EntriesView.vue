<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import { InboxIcon, ChevronLeftIcon, ChevronRightIcon, FunnelIcon } from '@heroicons/vue/24/outline'

const finance = useFinanceStore()
const toast = useToastStore()

// Aseguramos que la lista de cuentas esté disponible para el filtro.
onMounted(async () => {
  if (!finance.accounts.length) {
    try {
      await finance.fetchState()
    } catch {
      // El error se muestra dentro de la vista, pero si la auth global falla
      // el interceptor 401 redirige solo.
    }
  }
  await fetchEntries()
})

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

const filters = ref({
  account_id: null,
  kind: null,
  from: '',
  to: '',
})

const page = ref(1)
const data = ref({ data: [], current_page: 1, last_page: 1, total: 0, per_page: 25 })
const loading = ref(false)
const error = ref(null)

const accountOptions = computed(() => [
  { value: null, label: 'Todas las cuentas' },
  ...finance.accounts.map((a) => ({ value: a.id, label: a.name })),
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
    if (filters.value.account_id) params.account_id = filters.value.account_id
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

// Reset a página 1 cada vez que cambia un filtro.
watch(
  () => [filters.value.account_id, filters.value.kind, filters.value.from, filters.value.to],
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
  filters.value = { account_id: null, kind: null, from: '', to: '' }
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
    || filters.value.kind !== null
    || filters.value.from
    || filters.value.to,
)
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Historial de movimientos</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Filtra y revisa todas tus pólizas
          </p>
        </div>
        <RouterLink
          :to="{ name: 'dashboard' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
        >
          ← Volver al dashboard
        </RouterLink>
      </header>

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
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <BaseSelect v-model="filters.account_id" label="Cuenta" :options="accountOptions" />
          <BaseSelect v-model="filters.kind" label="Tipo" :options="kindOptions" />
          <BaseInput v-model="filters.from" type="date" label="Desde" />
          <BaseInput v-model="filters.to" type="date" label="Hasta" />
        </div>
      </section>

      <!-- Tabla -->
      <section
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl overflow-hidden"
      >
        <!-- Loading -->
        <div v-if="loading" class="p-4 space-y-2" aria-busy="true">
          <BaseSkeleton v-for="n in 6" :key="n" height="h-10" rounded="rounded-md" />
        </div>

        <!-- Error -->
        <div v-else-if="error" class="py-12 text-center">
          <p class="text-sm text-[color:var(--color-negative)]">{{ error }}</p>
          <BaseButton variant="secondary" class="mt-3" @click="fetchEntries">Reintentar</BaseButton>
        </div>

        <!-- Vacío -->
        <div v-else-if="!data.data.length" class="py-12 text-center">
          <InboxIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
          <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
            No hay movimientos con esos filtros.
          </p>
          <p v-if="hasActiveFilters" class="text-xs text-[color:var(--color-text-subtle)] mt-1">
            Intenta limpiar los filtros para ver el historial completo.
          </p>
        </div>

        <!-- Tabla con datos -->
        <table v-else class="w-full text-sm">
          <thead class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-[0.08em] border-b border-[color:var(--color-border)]">
            <tr>
              <th class="text-left px-4 py-3 font-semibold">Tipo</th>
              <th class="text-left px-4 py-3 font-semibold">Movimiento</th>
              <th class="text-left px-4 py-3 font-semibold hidden md:table-cell">Descripción</th>
              <th class="text-right px-4 py-3 font-semibold">Monto</th>
              <th class="text-right px-4 py-3 font-semibold hidden sm:table-cell">Fecha</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="e in data.data"
              :key="e.id"
              class="border-b border-[color:var(--color-border)] last:border-0 hover:bg-[color:var(--color-surface-elevated)]/40 transition-colors"
            >
              <td class="px-4 py-3">
                <span
                  class="inline-block px-2 py-0.5 rounded text-xs font-medium"
                  :class="KIND_COLORS[e.kind]"
                >
                  {{ KIND_LABELS[e.kind] ?? e.kind }}
                </span>
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
            </tr>
          </tbody>
        </table>

        <!-- Paginación -->
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
    </div>
  </AppLayout>
</template>
