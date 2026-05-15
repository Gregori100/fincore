import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createWebHistory } from 'vue-router'
import CreditCardSummary from '@/components/finance/CreditCardSummary.vue'

// Router stub: el componente usa RouterLink para los "no configurado".
// Construimos un router minimal con la sola ruta que necesita.
const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/accounts/:uuid', name: 'account-detail', component: { template: '<div/>' } },
  ],
})

function makeCard(overrides = {}) {
  return {
    id: 'card-1',
    name: 'Visa Oro',
    balance: 0,
    credit_limit: 10000,
    available: 10000,
    utilization_pct: 0,
    closing_day: 15,
    payment_day: 5,
    interest_rate: 0.0367,
    minimum_payment_pct: 0.05,
    next_closing_date: '2026-06-15',
    days_to_closing: 24,
    next_payment_date: '2026-06-05',
    days_to_payment: 14,
    current_cycle: { from: '2026-05-16', to: '2026-05-22', charges_total: 0, charges_count: 0 },
    last_cycle: { from: '2026-04-16', to: '2026-05-15', charges_total: 0, charges_count: 0 },
    minimum_payment_estimated: 0,
    ...overrides,
  }
}

function mountCard(card) {
  return mount(CreditCardSummary, {
    props: { card },
    global: { plugins: [router] },
  })
}

describe('CreditCardSummary', () => {
  it('renderiza nombre, deuda y disponible', () => {
    const wrapper = mountCard(makeCard({ balance: 2500, available: 7500, utilization_pct: 25 }))

    expect(wrapper.text()).toContain('Visa Oro')
    expect(wrapper.text()).toContain('$2,500.00')
    expect(wrapper.text()).toContain('$7,500.00')
  })

  it('clamp del % de utilización: 0 → 0, >100 → 100', () => {
    const wrapper = mountCard(makeCard({ utilization_pct: 0 }))
    expect(wrapper.text()).toContain('0.0%')

    const over = mountCard(makeCard({ utilization_pct: 120 }))
    // El text muestra el valor original; el clamp aplica al width visual.
    const bar = over.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('width: 100%')
  })

  it('barra usa color verde cuando uso < 50%', () => {
    const wrapper = mountCard(makeCard({ utilization_pct: 30 }))
    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-positive')
  })

  it('barra usa color ámbar cuando 50 <= uso < 80', () => {
    const wrapper = mountCard(makeCard({ utilization_pct: 65 }))
    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-warning')
  })

  it('barra usa color rojo cuando uso >= 80', () => {
    const wrapper = mountCard(makeCard({ utilization_pct: 92 }))
    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-negative')
  })

  it('muestra "no configurado" cuando closing_day es null', () => {
    const wrapper = mountCard(makeCard({
      closing_day: null,
      next_closing_date: null,
      days_to_closing: null,
      current_cycle: null,
      last_cycle: null,
      minimum_payment_estimated: null,
    }))

    expect(wrapper.text().match(/no configurado/g)?.length).toBeGreaterThanOrEqual(2)
  })

  it('formatea el resumen del ciclo: monto + N movimientos', () => {
    const wrapper = mountCard(makeCard({
      current_cycle: { from: '2026-05-16', to: '2026-05-22', charges_total: 1500, charges_count: 1 },
    }))

    expect(wrapper.text()).toContain('$1,500.00')
    expect(wrapper.text()).toContain('1 movimiento')
  })

  it('pluraliza correctamente cuando count > 1', () => {
    const wrapper = mountCard(makeCard({
      current_cycle: { from: '2026-05-16', to: '2026-05-22', charges_total: 3000, charges_count: 4 },
    }))

    expect(wrapper.text()).toContain('4 movimientos')
  })
})
