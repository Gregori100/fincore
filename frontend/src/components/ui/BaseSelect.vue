<script setup>
import { computed } from 'vue'
import {
  Listbox,
  ListboxButton,
  ListboxOptions,
  ListboxOption,
} from '@headlessui/vue'
import { CheckIcon, ChevronUpDownIcon } from '@heroicons/vue/20/solid'

const props = defineProps({
  modelValue: { type: [String, Number, null], default: null },
  options: { type: Array, default: () => [] }, // [{ value, label, sublabel? }]
  label: { type: String, default: '' },
  placeholder: { type: String, default: 'Selecciona…' },
  required: { type: Boolean, default: false },
  error: { type: String, default: '' },
})

const emit = defineEmits(['update:modelValue'])

const selected = computed(() =>
  props.options.find((o) => o.value === props.modelValue) ?? null,
)
</script>

<template>
  <div>
    <label
      v-if="label"
      class="block text-sm font-medium text-[color:var(--color-text-muted)] mb-1"
    >
      {{ label }}
      <span v-if="required" class="text-[color:var(--color-warning)]">*</span>
    </label>
    <Listbox
      :model-value="modelValue"
      @update:model-value="(v) => emit('update:modelValue', v)"
    >
      <div class="relative">
        <ListboxButton
          class="relative w-full cursor-default rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] py-2 pl-3 pr-10 text-left text-[color:var(--color-text-primary)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] transition"
          :class="error && 'border-[color:var(--color-negative)]'"
        >
          <span class="block truncate">
            <span v-if="selected">{{ selected.label }}</span>
            <span v-else class="text-[color:var(--color-text-subtle)]">{{ placeholder }}</span>
          </span>
          <span class="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-2">
            <ChevronUpDownIcon class="h-5 w-5 text-[color:var(--color-text-subtle)]" />
          </span>
        </ListboxButton>

        <transition
          leave-active-class="transition duration-100 ease-in"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <ListboxOptions
            class="absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] py-1 text-sm shadow-lg focus:outline-none"
          >
            <ListboxOption
              v-for="opt in options"
              :key="opt.value"
              v-slot="{ active, selected: isSelected }"
              :value="opt.value"
              as="template"
            >
              <li
                class="relative cursor-pointer select-none py-2 pl-10 pr-4"
                :class="active ? 'bg-[color:var(--color-accent)] text-black' : 'text-[color:var(--color-text-primary)]'"
              >
                <span class="block truncate" :class="isSelected && 'font-medium'">
                  {{ opt.label }}
                </span>
                <span v-if="opt.sublabel" class="block text-xs opacity-75 truncate">
                  {{ opt.sublabel }}
                </span>
                <span v-if="isSelected" class="absolute inset-y-0 left-0 flex items-center pl-3">
                  <CheckIcon class="h-5 w-5" />
                </span>
              </li>
            </ListboxOption>
            <li
              v-if="!options.length"
              class="px-3 py-2 text-sm text-[color:var(--color-text-subtle)] italic"
            >
              Sin opciones disponibles
            </li>
          </ListboxOptions>
        </transition>
      </div>
    </Listbox>
    <p v-if="error" class="mt-1 text-xs text-[color:var(--color-negative)]">
      {{ error }}
    </p>
  </div>
</template>
