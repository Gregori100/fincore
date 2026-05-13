<script setup>
import { useToastStore } from '@/stores/toast'
import { XMarkIcon } from '@heroicons/vue/20/solid'

const toast = useToastStore()

const kindClasses = {
  success: 'border-[color:var(--color-positive)] bg-[color:var(--color-surface-elevated)]',
  error: 'border-[color:var(--color-negative)] bg-[color:var(--color-surface-elevated)]',
  info: 'border-[color:var(--color-border)] bg-[color:var(--color-surface-elevated)]',
}
</script>

<template>
  <div class="fixed top-4 right-4 z-[100] flex flex-col gap-2 max-w-sm">
    <transition-group
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="translate-x-full opacity-0"
      enter-to-class="translate-x-0 opacity-100"
      leave-active-class="transition duration-150 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-for="m in toast.messages"
        :key="m.id"
        class="rounded-lg border-l-4 shadow-lg pr-3 pl-4 py-3 flex items-start gap-3"
        :class="kindClasses[m.kind] ?? kindClasses.info"
      >
        <p class="flex-1 text-sm">{{ m.text }}</p>
        <button
          type="button"
          class="text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-text-primary)]"
          @click="toast.dismiss(m.id)"
        >
          <XMarkIcon class="h-4 w-4" />
        </button>
      </div>
    </transition-group>
  </div>
</template>
