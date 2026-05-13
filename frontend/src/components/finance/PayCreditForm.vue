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

const originOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Saldo: ${a.balance ?? 0}`,
  })),
)

const creditOptions = computed(() =>
  finance.creditAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Deuda: ${a.balance ?? 0}`,
  })),
)

const form = ref({
  origin_id: originOptions.value[0]?.value ?? null,
  credit_account_id: creditOptions.value[0]?.value ?? null,
  amount: '',
  description: '',
})
const submitting = ref(false)
const errors = ref({})

const canSubmit = computed(
  () => originOptions.value.length && creditOptions.value.length,
)

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await finance.payCredit({
      origin_id: form.value.origin_id,
      credit_account_id: form.value.credit_account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
    })
    toast.success('Pago aplicado')
    emit('success')
    emit('close')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? 'No se pudo aplicar el pago')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" @submit.prevent="handleSubmit">
    <p
      v-if="!canSubmit"
      class="text-sm text-[color:var(--color-text-subtle)] italic"
    >
      Necesitas al menos una cuenta cash/débito y una de crédito.
    </p>
    <template v-else>
      <BaseSelect
        v-model="form.origin_id"
        label="Pagar desde"
        :options="originOptions"
        :error="errors.origin_id"
        required
      />
      <BaseSelect
        v-model="form.credit_account_id"
        label="Pagar a"
        :options="creditOptions"
        :error="errors.credit_account_id"
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
        placeholder="ej. abono mensual"
        :error="errors.description"
      />
    </template>

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting" :disabled="!canSubmit">
        Pagar tarjeta
      </BaseButton>
    </footer>
  </form>
</template>
