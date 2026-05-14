<script setup>
import { computed } from 'vue'
import { LockClosedIcon, PencilSquareIcon, ArchiveBoxXMarkIcon } from '@heroicons/vue/20/solid'

const props = defineProps({
  account: { type: Object, required: true },
  highlighted: { type: Boolean, default: false },
})

defineEmits(['edit', 'delete'])

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const typeLabel = computed(() => {
  return {
    cash: 'Efectivo',
    debit: 'Débito',
    credit: 'Crédito',
  }[props.account.type] ?? props.account.type
})

const typeColor = computed(() => {
  return {
    cash: 'text-[color:var(--color-positive)]',
    debit: 'text-[color:var(--color-accent)]',
    credit: 'text-[color:var(--color-warning)]',
  }[props.account.type] ?? ''
})

const editable = computed(() => !props.account.is_protected)
</script>

<template>
  <article
    class="group bg-[color:var(--color-surface)] border rounded-xl p-4 transition-all duration-300 hover:border-[color:var(--color-accent)]/60"
    :class="
      highlighted
        ? 'border-[color:var(--color-accent)] ring-2 ring-[color:var(--color-accent)]/40 shadow-lg shadow-[color:var(--color-accent)]/10'
        : 'border-[color:var(--color-border)]'
    "
  >
    <header class="flex items-start justify-between gap-2 mb-3">
      <div class="min-w-0">
        <h3 class="font-medium truncate flex items-center gap-1.5">
          {{ account.name }}
          <LockClosedIcon
            v-if="account.is_protected"
            class="h-3.5 w-3.5 text-[color:var(--color-text-subtle)] shrink-0"
            :title="'Cuenta protegida'"
          />
        </h3>
        <p class="text-[10px] mt-0.5 uppercase tracking-[0.08em] font-semibold" :class="typeColor">
          {{ typeLabel }}
        </p>
      </div>

      <div
        v-if="editable"
        class="flex items-center gap-1 opacity-0 group-hover:opacity-100 focus-within:opacity-100 transition"
      >
        <button
          type="button"
          class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-accent)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
          aria-label="Editar cuenta"
          title="Editar"
          @click="$emit('edit', account)"
        >
          <PencilSquareIcon class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-warning)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-warning)]"
          aria-label="Archivar cuenta"
          title="Archivar"
          @click="$emit('delete', account)"
        >
          <ArchiveBoxXMarkIcon class="h-4 w-4" />
        </button>
      </div>
    </header>

    <p class="text-2xl font-semibold tabular-nums tracking-tight">
      {{ fmt(account.balance) }}
    </p>

    <div v-if="account.type === 'credit'" class="mt-3 pt-3 border-t border-[color:var(--color-border)] space-y-1 text-xs">
      <div class="flex justify-between text-[color:var(--color-text-muted)]">
        <span>Límite</span>
        <span class="tabular-nums">{{ fmt(account.credit_limit) }}</span>
      </div>
      <div class="flex justify-between">
        <span class="text-[color:var(--color-text-muted)]">Disponible</span>
        <span class="tabular-nums text-[color:var(--color-accent)] font-medium">
          {{ fmt(account.available_credit) }}
        </span>
      </div>
      <div v-if="account.payment_day" class="flex justify-between text-[color:var(--color-text-muted)]">
        <span>Día de pago</span>
        <span>{{ account.payment_day }}</span>
      </div>
    </div>
  </article>
</template>
