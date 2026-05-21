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
  // projection.accounts + projection.series + projection.events del endpoint /projection.
  accounts: { type: Array, default: () => [] },
  series: { type: Object, default: () => ({}) },
  events: { type: Array, default: () => [] },
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

const fmtCurrency = new Intl.NumberFormat('es-MX', {
  style: 'currency',
  currency: 'MXN',
  maximumFractionDigits: 0,
})

const KIND_LABEL = {
  income: 'Ingreso',
  expense: 'Gasto',
  credit_expense: 'Cargo tarjeta',
  debt_payment: 'Pago tarjeta',
}

// Mapa: por cada accountId, set de fechas donde hubo un evento que tocó esa cuenta.
// Sirve para pintar puntos visibles solo en esos días.
const eventDatesByAccount = computed(() => {
  const map = new Map()
  for (const ev of props.events) {
    if (ev.skipped) continue
    for (const id of [ev.account_origin_id, ev.account_destination_id]) {
      if (!id) continue
      if (!map.has(id)) map.set(id, new Set())
      map.get(id).add(ev.date)
    }
  }
  return map
})

// Mapa: fecha → lista de eventos del día. Sirve para enriquecer el tooltip.
const eventsByDate = computed(() => {
  const map = new Map()
  for (const ev of props.events) {
    if (ev.skipped) continue
    if (!map.has(ev.date)) map.set(ev.date, [])
    map.get(ev.date).push(ev)
  }
  return map
})

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

    // Puntos visibles SOLO donde hubo un evento que afectó esta cuenta.
    const eventDates = eventDatesByAccount.value.get(acc.id) ?? new Set()
    const pointRadius = labels.map((d) => (eventDates.has(d) ? 4 : 0))
    const pointHoverRadius = labels.map((d) => (eventDates.has(d) ? 6 : 0))

    return {
      label: acc.name,
      data,
      borderColor: color,
      backgroundColor: color,
      tension: 0.15,
      pointRadius,
      pointHoverRadius,
      pointBackgroundColor: color,
      borderWidth: 2,
    }
  })

  return { labels, datasets }
})

// Plugin custom inline para dibujar una línea horizontal punteada en y=0 cuando
// alguna serie cruza el cero. Útil para identificar visualmente saldos negativos
// y deudas saldadas sin instalar `chartjs-plugin-annotation`.
const zeroLinePlugin = {
  id: 'zeroLine',
  afterDraw(chart) {
    const yScale = chart.scales.y
    if (yScale.min > 0 || yScale.max < 0) return
    const y = yScale.getPixelForValue(0)
    const { left, right } = chart.chartArea
    const ctx = chart.ctx
    ctx.save()
    ctx.strokeStyle = resolveCss('--color-text-subtle') || '#666'
    ctx.globalAlpha = 0.5
    ctx.setLineDash([4, 4])
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.moveTo(left, y)
    ctx.lineTo(right, y)
    ctx.stroke()
    ctx.restore()
  },
}

const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  scales: {
    x: { ticks: { maxTicksLimit: 12, autoSkip: true } },
    y: {
      ticks: {
        callback: (v) => fmtCurrency.format(v),
      },
    },
  },
  plugins: {
    legend: { position: 'top' },
    tooltip: {
      callbacks: {
        label: (ctx) => `${ctx.dataset.label}: ${fmtCurrency.format(ctx.parsed.y)}`,
        afterBody: (items) => {
          if (!items.length) return ''
          const date = items[0].label
          const events = eventsByDate.value.get(date) ?? []
          if (!events.length) return ''
          const lines = ['', 'Eventos de este día:']
          for (const ev of events) {
            const sign = ev.kind === 'income' ? '+' : '−'
            lines.push(`  ${KIND_LABEL[ev.kind] ?? ev.kind}: ${sign}${fmtCurrency.format(Math.abs(ev.amount))}`)
          }
          return lines.join('\n')
        },
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
      <Line :data="chartData" :options="chartOptions" :plugins="[zeroLinePlugin]" />
    </div>
  </div>
</template>
