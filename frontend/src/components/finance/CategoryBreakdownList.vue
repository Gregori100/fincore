<script setup>
import { computed } from 'vue'
import { cssVarBySlug, iconBySlug } from '@/constants/categoryCatalog'

const props = defineProps({
  // Todos los buckets (incluido "Sin categorizar" si aplica). Orden cualquiera;
  // este componente reordena por total desc.
  buckets: { type: Array, default: () => [] },
})
const emit = defineEmits(['drilldown'])

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const total = computed(() =>
  props.buckets.reduce((acc, b) => acc + Number(b.total ?? 0), 0),
)

const rows = computed(() => {
  return [...props.buckets]
    .sort((a, b) => Number(b.total) - Number(a.total))
    .map((b) => {
      const t = Number(b.total)
      const count = Number(b.count ?? 0)
      return {
        ...b,
        pct: total.value > 0 ? (t / total.value) * 100 : 0,
        average: count > 0 ? t / count : 0,
        icon: b.icon_slug ? iconBySlug(b.icon_slug) : null,
        cssVar: b.color_slug ? cssVarBySlug(b.color_slug) : '--color-text-subtle',
      }
    })
})
</script>

<template>
  <ul class="divide-y divide-[color:var(--color-border)]">
    <li
      v-for="b in rows"
      :key="b.category_id ?? 'uncategorized'"
      class="flex items-center justify-between gap-3 py-3 px-2 -mx-2 rounded"
      :class="b.total > 0 ? 'cursor-pointer hover:bg-[color:var(--color-surface-elevated)]/50' : ''"
      @click="b.total > 0 && emit('drilldown', b)"
    >
      <div class="flex items-center gap-3 min-w-0">
        <div
          class="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
          :style="{
            backgroundColor: `color-mix(in oklch, var(${b.cssVar}) 22%, transparent)`,
            color: `var(${b.cssVar})`,
          }"
        >
          <component v-if="b.icon" :is="b.icon" class="h-4 w-4" />
          <span v-else class="text-[10px] uppercase tracking-[0.08em]">—</span>
        </div>
        <div class="min-w-0">
          <p class="text-sm font-medium truncate">{{ b.name }}</p>
          <p class="text-xs text-[color:var(--color-text-muted)] tabular-nums">
            {{ b.count }} mov · prom {{ fmt(b.average) }}
          </p>
        </div>
      </div>
      <div class="text-right shrink-0">
        <p class="text-sm font-semibold tabular-nums">{{ fmt(b.total) }}</p>
        <p class="text-xs text-[color:var(--color-text-muted)] tabular-nums">
          {{ b.pct.toFixed(1) }}%
        </p>
      </div>
    </li>
  </ul>
</template>
