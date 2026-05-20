<script setup>
import { computed, ref } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { usePlanStore } from '@/stores/plan'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const props = defineProps({
  // null = crear; objeto = editar.
  event: { type: Object, default: null },
})
const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const plan = usePlanStore()
const toast = useToastStore()

const KIND_OPTIONS = [
  { value: 'income', label: 'Ingreso' },
  { value: 'expense', label: 'Gasto' },
  { value: 'credit_expense', label: 'Cargo a tarjeta' },
  { value: 'debt_payment', label: 'Pago a tarjeta' },
]
const RECURRENCE_OPTIONS = [
  { value: 'one_off', label: 'Puntual (una fecha)' },
  { value: 'weekly', label: 'Semanal' },
  { value: 'monthly', label: 'Mensual' },
]
const WEEKDAY_OPTIONS = [
  { value: 0, label: 'Lunes' },
  { value: 1, label: 'Martes' },
  { value: 2, label: 'Miércoles' },
  { value: 3, label: 'Jueves' },
  { value: 4, label: 'Viernes' },
  { value: 5, label: 'Sábado' },
  { value: 6, label: 'Domingo' },
]

function todayInputDate() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function isoSlice(iso) {
  return iso ? String(iso).slice(0, 10) : ''
}

const isEdit = computed(() => !!props.event)

const form = ref({
  kind: props.event?.kind ?? 'expense',
  amount: props.event?.amount != null ? String(props.event.amount) : '',
  account_origin_id: props.event?.account_origin_id ?? null,
  account_destination_id: props.event?.account_destination_id ?? null,
  category_id: props.event?.category_id ?? null,
  description: props.event?.description ?? '',
  recurrence_type: props.event?.recurrence_type ?? 'weekly',
  recurrence_day: props.event?.recurrence_day ?? 4,
  start_date: isoSlice(props.event?.start_date) || todayInputDate(),
  end_date: isoSlice(props.event?.end_date) || '',
})

const accountConfig = computed(() => {
  switch (form.value.kind) {
    case 'income':
      return { origin: null, destination: 'cashLike' }
    case 'expense':
      return { origin: 'cashLike', destination: null }
    case 'credit_expense':
      return { origin: 'credit', destination: null }
    case 'debt_payment':
      return { origin: 'cashLike', destination: 'credit' }
    default:
      return { origin: null, destination: null }
  }
})

function accountOptionsFor(filter) {
  if (!filter) return []
  const list = filter === 'credit' ? finance.creditAccounts : finance.cashAndDebitAccounts
  return list.map((a) => ({ value: a.id, label: a.name }))
}

const originOptions = computed(() => accountOptionsFor(accountConfig.value.origin))
const destinationOptions = computed(() => accountOptionsFor(accountConfig.value.destination))

const kindForCategories = computed(() => {
  switch (form.value.kind) {
    case 'income':
      return 'income'
    case 'expense':
    case 'credit_expense':
      return 'expense'
    default:
      return null
  }
})

const categoryOptions = computed(() => {
  const opts = [{ value: null, label: 'Sin categorizar' }]
  if (kindForCategories.value) {
    opts.push(
      ...finance.categoriesFor(kindForCategories.value).map((c) => ({
        value: c.id,
        label: c.name,
      })),
    )
  }
  return opts
})

