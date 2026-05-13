<script setup>
defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
})
</script>

<template>
  <main class="min-h-full flex items-center justify-center px-4 py-12">
    <div class="w-full max-w-md">
      <div class="mb-8 text-center">
        <h1 class="text-3xl font-semibold tracking-tight text-[color:var(--color-text-primary)]">
          FinCore
        </h1>
        <p class="mt-1 text-sm text-[color:var(--color-text-muted)]">
          Tu libreta digital de finanzas
        </p>
      </div>

      <div
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl shadow-2xl shadow-black/30 p-8"
      >
        <h2 v-if="title" class="text-xl font-medium mb-1">
          {{ title }}
        </h2>
        <p v-if="subtitle" class="text-sm text-[color:var(--color-text-muted)] mb-6">
          {{ subtitle }}
        </p>

        <slot />
      </div>
    </div>
  </main>
</template>
