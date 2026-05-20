<script setup>
import { computed } from 'vue'
import { PencilSquareIcon, TrashIcon } from '@heroicons/vue/20/solid'
import { useFinanceStore } from '@/stores/finance'

const props = defineProps({
  events: { type: Array, required: true },
})
const emit = defineEmits(['edit', 'delete'])

const finance = useFinanceStore()

const KIND_LABEL = {
  income: 'Ingreso',
  expense: 'Gasto',
  credit_expense: 'Cargo tarjeta',
  debt_payment: 'Pago tarjeta',
}
const KIND_COLOR = {
  income: 'text-[color:var(--color-positive)]',
  expense: 'text-[color:var(--color-negative)]',
  credit_expense: 'text-[color:var(--color-warning)]',
  debt_payment: 'text-[color:var(--color-accent)]',
}
const RECURRENCE_LABEL = {
  one_off: 'Puntual',
  weekly: 'Semanal',
  monthly: 'Mensual',
}
const WEEKDAY_LABEL = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

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
  return a?.name ?? '(cuenta desconocida)'
}

function recurrenceText(event) {
  if (event.recurrence_type === 'one_off') {
    return `Puntual: ${String(event.start_date).slice(0, 10)}`
  }
  if (event.recurrence_type === 'weekly') {
    return `Cada ${WEEKDAY_LABEL[event.recurrence_day]?.toLowerCase() ?? '?'}`
  }
  if (event.recurrence_type === 'monthly') {
    return `Día ${event.recurrence_day} de cada mes`
  }
  return ''
}

function hasArchivedAccount(event) {
  const involves = [event.account_origin_id, event.account_destination_id].filter(Boolean)
  return involves.some((id) => {
    const a = finance.accounts.find((x) => x.id === id)
    return !a || a.deleted_at
  })
}

const grouped = computed(() => {
  const map = new Map()
  for (const e of props.events) {
    if (!map.has(e.kind)) map.set(e.kind, [])
    map.get(e.kind).push(e)
  }
  return Array.from(map.entries())
})
</script>

<template>
  <div v-if="events.length === 0" class="text-sm text-[color:var(--color-text-subtle)] italic">
    Todavía no tienes eventos planeados. Crea el primero para empezar a proyectar.
  </div>
  <div v-else class="space-y-4">
    <section v-for="[kind, items] in grouped" :key="kind">
      <p class="text-[10px] uppercase tracking-[0.08em] font-semibold mb-2" :class="KIND_COLOR[kind]">
        {{ KIND_LABEL[kind] }} · {{ items.length }}
      </p>
      <ul class="space-y-2">
        <li
          v-for="e in items"
          :key="e.id"
          class="group flex items-start gap-3 bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-lg p-3"
        >
          <div class="flex-1 min-w-0">
            <p class="font-medium truncate">
              {{ fmt(e.amount) }}
              <span class="text-[color:var(--color-text-muted)] text-xs ml-2">
                {{ recurrenceText(e) }}
              </span>
              <span
                v-if="hasArchivedAccount(e)"
                class="ml-2 text-[10px] font-medium tracking-normal text-[color:var(--color-warning)] bg-[color:var(--color-warning)]/10 border border-[color:var(--color-warning)]/30 px-1.5 py-0.5 rounded normal-case"
              >
                cuenta archivada
              </span>
            </p>
            <p class="text-xs text-[color:var(--color-text-muted)] truncate">
              <template v-if="e.account_origin_id">
                Desde: {{ accountName(e.account_origin_id) }}
              </template>
              <template v-if="e.account_origin_id && e.account_destination_id"> → </template>
              <template v-if="e.account_destination_id">
                Hacia: {{ accountName(e.account_destination_id) }}
              </template>
            </p>
            <p v-if="e.description" class="text-xs text-[color:var(--color-text-subtle)] truncate">
              {{ e.description }}
            </p>
          </div>
          <div class="flex items-center gap-1 sm:opacity-0 sm:group-hover:opacity-100 focus-within:opacity-100 transition">
            <button
              type="button"
              class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-accent)] hover:bg-[color:var(--color-surface-elevated)]"
              aria-label="Editar evento"
              @click="emit('edit', e)"
            >
              <PencilSquareIcon class="h-4 w-4" />
            </button>
            <button
              type="button"
              class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-negative)] hover:bg-[color:var(--color-surface-elevated)]"
              aria-label="Eliminar evento"
              @click="emit('delete', e)"
            >
              <TrashIcon class="h-4 w-4" />
            </button>
          </div>
        </li>
      </ul>
    </section>
  </div>
</template>
