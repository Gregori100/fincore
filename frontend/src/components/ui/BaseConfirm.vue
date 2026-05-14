<script setup>
import BaseModal from './BaseModal.vue'
import BaseButton from './BaseButton.vue'

defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: 'Confirmar' },
  message: { type: String, default: '¿Estás seguro?' },
  confirmLabel: { type: String, default: 'Confirmar' },
  cancelLabel: { type: String, default: 'Cancelar' },
  variant: { type: String, default: 'primary' }, // primary | danger
  loading: { type: Boolean, default: false },
})

defineEmits(['confirm', 'cancel'])
</script>

<template>
  <BaseModal :open="open" :title="title" @close="$emit('cancel')">
    <p class="text-sm text-[color:var(--color-text-muted)]">{{ message }}</p>

    <footer class="flex gap-2 justify-end pt-4 mt-4">
      <BaseButton variant="ghost" type="button" @click="$emit('cancel')">
        {{ cancelLabel }}
      </BaseButton>
      <BaseButton
        :variant="variant"
        :loading="loading"
        type="button"
        @click="$emit('confirm')"
      >
        {{ confirmLabel }}
      </BaseButton>
    </footer>
  </BaseModal>
</template>
