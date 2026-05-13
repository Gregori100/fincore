import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import StateSummary from '@/components/finance/StateSummary.vue'

describe('StateSummary', () => {
  it('renderiza los tres agregados con formato de moneda', () => {
    const wrapper = mount(StateSummary, {
      props: {
        state: {
          bo: 15200,
          de: 2500,
          cr: 22500,
          burn_rate: 5300,
          credit_usage_pct: 10,
        },
      },
    })

    const text = wrapper.text()
    expect(text).toContain('15,200')
    expect(text).toContain('2,500')
    expect(text).toContain('22,500')
    expect(text).toContain('5,300')
    expect(text).toContain('10.00%')
  })

  it('muestra ceros cuando no hay datos', () => {
    const wrapper = mount(StateSummary, {
      props: {
        state: { bo: 0, de: 0, cr: 0, burn_rate: 0, credit_usage_pct: 0 },
      },
    })

    expect(wrapper.text()).toContain('Bolsa')
    expect(wrapper.text()).toContain('Deudas')
    expect(wrapper.text()).toContain('Crédito')
  })
})
