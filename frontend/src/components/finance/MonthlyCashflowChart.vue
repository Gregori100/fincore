<script setup>
import { computed } from 'vue'
import { Bar } from 'vue-chartjs'
import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  LineController,
  LineElement,
  PointElement,
  Title,
  Tooltip,
} from 'chart.js'
import { formatYearMonth } from '@/utils/dates'

// Necesitamos LineController y elementos de línea para el dataset de "neto"
// que va superpuesto a las barras.
ChartJS.register(
  BarElement,
  LineElement,
  PointElement,
  LineController,
  CategoryScale,
  LinearScale,
  Tooltip,
  Legend,
  Title,
)

const props = defineProps({
  // [{ year_month, income, expense, net }] — array continuo (12 elementos)
  months: { type: Array, default: () => [] },
})
const emit = defineEmits(['drilldown'])

function onChartClick(_evt, elements) {
  if (!elements?.length) return
  const el = elements[0]
  const month = props.months[el.index]
  if (!month) return
  // dataset 0=Ingresos, 1=Egresos, 2=Neto (línea). Neto no abre drilldown.
  const datasetIndex = el.datasetIndex
  if (datasetIndex === 0) emit('drilldown', { year_month: month.year_month, kind: 'income' })
  else if (datasetIndex === 1) emit('drilldown', { year_month: month.year_month, kind: 'expense' })
}

/** Resuelve una CSS var oklch a un color real para Chart.js. */
function resolveCss(name) {
  if (typeof window === 'undefined') return '#888'
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || '#888'
}

const fmtCurrency = new Intl.NumberFormat('es-MX', {
  style: 'currency',
  currency: 'MXN',
  maximumFractionDigits: 0,
})

const chartData = computed(() => {
  const positive = resolveCss('--color-positive')
  const negative = resolveCss('--color-negative')
  const accent = resolveCss('--color-accent')

  return {
    labels: props.months.map((m) => formatYearMonth(m.year_month)),
    datasets: [
      {
        type: 'bar',
        label: 'Ingresos',
        data: props.months.map((m) => Number(m.income)),
        backgroundColor: positive,
        borderRadius: 4,
        order: 2,
      },
      {
        type: 'bar',
        label: 'Egresos',
        data: props.months.map((m) => Number(m.expense)),
        backgroundColor: negative,
        borderRadius: 4,
        order: 2,
      },
      {
        type: 'line',
        label: 'Ahorro neto',
        data: props.months.map((m) => Number(m.net)),
        borderColor: accent,
        backgroundColor: accent,
        borderWidth: 2,
        pointRadius: 4,
        pointHoverRadius: 6,
        tension: 0.25,
        order: 1, // se dibuja encima de las barras
      },
    ],
  }
})

const options = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  interaction: { mode: 'index', intersect: false },
  onClick: onChartClick,
  onHover: (evt, els) => {
    if (evt?.native?.target) {
      evt.native.target.style.cursor = els.length ? 'pointer' : 'default'
    }
  },
  scales: {
    x: {
      ticks: { color: resolveCss('--color-text-muted') },
      grid: { display: false },
    },
    y: {
      beginAtZero: true,
      ticks: {
        color: resolveCss('--color-text-muted'),
        callback: (v) => fmtCurrency.format(v),
      },
      grid: { color: resolveCss('--color-border') },
    },
  },
  plugins: {
    legend: {
      position: 'top',
      align: 'end',
      labels: {
        color: resolveCss('--color-text-muted'),
        usePointStyle: true,
        boxWidth: 8,
      },
    },
    tooltip: {
      callbacks: {
        label: (ctx) => `${ctx.dataset.label}: ${fmtCurrency.format(ctx.parsed.y)}`,
      },
    },
  },
}))
</script>

<template>
  <div class="relative h-80">
    <Bar v-if="months.length" :data="chartData" :options="options" />
  </div>
</template>
