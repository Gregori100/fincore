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
  finance.creditAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Disponible: ${a.available_credit ?? 0}`,
  })),
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
    await finance.registerCreditExpense({
      account_id: form.value.account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
    })
    toast.success('Cargo a tarjeta registrado')
    emit('success')
    emit('close')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? 'No se pudo registrar el cargo')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <form class="space-y-4" @submit.prevent="handleSubmit">
    <p
      v-if="!accountOptions.length"
      class="text-sm text-[color:var(--color-text-subtle)] italic"
    >
      No tienes cuentas de crédito. Crea una primero.
    </p>
    <template v-else>
      <BaseSelect
        v-model="form.account_id"
        label="Tarjeta"
        :options="accountOptions"
        :error="errors.account_id"
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
        placeholder="ej. laptop, vuelo, ..."
        :error="errors.description"
      />
    </template>

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton
        type="submit"
        :loading="submitting"
        :disabled="!accountOptions.length"
      >
        Cargar a tarjeta
      </BaseButton>
    </footer>
  </form>
</template>
