<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import MonthlyCashflowChart from '@/components/finance/MonthlyCashflowChart.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import { fillMissingMonths, lastNMonths } from '@/utils/dates'
import { ChartBarIcon } from '@heroicons/vue/24/outline'

const MONTHS_WINDOW = 12

const finance = useFinanceStore()

const range = ref(lastNMonths(MONTHS_WINDOW))
const accountId = ref(null)

const data = ref({ months: [], total_income: 0, total_expense: 0, total_net: 0 })
const loading = ref(false)
const error = ref(null)

const drillOpen = ref(false)
const drillFilters = ref({})

function openDrilldown(payload) {
  // payload viene del chart: { year_month, kind }
  drillFilters.value = {
    year_month: payload.year_month,
    kind: payload.kind,
    account_id: accountId.value ?? null,
  }
  drillOpen.value = true
}

const accountOptions = computed(() => [
  { value: null, label: 'Todas las cuentas' },
  ...finance.accounts.map((a) => ({ value: a.id, label: a.name })),
])

// Completa los meses faltantes con ceros para tener siempre 12 barras.
const months = computed(() =>
  fillMissingMonths(data.value.months, range.value.from, range.value.to),
)

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

// Tasa de ahorro promedio = (sum net / sum income) * 100. Sólo tiene sentido
// si hubo ingresos; sin ingresos la tasa no se define y mostramos 0%.
const savingsRate = computed(() => {
  const income = Number(data.value.total_income)
  if (income <= 0) return 0
  return (Number(data.value.total_net) / income) * 100
})

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const params = { from: range.value.from, to: range.value.to }
    if (accountId.value) params.account_id = accountId.value
    const { data: payload } = await financeApi.reportCashflowMonthly(params)
    data.value = {
      months: payload.months ?? [],
      total_income: Number(payload.total_income ?? 0),
      total_expense: Number(payload.total_expense ?? 0),
      total_net: Number(payload.total_net ?? 0),
    }
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudo cargar el cashflow.')
  } finally {
    loading.value = false
  }
}

watch(accountId, fetchReport)

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
            Cashflow mensual: ingresos vs egresos en los últimos {{ MONTHS_WINDOW }} meses
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

      <!-- Filtro -->
      <section class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 items-end">
          <BaseSelect v-model="accountId" label="Cuenta" :options="accountOptions" />
        </div>
      </section>

      <!-- Hero con métricas -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Total ingresos
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-positive)]">
            {{ fmt(data.total_income) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Total egresos
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-negative)]">
            {{ fmt(data.total_expense) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Ahorro neto
          </p>
          <p
            class="text-2xl font-semibold mt-2 tabular-nums tracking-tight"
            :class="data.total_net >= 0 ? 'text-[color:var(--color-positive)]' : 'text-[color:var(--color-negative)]'"
          >
            {{ fmt(data.total_net) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Tasa de ahorro
          </p>
          <p
            class="text-2xl font-semibold mt-2 tabular-nums tracking-tight"
            :class="savingsRate >= 0 ? 'text-[color:var(--color-accent)]' : 'text-[color:var(--color-negative)]'"
          >
            {{ savingsRate.toFixed(1) }}%
          </p>
          <p class="mt-1.5 text-xs text-[color:var(--color-text-muted)]">
            del total ingresado
          </p>
        </article>
      </section>

      <!-- Loading / Error / Vacío -->
      <div v-if="loading && !data.months.length">
        <BaseSkeleton height="h-80" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
      </div>

      <div
        v-else-if="!data.months.length && data.total_income === 0 && data.total_expense === 0"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <ChartBarIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          No hay movimientos en los últimos {{ MONTHS_WINDOW }} meses.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
          Registra ingresos o gastos para ver tu cashflow.
        </p>
      </div>

      <!-- Gráfico -->
      <section
        v-else
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-6"
      >
        <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-4">
          Cashflow mensual
        </h3>
        <MonthlyCashflowChart :months="months" @drilldown="openDrilldown" />
      </section>
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
