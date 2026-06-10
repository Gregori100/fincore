<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import DateRangePreset from '@/components/finance/DateRangePreset.vue'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import ExcelExportButton from '@/components/finance/ExcelExportButton.vue'
import { firstDayOfMonth, toISODate } from '@/utils/dates'

const loading = ref(false)
const error = ref(null)
const rows = ref([])
const filters = ref({
  from: firstDayOfMonth(),
  to: toISODate(),
})

// Adapter para DateRangePreset (v-model objeto { from, to }).
const dateRangeModel = computed({
  get: () => ({ from: filters.value.from, to: filters.value.to }),
  set: (range) => {
    filters.value.from = range.from
    filters.value.to = range.to
  },
})

const drillOpen = ref(false)
const drillFilters = ref({})

const totals = computed(() => ({
  income: rows.value.reduce((s, r) => s + Number(r.income ?? 0), 0),
  expense: rows.value.reduce((s, r) => s + Number(r.expense ?? 0), 0),
}))

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const TYPE_LABEL = {
  cash: 'Efectivo',
  debit: 'Débito',
  credit: 'Crédito',
}

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const { data } = await financeApi.reportByAccount(filters.value)
    rows.value = data.accounts ?? []
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network') ? 'No hay conexión con el servidor.' : 'No se pudo cargar el reporte.')
  } finally {
    loading.value = false
  }
}

function openDrilldown(row, kindOverride) {
  // kindOverride: 'income' | 'expense' | undefined (todos los movimientos de la cuenta).
  drillFilters.value = {
    account_id: row.account_id,
    from: filters.value.from,
    to: filters.value.to,
  }
  if (kindOverride === 'income') {
    drillFilters.value.kind = row.type === 'credit' ? 'debt_payment' : 'income'
  } else if (kindOverride === 'expense') {
    drillFilters.value.kind = row.type === 'credit' ? 'credit_expense' : 'expense'
  }
  drillOpen.value = true
}

function hasCreditAccount() {
  return rows.value.some((r) => r.type === 'credit')
}

// Refetch automático cuando cambia el rango (preset o personalizado),
// consistente con ReportsByCategoryView y EntriesTable.
watch(() => [filters.value.from, filters.value.to], fetchReport)

onMounted(fetchReport)
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Reportes</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Ingresos, gastos y neto por cada una de tus cuentas
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

      <!-- Filtros de rango -->
      <section class="space-y-3 sm:max-w-md">
        <DateRangePreset v-model="dateRangeModel" />
        <div class="flex items-center gap-2 flex-wrap">
          <BaseButton variant="secondary" :loading="loading" @click="fetchReport">Actualizar</BaseButton>
          <ExcelExportButton
            url="/finance/reports/by-account/export.xlsx"
            :params="{ from: filters.from, to: filters.to }"
            :disabled="loading || !rows.length"
          />
        </div>
      </section>

      <!-- Nota semántica si hay tarjetas -->
      <p
        v-if="hasCreditAccount()"
        class="text-xs text-[color:var(--color-text-subtle)] italic"
      >
        En tarjetas de crédito, <strong>Ingresos</strong> son pagos recibidos a la deuda y
        <strong>Gastos</strong> son cargos hechos a la tarjeta.
      </p>

      <BaseSkeleton v-if="loading && !rows.length" class="h-64" />
      <div v-else-if="error" class="text-sm text-[color:var(--color-negative)]">{{ error }}</div>
      <div
        v-else-if="!rows.length"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center text-sm text-[color:var(--color-text-muted)]"
      >
        Aún no tienes cuentas activas.
      </div>

      <div v-else class="border border-[color:var(--color-border)] rounded-xl overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-[color:var(--color-surface-elevated)]">
            <tr class="text-left text-[color:var(--color-text-muted)] text-xs uppercase tracking-wide">
              <th class="px-4 py-2">Cuenta</th>
              <th class="px-4 py-2 text-right">Ingresos</th>
              <th class="px-4 py-2 text-right">Gastos</th>
              <th class="px-4 py-2 text-right">Neto</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="r in rows"
              :key="r.account_id"
              class="border-t border-[color:var(--color-border)]"
            >
              <td
                class="px-4 py-3 cursor-pointer hover:bg-[color:var(--color-surface-elevated)]/50"
                @click="openDrilldown(r)"
              >
                <p class="font-medium">{{ r.name }}</p>
                <p class="text-[11px] uppercase tracking-wide text-[color:var(--color-text-subtle)]">
                  {{ TYPE_LABEL[r.type] ?? r.type }}
                </p>
              </td>
              <td
                class="px-4 py-3 text-right tabular-nums"
                :class="r.income > 0
                  ? 'cursor-pointer hover:bg-[color:var(--color-positive)]/10 text-[color:var(--color-positive)]'
                  : 'text-[color:var(--color-text-subtle)]'"
                @click="r.income > 0 && openDrilldown(r, 'income')"
              >
                {{ fmt(r.income) }}
              </td>
              <td
                class="px-4 py-3 text-right tabular-nums"
                :class="r.expense > 0
                  ? 'cursor-pointer hover:bg-[color:var(--color-negative)]/10 text-[color:var(--color-negative)]'
                  : 'text-[color:var(--color-text-subtle)]'"
                @click="r.expense > 0 && openDrilldown(r, 'expense')"
              >
                {{ fmt(r.expense) }}
              </td>
              <td
                class="px-4 py-3 text-right tabular-nums font-semibold"
                :class="r.net >= 0 ? 'text-[color:var(--color-positive)]' : 'text-[color:var(--color-negative)]'"
              >
                {{ fmt(r.net) }}
              </td>
            </tr>
          </tbody>
          <tfoot class="bg-[color:var(--color-surface-elevated)]">
            <tr>
              <td class="px-4 py-2 text-xs uppercase tracking-wide text-[color:var(--color-text-muted)]">
                Totales
              </td>
              <td class="px-4 py-2 text-right tabular-nums text-[color:var(--color-positive)]">
                {{ fmt(totals.income) }}
              </td>
              <td class="px-4 py-2 text-right tabular-nums text-[color:var(--color-negative)]">
                {{ fmt(totals.expense) }}
              </td>
              <td class="px-4 py-2 text-right tabular-nums font-semibold">
                {{ fmt(totals.income - totals.expense) }}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
