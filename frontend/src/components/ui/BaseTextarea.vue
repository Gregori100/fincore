<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: { type: [String, null], default: '' },
  // Igual que BaseInput, debemos aplicar los modifiers (.trim) manualmente
  // porque Vue solo los emite al componente como objeto.
  modelModifiers: { type: Object, default: () => ({}) },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  error: { type: String, default: '' },
  hint: { type: String, default: '' },
  required: { type: Boolean, default: false },
  rows: { type: [String, Number], default: 3 },
  maxlength: { type: [String, Number], default: undefined },
})

const emit = defineEmits(['update:modelValue'])

const taId = computed(() => `ta-${Math.random().toString(36).slice(2, 9)}`)

function onInput(event) {
  let value = event.target.value
  if (props.modelModifiers.trim && typeof value === 'string') {
    value = value.trim()
  }
  emit('update:modelValue', value)
}
</script>

<template>
  <div>
    <label
      v-if="label"
      :for="taId"
      class="block text-sm font-medium text-[color:var(--color-text-muted)] mb-1"
    >
      {{ label }}
      <span v-if="required" class="text-[color:var(--color-warning)]">*</span>
    </label>
    <textarea
      :id="taId"
      :value="modelValue ?? ''"
      :placeholder="placeholder"
      :required="required"
      :rows="rows"
      :maxlength="maxlength"
      class="w-full px-3 py-2 rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] text-[color:var(--color-text-primary)] placeholder:text-[color:var(--color-text-subtle)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] focus-visible:border-transparent transition resize-y"
      :class="error && 'border-[color:var(--color-negative)] focus-visible:ring-[color:var(--color-negative)]'"
      @input="onInput"
    />
    <p v-if="error" class="mt-1 text-xs text-[color:var(--color-negative)]">
      {{ error }}
    </p>
    <p v-else-if="hint" class="mt-1 text-xs text-[color:var(--color-text-subtle)]">
      {{ hint }}
    </p>
  </div>
</template>
