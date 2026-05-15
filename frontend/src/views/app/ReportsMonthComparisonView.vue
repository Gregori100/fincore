<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import MonthComparisonList from '@/components/finance/MonthComparisonList.vue'
import { currentYearMonth, formatYearMonth, previousYearMonth } from '@/utils/dates'
import { ArrowsRightLeftIcon } from '@heroicons/vue/24/outline'

const finance = useFinanceStore()

const kind = ref('expense') // 'expense' | 'income'
const accountId = ref(null)
const month = ref(currentYearMonth())

const data = ref({
  current_month: month.value,
  previous_month: previousYearMonth(month.value),
  current_total: 0,
  previous_total: 0,
  delta: 0,
  delta_pct: null,
  buckets: [],
})
const loading = ref(false)
const error = ref(null)

const accountOptions = computed(() => [
  { value: null, label: 'Todas las cuentas' },
  ...finance.accounts.map((a) => ({ value: a.id, label: a.name })),
])

const kindLabel = computed(() => kind.value === 'expense' ? 'Gastos' : 'Ingresos')
const currentLabel = computed(() => formatYearMonth(data.value.current_month))
const previousLabel = computed(() => formatYearMonth(data.value.previous_month))

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function fmtSigned(n) {
  const abs = fmt(Math.abs(n))
  if (n > 0) return `+${abs}`
  if (n < 0) return `-${abs}`
  return abs
}

// Colores semánticos del delta total para el Hero (mismas reglas que la lista).
const deltaTone = computed(() => {
  const d = Number(data.value.delta)
  if (d === 0) return 'text-[color:var(--color-text-muted)]'
  const positive = kind.value === 'expense' ? 'text-[color:var(--color-negative)]' : 'text-[color:var(--color-positive)]'
  const negative = kind.value === 'expense' ? 'text-[color:var(--color-positive)]' : 'text-[color:var(--color-negative)]'
  return d > 0 ? positive : negative
})

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const params = { kind: kind.value, month: month.value }
    if (accountId.value) params.account_id = accountId.value
    const { data: payload } = await financeApi.reportMonthComparison(params)
    data.value = payload
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudo cargar el comparativo.')
  } finally {
    loading.value = false
  }
}

watch([kind, accountId, month], fetchReport)

onMounted(async () => {
  if (!finance.accounts.length) {
    try {
      await finance.fetchState()
    } catch {
      // 401 lo redirige el interceptor.
    }
  }
  await fetchReport()
})
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Reportes</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Comparativo de este mes contra el mes pasado
          </p>
        </div>
        <RouterLink
          :to="{ name: 'dashboard' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
        >
          ← Dashboard
        </RouterLink>
      </header>

      <!-- Subnav entre reportes (3 tabs) -->
      <nav class="flex items-center gap-2 text-sm border-b border-[color:var(--color-border)] pb-2">
        <RouterLink
          :to="{ name: 'reports-by-category' }"
          class="px-3 py-1.5 rounded-md transition text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]"
          active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
        >
          Por categoría
        </RouterLink>
        <RouterLink
          :to="{ name: 'reports-cashflow' }"
          class="px-3 py-1.5 rounded-md transition text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]"
          active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
        >
          Cashflow
        </RouterLink>
        <RouterLink
          :to="{ name: 'reports-month-comparison' }"
          class="px-3 py-1.5 rounded-md transition text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]"
          active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
        >
          Comparativo
        </RouterLink>
        <RouterLink
          :to="{ name: 'reports-credit-cards' }"
          class="px-3 py-1.5 rounded-md transition text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]"
          active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
        >
          Tarjetas
        </RouterLink>
      </nav>

      <!-- Filtros -->
      <section class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4 space-y-4">
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="px-3 py-1.5 rounded text-sm font-medium border transition"
            :class="kind === 'expense'
              ? 'bg-[color:var(--color-negative)]/15 border-[color:var(--color-negative)]/50 text-[color:var(--color-negative)]'
              : 'border-[color:var(--color-border)] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]'"
            @click="kind = 'expense'"
          >
            Gastos
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded text-sm font-medium border transition"
            :class="kind === 'income'
              ? 'bg-[color:var(--color-positive)]/15 border-[color:var(--color-positive)]/50 text-[color:var(--color-positive)]'
              : 'border-[color:var(--color-border)] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]'"
            @click="kind = 'income'"
          >
            Ingresos
          </button>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 items-end">
          <BaseSelect v-model="accountId" label="Cuenta" :options="accountOptions" />
        </div>
      </section>

      <!-- Hero -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            {{ currentLabel }} · {{ kindLabel }}
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            {{ fmt(data.current_total) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            {{ previousLabel }}
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-text-muted)]">
            {{ fmt(data.previous_total) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Delta
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight" :class="deltaTone">
            {{ fmtSigned(data.delta) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Cambio
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight" :class="deltaTone">
            <template v-if="data.delta_pct !== null && data.delta_pct !== undefined">
              {{ data.delta_pct > 0 ? '+' : '' }}{{ data.delta_pct.toFixed(1) }}%
            </template>
            <template v-else>—</template>
          </p>
          <p class="mt-1.5 text-xs text-[color:var(--color-text-muted)]">
            vs {{ previousLabel }}
          </p>
        </article>
      </section>

      <!-- Loading / Error / Vacío / Lista -->
      <div v-if="loading && !data.buckets.length">
        <BaseSkeleton height="h-64" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
      </div>

      <div
        v-else-if="!data.buckets.length"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <ArrowsRightLeftIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          No hay movimientos en {{ currentLabel }} ni en {{ previousLabel }}.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
          Cambia el tipo o registra movimientos para ver el comparativo.
        </p>
      </div>

      <section
        v-else
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-6"
      >
        <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-2">
          Detalle por categoría (ordenado por cambio absoluto)
        </h3>
        <MonthComparisonList :buckets="data.buckets" :kind="kind" />
      </section>
    </div>
  </AppLayout>
</template>
