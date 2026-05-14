<script setup>
import AppLayout from '@/components/layout/AppLayout.vue'
import EntriesTable from '@/components/finance/EntriesTable.vue'
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Historial de movimientos</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Filtra y revisa todas tus pólizas
          </p>
        </div>
        <RouterLink
          :to="{ name: 'dashboard' }"
          class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
        >
          ← Volver al dashboard
        </RouterLink>
      </header>

      <EntriesTable />
    </div>
  </AppLayout>
</template>
