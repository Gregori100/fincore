<script setup>
import { ref, computed } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const toast = useToastStore()

const accountOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({ value: a.id, label: a.name })),
)

const form = ref({
  account_id: accountOptions.value[0]?.value ?? null,
  amount: '',
  description: '',
})
const submitting = ref(false)
const errors = ref({})

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await finance.registerIncome({
      account_id: form.value.account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
    })
    toast.success('Ingreso registrado')
    emit('success')
    emit('close')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? 'No se pudo registrar el ingreso')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" @submit.prevent="handleSubmit">
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
      :error="errors.amount"
      required
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
