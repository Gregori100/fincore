import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import CategoryCard from '@/components/finance/CategoryCard.vue'

function makeCategory(overrides = {}) {
  return {
    id: 'cat-1',
    name: 'Comida',
    applies_to: 'expense',
    color_slug: 'orange',
    icon_slug: 'shopping-bag',
    monthly_limit: null,
    deleted_at: null,
    ...overrides,
  }
}

describe('CategoryCard - presupuesto inline', () => {
  it('NO muestra el bloque cuando no se pasa budget', () => {
    const wrapper = mount(CategoryCard, { props: { category: makeCategory() } })

    expect(wrapper.text()).not.toContain('%')
    expect(wrapper.find('.h-1\\.5').exists()).toBe(false)
  })

  it('muestra montos y % cuando budget está presente', () => {
    const wrapper = mount(CategoryCard, {
      props: {
        category: makeCategory({ monthly_limit: 2000 }),
        budget: {
          category_id: 'cat-1',
          monthly_limit: 2000,
          spent: 850,
          remaining: 1150,
          pct_consumed: 42.5,
        },
      },
    })

    expect(wrapper.text()).toContain('$850.00')
    expect(wrapper.text()).toContain('$2,000.00')
    expect(wrapper.text()).toContain('42.5%')
  })

  it('barra verde cuando consumo < 70%', () => {
    const wrapper = mount(CategoryCard, {
      props: {
        category: makeCategory({ monthly_limit: 2000 }),
        budget: { monthly_limit: 2000, spent: 500, remaining: 1500, pct_consumed: 25 },
      },
    })

    const bar = wrapper.find('.h-1\\.5 > div')
    expect(bar.attributes('style')).toContain('--color-positive')
  })

  it('barra ámbar cuando 70-100%', () => {
    const wrapper = mount(CategoryCard, {
      props: {
        category: makeCategory({ monthly_limit: 1000 }),
        budget: { monthly_limit: 1000, spent: 800, remaining: 200, pct_consumed: 80 },
      },
    })

    const bar = wrapper.find('.h-1\\.5 > div')
    expect(bar.attributes('style')).toContain('--color-warning')
  })

  it('barra roja cuando > 100% y clamp visual al 100%', () => {
    const wrapper = mount(CategoryCard, {
      props: {
        category: makeCategory({ monthly_limit: 1000 }),
        budget: { monthly_limit: 1000, spent: 1200, remaining: -200, pct_consumed: 120 },
      },
    })

    const bar = wrapper.find('.h-1\\.5 > div')
    expect(bar.attributes('style')).toContain('--color-negative')
    expect(bar.attributes('style')).toContain('width: 100%')
  })
})
