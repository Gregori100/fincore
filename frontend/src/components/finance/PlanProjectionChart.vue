<script setup>
import { computed } from 'vue'
import { Line } from 'vue-chartjs'
import {
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  LineElement,
  PointElement,
  Title,
  Tooltip,
} from 'chart.js'

ChartJS.register(
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  Legend,
  Title,
)

const props = defineProps({
  // projection.accounts + projection.series del endpoint /projection.
  accounts: { type: Array, default: () => [] },
  series: { type: Object, default: () => ({}) },
})

function resolveCss(name) {
  if (typeof window === 'undefined') return '#888'
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || '#888'
}

const PALETTE = [
  '--color-accent',
  '--color-positive',
  '--color-warning',
  '--color-negative',
  '--color-text-muted',
]

// Concatena todas las fechas únicas y las ordena cronológicamente. Las series
// individuales pueden tener tamaños distintos según cuántos eventos las afectan;
// las normalizamos al eje X común usando el último valor conocido.
const chartData = computed(() => {
  if (!props.accounts.length) return { labels: [], datasets: [] }

  const allDates = new Set()
  for (const accountId of Object.keys(props.series)) {
    for (const point of props.series[accountId]) {
      allDates.add(point.date)
    }
  }
  const labels = Array.from(allDates).sort()

  const datasets = props.accounts.map((acc, idx) => {
    const color = resolveCss(PALETTE[idx % PALETTE.length])
    const points = props.series[acc.id] ?? []
    const byDate = new Map(points.map((p) => [p.date, Number(p.balance)]))
    // Forward-fill: usa el último valor conocido cuando la serie no tiene punto en esa fecha.
    let last = points[0]?.balance ?? acc.initial_balance
    const data = labels.map((d) => {
      if (byDate.has(d)) last = byDate.get(d)
      return last
    })
    return {
      label: acc.name,
      data,
      borderColor: color,
      backgroundColor: color,
      tension: 0.15,
      pointRadius: 0,
      pointHoverRadius: 4,
      borderWidth: 2,
    }
  })

  return { labels, datasets }
})

const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  scales: {
    x: { ticks: { maxTicksLimit: 12, autoSkip: true } },
    y: {
      ticks: {
        callback: (v) => new Intl.NumberFormat('es-MX', {
          style: 'currency',
          currency: 'MXN',
          maximumFractionDigits: 0,
        }).format(v),
      },
    },
  },
  plugins: {
    legend: { position: 'top' },
    tooltip: {
      callbacks: {
        label: (ctx) => `${ctx.dataset.label}: ${new Intl.NumberFormat('es-MX', {
          style: 'currency',
          currency: 'MXN',
        }).format(ctx.parsed.y)}`,
      },
    },
  },
}))
</script>

<template>
  <div class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4">
    <div v-if="!accounts.length" class="text-sm text-[color:var(--color-text-subtle)] italic">
      Sin cuentas activas para proyectar.
    </div>
    <div v-else class="relative h-64 sm:h-80">
      <Line :data="chartData" :options="chartOptions" />
    </div>
  </div>
</template>