function validate() {
  const e = {}
  const amount = Number(form.value.amount)
  if (!form.value.amount || Number.isNaN(amount) || amount <= 0) {
    e.amount = 'Ingresa un monto > 0'
  }
  if (accountConfig.value.origin && !form.value.account_origin_id) {
    e.account_origin_id = 'Selecciona una cuenta'
  }
  if (accountConfig.value.destination && !form.value.account_destination_id) {
    e.account_destination_id = 'Selecciona una cuenta'
  }
  if (!form.value.start_date) e.start_date = 'Fecha de inicio requerida'
  if (form.value.recurrence_type === 'weekly') {
    if (form.value.recurrence_day == null || form.value.recurrence_day < 0 || form.value.recurrence_day > 6) {
      e.recurrence_day = 'Día de semana inválido'
    }
  }
  if (form.value.recurrence_type === 'monthly') {
    const d = Number(form.value.recurrence_day)
    if (Number.isNaN(d) || d < 1 || d > 31) {
      e.recurrence_day = 'Día del mes 1-31'
    }
  }
  if (
    form.value.start_date && form.value.end_date
    && form.value.end_date < form.value.start_date
  ) {
    e.end_date = 'No puede ser anterior a la fecha de inicio'
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const payload = {
    amount: Number(form.value.amount),
    account_origin_id: accountConfig.value.origin ? form.value.account_origin_id : null,
    account_destination_id: accountConfig.value.destination ? form.value.account_destination_id : null,
    category_id: kindForCategories.value ? form.value.category_id : null,
    description: form.value.description?.trim() || null,
    recurrence_type: form.value.recurrence_type,
    start_date: form.value.start_date,
    end_date: form.value.end_date || null,
  }
  if (form.value.recurrence_type !== 'one_off') {
    payload.recurrence_day = Number(form.value.recurrence_day)
  } else {
    payload.recurrence_day = null
  }
  if (!isEdit.value) {
    payload.kind = form.value.kind
  }

  const action = isEdit.value
    ? () => plan.updateEvent(props.event.id, payload)
    : () => plan.createEvent(payload)
  const result = await submit(action)
  if (result.ok) {
    toast.success(isEdit.value ? 'Evento actualizado' : 'Evento creado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const data = result.error.response?.data
    if (!data?.errors) {
      toast.error(data?.error ?? 'No se pudo guardar el evento')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <BaseSelect
      v-if="!isEdit"
      v-model="form.kind"
      label="Tipo de evento"
      :options="KIND_OPTIONS"
    />
    <p v-else class="text-xs text-[color:var(--color-text-subtle)] italic">
      El tipo de evento no se puede cambiar tras la creación.
    </p>

    <BaseSelect
      v-if="accountConfig.origin"
      v-model="form.account_origin_id"
      label="Cuenta origen"
      :options="originOptions"
      :error="errors.account_origin_id"
      required
    />
    <BaseSelect
      v-if="accountConfig.destination"
      v-model="form.account_destination_id"
      label="Cuenta destino"
      :options="destinationOptions"
      :error="errors.account_destination_id"
      required
    />

    <BaseInput
      v-model="form.amount"
      type="number"
      step="0.01"
      min="0.01"
      label="Monto"
      :error="errors.amount"
      placeholder="0.00"
      required
    />

    <BaseSelect
      v-model="form.recurrence_type"
      label="Frecuencia"
      :options="RECURRENCE_OPTIONS"
    />

    <BaseSelect
      v-if="form.recurrence_type === 'weekly'"
      v-model="form.recurrence_day"
      label="Día de la semana"
      :options="WEEKDAY_OPTIONS"
      :error="errors.recurrence_day"
    />
    <BaseInput
      v-if="form.recurrence_type === 'monthly'"
      v-model="form.recurrence_day"
      type="number"
      min="1"
      max="31"
      label="Día del mes"
      :error="errors.recurrence_day"
      hint="1-31. Si el mes no tiene ese día, se aplica el último día."
    />

    <BaseInput
      v-model="form.start_date"
      type="date"
      :label="form.recurrence_type === 'one_off' ? 'Fecha' : 'Inicia el'"
      :error="errors.start_date"
      required
    />
    <BaseInput
      v-if="form.recurrence_type !== 'one_off'"
      v-model="form.end_date"
      type="date"
      label="Termina el (opcional)"
      :error="errors.end_date"
      hint="Dejar vacío para que continúe indefinidamente."
    />

    <BaseSelect
      v-if="kindForCategories"
      v-model="form.category_id"
      label="Categoría"
      :options="categoryOptions"
    />

    <BaseInput
      v-model="form.description"
      label="Descripción"
      placeholder="ej. sueldo quincenal, pago Visa..."
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">
        {{ isEdit ? 'Guardar cambios' : 'Crear evento' }}
      </BaseButton>
    </footer>
  </form>
</template>
