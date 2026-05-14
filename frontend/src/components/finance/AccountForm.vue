<script setup>
import { ref, computed } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseTextarea from '@/components/ui/BaseTextarea.vue'

const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const toast = useToastStore()

const form = ref({
  name: '',
  description: '',
  type: 'debit',
  credit_limit: '',
  closing_day: '',
  payment_day: '',
  interest_rate: '',
  minimum_payment_pct: '',
})

const isCredit = computed(() => form.value.type === 'credit')

function dayValid(v) {
  if (v === '' || v === null) return true
  const n = Number(v)
  return Number.isInteger(n) && n >= 1 && n <= 31
}

function pctValid(v) {
  if (v === '' || v === null) return true
  const n = Number(v)
  return !Number.isNaN(n) && n >= 0 && n <= 1
}

function nameAlreadyTaken(name) {
  const lc = name.toLowerCase()
  return finance.accounts.some((a) => a.name.toLowerCase() === lc)
}

function validate() {
  const e = {}
  const name = form.value.name?.trim() ?? ''
  if (!name) {
    e.name = 'Ingresa un nombre'
  } else if (name.length > 120) {
    e.name = 'Máximo 120 caracteres'
  } else if (nameAlreadyTaken(name)) {
    e.name = 'Ya tienes una cuenta con ese nombre'
  }
  const description = form.value.description?.trim() ?? ''
  if (description.length > 200) {
    e.description = 'Máximo 200 caracteres'
  }
  if (!['debit', 'credit'].includes(form.value.type)) {
    e.type = 'Selecciona un tipo válido'
  }
  if (isCredit.value) {
    const limit = Number(form.value.credit_limit)
    if (!form.value.credit_limit) {
      e.credit_limit = 'Ingresa el límite de crédito'
    } else if (Number.isNaN(limit) || limit <= 0) {
      e.credit_limit = 'El límite debe ser mayor a 0'
    }
    if (!dayValid(form.value.closing_day)) e.closing_day = 'Día entre 1 y 31'
    if (!dayValid(form.value.payment_day)) e.payment_day = 'Día entre 1 y 31'
    if (
      form.value.closing_day !== '' && form.value.payment_day !== ''
      && form.value.closing_day !== null && form.value.payment_day !== null
      && Number(form.value.closing_day) === Number(form.value.payment_day)
    ) {
      e.payment_day = 'El día de corte y pago no pueden ser iguales'
    }
    if (!pctValid(form.value.interest_rate)) {
      e.interest_rate = 'Valor entre 0 y 1 (ej. 0.0367)'
    }
    if (!pctValid(form.value.minimum_payment_pct)) {
      e.minimum_payment_pct = 'Valor entre 0 y 1 (ej. 0.05)'
    }
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const payload = {
    name: form.value.name.trim(),
    type: form.value.type,
  }
  const trimmedDescription = form.value.description?.trim() ?? ''
  if (trimmedDescription) {
    payload.description = trimmedDescription
  }
  if (isCredit.value) {
    payload.credit_limit = Number(form.value.credit_limit)
    if (form.value.closing_day) payload.closing_day = Number(form.value.closing_day)
    if (form.value.payment_day) payload.payment_day = Number(form.value.payment_day)
    if (form.value.interest_rate) payload.interest_rate = Number(form.value.interest_rate)
    if (form.value.minimum_payment_pct) {
      payload.minimum_payment_pct = Number(form.value.minimum_payment_pct)
    }
  }

  const result = await submit(() => finance.createAccount(payload))
  if (result.ok) {
    toast.success(`Cuenta "${payload.name}" creada`)
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const data = result.error.response?.data
    if (!data?.errors) {
      toast.error(data?.error ?? 'No se pudo crear la cuenta')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <BaseInput v-model.trim="form.name" label="Nombre" :error="errors.name" required />

    <BaseTextarea
      v-model.trim="form.description"
      label="Descripción"
      :rows="3"
      :maxlength="200"
      :error="errors.description"
      hint="Notas opcionales (máx. 200 caracteres)"
    />

    <BaseSelect
      v-model="form.type"
      label="Tipo"
      :options="[
        { value: 'debit', label: 'Débito (banco)' },
        { value: 'credit', label: 'Crédito (tarjeta)' },
      ]"
    />

    <template v-if="isCredit">
      <BaseInput
        v-model="form.credit_limit"
        label="Límite de crédito"
        type="number"
        step="0.01"
        min="0"
        placeholder="0.00"
        :error="errors.credit_limit"
        required
      />
      <div class="grid grid-cols-2 gap-3">
        <BaseInput
          v-model="form.closing_day"
          label="Día corte"
          type="number"
          min="1"
          max="31"
          :error="errors.closing_day"
          hint="1-31"
        />
        <BaseInput
          v-model="form.payment_day"
          label="Día pago"
          type="number"
          min="1"
          max="31"
          :error="errors.payment_day"
          hint="1-31"
        />
      </div>
      <div class="grid grid-cols-2 gap-3">
        <BaseInput
          v-model="form.interest_rate"
          label="Tasa mensual"
          type="number"
          step="0.0001"
          min="0"
          max="1"
          :error="errors.interest_rate"
          hint="ej. 0.0367 = 3.67%"
        />
        <BaseInput
          v-model="form.minimum_payment_pct"
          label="Pago mínimo %"
          type="number"
          step="0.0001"
          min="0"
          max="1"
          :error="errors.minimum_payment_pct"
          hint="ej. 0.05 = 5%"
        />
      </div>
    </template>

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Crear cuenta</BaseButton>
    </footer>
  </form>
</template>
