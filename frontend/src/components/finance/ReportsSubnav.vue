<script setup>
/**
 * Subnav compartido entre las vistas de /reports/*. Centraliza las 4 tabs
 * para que añadir un reporte nuevo signifique tocar UN componente en lugar
 * de N vistas. El active-class lo resuelve cada RouterLink contra la ruta
 * actual.
 */
const tabs = [
  { name: 'reports-by-category', label: 'Por categoría' },
  { name: 'reports-cashflow', label: 'Cashflow' },
  { name: 'reports-month-comparison', label: 'Comparativo' },
  { name: 'reports-credit-cards', label: 'Tarjetas' },
]
</script>

<template>
  <nav class="flex items-center gap-2 text-sm border-b border-[color:var(--color-border)] pb-2 flex-wrap">
    <RouterLink
      v-for="tab in tabs"
      :key="tab.name"
      :to="{ name: tab.name }"
      class="px-3 py-1.5 rounded-md transition text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)]"
      active-class="bg-[color:var(--color-surface-elevated)] text-[color:var(--color-text-primary)]"
    >
      {{ tab.label }}
    </RouterLink>
  </nav>
</template>
