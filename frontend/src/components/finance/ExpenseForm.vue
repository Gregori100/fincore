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

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
  }).format(Number(n ?? 0))
}

const accountOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Saldo: ${fmt(a.balance)}`,
  })),
)
const categoryOptions = computed(() => [
  { value: null, label: 'Sin categorizar' },
  ...finance.categoriesFor('expense').map((c) => ({ value: c.id, label: c.name })),
])

const form = ref({
  account_id: accountOptions.value[0]?.value ?? null,
  amount: '',
  description: '',
  category_id: null,
})

const selectedAccount = computed(() =>
  finance.cashAndDebitAccounts.find((a) => a.id === form.value.account_id),
)
const sourceBalance = computed(() => Number(selectedAccount.value?.balance ?? 0))

function validate() {
  const e = {}
  if (!form.value.account_id) e.account_id = 'Selecciona una cuenta'
  const amount = Number(form.value.amount)
  if (!form.value.amount) {
    e.amount = 'Ingresa un monto'
  } else if (Number.isNaN(amount) || amount <= 0) {
    e.amount = 'El monto debe ser mayor a 0'
  } else if (amount > sourceBalance.value) {
    e.amount = `Excede el saldo disponible (${fmt(sourceBalance.value)})`
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const result = await submit(() =>
    finance.registerExpense({
      account_id: form.value.account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
      category_id: form.value.category_id,
    }),
  )
  if (result.ok) {
    toast.success('Gasto registrado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const payload = result.error.response?.data
    if (!payload?.errors) {
      toast.error(payload?.error ?? 'No se pudo registrar el gasto')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <BaseSelect
      v-model="form.account_id"
      label="Cuenta origen"
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
      :hint="selectedAccount ? `Disponible: ${fmt(sourceBalance)}` : ''"
      :error="errors.amount"
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
      placeholder="ej. supermercado, Uber, ..."
      :error="errors.description"
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Registrar gasto</BaseButton>
    </footer>
  </form>
</template>
