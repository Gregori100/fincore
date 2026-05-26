/**
 * Helpers ligeros de fecha para reportes y filtros. Sin dependencia externa;
 * el alcance crece sólo cuando aparezca una necesidad nueva.
 */

/** Formatea un Date a string ISO `YYYY-MM-DD` (sin zona horaria). */
export function toISODate(date = new Date()) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

/** Devuelve `YYYY-MM-DD` del día 1 del mes de la fecha dada. */
export function firstDayOfMonth(date = new Date()) {
  return toISODate(new Date(date.getFullYear(), date.getMonth(), 1))
}

/** Devuelve `YYYY-MM-DD` del último día del mes de la fecha dada. */
export function lastDayOfMonth(date = new Date()) {
  return toISODate(new Date(date.getFullYear(), date.getMonth() + 1, 0))
}

/**
 * Número decimal de semanas que cubre el rango (inclusivo en ambos extremos).
 * `(to - from + 1 día) / 7`. Mínimo 1 semana para evitar divisiones por
 * fracciones absurdamente chicas en rangos de 1-2 días (que dividirían el
 * total mostrado y darían un "promedio semanal" inflado).
 */
export function weeksInRange(fromISO, toISO) {
  const from = new Date(`${fromISO}T00:00:00`)
  const to = new Date(`${toISO}T00:00:00`)
  const days = Math.max(1, Math.round((to - from) / 86400000) + 1)
  return Math.max(1, days / 7)
}

/**
 * Devuelve `{ from, to }` para los últimos N meses incluyendo el actual.
 * `from` es el primer día del mes (N-1) meses atrás; `to` es hoy.
 * Ej. hoy 2026-05-15, lastNMonths(12) → { from: '2025-06-01', to: '2026-05-15' }.
 */
export function lastNMonths(n) {
  const today = new Date()
  const from = new Date(today.getFullYear(), today.getMonth() - (n - 1), 1)
  return { from: toISODate(from), to: toISODate(today) }
}

const SHORT_MONTHS_ES = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']

/**
 * Convierte 'YYYY-MM' a una etiqueta corta tipo 'May 26'. Útil para el eje X
 * del gráfico de cashflow.
 */
export function formatYearMonth(ym) {
  const [y, m] = (ym ?? '').split('-').map((s) => parseInt(s, 10))
  if (!y || !m) return ym ?? ''
  return `${SHORT_MONTHS_ES[m - 1]} ${String(y).slice(-2)}`
}

/**
 * Rango de fechas que el backend del módulo Plan acepta
 * (CreatePlannedEvent::validateDateRange): [hoy − 1 año, hoy + 5 años]. El
 * cliente valida lo mismo para evitar un 422 sorpresa al crear eventos.
 */
export function isWithinPlanDateRange(dateStr) {
  if (!dateStr) return false
  const d = new Date(`${dateStr}T00:00:00`)
  if (Number.isNaN(d.getTime())) return false
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const min = new Date(today.getFullYear() - 1, today.getMonth(), today.getDate())
  const max = new Date(today.getFullYear() + 5, today.getMonth(), today.getDate())
  return d >= min && d <= max
}

/** Devuelve `YYYY-MM` del mes actual. */
export function currentYearMonth() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** Devuelve el `YYYY-MM` del mes inmediato anterior al ym pasado. */
export function previousYearMonth(ym) {
  const [y, m] = ym.split('-').map((s) => parseInt(s, 10))
  // m - 1 (índice 0) - 1 (mes anterior) = m - 2. Date normaliza overflow.
  const date = new Date(y, m - 2, 1)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

/**
 * Rellena con ceros los meses faltantes entre `from` y `to`. Recibe los rows
 * del backend (sólo meses con actividad) y devuelve la serie continua para
 * que el gráfico tenga 12 barras siempre, aunque haya meses vacíos.
 *
 * @param {Array<{year_month: string, income: number, expense: number, net: number}>} rows
 * @param {string} fromISO `YYYY-MM-DD` del límite inferior
 * @param {string} toISO   `YYYY-MM-DD` del límite superior
 */
export function fillMissingMonths(rows, fromISO, toISO) {
  const byKey = new Map(rows.map((r) => [r.year_month, r]))
  const result = []

  const start = new Date(`${fromISO}T00:00:00`)
  const end = new Date(`${toISO}T00:00:00`)
  const cursor = new Date(start.getFullYear(), start.getMonth(), 1)
  const last = new Date(end.getFullYear(), end.getMonth(), 1)

  while (cursor <= last) {
    const ym = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`
    const existing = byKey.get(ym)
    result.push(existing ?? { year_month: ym, income: 0, expense: 0, net: 0 })
    cursor.setMonth(cursor.getMonth() + 1)
  }

  return result
}
