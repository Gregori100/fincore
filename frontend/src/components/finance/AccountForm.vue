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

const form = ref({
  name: '',
  type: 'debit',
  credit_limit: '',
  closing_day: '',
  payment_day: '',
  interest_rate: '',
  minimum_payment_pct: '',
})
const submitting = ref(false)
const errors = ref({})

const isCredit = computed(() => form.value.type === 'credit')

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    const payload = {
      name: form.value.name,
      type: form.value.type,
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

    await finance.createAccount(payload)
    toast.success(`Cuenta "${payload.name}" creada`)
    emit('success')
    emit('close')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? 'No se pudo crear la cuenta')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" @submit.prevent="handleSubmit">
    <BaseInput v-model="form.name" label="Nombre" :error="errors.name" required />

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
          hint="ej. 0.0367"
        />
        <BaseInput
          v-model="form.minimum_payment_pct"
          label="Pago mínimo %"
          type="number"
          step="0.0001"
          min="0"
          max="1"
          :error="errors.minimum_payment_pct"
          hint="ej. 0.05"
        />
      </div>
    </template>

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Crear cuenta</BaseButton>
    </footer>
  </form>
</template>
