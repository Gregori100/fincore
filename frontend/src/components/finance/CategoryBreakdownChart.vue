<script setup>
import { computed } from 'vue'
import { Doughnut } from 'vue-chartjs'
import {
  ArcElement,
  Chart as ChartJS,
  Legend,
  Title,
  Tooltip,
} from 'chart.js'
import { COLORS, cssVarBySlug } from '@/constants/categoryCatalog'

ChartJS.register(ArcElement, Tooltip, Legend, Title)

const props = defineProps({
  // [{ name, color_slug, icon_slug, total, count }] — pre-agrupados (top N + "Otras")
  buckets: { type: Array, default: () => [] },
})

/**
 * Para colorear los segmentos: resolvemos la CSS var a un color real con
 * `getComputedStyle`. Chart.js no entiende `var(...)`, necesita rgb/hex/oklch.
 */
function resolveColor(slug) {
  const cssVar = cssVarBySlug(slug)
  if (typeof window === 'undefined') return '#888'
  const value = getComputedStyle(document.documentElement).getPropertyValue(cssVar).trim()
  return value || '#888'
}

// Fallback colors para buckets sin slug (Sin categorizar / Otras).
const FALLBACKS = ['#9aa0aa', '#7f828c']

const chartData = computed(() => {
  const labels = props.buckets.map((b) => b.name)
  const data = props.buckets.map((b) => Number(b.total))
  const backgroundColor = props.buckets.map((b, i) =>
    b.color_slug ? resolveColor(b.color_slug) : FALLBACKS[i % FALLBACKS.length],
  )

  return {
    labels,
    datasets: [
      {
        data,
        backgroundColor,
        borderColor: 'transparent',
        borderWidth: 0,
        hoverOffset: 8,
      },
    ],
  }
})

const totalLabel = computed(() => {
  const total = props.buckets.reduce((acc, b) => acc + Number(b.total), 0)
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 0,
  }).format(total)
})

const options = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  cutout: '62%',
  plugins: {
    legend: { display: false }, // la lista al lado ya enumera todo
    tooltip: {
      callbacks: {
        label: (ctx) => {
          const total = ctx.dataset.data.reduce((a, b) => a + b, 0)
          const pct = total ? (ctx.parsed / total) * 100 : 0
          const fmt = new Intl.NumberFormat('es-MX', {
            style: 'currency',
            currency: 'MXN',
          }).format(ctx.parsed)
          return `${ctx.label}: ${fmt} (${pct.toFixed(1)}%)`
        },
      },
    },
  },
}))

void COLORS // mantener la referencia para tree-shaking previsibilidad
</script>

<template>
  <div class="relative h-72">
    <Doughnut v-if="buckets.length" :data="chartData" :options="options" />
    <div
      v-if="buckets.length"
      class="absolute inset-0 flex flex-col items-center justify-center pointer-events-none"
    >
      <span class="text-xs uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
        Total
      </span>
      <span class="text-2xl font-semibold tabular-nums mt-1">
        {{ totalLabel }}
      </span>
    </div>
  </div>
</template>
