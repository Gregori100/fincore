<script setup>
import AccountCard from './AccountCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { PlusIcon } from '@heroicons/vue/20/solid'

defineProps({
  accounts: { type: Array, default: () => [] },
  canCreate: { type: Boolean, default: true },
})

defineEmits(['create'])
</script>

<template>
  <section>
    <header class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-medium">Mis cuentas</h2>
      <BaseButton
        variant="secondary"
        :disabled="!canCreate"
        :title="canCreate ? '' : 'Verifica tu email primero'"
        @click="$emit('create')"
      >
        <PlusIcon class="h-4 w-4" />
        Nueva cuenta
      </BaseButton>
    </header>

    <div
      v-if="accounts.length"
      class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4"
    >
      <AccountCard v-for="a in accounts" :key="a.id" :account="a" />
    </div>
    <p
      v-else
      class="text-sm text-[color:var(--color-text-subtle)] italic py-6 text-center bg-[color:var(--color-surface)] border border-dashed border-[color:var(--color-border)] rounded-xl"
    >
      Aún no tienes cuentas. Agrega tu primera cuenta de débito o crédito.
    </p>
  </section>
</template>
