<script setup>
import { computed, onMounted, ref } from 'vue'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BudgetsList from '@/components/finance/BudgetsList.vue'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import { firstDayOfMonth, toISODate } from '@/utils/dates'
import { WalletIcon } from '@heroicons/vue/24/outline'

const data = ref({
  month: '',
  total_limit: 0,
  total_spent: 0,
  total_pct: null,
  buckets: [],
})
const loading = ref(false)
const error = ref(null)

const hasBudgets = computed(() => data.value.buckets.length > 0)

const drillOpen = ref(false)
const drillFilters = ref({})

function openDrilldown(bucket) {
  drillFilters.value = {
    category_id: bucket.category_id,
    kind: 'expense',
    from: firstDayOfMonth(),
    to: toISODate(),
  }
  drillOpen.value = true
}

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function totalTone() {
  const pct = Number(data.value.total_pct ?? 0)
  if (pct < 70) return 'text-[color:var(--color-positive)]'
  if (pct <= 100) return 'text-[color:var(--color-warning)]'
  return 'text-[color:var(--color-negative)]'
}

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const { data: payload } = await financeApi.reportBudgets()
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
            Presupuestos del mes en curso por categoría
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

      <!-- Hero con totales -->
      <section
        v-if="hasBudgets"
        class="grid grid-cols-1 sm:grid-cols-3 gap-4"
      >
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Total presupuestado
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight">
            {{ fmt(data.total_limit) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Gastado este mes
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight" :class="totalTone()">
            {{ fmt(data.total_spent) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
          <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Consumo global
          </p>
          <p class="text-2xl font-semibold mt-2 tabular-nums tracking-tight" :class="totalTone()">
            <template v-if="data.total_pct !== null && data.total_pct !== undefined">
              {{ Number(data.total_pct).toFixed(1) }}%
            </template>
            <template v-else>—</template>
          </p>
        </article>
      </section>

      <!-- Loading / Error / Empty / Lista -->
      <div v-if="loading && !hasBudgets" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <BaseSkeleton v-for="n in 3" :key="n" height="h-40" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchReport">Reintentar</BaseButton>
      </div>

      <div
        v-else-if="!hasBudgets"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <WalletIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          No tienes presupuestos configurados.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1 mb-4">
          Edita una categoría de gasto y define su límite mensual para empezar.
        </p>
        <RouterLink :to="{ name: 'categories' }">
          <BaseButton variant="secondary">Ir a categorías</BaseButton>
        </RouterLink>
      </div>

      <BudgetsList v-else :buckets="data.buckets" @drilldown="openDrilldown" />
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
