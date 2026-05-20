<script setup>
import { useFinanceStore } from '@/stores/finance'

const props = defineProps({
  events: { type: Array, default: () => [] },
})
const emit = defineEmits(['edit'])

const finance = useFinanceStore()

const KIND_LABEL = {
  income: 'Ingreso',
  expense: 'Gasto',
  credit_expense: 'Cargo tarjeta',
  debt_payment: 'Pago tarjeta',
}
const KIND_COLOR = {
  income: 'bg-[color:var(--color-positive)]/15 text-[color:var(--color-positive)]',
  expense: 'bg-[color:var(--color-negative)]/15 text-[color:var(--color-negative)]',
  credit_expense: 'bg-[color:var(--color-warning)]/15 text-[color:var(--color-warning)]',
  debt_payment: 'bg-[color:var(--color-accent)]/15 text-[color:var(--color-accent)]',
}

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function accountName(id) {
  if (!id) return ''
  const a = finance.accounts.find((x) => x.id === id)
  return a?.name ?? '(archivada)'
}

function onRowClick(e) {
  emit('edit', { eventId: e.planned_event_id, occurrenceDate: e.date, defaultAmount: e.amount, overrideId: e.override_id })
}
</script>

<template>
  <div v-if="!events.length" class="text-sm text-[color:var(--color-text-subtle)] italic">
    No hay ocurrencias en el horizonte.
  </div>
  <div v-else class="border border-[color:var(--color-border)] rounded-lg overflow-hidden">
    <!-- Desktop -->
    <table class="hidden md:table w-full text-sm">
      <thead class="bg-[color:var(--color-surface-elevated)]">
        <tr class="text-left text-[color:var(--color-text-muted)] text-xs uppercase tracking-wide">
          <th class="px-3 py-2">Fecha</th>
          <th class="px-3 py-2">Tipo</th>
          <th class="px-3 py-2 text-right">Monto</th>
          <th class="px-3 py-2">Cuentas</th>
          <th class="px-3 py-2">Estado</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(e, idx) in events"
          :key="`${e.planned_event_id}-${e.date}-${idx}`"
          class="border-t border-[color:var(--color-border)] hover:bg-[color:var(--color-surface-elevated)]/50 cursor-pointer"
          :class="e.skipped && 'opacity-60'"
          @click="onRowClick(e)"
        >
          <td class="px-3 py-2 tabular-nums">{{ e.date }}</td>
          <td class="px-3 py-2">
            <span class="inline-block px-2 py-0.5 rounded text-[10px] font-semibold uppercase" :class="KIND_COLOR[e.kind]">
              {{ KIND_LABEL[e.kind] }}
            </span>
          </td>
          <td class="px-3 py-2 text-right tabular-nums">{{ fmt(e.amount) }}</td>
          <td class="px-3 py-2 text-xs text-[color:var(--color-text-muted)]">
            <template v-if="e.account_origin_id">{{ accountName(e.account_origin_id) }}</template>
            <template v-if="e.account_origin_id && e.account_destination_id"> → </template>
            <template v-if="e.account_destination_id">{{ accountName(e.account_destination_id) }}</template>
          </td>
          <td class="px-3 py-2 text-xs">
            <span
              v-if="e.source === 'override'"
              class="inline-block mr-1 text-[10px] font-medium tracking-normal text-[color:var(--color-accent)] bg-[color:var(--color-accent)]/10 border border-[color:var(--color-accent)]/30 px-1.5 py-0.5 rounded"
            >
              override
            </span>
            <span
              v-if="e.skipped"
              class="inline-block mr-1 text-[10px] font-medium tracking-normal text-[color:var(--color-text-subtle)] bg-[color:var(--color-surface-elevated)] px-1.5 py-0.5 rounded"
            >
              saltada
            </span>
            <span
              v-for="w in e.warnings"
              :key="w"
              class="inline-block mr-1 text-[10px] font-medium tracking-normal text-[color:var(--color-warning)] bg-[color:var(--color-warning)]/10 border border-[color:var(--color-warning)]/30 px-1.5 py-0.5 rounded"
            >
              {{ w }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Mobile -->
    <ul class="md:hidden divide-y divide-[color:var(--color-border)]">
      <li
        v-for="(e, idx) in events"
        :key="`m-${e.planned_event_id}-${e.date}-${idx}`"
        class="px-3 py-3 space-y-1 cursor-pointer"
        :class="e.skipped && 'opacity-60'"
        @click="onRowClick(e)"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="px-2 py-0.5 rounded text-[10px] font-semibold uppercase" :class="KIND_COLOR[e.kind]">
            {{ KIND_LABEL[e.kind] }}
          </span>
          <span class="tabular-nums font-semibold">{{ fmt(e.amount) }}</span>
        </div>
        <p class="text-xs text-[color:var(--color-text-muted)]">{{ e.date }}</p>
        <p class="text-xs text-[color:var(--color-text-muted)] truncate">
          <template v-if="e.account_origin_id">{{ accountName(e.account_origin_id) }}</template>
          <template v-if="e.account_origin_id && e.account_destination_id"> → </template>
          <template v-if="e.account_destination_id">{{ accountName(e.account_destination_id) }}</template>
        </p>
        <div class="flex flex-wrap gap-1">
          <span
            v-if="e.source === 'override'"
            class="text-[10px] font-medium text-[color:var(--color-accent)] bg-[color:var(--color-accent)]/10 border border-[color:var(--color-accent)]/30 px-1.5 py-0.5 rounded"
          >
            override
          </span>
          <span
            v-if="e.skipped"
            class="text-[10px] font-medium text-[color:var(--color-text-subtle)] bg-[color:var(--color-surface-elevated)] px-1.5 py-0.5 rounded"
          >
            saltada
          </span>
          <span
            v-for="w in e.warnings"
            :key="w"
            class="text-[10px] font-medium text-[color:var(--color-warning)] bg-[color:var(--color-warning)]/10 border border-[color:var(--color-warning)]/30 px-1.5 py-0.5 rounded"
          >
            {{ w }}
          </span>
        </div>
      </li>
    </ul>
  </div>
</template>
