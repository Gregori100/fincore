<script setup>
import { computed, ref } from 'vue'
import { usePlanStore } from '@/stores/plan'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const props = defineProps({
  eventId: { type: String, required: true },
  occurrenceDate: { type: String, required: true },
  // Si ya existe un override para esa ocurrencia, pasarlo como prop.
  override: { type: Object, default: null },
  defaultAmount: { type: [Number, String], default: 0 },
})
const emit = defineEmits(['close', 'success'])

const plan = usePlanStore()
const toast = useToastStore()

const isEdit = computed(() => !!props.override)

const form = ref({
  amount: props.override?.amount != null
    ? String(props.override.amount)
    : String(props.defaultAmount ?? ''),
  is_skipped: props.override?.is_skipped ?? false,
})

function validate() {
  const e = {}
  if (!form.value.is_skipped) {
    const a = Number(form.value.amount)
    if (!form.value.amount || Number.isNaN(a) || a <= 0) {
      e.amount = 'Ingresa un monto > 0 o marca como saltada'
    }
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const payload = {
    is_skipped: form.value.is_skipped,
  }
  if (!form.value.is_skipped) {
    payload.amount = Number(form.value.amount)
  }

  const action = isEdit.value
    ? () => plan.updateOverride(props.override.id, payload)
    : () => plan.createOverride(props.eventId, {
      occurrence_date: props.occurrenceDate,
      ...payload,
    })
  const result = await submit(action)
  if (result.ok) {
    toast.success('Override guardado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const data = result.error.response?.data
    if (!data?.errors) {
      toast.error(data?.error ?? 'No se pudo guardar el override')
    }
  }
}

async function removeOverride() {
  if (!isEdit.value) return
  await plan.deleteOverride(props.override.id)
  toast.success('Override eliminado')
  emit('success')
  emit('close')
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <p class="text-sm text-[color:var(--color-text-muted)]">
      Override para la ocurrencia del {{ occurrenceDate }}
    </p>

    <label class="flex items-center gap-2 text-sm cursor-pointer">
      <input v-model="form.is_skipped" type="checkbox" class="rounded" />
      Saltar esta ocurrencia (no aplicar en la proyección)
    </label>

    <BaseInput
      v-if="!form.is_skipped"
      v-model="form.amount"
      type="number"
      step="0.01"
      min="0.01"
      label="Monto custom para este día"
      :error="errors.amount"
      required
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton
        v-if="isEdit"
        variant="ghost"
        type="button"
        class="mr-auto text-[color:var(--color-negative)]"
        @click="removeOverride"
      >
        Eliminar override
      </BaseButton>
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Guardar</BaseButton>
    </footer>
  </form>
</template>
