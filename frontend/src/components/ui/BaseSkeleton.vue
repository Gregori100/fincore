<script setup>
defineProps({
  /** alto del bloque (clase Tailwind tipo h-8, h-12, etc.) */
  height: { type: String, default: 'h-4' },
  /** ancho (clase Tailwind: w-full, w-1/2, w-24...) */
  width: { type: String, default: 'w-full' },
  /** rounded variant */
  rounded: { type: String, default: 'rounded' },
})
</script>

<template>
  <div
    class="bg-[color:var(--color-surface-elevated)] animate-pulse"
    :class="[height, width, rounded]"
  />
</template>
