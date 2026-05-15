<script setup>
import { computed } from 'vue'
import { ArchiveBoxXMarkIcon, PencilSquareIcon } from '@heroicons/vue/20/solid'
import { cssVarBySlug, iconBySlug } from '@/constants/categoryCatalog'

const props = defineProps({
  category: { type: Object, required: true },
})

defineEmits(['edit', 'archive'])

const icon = computed(() => iconBySlug(props.category.icon_slug))
const cssVar = computed(() => cssVarBySlug(props.category.color_slug))
const isArchived = computed(() => Boolean(props.category.deleted_at))

const appliesLabel = computed(() => ({
  income: 'Ingresos',
  expense: 'Gastos',
  both: 'Ambos',
}[props.category.applies_to] ?? props.category.applies_to))
</script>

<template>
  <article
    class="group relative bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4 transition-all duration-200"
    :class="isArchived ? 'opacity-60' : 'hover:border-[color:var(--color-accent)]/60'"
  >
    <header class="flex items-start justify-between gap-2">
      <div class="flex items-center gap-3 min-w-0">
        <div
          class="w-10 h-10 rounded-full flex items-center justify-center shrink-0"
          :style="{
            backgroundColor: `color-mix(in oklch, var(${cssVar}) 25%, transparent)`,
            color: `var(${cssVar})`,
          }"
        >
          <component :is="icon" class="h-5 w-5" />
        </div>
        <div class="min-w-0">
          <h3 class="font-medium truncate">{{ category.name }}</h3>
          <p class="text-[10px] mt-0.5 uppercase tracking-[0.08em] font-semibold flex items-center gap-1.5 text-[color:var(--color-text-muted)]">
            {{ appliesLabel }}
            <span
              v-if="isArchived"
              class="ml-1 text-[10px] font-medium tracking-normal text-[color:var(--color-text-subtle)] bg-[color:var(--color-surface-elevated)] px-1.5 py-0.5 rounded normal-case"
            >
              archivada
            </span>
          </p>
        </div>
      </div>

      <div
        v-if="!isArchived"
        class="flex items-center gap-1 opacity-0 group-hover:opacity-100 focus-within:opacity-100 transition"
      >
        <button
          type="button"
          class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-accent)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)]"
          aria-label="Editar categoría"
          title="Editar"
          @click="$emit('edit', category)"
        >
          <PencilSquareIcon class="h-4 w-4" />
        </button>
        <button
          type="button"
          class="p-1 rounded text-[color:var(--color-text-subtle)] hover:text-[color:var(--color-warning)] hover:bg-[color:var(--color-surface-elevated)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-warning)]"
          aria-label="Archivar categoría"
          title="Archivar"
          @click="$emit('archive', category)"
        >
          <ArchiveBoxXMarkIcon class="h-4 w-4" />
        </button>
      </div>
    </header>
  </article>
</template>
