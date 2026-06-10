import { afterEach, describe, expect, it, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { ref } from 'vue'
import DateRangePreset from '@/components/finance/DateRangePreset.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import { DATE_PRESETS, rangeForPreset } from '@/utils/dates'

// Stub liviano de BaseSelect: el original usa Headless UI Listbox que requiere
// trabajo extra para clicks programáticos. Para los tests basta exponer un
// <select> nativo que emita el mismo `update:modelValue`.
const BaseSelectStub = {
  props: ['modelValue', 'options', 'label'],
  emits: ['update:modelValue'],
  template: `
    <div>
      <select
        data-testid="preset-select"
        :value="modelValue"
        @change="$emit('update:modelValue', $event.target.value)"
      >
        <option v-for="o in options" :key="o.value" :value="o.value">{{ o.label }}</option>
      </select>
    </div>
  `,
}

function mountComponent(modelValue) {
  return mount(DateRangePreset, {
    props: { modelValue },
    global: { stubs: { BaseSelect: BaseSelectStub } },
  })
}

describe('DateRangePreset', () => {
  afterEach(() => vi.useRealTimers())

  it('detecta el preset activo al mount desde modelValue y oculta los inputs', () => {
    const range = rangeForPreset('this_month')
    const wrapper = mountComponent(range)

    const select = wrapper.get('[data-testid="preset-select"]')
    expect(select.element.value).toBe('this_month')
    expect(wrapper.findAll('input[type="date"]')).toHaveLength(0)
  })

  it('con modelValue que no matchea ningún preset muestra "custom" y los inputs', () => {
    const wrapper = mountComponent({ from: '2026-03-15', to: '2026-04-15' })

    const select = wrapper.get('[data-testid="preset-select"]')
    expect(select.element.value).toBe('custom')
    expect(wrapper.findAll('input[type="date"]')).toHaveLength(2)
  })

  it('cambiar dropdown a un preset emite update:modelValue con el rango calculado', async () => {
    const wrapper = mountComponent(rangeForPreset('this_month'))

    const select = wrapper.get('[data-testid="preset-select"]')
    await select.setValue('last_month')

    const emitted = wrapper.emitted('update:modelValue')
    expect(emitted).toBeTruthy()
    expect(emitted.at(-1)[0]).toEqual(rangeForPreset('last_month'))
  })

  it('cambiar dropdown a "custom" muestra los inputs sin emitir update', async () => {
    const wrapper = mountComponent(rangeForPreset('this_month'))

    const select = wrapper.get('[data-testid="preset-select"]')
    await select.setValue('custom')
    await flushPromises()

    expect(wrapper.findAll('input[type="date"]')).toHaveLength(2)
    expect(wrapper.emitted('update:modelValue')).toBeFalsy()
  })

  it('editar input "Desde" en custom emite update con objeto nuevo y conserva to', async () => {
    const wrapper = mountComponent({ from: '2026-03-15', to: '2026-04-15' })

    const fromInput = wrapper.findAll('input[type="date"]')[0]
    await fromInput.setValue('2026-03-01')

    const emitted = wrapper.emitted('update:modelValue')
    expect(emitted).toBeTruthy()
    expect(emitted.at(-1)[0]).toEqual({ from: '2026-03-01', to: '2026-04-15' })
  })

  it('editar input "Hasta" en custom emite update con objeto nuevo y conserva from', async () => {
    const wrapper = mountComponent({ from: '2026-03-15', to: '2026-04-15' })

    const toInput = wrapper.findAll('input[type="date"]')[1]
    await toInput.setValue('2026-05-01')

    expect(wrapper.emitted('update:modelValue').at(-1)[0]).toEqual({
      from: '2026-03-15',
      to: '2026-05-01',
    })
  })

  it('cambio externo del modelValue a un preset actualiza el dropdown', async () => {
    const wrapper = mountComponent({ from: '2026-03-15', to: '2026-04-15' })
    expect(wrapper.get('[data-testid="preset-select"]').element.value).toBe('custom')

    await wrapper.setProps({ modelValue: rangeForPreset('last_month') })
    await flushPromises()

    expect(wrapper.get('[data-testid="preset-select"]').element.value).toBe('last_month')
    expect(wrapper.findAll('input[type="date"]')).toHaveLength(0)
  })

  it('cambio externo a rango custom abre los inputs', async () => {
    const wrapper = mountComponent(rangeForPreset('this_month'))
    expect(wrapper.findAll('input[type="date"]')).toHaveLength(0)

    await wrapper.setProps({ modelValue: { from: '2026-03-15', to: '2026-04-15' } })
    await flushPromises()

    expect(wrapper.get('[data-testid="preset-select"]').element.value).toBe('custom')
    expect(wrapper.findAll('input[type="date"]')).toHaveLength(2)
  })

  it('mutación parcial del modelValue (reactividad deep) actualiza el dropdown', async () => {
    // Simula el patrón real de las vistas: ref({from, to}) + mutación de propiedad.
    const range = ref(rangeForPreset('this_month'))
    const wrapper = mount(DateRangePreset, {
      props: { modelValue: range.value },
      global: { stubs: { BaseSelect: BaseSelectStub } },
    })
    expect(wrapper.get('[data-testid="preset-select"]').element.value).toBe('this_month')

    // Mutación parcial (no reemplazo del objeto).
    range.value.from = '2026-03-15'
    range.value.to = '2026-04-15'
    await flushPromises()

    expect(wrapper.get('[data-testid="preset-select"]').element.value).toBe('custom')
  })

  it('renderiza el label custom recibido por prop', () => {
    const wrapper = mount(DateRangePreset, {
      props: { modelValue: rangeForPreset('this_month'), label: 'Rango' },
      global: { stubs: { BaseSelect: BaseSelectStub } },
    })
    // El stub recibe el label como prop; lo verificamos en su instancia.
    const selectComp = wrapper.findComponent(BaseSelectStub)
    expect(selectComp.props('label')).toBe('Rango')
  })

  it('expone las 8 opciones correctas (7 presets + custom)', () => {
    const wrapper = mountComponent(rangeForPreset('this_month'))
    const opts = wrapper.findComponent(BaseSelectStub).props('options')

    expect(opts).toHaveLength(8)
    expect(opts.map((o) => o.value)).toEqual([
      ...DATE_PRESETS.map((p) => p.key),
      'custom',
    ])
  })
})
