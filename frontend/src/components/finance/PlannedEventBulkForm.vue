<script setup>
import { computed, ref } from 'vue'
import { TrashIcon, PlusIcon } from '@heroicons/vue/20/solid'
import { useFinanceStore } from '@/stores/finance'
import { usePlanStore } from '@/stores/plan'
import { useToastStore } from '@/stores/toast'
import { isWithinPlanDateRange } from '@/utils/dates'
import BaseButton from '@/components/ui/BaseButton.vue'

const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const plan = usePlanStore()
const toast = useToastStore()

const KIND_OPTIONS = [
  { value: 'income', label: 'Ingreso' },
  { value: 'expense', label: 'Gasto' },
  { value: 'credit_expense', label: 'Cargo crédito' },
  { value: 'debt_payment', label: 'Pago tarjeta' },
]
const RECURRENCE_OPTIONS = [
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensual' },
  { value: 'one_off', label: 'Único' },
]
const WEEKDAYS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']

function todayInputDate() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function blankRow() {
  return {
    kind: 'expense',
    account_origin_id: null,
    account_destination_id: null,
    amount: '',
    recurrence_type: 'weekly',
    recurrence_day: 4,
    start_date: todayInputDate(),
  }
}

const rows = ref([blankRow(), blankRow(), blankRow()])
const submitting = ref(false)

function accountConfig(kind) {
  switch (kind) {
    case 'income': return { origin: null, destination: 'cashLike' }
    case 'expense': return { origin: 'cashLike', destination: null }
    case 'credit_expense': return { origin: 'credit', destination: null }
    case 'debt_payment': return { origin: 'cashLike', destination: 'credit' }
    default: return { origin: null, destination: null }
  }
}

function accountOptions(filter) {
  if (!filter) return []
  const list = filter === 'credit' ? finance.creditAccounts : finance.cashAndDebitAccounts
  return list
}

function addRow() {
  rows.value.push(blankRow())
}

function removeRow(i) {
  rows.value.splice(i, 1)
}

function rowErrors(row) {
  const e = {}
  const cfg = accountConfig(row.kind)
  const amount = Number(row.amount)
  if (!row.amount || Number.isNaN(amount) || amount <= 0) e.amount = true
  if (cfg.origin && !row.account_origin_id) e.origin = true
  if (cfg.destination && !row.account_destination_id) e.destination = true
  if (!row.start_date || !isWithinPlanDateRange(row.start_date)) e.start_date = true
  if (row.recurrence_type === 'monthly') {
    const d = Number(row.recurrence_day)
    if (!Number.isInteger(d) || d < 1 || d > 31) e.recurrence_day = true
  }
  return e
}

const allValid = computed(() => rows.value.length > 0 && rows.value.every((r) => Object.keys(rowErrors(r)).length === 0))

function toPayload(row) {
  const cfg = accountConfig(row.kind)
  const payload = {
    kind: row.kind,
    amount: Number(row.amount),
    account_origin_id: cfg.origin ? row.account_origin_id : null,
    account_destination_id: cfg.destination ? row.account_destination_id : null,
    recurrence_type: row.recurrence_type,
    start_date: row.start_date,
  }
  payload.recurrence_day = row.recurrence_type === 'one_off' ? null : Number(row.recurrence_day)
  return payload
}

