import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import BudgetsList from '@/components/finance/BudgetsList.vue'

function bucket(overrides = {}) {
  return {
    category_id: 'cat-1',
    name: 'Comida',
    color_slug: 'orange',
    icon_slug: 'shopping-bag',
    monthly_limit: 2000,
    spent: 500,
    remaining: 1500,
    pct_consumed: 25,
    ...overrides,
  }
}

describe('BudgetsList', () => {
  it('usa color verde cuando consumo < 70%', () => {
    const wrapper = mount(BudgetsList, {
      props: { buckets: [bucket({ pct_consumed: 25 })] },
    })

    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-positive')
  })

  it('usa color ámbar cuando consumo 70-100%', () => {
    const wrapper = mount(BudgetsList, {
      props: { buckets: [bucket({ pct_consumed: 85 })] },
    })

    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-warning')
  })

  it('usa color rojo cuando consumo > 100%', () => {
    const wrapper = mount(BudgetsList, {
      props: { buckets: [bucket({ pct_consumed: 115 })] },
    })

    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('--color-negative')
  })

  it('muestra "Te quedan" con el remanente cuando spent < limit', () => {
    const wrapper = mount(BudgetsList, {
      props: {
        buckets: [bucket({ spent: 800, remaining: 1200, pct_consumed: 40 })],
      },
    })

    expect(wrapper.text()).toContain('Te quedan')
    expect(wrapper.text()).toContain('$1,200.00')
  })

  it('muestra "Te pasaste" con el exceso cuando spent > limit', () => {
    const wrapper = mount(BudgetsList, {
      props: {
        buckets: [bucket({ spent: 2500, remaining: -500, pct_consumed: 125 })],
      },
    })

    expect(wrapper.text()).toContain('Te pasaste')
    expect(wrapper.text()).toContain('$500.00')
  })

  it('clampa el width visual de la barra a 100% aunque pct_consumed sea mayor', () => {
    const wrapper = mount(BudgetsList, {
      props: { buckets: [bucket({ pct_consumed: 150 })] },
    })

    const bar = wrapper.find('.h-2 > div')
    expect(bar.attributes('style')).toContain('width: 100%')
  })

  it('renderiza una card por bucket', () => {
    const wrapper = mount(BudgetsList, {
      props: {
        buckets: [
          bucket({ category_id: 'a', name: 'Comida' }),
          bucket({ category_id: 'b', name: 'Transporte' }),
          bucket({ category_id: 'c', name: 'Salud' }),
        ],
      },
    })

    const items = wrapper.findAll('li')
    expect(items).toHaveLength(3)
  })
})
