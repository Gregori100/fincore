import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import MonthComparisonList from '@/components/finance/MonthComparisonList.vue'

function bucket(overrides = {}) {
  return {
    category_id: 'cat-1',
    name: 'Comida',
    color_slug: 'orange',
    icon_slug: 'shopping-bag',
    current: 0,
    previous: 0,
    delta: 0,
    delta_pct: 0,
    ...overrides,
  }
}

describe('MonthComparisonList', () => {
  it('marca como "nueva" cuando previous=0 y current>0', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'expense',
        buckets: [bucket({ current: 500, previous: 0, delta: 500, delta_pct: null })],
      },
    })

    expect(wrapper.text()).toContain('nueva')
    // Sin delta_pct, muestra guion en lugar de %.
    expect(wrapper.text()).toMatch(/—/)
  })

  it('marca como "sin actividad este mes" cuando current=0 y previous>0', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'expense',
        buckets: [bucket({ current: 0, previous: 200, delta: -200, delta_pct: -100 })],
      },
    })

    expect(wrapper.text()).toContain('sin actividad este mes')
  })

  it('subir gastos pinta el delta en rojo (mal)', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'expense',
        buckets: [bucket({ current: 1200, previous: 1000, delta: 200, delta_pct: 20 })],
      },
    })

    const html = wrapper.html()
    expect(html).toContain('var(--color-negative)')
    expect(wrapper.text()).toContain('+$200.00')
    expect(wrapper.text()).toContain('+20.0%')
  })

  it('subir ingresos pinta el delta en verde (bien)', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'income',
        buckets: [bucket({ name: 'Salario', current: 3500, previous: 3000, delta: 500, delta_pct: 16.67 })],
      },
    })

    expect(wrapper.html()).toContain('var(--color-positive)')
  })

  it('bajar gastos pinta el delta en verde (bien)', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'expense',
        buckets: [bucket({ current: 800, previous: 1000, delta: -200, delta_pct: -20 })],
      },
    })

    expect(wrapper.html()).toContain('var(--color-positive)')
    expect(wrapper.text()).toContain('-$200.00')
  })

  it('renderiza varios buckets sin colapsar', () => {
    const wrapper = mount(MonthComparisonList, {
      props: {
        kind: 'expense',
        buckets: [
          bucket({ category_id: 'a', name: 'Comida', current: 1200, previous: 1000, delta: 200, delta_pct: 20 }),
          bucket({ category_id: 'b', name: 'Transporte', current: 300, previous: 400, delta: -100, delta_pct: -25 }),
        ],
      },
    })

    const items = wrapper.findAll('li')
    expect(items).toHaveLength(2)
  })
})
