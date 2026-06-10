import { describe, expect, it } from 'vitest'
import { DATE_PRESETS, rangeForPreset, detectPreset } from '@/utils/dates'

// Día base para los tests "normales": miércoles 10 de junio de 2026.
const BASE = new Date(2026, 5, 10)

describe('DATE_PRESETS', () => {
  it('expone exactamente 7 presets en orden estable', () => {
    expect(DATE_PRESETS.map((p) => p.key)).toEqual([
      'today',
      'this_week',
      'this_month',
      'last_month',
      'last_30_days',
      'last_90_days',
      'this_year',
    ])
  })

  it('cada preset tiene label no vacío', () => {
    for (const p of DATE_PRESETS) {
      expect(typeof p.label).toBe('string')
      expect(p.label.length).toBeGreaterThan(0)
    }
  })
})

describe('rangeForPreset (today = mié 10 jun 2026)', () => {
  it('today → from = to = hoy', () => {
    expect(rangeForPreset('today', BASE)).toEqual({ from: '2026-06-10', to: '2026-06-10' })
  })

  it('this_week → from = lunes de la semana, to = hoy', () => {
    expect(rangeForPreset('this_week', BASE)).toEqual({ from: '2026-06-08', to: '2026-06-10' })
  })

  it('this_month → from = día 1 del mes, to = hoy', () => {
    expect(rangeForPreset('this_month', BASE)).toEqual({ from: '2026-06-01', to: '2026-06-10' })
  })

  it('last_month → rango completo del mes anterior', () => {
    expect(rangeForPreset('last_month', BASE)).toEqual({ from: '2026-05-01', to: '2026-05-31' })
  })

  it('last_30_days → hoy − 29 a hoy (inclusivo, total 30 días)', () => {
    expect(rangeForPreset('last_30_days', BASE)).toEqual({ from: '2026-05-12', to: '2026-06-10' })
  })

  it('last_90_days → hoy − 89 a hoy (10 jun - 89 días = 13 mar)', () => {
    expect(rangeForPreset('last_90_days', BASE)).toEqual({ from: '2026-03-13', to: '2026-06-10' })
  })

  it('this_year → 1 ene del año actual a hoy', () => {
    expect(rangeForPreset('this_year', BASE)).toEqual({ from: '2026-01-01', to: '2026-06-10' })
  })

  it('clave inválida lanza Error citando la clave', () => {
    expect(() => rangeForPreset('invalid', BASE)).toThrow(/invalid/)
    expect(() => rangeForPreset('', BASE)).toThrow(/rangeForPreset/)
  })
})

describe('rangeForPreset — casos borde', () => {
  it('hoy es lunes → this_week devuelve from = to = hoy', () => {
    const monday = new Date(2026, 5, 8) // lun 8 jun 2026
    expect(rangeForPreset('this_week', monday)).toEqual({ from: '2026-06-08', to: '2026-06-08' })
  })

  it('hoy es domingo → this_week devuelve lunes anterior a hoy', () => {
    const sunday = new Date(2026, 5, 14) // dom 14 jun 2026
    expect(rangeForPreset('this_week', sunday)).toEqual({ from: '2026-06-08', to: '2026-06-14' })
  })

  it('hoy es 1 del mes → this_month devuelve from = to = hoy', () => {
    const firstOfMonth = new Date(2026, 5, 1)
    expect(rangeForPreset('this_month', firstOfMonth)).toEqual({ from: '2026-06-01', to: '2026-06-01' })
  })

  it('último día febrero (no bisiesto): last_month en mar 2026 → 2026-02-01 a 2026-02-28', () => {
    const mar1 = new Date(2026, 2, 1)
    expect(rangeForPreset('last_month', mar1)).toEqual({ from: '2026-02-01', to: '2026-02-28' })
  })

  it('último día febrero (bisiesto): last_month en mar 2024 → 2024-02-01 a 2024-02-29', () => {
    const mar15Leap = new Date(2024, 2, 15)
    expect(rangeForPreset('last_month', mar15Leap)).toEqual({ from: '2024-02-01', to: '2024-02-29' })
  })

  it('último día abril (mes de 30): last_month en may → 2026-04-01 a 2026-04-30', () => {
    const may15 = new Date(2026, 4, 15)
    expect(rangeForPreset('last_month', may15)).toEqual({ from: '2026-04-01', to: '2026-04-30' })
  })

  it('semana ISO cruzando año: mié 1 ene 2026 → from = lun 29 dic 2025', () => {
    const jan1Wed = new Date(2026, 0, 1)
    expect(rangeForPreset('this_week', jan1Wed)).toEqual({ from: '2025-12-29', to: '2026-01-01' })
  })

  it('last_30_days cruzando año: hoy = 1 ene 2026 → from = 3 dic 2025', () => {
    const jan1 = new Date(2026, 0, 1)
    expect(rangeForPreset('last_30_days', jan1)).toEqual({ from: '2025-12-03', to: '2026-01-01' })
  })

  it('last_month cuando hoy es enero → diciembre del año anterior', () => {
    const jan15 = new Date(2026, 0, 15)
    expect(rangeForPreset('last_month', jan15)).toEqual({ from: '2025-12-01', to: '2025-12-31' })
  })
})

describe('detectPreset (today = mié 10 jun 2026)', () => {
  it('detecta cada uno de los 7 presets desde su rango propio', () => {
    for (const { key } of DATE_PRESETS) {
      const r = rangeForPreset(key, BASE)
      expect(detectPreset(r.from, r.to, BASE)).toBe(key)
    }
  })

  it('un rango que no matchea ningún preset → custom', () => {
    expect(detectPreset('2026-03-15', '2026-04-15', BASE)).toBe('custom')
  })

  it('strings vacíos → custom', () => {
    expect(detectPreset('', '', BASE)).toBe('custom')
    expect(detectPreset('2026-06-10', '', BASE)).toBe('custom')
    expect(detectPreset('', '2026-06-10', BASE)).toBe('custom')
  })

  it('null o undefined → custom sin lanzar', () => {
    expect(detectPreset(null, null, BASE)).toBe('custom')
    expect(detectPreset(undefined, undefined, BASE)).toBe('custom')
  })

  it('tipos no-string → custom sin lanzar', () => {
    expect(detectPreset(20260610, 20260610, BASE)).toBe('custom')
  })

  it('strings no parseables → custom sin lanzar', () => {
    expect(detectPreset('not-a-date', 'whatever', BASE)).toBe('custom')
  })

  it('orden estable: "today" gana sobre "this_week" cuando from = to = lunes (hoy es lunes)', () => {
    const monday = new Date(2026, 5, 8)
    // today → { from: 2026-06-08, to: 2026-06-08 }
    // this_week → { from: 2026-06-08, to: 2026-06-08 } también
    // El orden de DATE_PRESETS pone 'today' antes; ese es el resultado esperado.
    expect(detectPreset('2026-06-08', '2026-06-08', monday)).toBe('today')
  })

  it('today=hoy, default today = new Date() también funciona', () => {
    const now = new Date()
    const r = rangeForPreset('today', now)
    expect(detectPreset(r.from, r.to)).toBe('today')
  })
})
