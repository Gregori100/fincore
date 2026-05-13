<script setup>
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
    <h2 class="text-lg font-medium mb-4">Últimos movimientos</h2>

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
        <tbody>
          <tr
            v-for="e in entries"
            :key="e.id"
            class="border-b border-[color:var(--color-border)] last:border-0"
          >
            <td class="px-4 py-3">
              <span
                class="inline-block px-2 py-0.5 rounded text-xs font-medium"
                :class="KIND_COLORS[e.kind]"
              >
                {{ KIND_LABELS[e.kind] ?? e.kind }}
              </span>
            </td>
            <td class="px-4 py-3">
              <div class="text-sm">
                <span class="text-[color:var(--color-text-muted)]">{{ e.origin?.name ?? '—' }}</span>
                <span class="text-[color:var(--color-text-subtle)] mx-1.5">→</span>
                <span class="text-[color:var(--color-text-muted)]">{{ e.destination?.name ?? '—' }}</span>
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
        </tbody>
      </table>
      <p
        v-else
        class="text-sm text-[color:var(--color-text-subtle)] italic py-8 text-center"
      >
        Sin movimientos todavía.
      </p>
    </div>
  </section>
</template>
