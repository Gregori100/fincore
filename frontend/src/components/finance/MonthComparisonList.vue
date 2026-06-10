<script setup>
import { computed } from 'vue'
import { ArrowDownIcon, ArrowUpIcon, MinusIcon } from '@heroicons/vue/20/solid'
import { cssVarBySlug, iconBySlug } from '@/constants/categoryCatalog'

const props = defineProps({
  // [{ category_id, name, color_slug, icon_slug, current, previous, delta, delta_pct }]
  buckets: { type: Array, default: () => [] },
  // 'expense' | 'income'. Define qué dirección de delta es "buena" vs "mala".
  kind: { type: String, default: 'expense' },
})
const emit = defineEmits(['drilldown'])

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

function fmtSignedAmount(n) {
  const abs = fmt(Math.abs(n))
  if (n > 0) return `+${abs}`
  if (n < 0) return `-${abs}`
  return abs
}

const rows = computed(() => {
  return props.buckets.map((b) => {
    const current = Number(b.current)
    const previous = Number(b.previous)
    const delta = Number(b.delta)
    const isNew = previous === 0 && current > 0
    const disappeared = current === 0 && previous > 0

    // Color semántico del delta: para expense subir es malo (rojo); para
    // income subir es bueno (verde). Si delta == 0, neutral.
    let tone = 'neutral'
    if (delta > 0) tone = props.kind === 'expense' ? 'bad' : 'good'
    else if (delta < 0) tone = props.kind === 'expense' ? 'good' : 'bad'

    return {
      ...b,
      current,
      previous,
      delta,
      isNew,
      disappeared,
      tone,
      icon: b.icon_slug ? iconBySlug(b.icon_slug) : null,
      cssVar: b.color_slug ? cssVarBySlug(b.color_slug) : '--color-text-subtle',
      formattedDelta: fmtSignedAmount(delta),
    }
  })
})

function toneColor(tone) {
  if (tone === 'good') return 'text-[color:var(--color-positive)]'
  if (tone === 'bad') return 'text-[color:var(--color-negative)]'
  return 'text-[color:var(--color-text-muted)]'
}
</script>

<template>
  <ul class="divide-y divide-[color:var(--color-border)]">
    <li
      v-for="b in rows"
      :key="b.category_id ?? 'uncategorized'"
      class="flex items-center justify-between gap-3 py-3 px-2 -mx-2 rounded"
      :class="b.current > 0 ? 'cursor-pointer hover:bg-[color:var(--color-surface-elevated)]/50' : ''"
      @click="b.current > 0 && emit('drilldown', b)"
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
          <p class="text-sm font-medium truncate flex items-center gap-2 flex-wrap">
            {{ b.name }}
            <span
              v-if="b.isNew"
              class="text-[10px] font-medium tracking-normal text-[color:var(--color-accent)] bg-[color:var(--color-accent)]/12 border border-[color:var(--color-accent)]/30 px-1.5 py-0.5 rounded"
            >
              nueva
            </span>
            <span
              v-else-if="b.disappeared"
              class="text-[10px] font-medium tracking-normal text-[color:var(--color-text-subtle)] bg-[color:var(--color-surface-elevated)] px-1.5 py-0.5 rounded"
            >
              sin actividad este mes
            </span>
          </p>
          <p class="text-xs text-[color:var(--color-text-muted)] tabular-nums mt-0.5">
            <span class="text-[color:var(--color-text-primary)]">{{ fmt(b.current) }}</span>
            <span class="mx-1.5">·</span>
            antes {{ fmt(b.previous) }}
          </p>
        </div>
      </div>
      <div class="text-right shrink-0">
        <p class="text-sm font-semibold tabular-nums flex items-center justify-end gap-1" :class="toneColor(b.tone)">
          <ArrowUpIcon v-if="b.delta > 0" class="h-3.5 w-3.5" />
          <ArrowDownIcon v-else-if="b.delta < 0" class="h-3.5 w-3.5" />
          <MinusIcon v-else class="h-3.5 w-3.5" />
          {{ b.formattedDelta }}
        </p>
        <p class="text-xs tabular-nums" :class="toneColor(b.tone)">
          <template v-if="b.delta_pct !== null && b.delta_pct !== undefined">
            {{ b.delta_pct > 0 ? '+' : '' }}{{ b.delta_pct.toFixed(1) }}%
          </template>
          <template v-else>—</template>
        </p>
      </div>
    </li>
  </ul>
</template>
