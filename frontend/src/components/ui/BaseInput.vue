<script setup>
import { computed } from 'vue'

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  type: { type: String, default: 'text' },
  placeholder: { type: String, default: '' },
  error: { type: String, default: '' },
  hint: { type: String, default: '' },
  required: { type: Boolean, default: false },
  step: { type: [String, Number], default: undefined },
  min: { type: [String, Number], default: undefined },
  max: { type: [String, Number], default: undefined },
  autocomplete: { type: String, default: undefined },
})

defineEmits(['update:modelValue'])

const inputId = computed(() => `in-${Math.random().toString(36).slice(2, 9)}`)
</script>

<template>
  <div>
    <label
      v-if="label"
      :for="inputId"
      class="block text-sm font-medium text-[color:var(--color-text-muted)] mb-1"
    >
      {{ label }}
      <span v-if="required" class="text-[color:var(--color-warning)]">*</span>
    </label>
    <input
      :id="inputId"
      :type="type"
      :value="modelValue"
      :placeholder="placeholder"
      :required="required"
      :step="step"
      :min="min"
      :max="max"
      :autocomplete="autocomplete"
      class="w-full px-3 py-2 rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] text-[color:var(--color-text-primary)] placeholder:text-[color:var(--color-text-subtle)] focus:outline-none focus:ring-2 focus:ring-[color:var(--color-accent)] focus:border-transparent transition"
      :class="error && 'border-[color:var(--color-negative)] focus:ring-[color:var(--color-negative)]'"
      @input="$emit('update:modelValue', $event.target.value)"
    />
    <p v-if="error" class="mt-1 text-xs text-[color:var(--color-negative)]">
      {{ error }}
    </p>
    <p v-else-if="hint" class="mt-1 text-xs text-[color:var(--color-text-subtle)]">
      {{ hint }}
    </p>
  </div>
</template>
