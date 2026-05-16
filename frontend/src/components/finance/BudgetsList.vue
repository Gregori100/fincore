<script setup>
import { computed } from 'vue'
import { cssVarBySlug, iconBySlug } from '@/constants/categoryCatalog'

const props = defineProps({
  // [{ category_id, name, color_slug, icon_slug, monthly_limit, spent, remaining, pct_consumed }]
  buckets: { type: Array, default: () => [] },
})

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

/** Color de la barra según rango de consumo. Coherente con el patrón de tarjetas. */
function barCssVar(pct) {
  if (pct < 70) return '--color-positive'
  if (pct <= 100) return '--color-warning'
  return '--color-negative'
}

const rows = computed(() => {
  return props.buckets.map((b) => {
    const pct = Number(b.pct_consumed ?? 0)
    const remaining = Number(b.remaining ?? 0)
    return {
      ...b,
      pct,
      // Width clampado al 100% para evitar desbordes visuales cuando se pasó.
      barWidth: Math.min(100, pct),
      cssVar: barCssVar(pct),
      icon: b.icon_slug ? iconBySlug(b.icon_slug) : null,
      colorVar: b.color_slug ? cssVarBySlug(b.color_slug) : '--color-text-subtle',
      overspent: remaining < 0,
      remainingAbs: Math.abs(remaining),
    }
  })
})
</script>

<template>
  <ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
    <li
      v-for="b in rows"
      :key="b.category_id"
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5 flex flex-col gap-4"
    >
      <header class="flex items-start justify-between gap-3">
        <div class="flex items-center gap-3 min-w-0">
          <div
            class="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
            :style="{
              backgroundColor: `color-mix(in oklch, var(${b.colorVar}) 22%, transparent)`,
              color: `var(${b.colorVar})`,
            }"
          >
            <component v-if="b.icon" :is="b.icon" class="h-5 w-5" />
          </div>
          <div class="min-w-0">
            <h3 class="font-medium truncate">{{ b.name }}</h3>
            <p class="text-[10px] mt-0.5 uppercase tracking-[0.08em] font-semibold text-[color:var(--color-text-subtle)]">
              Límite {{ fmt(b.monthly_limit) }}
            </p>
          </div>
        </div>
      </header>

      <div>
        <div class="flex items-center justify-between text-xs mb-1.5">
          <span class="text-[color:var(--color-text-muted)] tabular-nums">
            {{ fmt(b.spent) }} / {{ fmt(b.monthly_limit) }}
          </span>
          <span
            class="tabular-nums font-medium"
            :style="{ color: `var(${b.cssVar})` }"
          >
            {{ b.pct.toFixed(1) }}%
          </span>
        </div>
        <div class="h-2 rounded-full bg-[color:var(--color-surface-elevated)] overflow-hidden">
          <div
            class="h-full transition-all"
            :style="{
              width: `${b.barWidth}%`,
              backgroundColor: `var(${b.cssVar})`,
            }"
          />
        </div>
      </div>

      <p
        class="text-xs tabular-nums"
        :style="{ color: b.overspent ? 'var(--color-negative)' : 'var(--color-text-muted)' }"
      >
        <template v-if="b.overspent">
          Te pasaste por <span class="font-medium">{{ fmt(b.remainingAbs) }}</span>
        </template>
        <template v-else>
          Te quedan <span class="font-medium text-[color:var(--color-text-primary)]">{{ fmt(b.remaining) }}</span>
        </template>
      </p>
    </li>
  </ul>
</template>
