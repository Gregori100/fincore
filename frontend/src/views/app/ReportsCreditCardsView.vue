<script setup>
import { computed, onMounted, ref } from 'vue'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import CreditCardSummary from '@/components/finance/CreditCardSummary.vue'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'
import ExcelExportButton from '@/components/finance/ExcelExportButton.vue'
import { firstDayOfMonth, toISODate } from '@/utils/dates'
import ReportsSubnav from '@/components/finance/ReportsSubnav.vue'
import { CreditCardIcon } from '@heroicons/vue/24/outline'

const cards = ref([])
const loading = ref(false)
const error = ref(null)

const hasCards = computed(() => cards.value.length > 0)

const drillOpen = ref(false)
const drillFilters = ref({})

function openDrilldown(card) {
  // Cargos del mes en curso para la tarjeta.
  drillFilters.value = {
    account_id: card.id,
    kind: 'credit_expense',
    from: firstDayOfMonth(),
    to: toISODate(),
  }
  drillOpen.value = true
}

async function fetchReport() {
  loading.value = true
  error.value = null
  try {
    const { data } = await financeApi.reportCreditCards()
    cards.value = data.cards ?? []
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
            Estado actual de tus tarjetas de crédito
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

      <div v-if="cards.length" class="flex justify-end">
        <ExcelExportButton
          url="/finance/reports/credit-cards/export.xlsx"
          :params="{}"
          :disabled="loading || !cards.length"
        />
      </div>

      <!-- Loading / Error / Empty / Cards -->
      <div v-if="loading && !cards.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <BaseSkeleton v-for="n in 3" :key="n" height="h-64" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchReport">Reintentar</BaseButton>
      </div>

      <div
        v-else-if="!hasCards"
        class="rounded-xl border border-[color:var(--color-border)] p-10 text-center"
      >
        <CreditCardIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          Aún no tienes tarjetas de crédito.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1 mb-4">
          Crea una desde la sección de cuentas para empezar a ver su estado aquí.
        </p>
        <RouterLink :to="{ name: 'accounts' }">
          <BaseButton variant="secondary">Ir a mis cuentas</BaseButton>
        </RouterLink>
      </div>

      <section v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <CreditCardSummary v-for="c in cards" :key="c.id" :card="c" @drilldown="openDrilldown" />
      </section>
    </div>

    <EntriesDrilldownModal :open="drillOpen" :filters="drillFilters" @close="drillOpen = false" />
  </AppLayout>
</template>
