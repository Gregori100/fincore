import { describe, it, expect, beforeEach, vi } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('@/api/plan', () => {
  return {
    default: {
      listEvents: vi.fn(),
      projection: vi.fn(),
      createEvent: vi.fn(),
      updateEvent: vi.fn(),
      deleteEvent: vi.fn(),
      createOverride: vi.fn(),
      updateOverride: vi.fn(),
      deleteOverride: vi.fn(),
    },
  }
})

import { usePlanStore } from '@/stores/plan'
import planApi from '@/api/plan'

const baseProjection = {
  horizon: { from: '2026-05-19', to: '2026-11-19' },
  accounts: [],
  series: {},
  events: [],
}

describe('plan store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
    planApi.projection.mockResolvedValue({ data: baseProjection })
  })

  it('estado inicial', () => {
    const plan = usePlanStore()
    expect(plan.events).toEqual([])
    expect(plan.projection).toBeNull()
    expect(plan.isEmpty).toBe(true)
  })

  it('fetchEvents popula events', async () => {
    planApi.listEvents.mockResolvedValue({ data: { events: [{ id: 'e1', kind: 'income' }] } })
    const plan = usePlanStore()
    await plan.fetchEvents()
    expect(plan.events).toHaveLength(1)
    expect(plan.isEmpty).toBe(false)
  })

  it('createEvent agrega al state y refresca proyección', async () => {
    planApi.createEvent.mockResolvedValue({ data: { event: { id: 'e2', kind: 'expense' } } })
    const plan = usePlanStore()
    await plan.createEvent({ kind: 'expense' })
    expect(plan.events).toContainEqual({ id: 'e2', kind: 'expense' })
    expect(planApi.projection).toHaveBeenCalledOnce()
  })

  it('updateEvent reemplaza el evento existente', async () => {
    planApi.listEvents.mockResolvedValue({ data: { events: [{ id: 'e1', amount: 1000 }] } })
    planApi.updateEvent.mockResolvedValue({ data: { event: { id: 'e1', amount: 2000 }, removed_overrides: 0 } })
    const plan = usePlanStore()
    await plan.fetchEvents()
    await plan.updateEvent('e1', { amount: 2000 })
    expect(plan.events[0].amount).toBe(2000)
  })

  it('deleteEvent quita el evento', async () => {
    planApi.listEvents.mockResolvedValue({ data: { events: [{ id: 'e1' }, { id: 'e2' }] } })
    planApi.deleteEvent.mockResolvedValue({ data: {} })
    const plan = usePlanStore()
    await plan.fetchEvents()
    await plan.deleteEvent('e1')
    expect(plan.events.map((e) => e.id)).toEqual(['e2'])
  })

  it('createOverride lo anida en el evento', async () => {
    planApi.listEvents.mockResolvedValue({ data: { events: [{ id: 'e1', overrides: [] }] } })
    planApi.createOverride.mockResolvedValue({ data: { override: { id: 'o1' } } })
    const plan = usePlanStore()
    await plan.fetchEvents()
    await plan.createOverride('e1', { occurrence_date: '2026-06-01', amount: 100 })
    expect(plan.events[0].overrides).toHaveLength(1)
    expect(plan.events[0].overrides[0].id).toBe('o1')
  })

  it('deleteOverride limpia el override en el evento', async () => {
    planApi.listEvents.mockResolvedValue({ data: { events: [{ id: 'e1', overrides: [{ id: 'o1' }] }] } })
    planApi.deleteOverride.mockResolvedValue({ data: {} })
    const plan = usePlanStore()
    await plan.fetchEvents()
    await plan.deleteOverride('o1')
    expect(plan.events[0].overrides).toEqual([])
  })

  it('fetchProjection setea projection', async () => {
    planApi.projection.mockResolvedValue({ data: { ...baseProjection, accounts: [{ id: 'a1' }] } })
    const plan = usePlanStore()
    await plan.fetchProjection()
    expect(plan.projection.accounts).toHaveLength(1)
  })
})
