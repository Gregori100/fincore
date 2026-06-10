import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { useExcelDownload, parseFilename } from '@/composables/useExcelDownload'

vi.mock('@/api/client', () => ({
  default: { get: vi.fn() },
}))

import client from '@/api/client'

describe('parseFilename', () => {
  it('parses filename simple', () => {
    expect(parseFilename('attachment; filename="foo.xlsx"')).toBe('foo.xlsx')
  })

  it('parses filename sin quotes', () => {
    expect(parseFilename('attachment; filename=foo.xlsx')).toBe('foo.xlsx')
  })

  it('parses RFC 5987 filename*', () => {
    expect(parseFilename("attachment; filename*=UTF-8''reporte%20con%20espacios.xlsx"))
      .toBe('reporte con espacios.xlsx')
  })

  it('devuelve null si no hay header', () => {
    expect(parseFilename(null)).toBeNull()
    expect(parseFilename('')).toBeNull()
  })
})

describe('useExcelDownload', () => {
  let createObjectURLSpy
  let revokeObjectURLSpy
  let clickSpy
  // Captura la referencia real ANTES de cualquier vi.spyOn para evitar recursión.
  const realCreateElement = Document.prototype.createElement

  beforeEach(() => {
    createObjectURLSpy = vi.fn(() => 'blob:fake-url')
    revokeObjectURLSpy = vi.fn()
    URL.createObjectURL = createObjectURLSpy
    URL.revokeObjectURL = revokeObjectURLSpy

    clickSpy = vi.fn()
    vi.spyOn(document, 'createElement').mockImplementation(function (tag) {
      const el = realCreateElement.call(document, tag)
      if (tag === 'a') {
        el.click = clickSpy
      }
      return el
    })
  })

  afterEach(() => {
    vi.resetAllMocks()
  })

  it('descarga el blob, clickea el anchor y revoca la URL', async () => {
    client.get.mockResolvedValue({
      data: new Blob(['xlsx-binary']),
      headers: {
        'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'content-disposition': 'attachment; filename="fincore-test.xlsx"',
      },
    })

    const { download } = useExcelDownload()
    await download('/api/finance/reports/by-category/export.xlsx', { kind: 'expense' })

    expect(client.get).toHaveBeenCalledWith(
      '/api/finance/reports/by-category/export.xlsx',
      expect.objectContaining({ params: { kind: 'expense' }, responseType: 'blob' })
    )
    expect(createObjectURLSpy).toHaveBeenCalled()
    expect(clickSpy).toHaveBeenCalledTimes(1)
    expect(revokeObjectURLSpy).toHaveBeenCalledWith('blob:fake-url')
  })

  it('lee filename del header Content-Disposition', async () => {
    client.get.mockResolvedValue({
      data: new Blob([]),
      headers: {
        'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'content-disposition': 'attachment; filename="fincore-cashflow.xlsx"',
      },
    })

    const anchorRef = { value: null }
    document.createElement.mockImplementation(function (tag) {
      const el = realCreateElement.call(document, tag)
      if (tag === 'a') {
        el.click = clickSpy
        anchorRef.value = el
      }
      return el
    })

    const { download } = useExcelDownload()
    await download('/url')

    expect(anchorRef.value.download).toBe('fincore-cashflow.xlsx')
  })

  it('loading.value es true durante el request y false después', async () => {
    let resolve
    client.get.mockReturnValue(new Promise((r) => { resolve = r }))

    const { download, loading } = useExcelDownload()
    const promise = download('/url')

    expect(loading.value).toBe(true)
    resolve({ data: new Blob([]), headers: { 'content-type': 'application/octet-stream', 'content-disposition': 'attachment; filename="x.xlsx"' } })
    await promise
    expect(loading.value).toBe(false)
  })

  it('segundo click durante loading se ignora', async () => {
    let resolve
    client.get.mockReturnValueOnce(new Promise((r) => { resolve = r }))

    const { download } = useExcelDownload()
    const first = download('/url')
    await download('/url') // segundo, debe ser noop

    expect(client.get).toHaveBeenCalledTimes(1)
    resolve({ data: new Blob([]), headers: { 'content-type': 'application/octet-stream', 'content-disposition': 'attachment; filename="x.xlsx"' } })
    await first
  })

  it('si backend responde JSON sobre blob, lanza Error con el mensaje', async () => {
    const errBlob = new Blob([JSON.stringify({ error: 'Falló todo' })], { type: 'application/json' })
    client.get.mockResolvedValue({
      data: errBlob,
      headers: { 'content-type': 'application/json' },
    })

    const { download, error } = useExcelDownload()
    await expect(download('/url')).rejects.toThrow('Falló todo')
    expect(error.value).toBe('Falló todo')
  })
})
