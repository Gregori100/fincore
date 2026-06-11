<script setup>
import { computed, onMounted, ref } from 'vue'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import CategoryBadge from '@/components/finance/CategoryBadge.vue'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import ExcelExportButton from '@/components/finance/ExcelExportButton.vue'
import { ChartBarIcon } from '@heroicons/vue/24/outline'

const data = ref({
  month: '',
  today: '',
  days_in_month: 0,
  days_elapsed: 0,
  window_from: '',
  window_to: '',
  categories: [],
  totals: { current_spent: 0, historical_average: 0, projection: 0, delta_pct: null },
})
const loading = ref(false)
const error = ref(null)

const hasData = computed(() => data.value.categories.length > 0)

const drillOpen = ref(false)
const drillFilters = ref({})

function openDrilldown(bucket) {
  drillFilters.value = {
    category_id: bucket.category_id,
    kind: 'expense',
    from: data.value.window_to ? toFirstOfMonth(data.value.today) : null,
    to: data.value.today,
  }
  drillOpen.value = true
}

function toFirstOfMonth(isoDate) {
  if (!isoDate) return null
  // 'YYYY-MM-DD' → 'YYYY-MM-01'
  return isoDate.slice(0, 7) + '-01'
}

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

// Badge color del Δ% según los umbrales de la spec:
// verde si ≤ 0, amarillo si 0 < Δ ≤ 20, rojo si > 20, neutro si null.
function deltaClass(deltaPct) {
  if (deltaPct === null || deltaPct === undefined) {
    return 'text-[color:var(--color-text-muted)] bg-[color:var(--color-surface-elevated)]'
  }
  if (deltaPct <= 0) {
    return 'text-[color:var(--color-positive)] bg-[color:var(--color-positive)]/10'
  }
  if (deltaPct <= 20) {
    return 'text-[color:var(--color-warning)] bg-[color:var(--color-warning)]/10'
  }
  return 'text-[color:var(--color-negative)] bg-[color:var(--color-negative)]/10'
}

function fmtDelta(deltaPct) {
  if (deltaPct === null || deltaPct === undefined) return '—'
  const sign = deltaPct > 0 ? '+' : ''
  return `${sign}${Number(deltaPct).toFixed(1)}%`
}

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const { data: payload } = await financeApi.reportForecast()
    data.value = payload
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

onMounted(fetchReport)
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Reportes</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Proyección de cierre del mes en curso, basada en tu histórico de los últimos 3 meses
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

      <div v-if="hasData" class="flex justify-end">
        <ExcelExportButton
          url="/finance/reports/forecast/export.xlsx"
          :params="{}"
          :disabled="loading || !hasData"
        />
      </div>

      <!-- Hero con totales -->
      <section
        v-if="hasData"
        class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4"
      >
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Gastado este mes
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            {{ fmt(data.totals.current_spent) }}
          </p>
          <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
            día {{ data.days_elapsed }} de {{ data.days_in_month }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Promedio histórico
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            {{ fmt(data.totals.historical_average) }}
          </p>
          <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
            {{ data.window_from }} → {{ data.window_to }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Proyección fin de mes
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            {{ fmt(data.totals.projection) }}
          </p>
          <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
            si sigues con este ritmo
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Δ vs promedio
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            <span
              class="inline-flex items-center px-2 py-0.5 rounded-md text-xl"
              :class="deltaClass(data.totals.delta_pct)"
            >
              {{ fmtDelta(data.totals.delta_pct) }}
            </span>
          </p>
          <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
            verde si por debajo del promedio
          </p>
        </article>
      </section>

      <!-- Loading / Error / Empty / Tabla -->
      <div v-if="loading && !hasData" class="space-y-2">
        <BaseSkeleton v-for="n in 4" :key="n" height="h-12" rounded="rounded-md" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchReport">Reintentar</BaseButton>
      </div>

      <div
        v-else-if="!hasData"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <ChartBarIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          Aún no tienes suficiente historial para proyectar.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1 mb-4">
          Vuelve después de registrar movimientos en al menos un mes completo.
        </p>
        <RouterLink :to="{ name: 'entries' }">
          <BaseButton variant="secondary">Ir a movimientos</BaseButton>
        </RouterLink>
      </div>

      <section
        v-else
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl overflow-hidden"
      >
        <table class="w-full text-sm">
          <thead class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-muted)] text-xs uppercase tracking-wider">
            <tr>
              <th class="text-left px-4 py-3 font-medium">Categoría</th>
              <th class="text-right px-4 py-3 font-medium">Gastado</th>
              <th class="text-right px-4 py-3 font-medium">Promedio</th>
              <th class="text-right px-4 py-3 font-medium">Proyección</th>
              <th class="text-right px-4 py-3 font-medium">Δ %</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="bucket in data.categories"
              :key="bucket.category_id ?? '__uncategorized__'"
              class="border-t border-[color:var(--color-border)] hover:bg-[color:var(--color-surface-elevated)]/40 cursor-pointer transition"
              data-testid="forecast-row"
              @click="openDrilldown(bucket)"
            >
              <td class="px-4 py-3">
                <CategoryBadge
                  v-if="bucket.color_slug && bucket.icon_slug"
                  :category="bucket"
                />
                <span
                  v-else
                  class="text-[color:var(--color-text-muted)] italic text-xs"
                >
                  {{ bucket.name }}
                </span>
              </td>
              <td class="px-4 py-3 text-right tabular-nums">{{ fmt(bucket.current_spent) }}</td>
              <td class="px-4 py-3 text-right tabular-nums text-[color:var(--color-text-muted)]">
                {{ fmt(bucket.historical_average) }}
              </td>
              <td class="px-4 py-3 text-right tabular-nums font-medium">{{ fmt(bucket.projection) }}</td>
              <td class="px-4 py-3 text-right">
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium"
                  :class="deltaClass(bucket.delta_pct)"
                  data-testid="delta-badge"
                >
                  {{ fmtDelta(bucket.delta_pct) }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
