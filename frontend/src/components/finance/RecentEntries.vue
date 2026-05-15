<script setup>
import { InboxIcon } from '@heroicons/vue/24/outline'
import CategoryBadge from '@/components/finance/CategoryBadge.vue'

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

defineProps({
  entries: { type: Array, default: () => [] },
})

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
    hour: '2-digit',
    minute: '2-digit',
  })
}
</script>

<template>
  <section>
    <header class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-medium">Últimos movimientos</h2>
      <RouterLink
        :to="{ name: 'entries' }"
        class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-accent)] transition"
      >
        Ver historial →
      </RouterLink>
    </header>

    <div
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl overflow-hidden"
    >
      <table v-if="entries.length" class="w-full text-sm">
        <thead class="text-xs text-[color:var(--color-text-subtle)] uppercase tracking-wide border-b border-[color:var(--color-border)]">
          <tr>
            <th class="text-left px-4 py-3 font-medium">Tipo</th>
            <th class="text-left px-4 py-3 font-medium">Movimiento</th>
            <th class="text-right px-4 py-3 font-medium">Monto</th>
            <th class="text-right px-4 py-3 font-medium hidden sm:table-cell">Fecha</th>
          </tr>
        </thead>
        <transition-group
          name="entry"
          tag="tbody"
        >
          <tr
            v-for="e in entries"
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
              <CategoryBadge
                v-if="e.category"
                :category="e.category"
                class="mt-1 max-w-full"
              />
            </td>
            <td class="px-4 py-3">
              <div class="text-sm">
                <span class="text-[color:var(--color-text-muted)]">
                  {{ e.origin?.name ?? '—' }}
                  <span
                    v-if="e.origin?.deleted_at"
                    class="text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] ml-0.5"
                  >
                    (arch.)
                  </span>
                </span>
                <span class="text-[color:var(--color-text-subtle)] mx-1.5">→</span>
                <span class="text-[color:var(--color-text-muted)]">
                  {{ e.destination?.name ?? '—' }}
                  <span
                    v-if="e.destination?.deleted_at"
                    class="text-[10px] uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] ml-0.5"
                  >
                    (arch.)
                  </span>
                </span>
              </div>
              <p v-if="e.description" class="text-xs text-[color:var(--color-text-subtle)] mt-0.5 truncate">
                {{ e.description }}
              </p>
            </td>
            <td class="px-4 py-3 text-right font-medium tabular-nums">
              {{ fmt(e.amount) }}
            </td>
            <td class="px-4 py-3 text-right text-xs text-[color:var(--color-text-subtle)] hidden sm:table-cell">
              {{ fmtDate(e.occurred_at) }}
            </td>
          </tr>
        </transition-group>
      </table>
      <div
        v-else
        class="py-10 text-center"
      >
        <InboxIcon class="h-10 w-10 mx-auto text-[color:var(--color-text-subtle)] opacity-60" />
        <p class="text-sm text-[color:var(--color-text-muted)] mt-3">
          Sin movimientos todavía.
        </p>
        <p class="text-xs text-[color:var(--color-text-subtle)] mt-1">
          Cuando registres un ingreso o gasto, aparecerá aquí.
        </p>
      </div>
    </div>
  </section>
</template>

<style scoped>
.entry-enter-active {
  transition: all 280ms cubic-bezier(0.22, 1, 0.36, 1);
}
.entry-enter-from {
  opacity: 0;
  transform: translateY(-8px);
  background-color: color-mix(in oklch, var(--color-accent) 10%, transparent);
}
.entry-leave-active {
  transition: opacity 180ms;
}
.entry-leave-to {
  opacity: 0;
}
</style>
