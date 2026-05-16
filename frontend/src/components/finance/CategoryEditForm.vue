<script setup>
import { computed, ref } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseColorPicker from '@/components/ui/BaseColorPicker.vue'
import BaseIconPicker from '@/components/ui/BaseIconPicker.vue'

const props = defineProps({
  category: { type: Object, required: true },
})
const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const toast = useToastStore()

const form = ref({
  name: props.category.name,
  applies_to: props.category.applies_to,
  color_slug: props.category.color_slug,
  icon_slug: props.category.icon_slug,
  monthly_limit: props.category.monthly_limit ?? '',
})

// El campo "Límite mensual" solo aplica a categorías de gasto (o ambos).
// Para income lo ocultamos pero mantenemos el valor en el state.
const supportsBudget = computed(() =>
  form.value.applies_to === 'expense' || form.value.applies_to === 'both',
)

function validate() {
  const e = {}
  const name = form.value.name?.trim() ?? ''
  if (!name) {
    e.name = 'Ingresa un nombre'
  } else if (name.length > 80) {
    e.name = 'Máximo 80 caracteres'
  } else if (finance.categories.some(
    (c) => c.id !== props.category.id && !c.deleted_at
      && c.name.toLowerCase() === name.toLowerCase(),
  )) {
    e.name = 'Ya tienes otra categoría con ese nombre'
  }
  if (!['income', 'expense', 'both'].includes(form.value.applies_to)) {
    e.applies_to = 'Selecciona dónde aplica'
  }

  if (supportsBudget.value && form.value.monthly_limit !== '' && form.value.monthly_limit !== null) {
    const n = Number(form.value.monthly_limit)
    if (Number.isNaN(n) || n < 0) {
      e.monthly_limit = 'El límite debe ser un número >= 0'
    }
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const payload = {
    name: form.value.name.trim(),
    applies_to: form.value.applies_to,
    color_slug: form.value.color_slug,
    icon_slug: form.value.icon_slug,
  }

  // Si la categoría soporta presupuesto, mandamos el valor (o null si está vacío)
  // para que el backend pueda limpiar un límite anterior con un PATCH.
  if (supportsBudget.value) {
    payload.monthly_limit
      = form.value.monthly_limit === '' || form.value.monthly_limit === null
        ? null
        : Number(form.value.monthly_limit)
  }

  const result = await submit(() => finance.updateCategory(props.category.id, payload))
  if (result.ok) {
    toast.success(`Categoría "${payload.name}" actualizada`)
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const data = result.error.response?.data
    if (!data?.errors) {
      toast.error(data?.error ?? 'No se pudo actualizar la categoría')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <BaseInput v-model.trim="form.name" label="Nombre" :error="errors.name" required />

    <BaseSelect
      v-model="form.applies_to"
      label="Aplica a"
      :options="[
        { value: 'expense', label: 'Gastos' },
        { value: 'income', label: 'Ingresos' },
        { value: 'both', label: 'Ambos' },
      ]"
      :error="errors.applies_to"
      required
    />

    <BaseColorPicker v-model="form.color_slug" label="Color" required />
    <BaseIconPicker v-model="form.icon_slug" label="Icono" required />

    <BaseInput
      v-if="supportsBudget"
      v-model="form.monthly_limit"
      label="Límite mensual"
      type="number"
      step="0.01"
      min="0"
      placeholder="$0.00"
      hint="Tope mensual de gasto (opcional)"
      :error="errors.monthly_limit"
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Guardar cambios</BaseButton>
    </footer>
  </form>
</template>
