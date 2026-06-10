<script setup>
import { ArrowDownTrayIcon } from '@heroicons/vue/24/outline'
import BaseButton from '@/components/ui/BaseButton.vue'
import { useExcelDownload } from '@/composables/useExcelDownload'
import { useToastStore } from '@/stores/toast'

const props = defineProps({
  // URL relativa al baseURL del cliente (ej. '/finance/reports/by-category/export.xlsx').
  url: { type: String, required: true },
  // Query params reactivos del estado actual del reporte.
  params: { type: Object, default: () => ({}) },
  disabled: { type: Boolean, default: false },
  label: { type: String, default: 'Exportar a Excel' },
})

const emit = defineEmits(['done', 'error'])

const { download, loading } = useExcelDownload()
const toast = useToastStore()

async function onClick() {
  try {
    await download(props.url, props.params)
    emit('done')
  } catch (e) {
    toast.error(e?.message || 'No se pudo exportar el reporte')
    emit('error', e)
  }
}
</script>

<template>
  <BaseButton
    variant="secondary"
    :loading="loading"
    :disabled="disabled || loading"
    @click="onClick"
  >
    <ArrowDownTrayIcon v-if="!loading" class="h-4 w-4" />
    <span>{{ label }}</span>
  </BaseButton>
</template>
