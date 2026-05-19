<script setup>
import { ref, computed } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const toast = useToastStore()

const accountOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({ value: a.id, label: a.name })),
)
const categoryOptions = computed(() => [
  { value: null, label: 'Sin categorizar' },
  ...finance.categoriesFor('income').map((c) => ({ value: c.id, label: c.name })),
])

// Hoy en YYYY-MM-DD usando hora local (no UTC).
function todayInputDate() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const form = ref({
  account_id: accountOptions.value[0]?.value ?? null,
  amount: '',
  description: '',
  category_id: null,
  occurred_at: todayInputDate(),
})

function validate() {
  const e = {}
  if (!form.value.account_id) e.account_id = 'Selecciona una cuenta'
  const amount = Number(form.value.amount)
  if (!form.value.amount) {
    e.amount = 'Ingresa un monto'
  } else if (Number.isNaN(amount) || amount <= 0) {
    e.amount = 'El monto debe ser mayor a 0'
  }
  if (!form.value.occurred_at) e.occurred_at = 'Ingresa una fecha'
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const result = await submit(() =>
    finance.registerIncome({
      account_id: form.value.account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
      category_id: form.value.category_id,
      occurred_at: form.value.occurred_at,
    }),
  )
  if (result.ok) {
    toast.success('Ingreso registrado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const payload = result.error.response?.data
    if (!payload?.errors) {
      toast.error(payload?.error ?? 'No se pudo registrar el ingreso')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <BaseSelect
      v-model="form.account_id"
      label="Cuenta destino"
      :options="accountOptions"
      :error="errors.account_id"
      placeholder="Elige una cuenta cash o débito"
      required
    />
    <BaseInput
      v-model="form.amount"
      label="Monto"
      type="number"
      step="0.01"
      min="0.01"
      placeholder="0.00"
      hint="Cantidad recibida (ej. sueldo, transferencia)"
      :error="errors.amount"
      required
    />
    <BaseInput
      v-model="form.occurred_at"
      type="date"
      label="Fecha"
      :error="errors.occurred_at"
      required
    />
    <BaseSelect
      v-model="form.category_id"
      label="Categoría"
      :options="categoryOptions"
    />
    <BaseInput
      v-model="form.description"
      label="Descripción"
      placeholder="ej. sueldo, freelance, ..."
      :error="errors.description"
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Registrar ingreso</BaseButton>
    </footer>
  </form>
</template>
