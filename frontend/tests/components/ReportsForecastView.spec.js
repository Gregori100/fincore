import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { createRouter, createMemoryHistory } from 'vue-router'
import ReportsForecastView from '@/views/app/ReportsForecastView.vue'

vi.mock('@/api/finance', () => ({
  financeApi: { reportForecast: vi.fn() },
}))

import { financeApi } from '@/api/finance'

// Stubs livianos para componentes hijo que no son foco del smoke.
const stubs = {
  AppLayout: { template: '<div><slot /></div>' },
  ReportsSubnav: { template: '<nav data-testid="subnav" />' },
  ExcelExportButton: {
    props: ['url', 'params', 'disabled'],
    template: '<button data-testid="export-btn" :disabled="disabled">Export</button>',
  },
  EntriesDrilldownModal: {
    props: ['open', 'filters'],
    template: '<div v-if="open" data-testid="modal" :data-filters="JSON.stringify(filters)" />',
  },
  CategoryBadge: {
    props: ['category'],
    template: '<span data-testid="badge">{{ category.name }}</span>',
  },
  BaseSkeleton: { template: '<div class="skeleton" />' },
  BaseButton: { template: '<button><slot /></button>' },
}

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/dashboard', name: 'dashboard', component: { template: '<div />' } },
      { path: '/entries', name: 'entries', component: { template: '<div />' } },
    ],
  })
}

function mountView() {
  setActivePinia(createPinia())
  return mount(ReportsForecastView, {
    global: {
      plugins: [makeRouter()],
      stubs,
    },
  })
}

const SAMPLE_PAYLOAD = {
  month: '2026-06',
  today: '2026-06-10',
  days_in_month: 30,
  days_elapsed: 10,
  window_from: '2026-03-01',
  window_to: '2026-05-31',
  categories: [
    {
      category_id: 'c1', name: 'Comida', color_slug: 'orange', icon_slug: 'shopping-bag',
      current_spent: 2500, historical_average: 6000, projection: 7500, delta_pct: 25.0,
    },
    {
      category_id: 'c2', name: 'Streaming', color_slug: 'blue', icon_slug: 'cake',
      current_spent: 450, historical_average: 450, projection: 450, delta_pct: 0.0,
    },
    {
      category_id: 'c3', name: 'Ropa', color_slug: 'pink', icon_slug: 'gift',
      current_spent: 0, historical_average: 300, projection: 0, delta_pct: -100.0,
    },
  ],
  totals: {
    current_spent: 2950, historical_average: 6750, projection: 7950, delta_pct: 17.8,
  },
}

describe('ReportsForecastView', () => {
  afterEach(() => vi.resetAllMocks())

  it('renderiza filas de cada categoría con los valores fetcheados', async () => {
    financeApi.reportForecast.mockResolvedValue({ data: SAMPLE_PAYLOAD })

    const wrapper = mountView()
    await flushPromises()

    const rows = wrapper.findAll('[data-testid="forecast-row"]')
    expect(rows).toHaveLength(3)
    expect(rows[0].text()).toContain('Comida')
    expect(rows[1].text()).toContain('Streaming')
    expect(rows[2].text()).toContain('Ropa')
  })

  it('los badges de delta_pct usan la clase correcta según el umbral', async () => {
    financeApi.reportForecast.mockResolvedValue({ data: SAMPLE_PAYLOAD })

    const wrapper = mountView()
    await flushPromises()

    const badges = wrapper.findAll('[data-testid="delta-badge"]')
    // Comida +25% → rojo (>20).
    expect(badges[0].classes().join(' ')).toContain('negative')
    // Streaming 0% → verde (≤0).
    expect(badges[1].classes().join(' ')).toContain('positive')
    // Ropa -100% → verde (≤0).
    expect(badges[2].classes().join(' ')).toContain('positive')
  })

  it('badge para amarillo cuando 0 < delta ≤ 20', async () => {
    const payload = {
      ...SAMPLE_PAYLOAD,
      categories: [{
        category_id: 'c1', name: 'X', color_slug: 'orange', icon_slug: 'gift',
        current_spent: 110, historical_average: 100, projection: 110, delta_pct: 10.0,
      }],
    }
    financeApi.reportForecast.mockResolvedValue({ data: payload })

    const wrapper = mountView()
    await flushPromises()

    const badge = wrapper.find('[data-testid="delta-badge"]')
    expect(badge.classes().join(' ')).toContain('warning')
  })

  it('badge neutral cuando delta_pct es null', async () => {
    const payload = {
      ...SAMPLE_PAYLOAD,
      categories: [{
        category_id: 'c1', name: 'X', color_slug: null, icon_slug: null,
        current_spent: 100, historical_average: 0, projection: 100, delta_pct: null,
      }],
    }
    financeApi.reportForecast.mockResolvedValue({ data: payload })

    const wrapper = mountView()
    await flushPromises()

    const badge = wrapper.find('[data-testid="delta-badge"]')
    expect(badge.text()).toBe('—')
  })

  it('muestra empty state cuando categories.length === 0', async () => {
    financeApi.reportForecast.mockResolvedValue({
      data: {
        ...SAMPLE_PAYLOAD,
        categories: [],
        totals: { current_spent: 0, historical_average: 0, projection: 0, delta_pct: null },
      },
    })

    const wrapper = mountView()
    await flushPromises()

    expect(wrapper.text()).toContain('Aún no tienes suficiente historial')
    expect(wrapper.findAll('[data-testid="forecast-row"]')).toHaveLength(0)
    expect(wrapper.find('[data-testid="export-btn"]').exists()).toBe(false)
  })

  it('click en una fila abre el drill-down con filtros correctos', async () => {
    financeApi.reportForecast.mockResolvedValue({ data: SAMPLE_PAYLOAD })

    const wrapper = mountView()
    await flushPromises()

    await wrapper.findAll('[data-testid="forecast-row"]')[0].trigger('click')
    await flushPromises()

    const modal = wrapper.find('[data-testid="modal"]')
    expect(modal.exists()).toBe(true)
    const filters = JSON.parse(modal.attributes('data-filters'))
    expect(filters).toEqual({
      category_id: 'c1',
      kind: 'expense',
      from: '2026-06-01',
      to: '2026-06-10',
    })
  })
})
