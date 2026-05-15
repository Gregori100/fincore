<script setup>
import { computed } from 'vue'
import { cssVarBySlug, iconBySlug } from '@/constants/categoryCatalog'

const props = defineProps({
  // { name, color_slug, icon_slug }
  category: { type: Object, required: true },
})

const icon = computed(() => iconBySlug(props.category.icon_slug))
const cssVar = computed(() => cssVarBySlug(props.category.color_slug))
</script>

<template>
  <span
    class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium border whitespace-nowrap"
    :style="{
      backgroundColor: `color-mix(in oklch, var(${cssVar}) 18%, transparent)`,
      color: `var(${cssVar})`,
      borderColor: `color-mix(in oklch, var(${cssVar}) 35%, transparent)`,
    }"
  >
    <component :is="icon" class="h-3 w-3 shrink-0" />
    <span class="truncate max-w-[8rem]">{{ category.name }}</span>
  </span>
</template>
