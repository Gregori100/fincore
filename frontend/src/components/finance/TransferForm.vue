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

const baseOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Saldo: ${fmt(a.balance)}`,
  })),
)

function todayInputDate() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const form = ref({
  origin_id: baseOptions.value[0]?.value ?? null,
  destination_id: baseOptions.value[1]?.value ?? null,
  amount: '',
  description: '',
  occurred_at: todayInputDate(),
})

const origin = computed(() =>
  finance.cashAndDebitAccounts.find((a) => a.id === form.value.origin_id),
)
const originBalance = computed(() => Number(origin.value?.balance ?? 0))

const destinationOptions = computed(() =>
  baseOptions.value.filter((o) => o.value !== form.value.origin_id),
)

const canSubmit = computed(() => baseOptions.value.length >= 2)

function validate() {
  const e = {}
  if (!form.value.origin_id) e.origin_id = 'Selecciona el origen'
  if (!form.value.destination_id) e.destination_id = 'Selecciona el destino'
  if (
    form.value.origin_id
    && form.value.destination_id
    && form.value.origin_id === form.value.destination_id
  ) {
    e.destination_id = 'Origen y destino no pueden ser la misma cuenta'
  }
  const amount = Number(form.value.amount)
  if (!form.value.amount) {
    e.amount = 'Ingresa un monto'
  } else if (Number.isNaN(amount) || amount <= 0) {
    e.amount = 'El monto debe ser mayor a 0'
  } else if (amount > originBalance.value) {
    e.amount = `Excede el saldo del origen (${fmt(originBalance.value)})`
  }
  if (!form.value.occurred_at) e.occurred_at = 'Ingresa una fecha'
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const result = await submit(() =>
    finance.transfer({
      origin_id: form.value.origin_id,
      destination_id: form.value.destination_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
      occurred_at: form.value.occurred_at,
    }),
  )
  if (result.ok) {
    toast.success('Transferencia registrada')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const payload = result.error.response?.data
    if (!payload?.errors) {
      toast.error(payload?.error ?? 'No se pudo registrar la transferencia')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
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
        placeholder="0.00"
        :hint="origin ? `Disponible: ${fmt(originBalance)}` : ''"
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
