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

const baseOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Saldo: ${a.balance ?? 0}`,
  })),
)

const form = ref({
  origin_id: baseOptions.value[0]?.value ?? null,
  destination_id: baseOptions.value[1]?.value ?? null,
  amount: '',
  description: '',
})
const submitting = ref(false)
const errors = ref({})

const destinationOptions = computed(() =>
  baseOptions.value.filter((o) => o.value !== form.value.origin_id),
)

const canSubmit = computed(() => baseOptions.value.length >= 2)

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await finance.transfer({
      origin_id: form.value.origin_id,
      destination_id: form.value.destination_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
    })
    toast.success('Transferencia registrada')
    emit('success')
    emit('close')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? 'No se pudo registrar la transferencia')
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
      Necesitas al menos dos cuentas cash o débito para transferir.
    </p>
    <template v-else>
      <BaseSelect
        v-model="form.origin_id"
        label="Desde"
        :options="baseOptions"
        :error="errors.origin_id"
        required
      />
      <BaseSelect
        v-model="form.destination_id"
        label="Hacia"
        :options="destinationOptions"
        :error="errors.destination_id"
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
        :error="errors.description"
      />
    </template>

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting" :disabled="!canSubmit">
        Transferir
      </BaseButton>
    </footer>
  </form>
</template>
