import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import CategoryBreakdownList from '@/components/finance/CategoryBreakdownList.vue'

describe('CategoryBreakdownList', () => {
  it('ordena los buckets por total descendente', () => {
    const wrapper = mount(CategoryBreakdownList, {
      props: {
        buckets: [
          { category_id: 'b', name: 'Transporte', color_slug: 'blue', icon_slug: 'truck', total: 300, count: 1 },
          { category_id: 'a', name: 'Comida', color_slug: 'orange', icon_slug: 'shopping-bag', total: 800, count: 4 },
          { category_id: 'c', name: 'Salud', color_slug: 'red', icon_slug: 'heart', total: 150, count: 2 },
        ],
      },
    })

    const items = wrapper.findAll('li')
    expect(items[0].text()).toContain('Comida')
    expect(items[1].text()).toContain('Transporte')
    expect(items[2].text()).toContain('Salud')
  })

  it('calcula el porcentaje del total para cada bucket', () => {
    const wrapper = mount(CategoryBreakdownList, {
      props: {
        buckets: [
          { category_id: 'a', name: 'Comida', color_slug: 'orange', icon_slug: 'shopping-bag', total: 750, count: 3 },
          { category_id: 'b', name: 'Transporte', color_slug: 'blue', icon_slug: 'truck', total: 250, count: 1 },
        ],
      },
    })

    expect(wrapper.text()).toContain('75.0%')
    expect(wrapper.text()).toContain('25.0%')
  })

  it('calcula el promedio por movimiento (total / count)', () => {
    const wrapper = mount(CategoryBreakdownList, {
      props: {
        buckets: [
          { category_id: 'a', name: 'Comida', color_slug: 'orange', icon_slug: 'shopping-bag', total: 600, count: 3 },
        ],
      },
    })

    // 600 / 3 = 200 promedio.
    expect(wrapper.text()).toContain('3 mov')
    expect(wrapper.text()).toContain('$200.00')
  })

  it('soporta bucket "Sin categorizar" con color_slug e icon_slug null', () => {
    const wrapper = mount(CategoryBreakdownList, {
      props: {
        buckets: [
          { category_id: null, name: 'Sin categorizar', color_slug: null, icon_slug: null, total: 500, count: 2 },
        ],
      },
    })

    expect(wrapper.text()).toContain('Sin categorizar')
    // El placeholder visual del avatar muestra "—" cuando no hay icono.
    expect(wrapper.text()).toContain('—')
  })

  it('no rompe cuando count = 0 (promedio queda en cero)', () => {
    const wrapper = mount(CategoryBreakdownList, {
      props: {
        buckets: [
          { category_id: 'a', name: 'Vacía', color_slug: 'gray', icon_slug: 'tag', total: 0, count: 0 },
        ],
      },
    })

    expect(wrapper.text()).toContain('0 mov')
    expect(wrapper.text()).toContain('$0.00')
  })
})
