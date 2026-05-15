<script setup>
import { ref } from 'vue'
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
})

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

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Guardar cambios</BaseButton>
    </footer>
  </form>
</template>
