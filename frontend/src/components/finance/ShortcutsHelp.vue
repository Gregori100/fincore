<script setup>
const SHORTCUTS = [
  { keys: ['i'], label: 'Registrar ingreso' },
  { keys: ['g'], label: 'Registrar gasto' },
  { keys: ['c'], label: 'Cargo a tarjeta' },
  { keys: ['p'], label: 'Pagar tarjeta' },
  { keys: ['t'], label: 'Transferir' },
  { keys: ['n'], label: 'Nueva cuenta' },
  { keys: ['Esc'], label: 'Cerrar modal' },
  { keys: ['Enter'], label: 'Enviar formulario' },
  { keys: ['?'], label: 'Esta ayuda' },
]
</script>

<template>
  <ul class="space-y-2">
    <li
      v-for="s in SHORTCUTS"
      :key="s.label"
      class="flex items-center justify-between text-sm"
    >
      <span class="text-[color:var(--color-text-muted)]">{{ s.label }}</span>
      <span class="flex gap-1">
        <kbd
          v-for="k in s.keys"
          :key="k"
          class="inline-flex items-center justify-center min-w-[1.75rem] h-7 px-2 rounded border border-[color:var(--color-border)] bg-[color:var(--color-surface-elevated)] text-xs font-mono font-medium"
        >
          {{ k }}
        </kbd>
      </span>
    </li>
  </ul>

  <p class="text-xs text-[color:var(--color-text-subtle)] mt-4 pt-4 border-t border-[color:var(--color-border)]">
    Los atajos solo funcionan cuando ningún campo está enfocado.
  </p>
</template>
