<script setup>
import { computed } from 'vue'
import {
  Dialog,
  DialogPanel,
  DialogTitle,
  TransitionRoot,
  TransitionChild,
} from '@headlessui/vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: '' },
  // md (default) | lg | xl | 2xl | 4xl — controla el ancho máximo del panel.
  size: { type: String, default: 'md' },
  // persistent: ignora click-fuera y Escape para no perder trabajo. Los botones
  // explícitos del contenido (Cancelar/X) siguen emitiendo 'close'.
  persistent: { type: Boolean, default: false },
})

const emit = defineEmits(['close'])

function onDialogClose() {
  if (props.persistent) return
  emit('close')
}

const maxWidthClass = computed(() => ({
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  '2xl': 'max-w-2xl',
  '4xl': 'max-w-4xl',
}[props.size] ?? 'max-w-md'))
</script>

<template>
  <TransitionRoot appear :show="open" as="template">
    <Dialog as="div" class="relative z-50" @close="onDialogClose">
      <TransitionChild
        as="template"
        enter="duration-200 ease-out"
        enter-from="opacity-0"
        enter-to="opacity-100"
        leave="duration-150 ease-in"
        leave-from="opacity-100"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/60 backdrop-blur-sm" />
      </TransitionChild>

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <TransitionChild
            as="template"
            enter="duration-200 ease-out"
            enter-from="opacity-0 scale-95"
            enter-to="opacity-100 scale-100"
            leave="duration-150 ease-in"
            leave-from="opacity-100 scale-100"
            leave-to="opacity-0 scale-95"
          >
            <DialogPanel
              class="w-full rounded-xl bg-[color:var(--color-surface)] border border-[color:var(--color-border)] shadow-2xl shadow-black/40 p-6"
              :class="maxWidthClass"
            >
              <DialogTitle v-if="title" class="text-lg font-medium mb-4">
                {{ title }}
              </DialogTitle>
              <slot />
            </DialogPanel>
          </TransitionChild>
        </div>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
