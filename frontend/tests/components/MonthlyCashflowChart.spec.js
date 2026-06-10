import { describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import MonthlyCashflowChart from '@/components/finance/MonthlyCashflowChart.vue'

// vue-chartjs envuelve Chart.js. Capturamos las options pasadas al Bar via spy
// para poder invocar onClick directamente sin depender de canvas/Chart.js.
const capturedOptions = { value: null }

vi.mock('vue-chartjs', () => ({
  Bar: {
    name: 'Bar',
    props: ['data', 'options'],
    setup(props) {
      capturedOptions.value = props.options
      return () => null
    },
  },
}))

const MONTHS = [
  { year_month: '2026-04', income: 1000, expense: 500, net: 500 },
  { year_month: '2026-05', income: 2000, expense: 700, net: 1300 },
]

function mountChart() {
  capturedOptions.value = null
  return mount(MonthlyCashflowChart, { props: { months: MONTHS } })
}

describe('MonthlyCashflowChart', () => {
  it('emite drilldown con kind=income al click en barra del dataset 0', async () => {
    const wrapper = mountChart()
    capturedOptions.value.onClick(null, [{ datasetIndex: 0, index: 1 }])

    expect(wrapper.emitted('drilldown')).toEqual([[{ year_month: '2026-05', kind: 'income' }]])
  })

  it('emite drilldown con kind=expense al click en barra del dataset 1', async () => {
    const wrapper = mountChart()
    capturedOptions.value.onClick(null, [{ datasetIndex: 1, index: 0 }])

    expect(wrapper.emitted('drilldown')).toEqual([[{ year_month: '2026-04', kind: 'expense' }]])
  })

  it('NO emite drilldown al click en la línea de Neto (datasetIndex 2)', async () => {
    const wrapper = mountChart()
    capturedOptions.value.onClick(null, [{ datasetIndex: 2, index: 1 }])

    expect(wrapper.emitted('drilldown')).toBeUndefined()
  })

  it('NO emite drilldown si no hay element bajo el click', async () => {
    const wrapper = mountChart()
    capturedOptions.value.onClick(null, [])

    expect(wrapper.emitted('drilldown')).toBeUndefined()
  })
})
