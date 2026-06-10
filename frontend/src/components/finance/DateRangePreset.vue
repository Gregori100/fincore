<script setup>
import { computed, ref, watch } from 'vue'
import BaseSelect from '@/components/ui/BaseSelect.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import { DATE_PRESETS, detectPreset, rangeForPreset } from '@/utils/dates'

const props = defineProps({
  // v-model con objeto { from, to } en ISO YYYY-MM-DD.
  modelValue: {
    type: Object,
    required: true,
  },
  label: { type: String, default: 'Período' },
})

const emit = defineEmits(['update:modelValue'])

const CUSTOM_KEY = 'custom'

// Opciones que ve BaseSelect: las 7 de DATE_PRESETS + "Personalizado" al final.
const presetOptions = computed(() => [
  ...DATE_PRESETS.map((p) => ({ value: p.key, label: p.label })),
  { value: CUSTOM_KEY, label: 'Personalizado' },
])

// Clave activa. Se sincroniza desde modelValue al mount y en cambios externos.
const preset = ref(detectPreset(props.modelValue?.from, props.modelValue?.to))

// Bandera para evitar loops cuando emitimos un cambio que dispararía
// el watcher de modelValue → preset → emit, en cadena.
let internalUpdate = false

// Cambios externos de modelValue (drill-down, recarga con query params, etc.)
// disparan la detección de preset. deep para captar mutaciones parciales
// (`filters.value.from = X` en lugar de reemplazar el objeto).
watch(
  () => props.modelValue,
  (val) => {
    if (internalUpdate) {
      internalUpdate = false
      return
    }
    preset.value = detectPreset(val?.from, val?.to)
  },
  { deep: true, immediate: true },
)

// Cambios del dropdown: si el usuario eligió un preset (≠ custom), emitir el
// rango calculado. Si eligió "custom", solo abrir los inputs sin emitir
// (los inputs muestran lo que ya hay en modelValue).
function onPresetChange(newKey) {
  preset.value = newKey
  if (newKey === CUSTOM_KEY) return
  const range = rangeForPreset(newKey)
  internalUpdate = true
  emit('update:modelValue', { from: range.from, to: range.to })
}

// Edición de input en personalizado: emitimos un objeto nuevo, sin tocar
// el preset (el watcher de modelValue lo recalcula y, si el rango editado
// matchea uno, salta a ese preset; comportamiento esperado por RF-004).
function onFromInput(value) {
  emit('update:modelValue', { ...props.modelValue, from: value })
}
function onToInput(value) {
  emit('update:modelValue', { ...props.modelValue, to: value })
}

const showCustomInputs = computed(() => preset.value === CUSTOM_KEY)
</script>

<template>
  <div class="space-y-3">
    <BaseSelect
      :model-value="preset"
      :options="presetOptions"
      :label="label"
      @update:model-value="onPresetChange"
    />
    <div
      v-if="showCustomInputs"
      class="grid grid-cols-1 sm:grid-cols-2 gap-3"
    >
      <BaseInput
        :model-value="modelValue.from"
        type="date"
        label="Desde"
        @update:model-value="onFromInput"
      />
      <BaseInput
        :model-value="modelValue.to"
        type="date"
        label="Hasta"
        @update:model-value="onToInput"
      />
    </div>
  </div>
</template>
