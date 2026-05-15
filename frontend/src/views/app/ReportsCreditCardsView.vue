<script setup>
import { computed, onMounted, ref } from 'vue'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import CreditCardSummary from '@/components/finance/CreditCardSummary.vue'
import { CreditCardIcon } from '@heroicons/vue/24/outline'

const cards = ref([])
const loading = ref(false)
const error = ref(null)

const hasCards = computed(() => cards.value.length > 0)

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

      <!-- Subnav entre reportes (4 tabs) -->
      <nav class="flex items-center gap-2 text-sm border-b border-[color:var(--color-border)] pb-2 flex-wrap">
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
        <CreditCardSummary v-for="c in cards" :key="c.id" :card="c" />
      </section>
    </div>
  </AppLayout>
</template>
