<script setup>
const props = defineProps({
  total: { type: Number, required: true },
  weeklyAverage: { type: Number, required: true },
  count: { type: Number, required: true },
  periodLabel: { type: String, default: '' },
  kindLabel: { type: String, default: 'Gastos' },
})

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}
</script>

<template>
  <section class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
      <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
        Total · {{ kindLabel }}
      </p>
      <p class="text-3xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-text-primary)]">
        {{ fmt(total) }}
      </p>
      <p v-if="periodLabel" class="mt-1.5 text-xs text-[color:var(--color-text-muted)]">
        {{ periodLabel }}
      </p>
    </article>

    <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
      <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
        Promedio semanal
      </p>
      <p class="text-3xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-accent)]">
        {{ fmt(weeklyAverage) }}
      </p>
      <p class="mt-1.5 text-xs text-[color:var(--color-text-muted)]">
        Burn por semana en el rango
      </p>
    </article>

    <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5">
      <p class="text-[11px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
        Movimientos
      </p>
      <p class="text-3xl font-semibold mt-2 tabular-nums tracking-tight text-[color:var(--color-text-primary)]">
        {{ count }}
      </p>
      <p class="mt-1.5 text-xs text-[color:var(--color-text-muted)]">
        Total de entries del periodo
      </p>
    </article>
  </section>
</template>
