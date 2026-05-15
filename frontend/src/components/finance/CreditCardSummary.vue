<script setup>
import { computed } from 'vue'
import { CalendarIcon, CreditCardIcon } from '@heroicons/vue/24/outline'

const props = defineProps({
  card: { type: Object, required: true },
})

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function fmtPct(n) {
  return `${Number(n ?? 0).toFixed(1)}%`
}

const utilizationPct = computed(() => Math.min(100, Math.max(0, Number(props.card.utilization_pct ?? 0))))

// Color de la barra según rango: <50 verde, 50-80 ámbar, >80 rojo.
const barCssVar = computed(() => {
  const p = utilizationPct.value
  if (p < 50) return '--color-positive'
  if (p < 80) return '--color-warning'
  return '--color-negative'
})

const balanceTone = computed(() => `text-[color:var(${barCssVar.value})]`)

function daysLabel(n) {
  if (n === null || n === undefined) return null
  if (n === 0) return 'hoy'
  if (n === 1) return 'en 1 día'
  if (n > 1) return `en ${n} días`
  if (n === -1) return 'hace 1 día'
  return `hace ${Math.abs(n)} días`
}

const SHORT_MONTHS_ES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

function fmtDate(iso) {
  if (!iso) return null
  const [y, m, d] = iso.split('-').map((s) => parseInt(s, 10))
  return `${d} ${SHORT_MONTHS_ES[m - 1]}`
}

const cycleSummary = computed(() => {
  const c = props.card.current_cycle
  if (!c) return null
  return `${fmt(c.charges_total)} · ${c.charges_count} ${c.charges_count === 1 ? 'movimiento' : 'movimientos'}`
})
</script>

<template>
  <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5 flex flex-col gap-4">
    <header class="flex items-start justify-between gap-2">
      <div class="min-w-0">
        <h3 class="font-medium truncate flex items-center gap-2">
          <CreditCardIcon class="h-4 w-4 text-[color:var(--color-text-subtle)]" />
          {{ card.name }}
        </h3>
        <p class="text-[10px] mt-0.5 uppercase tracking-[0.08em] font-semibold text-[color:var(--color-warning)]">
          Crédito
        </p>
      </div>
      <p class="text-2xl font-semibold tabular-nums tracking-tight" :class="balanceTone">
        {{ fmt(card.balance) }}
      </p>
    </header>

    <div>
      <div class="flex items-center justify-between text-xs mb-1.5">
        <span class="text-[color:var(--color-text-muted)]">Utilizado</span>
        <span class="tabular-nums font-medium" :class="balanceTone">{{ fmtPct(utilizationPct) }}</span>
      </div>
      <div class="h-2 rounded-full bg-[color:var(--color-surface-elevated)] overflow-hidden">
        <div
          class="h-full transition-all"
          :style="{
            width: `${utilizationPct}%`,
            backgroundColor: `var(${barCssVar})`,
          }"
        />
      </div>
    </div>

    <dl class="space-y-1.5 text-xs">
      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <dt>Disponible</dt>
        <dd class="tabular-nums text-[color:var(--color-accent)] font-medium">{{ fmt(card.available) }}</dd>
      </div>

      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <dt class="flex items-center gap-1.5">
          <CalendarIcon class="h-3 w-3" />
          Próximo corte
        </dt>
        <dd v-if="card.next_closing_date" class="tabular-nums">
          {{ fmtDate(card.next_closing_date) }}
          <span class="text-[color:var(--color-text-subtle)] ml-1">({{ daysLabel(card.days_to_closing) }})</span>
        </dd>
        <dd v-else>
          <RouterLink
            :to="{ name: 'account-detail', params: { uuid: card.id } }"
            class="text-[color:var(--color-text-subtle)] italic hover:text-[color:var(--color-accent)] transition"
          >
            no configurado
          </RouterLink>
        </dd>
      </div>

      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <dt class="flex items-center gap-1.5">
          <CalendarIcon class="h-3 w-3" />
          Próximo pago
        </dt>
        <dd v-if="card.next_payment_date" class="tabular-nums">
          {{ fmtDate(card.next_payment_date) }}
          <span class="text-[color:var(--color-text-subtle)] ml-1">({{ daysLabel(card.days_to_payment) }})</span>
        </dd>
        <dd v-else>
          <RouterLink
            :to="{ name: 'account-detail', params: { uuid: card.id } }"
            class="text-[color:var(--color-text-subtle)] italic hover:text-[color:var(--color-accent)] transition"
          >
            no configurado
          </RouterLink>
        </dd>
      </div>

      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <dt>Ciclo en curso</dt>
        <dd v-if="cycleSummary" class="tabular-nums text-right">{{ cycleSummary }}</dd>
        <dd v-else class="text-[color:var(--color-text-subtle)] italic">no configurado</dd>
      </div>

      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <dt>Pago mínimo estimado</dt>
        <dd v-if="card.minimum_payment_estimated !== null" class="tabular-nums">
          {{ fmt(card.minimum_payment_estimated) }}
        </dd>
        <dd v-else>
          <RouterLink
            :to="{ name: 'account-detail', params: { uuid: card.id } }"
            class="text-[color:var(--color-text-subtle)] italic hover:text-[color:var(--color-accent)] transition"
          >
            no configurado
          </RouterLink>
        </dd>
      </div>
    </dl>
  </article>
</template>
