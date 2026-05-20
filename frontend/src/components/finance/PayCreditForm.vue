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

const originOptions = computed(() =>
  finance.cashAndDebitAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Saldo: ${fmt(a.balance)}`,
  })),
)

const creditOptions = computed(() =>
  finance.creditAccounts.map((a) => ({
    value: a.id,
    label: a.name,
    sublabel: `Deuda: ${fmt(a.balance)}`,
  })),
)

function todayInputDate() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const form = ref({
  origin_id: originOptions.value[0]?.value ?? null,
  credit_account_id: creditOptions.value[0]?.value ?? null,
  amount: '',
  description: '',
  occurred_at: todayInputDate(),
})

const origin = computed(() =>
  finance.cashAndDebitAccounts.find((a) => a.id === form.value.origin_id),
)
const credit = computed(() =>
  finance.creditAccounts.find((a) => a.id === form.value.credit_account_id),
)
const originBalance = computed(() => Number(origin.value?.balance ?? 0))
const creditDebt = computed(() => Number(credit.value?.balance ?? 0))

const canSubmit = computed(
  () => originOptions.value.length && creditOptions.value.length,
)

function validate() {
  const e = {}
  if (!form.value.origin_id) e.origin_id = 'Selecciona una cuenta origen'
  if (!form.value.credit_account_id) e.credit_account_id = 'Selecciona la tarjeta a pagar'
  const amount = Number(form.value.amount)
  if (!form.value.amount) {
    e.amount = 'Ingresa un monto'
  } else if (Number.isNaN(amount) || amount <= 0) {
    e.amount = 'El monto debe ser mayor a 0'
  } else if (credit.value && amount > creditDebt.value) {
    // El sobrepago SÍ se bloquea: no tiene sentido pagar más de lo que se debe.
    e.amount = `Excede la deuda de la tarjeta (${fmt(creditDebt.value)})`
  }
  if (!form.value.occurred_at) e.occurred_at = 'Ingresa una fecha'
  return e
}

// Aviso no bloqueante: si el pago excede el saldo del origen, la cuenta queda
// en negativo (libreta libre).
const overdraftWarning = computed(() => {
  const amount = Number(form.value.amount)
  if (!form.value.amount || Number.isNaN(amount) || amount <= 0) return ''
  if (!origin.value) return ''
  if (amount > originBalance.value) {
    return `Dejará el origen en negativo (excede ${fmt(originBalance.value)} disponibles).`
  }
  return ''
})

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const result = await submit(() =>
    finance.payCredit({
      origin_id: form.value.origin_id,
      credit_account_id: form.value.credit_account_id,
      amount: Number(form.value.amount),
      description: form.value.description || null,
      occurred_at: form.value.occurred_at,
    }),
  )
  if (result.ok) {
    toast.success('Pago aplicado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const payload = result.error.response?.data
    if (!payload?.errors) {
      toast.error(payload?.error ?? 'No se pudo aplicar el pago')
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
        placeholder="0.00"
        :hint="
          origin && credit
            ? `Disponible en origen: ${fmt(originBalance)} · Deuda en tarjeta: ${fmt(creditDebt)}`
            : ''
        "
        :error="errors.amount"
        required
      />
      <p
        v-if="overdraftWarning"
        class="text-xs text-[color:var(--color-warning)] -mt-2"
      >
        ⚠ {{ overdraftWarning }}
      </p>
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