async function handleSubmit() {
  if (!allValid.value || submitting.value) return // guard anti doble-submit
  submitting.value = true
  try {
    const data = await plan.bulkCreateEvents(rows.value.map(toPayload))
    toast.success(`${data.created ?? rows.value.length} eventos creados`)
    emit('success')
    emit('close')
  } catch (e) {
    // Mensaje diferenciado: dominio (error/code) vs validación (message) vs
    // sin respuesta (red). Antes mostrábamos un genérico ciego que ocultaba la causa.
    const payload = e.response?.data
    if (payload?.error) {
      toast.error(payload.error)
    } else if (payload?.message) {
      toast.error(payload.message)
    } else if (e.response) {
      toast.error(`Error ${e.response.status} al crear los eventos. Reintenta.`)
    } else {
      toast.error('No hay conexión con el servidor. Reintenta.')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
    <p class="text-sm text-[color:var(--color-text-muted)]">
      Agrega varios eventos de golpe. Las filas con campos incompletos se marcan en rojo;
      el botón se habilita cuando todas son válidas. La descripción se puede editar después por evento.
    </p>

    <div class="space-y-2 max-h-[55vh] overflow-y-auto pr-1">
      <!-- Encabezado (solo desktop) -->
      <div class="hidden md:grid grid-cols-[1.1fr_1.4fr_0.9fr_1fr_1.1fr_auto] gap-2 text-[10px] uppercase tracking-wide text-[color:var(--color-text-subtle)] px-1">
        <span>Tipo</span>
        <span>Cuenta(s)</span>
        <span>Monto</span>
        <span>Frecuencia</span>
        <span>Día / Fecha</span>
        <span></span>
      </div>

      <div
        v-for="(row, i) in rows"
        :key="i"
        class="grid grid-cols-2 md:grid-cols-[1.1fr_1.4fr_0.9fr_1fr_1.1fr_auto] gap-2 items-start bg-[color:var(--color-surface-elevated)] md:bg-transparent rounded-lg md:rounded-none p-2 md:p-0"
      >
        <select v-model="row.kind" class="bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] rounded px-2 py-1.5 text-sm">
          <option v-for="o in KIND_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
        </select>

        <div class="space-y-1">
          <select
            v-if="accountConfig(row.kind).origin"
            v-model="row.account_origin_id"
            class="w-full bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1.5 text-sm"
            :class="rowErrors(row).origin ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
          >
            <option :value="null" disabled>De…</option>
            <option v-for="a in accountOptions(accountConfig(row.kind).origin)" :key="a.id" :value="a.id">{{ a.name }}</option>
          </select>
          <select
            v-if="accountConfig(row.kind).destination"
            v-model="row.account_destination_id"
            class="w-full bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1.5 text-sm"
            :class="rowErrors(row).destination ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
          >
            <option :value="null" disabled>A…</option>
            <option v-for="a in accountOptions(accountConfig(row.kind).destination)" :key="a.id" :value="a.id">{{ a.name }}</option>
          </select>
        </div>

        <input
          v-model="row.amount"
          type="number"
          step="0.01"
          min="0.01"
          placeholder="0.00"
          class="bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1.5 text-sm tabular-nums"
          :class="rowErrors(row).amount ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
        />

        <select v-model="row.recurrence_type" class="bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] rounded px-2 py-1.5 text-sm">
          <option v-for="o in RECURRENCE_OPTIONS" :key="o.value" :value="o.value">{{ o.label }}</option>
        </select>

        <select
          v-if="row.recurrence_type === 'weekly'"
          v-model.number="row.recurrence_day"
          class="bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] rounded px-2 py-1.5 text-sm"
        >
          <option v-for="(d, idx) in WEEKDAYS" :key="idx" :value="idx">{{ d }}</option>
        </select>
        <input
          v-else-if="row.recurrence_type === 'monthly'"
          v-model="row.recurrence_day"
          type="number"
          min="1"
          max="31"
          placeholder="Día 1-31"
          class="bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1.5 text-sm"
          :class="rowErrors(row).recurrence_day ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
        />
        <input
          v-else
          v-model="row.start_date"
          type="date"
          class="bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1.5 text-sm"
          :class="rowErrors(row).start_date ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
        />

        <button
          type="button"
          class="p-1.5 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-negative)] hover:bg-[color:var(--color-surface)] justify-self-end"
          aria-label="Eliminar fila"
          @click="removeRow(i)"
        >
          <TrashIcon class="h-4 w-4" />
        </button>

        <!-- Para weekly/monthly mostramos también la fecha de inicio en una segunda línea compacta -->
        <input
          v-if="row.recurrence_type !== 'one_off'"
          v-model="row.start_date"
          type="date"
          title="Fecha de inicio"
          class="col-span-2 md:col-start-5 md:col-span-1 bg-[color:var(--color-surface-elevated)] border rounded px-2 py-1 text-xs text-[color:var(--color-text-muted)]"
          :class="rowErrors(row).start_date ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
        />
      </div>
    </div>

    <button
      type="button"
      class="inline-flex items-center gap-1 text-sm text-[color:var(--color-accent)] hover:underline"
      @click="addRow"
    >
      <PlusIcon class="h-4 w-4" />
      Agregar fila
    </button>

    <footer class="flex gap-2 justify-end pt-2 border-t border-[color:var(--color-border)]">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="button" :loading="submitting" :disabled="!allValid" @click="handleSubmit">
        Guardar ({{ rows.length }})
      </BaseButton>
    </footer>
  </div>
</template>
