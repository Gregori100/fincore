<script setup>
defineProps({
  state: {
    type: Object,
    required: true,
  },
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
  <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
    <article
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5"
    >
      <p class="text-xs font-medium uppercase tracking-wide text-[color:var(--color-text-subtle)]">
        Bolsa (BO)
      </p>
      <p class="text-3xl font-semibold mt-2 text-[color:var(--color-positive)]">
        {{ fmt(state.bo) }}
      </p>
      <p class="mt-1 text-xs text-[color:var(--color-text-muted)]">
        Efectivo disponible
      </p>
    </article>

    <article
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5"
    >
      <p class="text-xs font-medium uppercase tracking-wide text-[color:var(--color-text-subtle)]">
        Deudas (DE)
      </p>
      <p class="text-3xl font-semibold mt-2 text-[color:var(--color-negative)]">
        {{ fmt(state.de) }}
      </p>
      <p class="mt-1 text-xs text-[color:var(--color-text-muted)]">
        Total que debes a tarjetas
      </p>
    </article>

    <article
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5"
    >
      <p class="text-xs font-medium uppercase tracking-wide text-[color:var(--color-text-subtle)]">
        Crédito (CR)
      </p>
      <p class="text-3xl font-semibold mt-2 text-[color:var(--color-accent)]">
        {{ fmt(state.cr) }}
      </p>
      <p class="mt-1 text-xs text-[color:var(--color-text-muted)]">
        Disponible en tus tarjetas
      </p>
    </article>

    <article
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5 sm:col-span-2 lg:col-span-3"
    >
      <div class="flex flex-wrap items-baseline gap-6">
        <div>
          <p class="text-xs uppercase tracking-wide text-[color:var(--color-text-subtle)]">
            Burn rate mensual
          </p>
          <p class="text-xl font-medium mt-1">
            {{ fmt(state.burn_rate) }}
          </p>
        </div>
        <div>
          <p class="text-xs uppercase tracking-wide text-[color:var(--color-text-subtle)]">
            Uso de crédito
          </p>
          <p class="text-xl font-medium mt-1">
            {{ Number(state.credit_usage_pct).toFixed(2) }}%
          </p>
        </div>
      </div>
    </article>
  </section>
</template>
