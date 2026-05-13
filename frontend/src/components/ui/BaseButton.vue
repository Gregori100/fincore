<script setup>
import { computed } from 'vue'

const props = defineProps({
  variant: { type: String, default: 'primary' }, // primary | secondary | ghost | danger
  type: { type: String, default: 'button' },
  loading: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  block: { type: Boolean, default: false },
})

const classes = computed(() => {
  const base =
    'inline-flex items-center justify-center gap-2 px-4 py-2 rounded-md text-sm font-medium transition focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-[color:var(--color-canvas)] disabled:opacity-50 disabled:cursor-not-allowed'
  const variants = {
    primary:
      'bg-[color:var(--color-accent)] text-black hover:bg-[color:var(--color-accent-hover)] focus:ring-[color:var(--color-accent)]',
    secondary:
      'bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)] hover:bg-[color:var(--color-border)] border border-[color:var(--color-border)]',
    ghost:
      'text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] hover:bg-[color:var(--color-surface-elevated)]',
    danger:
      'bg-[color:var(--color-negative)] text-white hover:opacity-90 focus:ring-[color:var(--color-negative)]',
  }
  return [base, variants[props.variant] ?? variants.primary, props.block && 'w-full']
})
</script>

<template>
  <button :type="type" :class="classes" :disabled="disabled || loading">
    <span v-if="loading" class="inline-block h-3 w-3 rounded-full border-2 border-current border-r-transparent animate-spin" />
    <slot />
  </button>
</template>
