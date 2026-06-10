<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import CategoryBreakdownChart from '@/components/finance/CategoryBreakdownChart.vue'
import CategoryBreakdownList from '@/components/finance/CategoryBreakdownList.vue'
import DateRangePreset from '@/components/finance/DateRangePreset.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import ExcelExportButton from '@/components/finance/ExcelExportButton.vue'
import ReportHero from '@/components/finance/ReportHero.vue'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import { firstDayOfMonth, toISODate, weeksInRange } from '@/utils/dates'
import { ChartPieIcon } from '@heroicons/vue/24/outline'

const finance = useFinanceStore()

// Filtros locales — el reporte cambia seguido y no vale persistirlo en el store.
const filters = ref({
  kind: 'expense', // 'expense' | 'income'
  account_id: null,
  from: firstDayOfMonth(),
  to: toISODate(),
})

const data = ref({ total: 0, count: 0, buckets: [] })
const loading = ref(false)
const error = ref(null)

const drillOpen = ref(false)
const drillFilters = ref({})

function openDrilldown(bucket) {
  drillFilters.value = {
    kind: filters.value.kind,
    category_id: bucket.category_id ?? null,
    account_id: filters.value.account_id ?? null,
    from: filters.value.from,
    to: filters.value.to,
  }
  drillOpen.value = true
}

const kindLabel = computed(() => filters.value.kind === 'expense' ? 'Gastos' : 'Ingresos')
const periodLabel = computed(() => `${filters.value.from} → ${filters.value.to}`)

const accountOptions = computed(() => [
  { value: null, label: 'Todas las cuentas' },
  ...finance.accounts.map((a) => ({ value: a.id, label: a.name })),
])

const weeklyAverage = computed(() => {
  const weeks = weeksInRange(filters.value.from, filters.value.to)
  return weeks > 0 ? data.value.total / weeks : 0
})

// Para la dona: top 6 + "Otras". La lista detallada al lado muestra todos.
const TOP_N = 6
const chartBuckets = computed(() => {
  const sorted = [...data.value.buckets].sort((a, b) => Number(b.total) - Number(a.total))
  if (sorted.length <= TOP_N) return sorted
  const top = sorted.slice(0, TOP_N)
  const restTotal = sorted.slice(TOP_N).reduce((acc, b) => acc + Number(b.total), 0)
  return [
    ...top,
    { category_id: '__others__', name: 'Otras', color_slug: null, icon_slug: null, total: restTotal, count: 0 },
  ]
})

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const params = {
      kind: filters.value.kind,
      from: filters.value.from,
      to: filters.value.to,
    }
    if (filters.value.account_id) params.account_id = filters.value.account_id
    const { data: payload } = await financeApi.reportByCategory(params)
    data.value = {
      total: Number(payload.total ?? 0),
      count: Number(payload.count ?? 0),
      buckets: payload.buckets ?? [],
    }
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudo cargar el reporte.')
  } finally {
    loading.value = false
  }
}

// Adapter para DateRangePreset (v-model objeto { from, to }) sin reemplazar
// el objeto filters (mantiene reactividad del watch sobre filters).
const dateRangeModel = computed({
  get: () => ({ from: filters.value.from, to: filters.value.to }),
  set: (range) => {
    filters.value.from = range.from
    filters.value.to = range.to
  },
})

watch(
  () => [filters.value.kind, filters.value.account_id, filters.value.from, filters.value.to],
  fetchReport,
)

onMounted(async () => {
  // Aseguramos que las cuentas estén cargadas para el filtro.
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
            Distribución de gastos o ingresos por categoría
          </p>
        </div>
        <RouterLink
          :to="{ name: 'dashboard' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
        >
          ← Dashboard
        </RouterLink>
      </header>

      <ReportsSubnav />

      <!-- Toolbar de filtros -->
      <section class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4 space-y-4">
        <!-- Toggle Gastos / Ingresos -->
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="px-3 py-1.5 rounded text-sm font-medium border transition"
            :class="filters.kind === 'expense'
              ? 'bg-[color:var(--color-negative)]/15 border-[color:var(--color-negative)]/50 text-[color:var(--color-negative)]'
              : 'border-[color:var(--color-border)] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]'"
            @click="filters.kind = 'expense'"
          >
            Gastos
          </button>
          <button
            type="button"
            class="px-3 py-1.5 rounded text-sm font-medium border transition"
            :class="filters.kind === 'income'
              ? 'bg-[color:var(--color-positive)]/15 border-[color:var(--color-positive)]/50 text-[color:var(--color-positive)]'
              : 'border-[color:var(--color-border)] text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]'"
            @click="filters.kind = 'income'"
          >
            Ingresos
          </button>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 items-end">
          <BaseSelect v-model="filters.account_id" label="Cuenta" :options="accountOptions" />
          <DateRangePreset v-model="dateRangeModel" />
        </div>

        <div class="flex justify-end">
          <ExcelExportButton
            url="/finance/reports/by-category/export.xlsx"
            :params="{
              kind: filters.kind,
              from: filters.from,
              to: filters.to,
              ...(filters.account_id ? { account_id: filters.account_id } : {}),
            }"
            :disabled="loading || !data.buckets.length"
          />
        </div>
      </section>

      <!-- Hero -->
      <ReportHero
        :total="data.total"
        :weekly-average="weeklyAverage"
        :count="data.count"
        :period-label="periodLabel"
        :kind-label="kindLabel"
      />

      <!-- Loading / Error / Vacío -->
      <div v-if="loading && !data.buckets.length" class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <BaseSkeleton height="h-72" rounded="rounded-xl" />
        <BaseSkeleton height="h-72" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchReport">Reintentar</BaseButton>
      </div>

      <div
        v-else-if="!data.buckets.length"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <ChartPieIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          No hay movimientos en este periodo.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
          Cambia el rango o el tipo para ver resultados.
        </p>
      </div>

      <!-- Dona + Lista -->
      <section v-else class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-6">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-4">
            Distribución
          </h3>
          <CategoryBreakdownChart :buckets="chartBuckets" />
        </div>
        <div class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-6">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-2">
            Detalle por categoría
          </h3>
          <CategoryBreakdownList :buckets="data.buckets" @drilldown="openDrilldown" />
        </div>
      </section>
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
