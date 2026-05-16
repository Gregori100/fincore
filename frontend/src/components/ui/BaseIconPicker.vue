<script setup>
import { ICONS } from '@/constants/categoryCatalog'

const props = defineProps({
  modelValue: { type: String, default: null },
  options: { type: Array, default: () => ICONS },
  label: { type: String, default: '' },
  required: { type: Boolean, default: false },
  error: { type: String, default: '' },
})

const emit = defineEmits(['update:modelValue'])

function select(slug) {
  emit('update:modelValue', slug)
}
</script>

<template>
  <div>
    <label
      v-if="label"
      class="block text-sm font-medium text-[color:var(--color-text-muted)] mb-1"
    >
      {{ label }}
      <span v-if="required" class="text-[color:var(--color-warning)]">*</span>
    </label>
    <div
      class="grid grid-cols-6 sm:grid-cols-8 gap-1 p-2 rounded-md bg-[color:var(--color-surface-elevated)] border max-h-44 overflow-y-auto"
      :class="error ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
    >
      <button
        v-for="opt in options"
        :key="opt.slug"
        type="button"
        :aria-label="opt.label"
        :aria-pressed="opt.slug === modelValue"
        class="w-9 h-9 sm:w-8 sm:h-8 flex items-center justify-center rounded transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
        :class="opt.slug === modelValue
          ? 'bg-[color:var(--color-accent)] text-black'
          : 'text-[color:var(--color-text-muted)] hover:bg-[color:var(--color-surface)] hover:text-[color:var(--color-text-primary)]'"
        @click="select(opt.slug)"
      >
        <component :is="opt.component" class="h-5 w-5 sm:h-4 sm:w-4" />
      </button>
    </div>
    <p v-if="error" class="mt-1 text-xs text-[color:var(--color-negative)]">
      {{ error }}
    </p>
  </div>
</template>
