import { ref } from 'vue'
import client from '@/api/client'

/**
 * Descarga un archivo .xlsx desde el backend respetando bearer auth de Sanctum.
 *
 * Patrón: axios con responseType='blob' (porque <a href> no manda Authorization),
 * lee filename del header Content-Disposition, crea blob URL, click programático,
 * y revoca la URL para liberar memoria.
 *
 * Si el backend devuelve error JSON (4xx/5xx) sobre la respuesta tipo blob, se
 * detecta por Content-Type y se parsea para lanzar un Error con el mensaje real.
 *
 * Devuelve { download, loading, error } reactivos. El segundo click durante un
 * loading=true se ignora silenciosamente para evitar descargas duplicadas.
 */
export function useExcelDownload() {
  const loading = ref(false)
  const error = ref(null)

  async function download(url, params = {}) {
    if (loading.value) return
    loading.value = true
    error.value = null

    try {
      const response = await client.get(url, {
        params,
        responseType: 'blob',
      })

      const contentType = String(response.headers['content-type'] || '')

      // Backend devolvió JSON o HTML pese a responseType=blob → es un error con body.
      // Cubrir text/html también atrapa páginas de error de Laravel en modo debug.
      if (contentType.includes('application/json') || contentType.includes('text/html')) {
        const text = await response.data.text()
        let message
        try {
          const parsed = JSON.parse(text)
          message = parsed.error || parsed.message
        } catch {
          // No es JSON parseable (HTML, texto plano). Mensaje genérico.
          message = 'Error al exportar (respuesta inesperada del servidor)'
        }
        throw new Error(message || 'Error al exportar')
      }

      const filename = parseFilename(response.headers['content-disposition']) || 'fincore-export.xlsx'
      triggerDownload(response.data, filename)
    } catch (e) {
      // Axios envuelve errores HTTP con { response: { data: Blob } }; intentar
      // extraer el mensaje JSON real.
      const blob = e?.response?.data
      if (blob && typeof blob.text === 'function') {
        try {
          const text = await blob.text()
          const parsed = JSON.parse(text)
          error.value = parsed.error || parsed.message || e.message
          throw new Error(error.value)
        } catch (parseErr) {
          // si no parsea, seguimos al fallback
        }
      }
      error.value = e?.message || 'Error al exportar'
      throw e
    } finally {
      loading.value = false
    }
  }

  return { download, loading, error }
}

/**
 * Parsea filename de un header Content-Disposition. Soporta:
 *   attachment; filename="foo.xlsx"
 *   attachment; filename=foo.xlsx
 *   attachment; filename*=UTF-8''foo%20bar.xlsx
 */
export function parseFilename(header) {
  if (!header) return null
  // Prefiere filename*=UTF-8'' (RFC 5987) si está presente.
  const star = /filename\*\s*=\s*(?:UTF-8'')?"?([^";]+)"?/i.exec(header)
  if (star?.[1]) {
    try {
      return decodeURIComponent(star[1])
    } catch {
      return star[1]
    }
  }
  const simple = /filename\s*=\s*"?([^";]+)"?/i.exec(header)
  return simple?.[1] || null
}

function triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob)
  try {
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = filename
    document.body.appendChild(anchor)
    try {
      anchor.click()
    } finally {
      document.body.removeChild(anchor)
    }
  } finally {
    // Garantiza el revoke incluso si appendChild/click/removeChild lanzan.
    URL.revokeObjectURL(url)
  }
}
