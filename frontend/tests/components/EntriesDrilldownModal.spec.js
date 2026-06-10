import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import EntriesDrilldownModal from '@/components/finance/EntriesDrilldownModal.vue'

vi.mock('@/api/finance', () => ({
  financeApi: {
    entriesByBucket: vi.fn(),
  },
}))

import { financeApi } from '@/api/finance'

function makeRouter() {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/entries', name: 'entries', component: { template: '<div />' } },
    ],
  })
}

// Stub de BaseModal: el original usa Headless UI Dialog que requiere ResizeObserver
// y hace teleport, lo que oculta el contenido del wrapper.text(). El stub renderiza
// el slot inline cuando open=true para poder asertar la UI del drilldown.
const BaseModalStub = {
  props: ['open', 'title', 'size'],
  template: '<div v-if="open"><slot /></div>',
}

function mountModal({ open = true, filters = { kind: 'expense' } } = {}) {
  const router = makeRouter()
  return mount(EntriesDrilldownModal, {
    props: { open, filters },
    global: {
      plugins: [router],
      stubs: { BaseModal: BaseModalStub },
    },
  })
}

describe('EntriesDrilldownModal', () => {
  afterEach(() => vi.resetAllMocks())

  it('al abrir, fetch el endpoint con los filtros y muestra entries', async () => {
    financeApi.entriesByBucket.mockResolvedValue({
      data: {
        entries: [
          { id: 'e1', occurred_at: '2026-05-12', kind: 'expense', amount: 250, description: 'Café', origin: { name: 'Bolsa' }, destination: null, category: null },
        ],
        truncated: false,
        total_count: 1,
        bucket_label: 'Gastos en Bolsa',
      },
    })

    const wrapper = mountModal()
    await flushPromises()

    expect(financeApi.entriesByBucket).toHaveBeenCalledWith({ kind: 'expense' })
    expect(wrapper.text()).toContain('Café')
    expect(wrapper.text()).toContain('1 de 1 movimientos')
  })

  it('renderiza vacío con mensaje cuando no hay entries', async () => {
    financeApi.entriesByBucket.mockResolvedValue({
      data: { entries: [], truncated: false, total_count: 0, bucket_label: 'Sin nada' },
    })

    const wrapper = mountModal()
    await flushPromises()

    expect(wrapper.text()).toContain('Sin movimientos en este bucket')
  })

  it('muestra aviso de truncado cuando total_count > 100', async () => {
    financeApi.entriesByBucket.mockResolvedValue({
      data: {
        entries: Array.from({ length: 100 }, (_, i) => ({
          id: `e${i}`, occurred_at: '2026-05-01', kind: 'income', amount: 10,
          description: '', origin: null, destination: { name: 'Bolsa' }, category: null,
        })),
        truncated: true,
        total_count: 137,
        bucket_label: 'Ingresos',
      },
    })

    const wrapper = mountModal()
    await flushPromises()

    expect(wrapper.text()).toContain('Mostrando los 100 más recientes de 137')
  })

  it('quita campos vacíos antes de enviar al backend', async () => {
    financeApi.entriesByBucket.mockResolvedValue({
      data: { entries: [], truncated: false, total_count: 0, bucket_label: '' },
    })

    mountModal({ filters: { kind: 'expense', category_id: null, account_id: '', from: '2026-05-01' } })
    await flushPromises()

    expect(financeApi.entriesByBucket).toHaveBeenCalledWith({ kind: 'expense', from: '2026-05-01' })
  })

  it('al click "Ir a Movimientos" navega a /entries con filtros podados', async () => {
    financeApi.entriesByBucket.mockResolvedValue({
      data: {
        entries: [
          { id: 'e1', occurred_at: '2026-05-12', kind: 'expense', amount: 250, description: 'x', origin: { name: 'Bolsa' }, destination: null, category: null },
        ],
        truncated: false,
        total_count: 1,
        bucket_label: 'Gastos',
      },
    })

    const router = makeRouter()
    const pushSpy = vi.spyOn(router, 'push')
    const wrapper = mount(EntriesDrilldownModal, {
      props: { open: true, filters: { kind: 'expense', account_id: 'acc-1', category_id: null } },
      global: { plugins: [router], stubs: { BaseModal: BaseModalStub } },
    })
    await flushPromises()

    await wrapper.get('button:nth-of-type(2)').trigger('click') // "Ir a Movimientos"
    expect(pushSpy).toHaveBeenCalledWith({
      name: 'entries',
      query: { kind: 'expense', account_id: 'acc-1' },
    })
  })
})
