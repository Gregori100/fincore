<script setup>
import { computed } from 'vue'
import AccountCard from './AccountCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { PlusIcon } from '@heroicons/vue/20/solid'

const props = defineProps({
  accounts: { type: Array, default: () => [] },
  canCreate: { type: Boolean, default: true },
  highlightedIds: { type: Object, default: () => new Set() },
})

defineEmits(['create'])

// "Vacío" significa que solo existe la Bolsa (todos los users la tienen).
const onlyHasBolsa = computed(
  () =>
    props.accounts.length <= 1
    && (props.accounts[0]?.type === 'cash' || props.accounts.length === 0),
)
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

    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <transition-group
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="opacity-0 scale-95"
        enter-to-class="opacity-100 scale-100"
        appear
      >
        <AccountCard
          v-for="a in accounts"
          :key="a.id"
          :account="a"
          :highlighted="highlightedIds.has(a.id)"
        />
      </transition-group>

      <button
        v-if="onlyHasBolsa && canCreate"
        type="button"
        class="rounded-xl border-2 border-dashed border-[color:var(--color-border)] hover:border-[color:var(--color-accent)] hover:bg-[color:var(--color-surface)] transition p-4 flex flex-col items-center justify-center gap-2 text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] min-h-[140px]"
        @click="$emit('create')"
      >
        <PlusIcon class="h-6 w-6" />
        <span class="text-sm font-medium">Agregar tu primera cuenta</span>
        <span class="text-xs text-[color:var(--color-text-subtle)]">débito o crédito</span>
      </button>
    </div>
  </section>
</template>
