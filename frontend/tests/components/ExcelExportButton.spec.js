import { afterEach, describe, expect, it, vi } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { ref } from 'vue'
import ExcelExportButton from '@/components/finance/ExcelExportButton.vue'

// Estado compartido entre el mock y los tests. ref() real para que Vue lo unwrap.
const downloadMock = vi.fn()
const loadingRef = ref(false)
const errorRef = ref(null)

vi.mock('@/composables/useExcelDownload', () => ({
  useExcelDownload: () => ({
    download: downloadMock,
    loading: loadingRef,
    error: errorRef,
  }),
}))

vi.mock('@/stores/toast', () => ({
  useToastStore: () => ({
    error: vi.fn(),
    success: vi.fn(),
  }),
}))

function mountBtn(props = {}) {
  setActivePinia(createPinia())
  return mount(ExcelExportButton, {
    props: { url: '/x', params: {}, ...props },
  })
}

describe('ExcelExportButton', () => {
  afterEach(() => {
    downloadMock.mockReset()
    loadingRef.value = false
    errorRef.value = null
  })

  it('renderiza con label default y dispara download al click', async () => {
    downloadMock.mockResolvedValue()
    const wrapper = mountBtn({ url: '/api/foo', params: { kind: 'expense' } })

    expect(wrapper.text()).toContain('Exportar a Excel')
    await wrapper.find('button').trigger('click')
    await flushPromises()

    expect(downloadMock).toHaveBeenCalledWith('/api/foo', { kind: 'expense' })
    expect(wrapper.emitted('done')).toBeTruthy()
  })

  it('queda con attribute disabled cuando se pasa disabled=true', () => {
    const wrapper = mountBtn({ disabled: true })
    expect(wrapper.find('button').attributes('disabled')).toBeDefined()
  })

  it('acepta label custom', () => {
    const wrapper = mountBtn({ label: 'Descargar xlsx' })
    expect(wrapper.text()).toContain('Descargar xlsx')
  })

  it('emite error si download lanza', async () => {
    downloadMock.mockRejectedValue(new Error('boom'))
    const wrapper = mountBtn()

    await wrapper.find('button').trigger('click')
    await flushPromises()

    expect(wrapper.emitted('error')).toBeTruthy()
    expect(wrapper.emitted('done')).toBeFalsy()
  })

  it('muestra spinner cuando loading.value es true', async () => {
    loadingRef.value = true
    const wrapper = mountBtn()
    // BaseButton renderiza un span con clase animate-spin cuando loading=true.
    expect(wrapper.find('.animate-spin').exists()).toBe(true)
    expect(wrapper.find('button').attributes('disabled')).toBeDefined()
  })
})
