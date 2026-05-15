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
