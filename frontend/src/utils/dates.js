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
 * Lista canónica de presets de fecha para los filtros de rango. El orden importa:
 * `detectPreset` recorre en este orden y devuelve la primera coincidencia.
 *
 * Mantener "today" antes de "this_week" / "this_month" para que un rango
 * `from == to == hoy` se detecte como "today", no como "this_week" en lunes
 * ni como "this_month" si hoy es 1.
 */
export const DATE_PRESETS = [
  { key: 'today', label: 'Hoy' },
  { key: 'this_week', label: 'Esta semana' },
  { key: 'this_month', label: 'Este mes' },
  { key: 'last_month', label: 'Mes pasado' },
  { key: 'last_30_days', label: 'Últimos 30 días' },
  { key: 'last_90_days', label: 'Últimos 90 días' },
  { key: 'this_year', label: 'Este año' },
]

/**
 * Devuelve `{ from, to }` en ISO `YYYY-MM-DD` para el preset solicitado.
 *
 * Reglas semánticas:
 * - `today`: from = to = hoy.
 * - `this_week`: lunes de esta semana → hoy (semana ISO; lunes = 1).
 * - `this_month`: día 1 del mes en curso → hoy.
 * - `last_month`: rango completo del mes anterior.
 * - `last_30_days` / `last_90_days`: inclusivos del día actual (hoy - (N-1) → hoy = N días).
 * - `this_year`: 1 ene del año actual → hoy.
 *
 * Todas las operaciones usan fecha local del navegador, nunca UTC, y usan
 * `setDate(getDate() - N)` para evitar bugs DST en "Últimos N días".
 *
 * @param {string} presetKey una clave de `DATE_PRESETS`.
 * @param {Date} today por defecto `new Date()`; inyectable para tests.
 * @returns {{ from: string, to: string }}
 * @throws {Error} si la clave no está en `DATE_PRESETS`.
 */
export function rangeForPreset(presetKey, today = new Date()) {
  const toDate = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  const toISO = toISODate(toDate)

  switch (presetKey) {
    case 'today':
      return { from: toISO, to: toISO }

    case 'this_week': {
      // getDay(): 0=domingo, 1=lunes, ..., 6=sábado. Semana ISO comienza lunes.
      // Para lunes: offset 0. Para domingo (0): offset 6. Para resto: dow - 1.
      const dow = toDate.getDay()
      const offset = dow === 0 ? 6 : dow - 1
      const monday = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate() - offset)
      return { from: toISODate(monday), to: toISO }
    }

    case 'this_month':
      return { from: firstDayOfMonth(toDate), to: toISO }

    case 'last_month': {
      // mes anterior: setMonth a mes-1; Date normaliza el desbordamiento si día > daysInMonth.
      const firstOfPrev = new Date(toDate.getFullYear(), toDate.getMonth() - 1, 1)
      const lastOfPrev = new Date(toDate.getFullYear(), toDate.getMonth(), 0)
      return { from: toISODate(firstOfPrev), to: toISODate(lastOfPrev) }
    }

    case 'last_30_days':
    case 'last_90_days': {
      const n = presetKey === 'last_30_days' ? 30 : 90
      // setDate con valor negativo retrocede días respetando DST y cambios de mes.
      const from = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate() - (n - 1))
      return { from: toISODate(from), to: toISO }
    }

    case 'this_year': {
      const jan1 = new Date(toDate.getFullYear(), 0, 1)
      return { from: toISODate(jan1), to: toISO }
    }

    default:
      throw new Error(`rangeForPreset: clave de preset desconocida: "${presetKey}"`)
  }
}

/**
 * Dado un rango `{ from, to }`, devuelve la clave de `DATE_PRESETS` cuyo
 * `rangeForPreset(today)` coincide exactamente, o `'custom'` si ninguna lo hace.
 *
 * Valores vacíos, null o no parseables devuelven `'custom'` sin lanzar.
 *
 * @param {string} from ISO `YYYY-MM-DD`.
 * @param {string} to   ISO `YYYY-MM-DD`.
 * @param {Date} today por defecto `new Date()`.
 * @returns {string} clave de preset o `'custom'`.
 */
export function detectPreset(from, to, today = new Date()) {
  if (!from || !to) return 'custom'
  if (typeof from !== 'string' || typeof to !== 'string') return 'custom'

  for (const { key } of DATE_PRESETS) {
    const r = rangeForPreset(key, today)
    if (r.from === from && r.to === to) return key
  }
  return 'custom'
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
