<script setup>
import { computed, ref } from 'vue'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const props = defineProps({
  entry: { type: Object, required: true },
})
const emit = defineEmits(['close', 'success'])

const finance = useFinanceStore()
const toast = useToastStore()

// Mapeamos el kind al set de categorías aplicables; transfer y debt_payment no
// se pueden categorizar (su select queda con sólo "Sin categorizar").
const kindForCategories = computed(() => {
  switch (props.entry.kind) {
    case 'income':
      return 'income'
    case 'expense':
    case 'credit_expense':
      return 'expense'
    default:
      return null
  }
})

const categoryOptions = computed(() => {
  const opts = [{ value: null, label: 'Sin categorizar' }]
  if (kindForCategories.value) {
    opts.push(
      ...finance.categoriesFor(kindForCategories.value).map((c) => ({
        value: c.id,
        label: c.name,
      })),
    )
  }
  return opts
})

// occurred_at puede llegar como ISO 8601 ("2026-05-10T14:35:00.000000Z"); el
// input type=date espera YYYY-MM-DD. Cortamos al primer "T" para evitar tocar
// timezone — la app no usa hora en ningún reporte, así que es seguro.
function isoToInputDate(iso) {
  if (!iso) return ''
  return String(iso).slice(0, 10)
}

const form = ref({
  category_id: props.entry.category_id ?? null,
  description: props.entry.description ?? '',
  occurred_at: isoToInputDate(props.entry.occurred_at),
})

function validate() {
  const e = {}
  if (form.value.description && form.value.description.length > 200) {
    e.description = 'Máximo 200 caracteres'
  }
  if (!form.value.occurred_at) {
    e.occurred_at = 'Ingresa una fecha'
  }
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

async function handleSubmit() {
  const payload = {
    category_id: form.value.category_id,
    description: form.value.description?.trim() || null,
  }
  // Sólo mandamos occurred_at si cambió respecto al valor original, para no
  // pisar el datetime original (con su hora exacta) cada vez que se edite otra cosa.
  if (form.value.occurred_at !== isoToInputDate(props.entry.occurred_at)) {
    payload.occurred_at = form.value.occurred_at
  }

  const result = await submit(() => finance.updateEntry(props.entry.id, payload))
  if (result.ok) {
    toast.success('Movimiento actualizado')
    emit('success')
    emit('close')
  } else if (result.reason === 'server') {
    const payload = result.error.response?.data
    if (!payload?.errors) {
      toast.error(payload?.error ?? 'No se pudo actualizar el movimiento')
    }
  }
}
</script>

<template>
  <form class="space-y-4" novalidate @submit.prevent="handleSubmit">
    <p
      v-if="!kindForCategories"
      class="text-xs text-[color:var(--color-text-subtle)] italic"
    >
      Las transferencias y pagos de tarjeta no se categorizan; sólo puedes editar la descripción.
    </p>
    <BaseSelect
      v-if="kindForCategories"
      v-model="form.category_id"
      label="Categoría"
      :options="categoryOptions"
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
      placeholder="Nota sobre el movimiento"
    />

    <footer class="flex gap-2 justify-end pt-2">
      <BaseButton variant="ghost" type="button" @click="emit('close')">Cancelar</BaseButton>
      <BaseButton type="submit" :loading="submitting">Guardar cambios</BaseButton>
    </footer>
  </form>
</template>
