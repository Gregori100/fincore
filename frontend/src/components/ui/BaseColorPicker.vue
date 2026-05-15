<script setup>
import { CheckIcon } from '@heroicons/vue/20/solid'
import { COLORS } from '@/constants/categoryCatalog'

const props = defineProps({
  modelValue: { type: String, default: null },
  options: { type: Array, default: () => COLORS },
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
      class="grid grid-cols-5 gap-2 p-2 rounded-md bg-[color:var(--color-surface-elevated)] border"
      :class="error ? 'border-[color:var(--color-negative)]' : 'border-[color:var(--color-border)]'"
    >
      <button
        v-for="opt in options"
        :key="opt.slug"
        type="button"
        :aria-label="opt.label"
        :aria-pressed="opt.slug === modelValue"
        class="relative w-8 h-8 rounded-full transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-[color:var(--color-surface-elevated)] focus-visible:ring-[color:var(--color-accent)]"
        :style="{ backgroundColor: `var(${opt.cssVar})` }"
        @click="select(opt.slug)"
      >
        <CheckIcon
          v-if="opt.slug === modelValue"
          class="absolute inset-0 m-auto h-4 w-4 text-black"
        />
      </button>
    </div>
    <p v-if="error" class="mt-1 text-xs text-[color:var(--color-negative)]">
      {{ error }}
    </p>
  </div>
</template>
