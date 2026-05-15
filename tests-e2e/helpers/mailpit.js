/**
 * Cliente mínimo para la API de Mailpit (http://localhost:8025/api/v1).
 *
 * Mailpit es el SMTP de dev; aquí lo usamos solo para extraer links de
 * verificación de email durante los tests. No mantenemos estado: cada test
 * que necesite inspeccionar correos llama directo a estas funciones.
 *
 * Docs API: https://github.com/axllent/mailpit/wiki/HTTP-API
 */
const MAILPIT_BASE = 'http://localhost:8025/api/v1'

/**
 * Busca el correo de verificación más reciente dirigido al email dado.
 * Reintenta unos segundos porque el envío SMTP no es instantáneo.
 *
 * @returns {Promise<{subject: string, text: string, html: string}>}
 */
export async function waitForVerificationEmail(email, { timeoutMs = 8000 } = {}) {
  const deadline = Date.now() + timeoutMs
  while (Date.now() < deadline) {
    const res = await fetch(`${MAILPIT_BASE}/search?query=to:${encodeURIComponent(email)}`)
    if (res.ok) {
      const data = await res.json()
      const match = (data.messages ?? []).find((m) =>
        /verif/i.test(m.Subject ?? ''),
      )
      if (match) {
        const detail = await fetch(`${MAILPIT_BASE}/message/${match.ID}`)
        if (detail.ok) {
          const body = await detail.json()
          return {
            subject: body.Subject ?? '',
            text: body.Text ?? '',
            html: body.HTML ?? '',
          }
        }
      }
    }
    await new Promise((r) => setTimeout(r, 300))
  }
  throw new Error(`No llegó correo de verificación para ${email} en ${timeoutMs}ms`)
}

/**
 * Extrae el primer URL absoluto que apunte al endpoint de verify del API.
 * El link real incluye signature + expires; lo devolvemos tal cual.
 */
export function extractVerificationLink(body) {
  const haystack = `${body.text}\n${body.html}`
  // El link va al backend (puerto 83 en dev) bajo /api/auth/email/verify/{id}/{hash}
  const re = /https?:\/\/[^\s"'<>]+\/api\/auth\/email\/verify\/[^\s"'<>]+/i
  const match = haystack.match(re)
  if (!match) {
    throw new Error('No se encontró link de verificación en el correo')
  }
  // Mailpit a veces escapa & como &amp; en el HTML.
  return match[0].replace(/&amp;/g, '&')
}

/**
 * Borra todos los correos del buzón. Útil entre tests para no acumular ruido.
 */
export async function purgeAllEmails() {
  await fetch(`${MAILPIT_BASE}/messages`, { method: 'DELETE' })
}
