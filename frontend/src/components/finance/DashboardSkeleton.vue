<script setup>
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
</script>

<template>
  <div class="space-y-8" aria-busy="true" aria-label="Cargando estado financiero">
    <!-- StateSummary skeleton: 3 cards + 1 wide -->
    <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <article
        v-for="n in 3"
        :key="n"
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5"
      >
        <BaseSkeleton height="h-3" width="w-20" />
        <BaseSkeleton height="h-8" width="w-32" rounded="rounded-md" class="mt-3" />
        <BaseSkeleton height="h-3" width="w-24" class="mt-2" />
      </article>
      <article
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-5 sm:col-span-2 lg:col-span-3"
      >
        <div class="flex gap-6">
          <div>
            <BaseSkeleton height="h-3" width="w-24" />
            <BaseSkeleton height="h-6" width="w-20" rounded="rounded-md" class="mt-2" />
          </div>
          <div>
            <BaseSkeleton height="h-3" width="w-20" />
            <BaseSkeleton height="h-6" width="w-16" rounded="rounded-md" class="mt-2" />
          </div>
        </div>
      </article>
    </section>

    <!-- Acciones placeholder -->
    <section
      class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4"
    >
      <BaseSkeleton height="h-3" width="w-32" />
      <div class="flex gap-2 mt-3">
        <BaseSkeleton v-for="n in 5" :key="n" height="h-9" width="w-28" rounded="rounded-md" />
      </div>
    </section>

    <!-- AccountList skeleton -->
    <section>
      <div class="flex items-center justify-between mb-4">
        <BaseSkeleton height="h-5" width="w-32" />
        <BaseSkeleton height="h-9" width="w-32" rounded="rounded-md" />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <article
          v-for="n in 3"
          :key="n"
          class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4"
        >
          <BaseSkeleton height="h-4" width="w-24" />
          <BaseSkeleton height="h-3" width="w-16" class="mt-1.5" />
          <BaseSkeleton height="h-7" width="w-28" rounded="rounded-md" class="mt-3" />
        </article>
      </div>
    </section>

    <!-- RecentEntries skeleton -->
    <section>
      <BaseSkeleton height="h-5" width="w-44" class="mb-4" />
      <div
        class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4 space-y-3"
      >
        <BaseSkeleton v-for="n in 4" :key="n" height="h-10" width="w-full" rounded="rounded-md" />
      </div>
    </section>
  </div>
</template>
