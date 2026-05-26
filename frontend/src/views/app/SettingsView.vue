<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ExclamationTriangleIcon } from '@heroicons/vue/24/outline'
import { useFinanceStore } from '@/stores/finance'
import { usePlanStore } from '@/stores/plan'
import { useToastStore } from '@/stores/toast'
import { useFormErrors } from '@/composables/useFormErrors'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import settingsApi from '@/api/settings'

const router = useRouter()
const finance = useFinanceStore()
const plan = usePlanStore()
const toast = useToastStore()

// mode: 'full' | 'movements' | null
const resetMode = ref(null)
const password = ref('')

const MODE_COPY = {
  full: {
    title: 'Restablecer cuenta completa',
    warning: 'Vas a borrar todo de forma permanente.',
    detail: 'Movimientos, cuentas adicionales y plan. Tu Bolsa queda vacía y las categorías se conservan. No hay vuelta atrás.',
  },
  movements: {
    title: 'Vaciar movimientos',
    warning: 'Vas a borrar todos tus movimientos de forma permanente.',
    detail: 'Se conservan tus cuentas (quedan en saldo 0), categorías y plan. Sólo se eliminan las transacciones. No hay vuelta atrás.',
  },
}

const activeCopy = computed(() => MODE_COPY[resetMode.value] ?? MODE_COPY.full)

function validate() {
  const e = {}
  if (!password.value) e.password = 'Ingresa tu contraseña para confirmar'
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

function openReset(mode) {
  resetMode.value = mode
  password.value = ''
}

function closeReset() {
  resetMode.value = null
  password.value = ''
}

async function confirmReset() {
  let summary = {}
  const mode = resetMode.value
  const result = await submit(async () => {
    const { data } = await settingsApi.hardReset(password.value, mode)
    summary = data ?? {}
  })
  if (result.ok) {
    const msg = mode === 'movements'
      ? `Movimientos eliminados: ${summary.deleted_entries ?? 0}. Tus cuentas quedaron en cero.`
      : `Cuenta restablecida: ${summary.deleted_entries ?? 0} movimientos y ${summary.deleted_accounts ?? 0} cuentas eliminados.`
    toast.success(msg)
    closeReset()
    plan.reset()
    await finance.fetchState().catch(() => {})
    router.push({ name: 'dashboard' })
  } else if (result.reason === 'server') {
    const data = result.error.response?.data
    if (!data?.errors) {
      toast.error(data?.message ?? data?.error ?? 'No se pudo restablecer la cuenta')
    }
  }
}
</script>

<template>
  <AppLayout>
    <div class="space-y-6 max-w-2xl">
      <header>
        <h2 class="text-xl font-semibold tracking-tight">Ajustes</h2>
        <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
          Configuración y herramientas de tu cuenta
        </p>
      </header>

      <!-- Zona de peligro -->
      <section class="border border-[color:var(--color-negative)]/40 rounded-xl overflow-hidden">
        <div class="bg-[color:var(--color-negative)]/10 px-4 py-3 border-b border-[color:var(--color-negative)]/30">
          <h3 class="text-sm font-semibold text-[color:var(--color-negative)] flex items-center gap-2">
            <ExclamationTriangleIcon class="h-4 w-4" />
            Zona de peligro
          </h3>
        </div>
        <div class="divide-y divide-[color:var(--color-border)]">
          <div class="p-4 flex items-start justify-between gap-4 flex-wrap">
            <div class="min-w-0 flex-1">
              <p class="font-medium text-sm">Vaciar movimientos</p>
              <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
                Borra todas las transacciones pero <strong>conserva tus cuentas</strong>
                (quedan en saldo 0), categorías y plan. Útil para empezar un periodo
                nuevo sin perder tu estructura.
              </p>
            </div>
            <BaseButton
              variant="ghost"
              class="text-[color:var(--color-negative)] border border-[color:var(--color-negative)]/40 shrink-0"
              @click="openReset('movements')"
            >
              Vaciar movimientos
            </BaseButton>
          </div>

          <div class="p-4 flex items-start justify-between gap-4 flex-wrap">
            <div class="min-w-0 flex-1">
              <p class="font-medium text-sm">Restablecer cuenta completa</p>
              <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
                Borra <strong>permanentemente</strong> movimientos, cuentas adicionales
                y plan. Tu Bolsa queda vacía y las categorías se conservan. Deja la cuenta
                como recién creada.
              </p>
            </div>
            <BaseButton
              variant="ghost"
              class="text-[color:var(--color-negative)] border border-[color:var(--color-negative)]/40 shrink-0"
              @click="openReset('full')"
            >
              Restablecer todo
            </BaseButton>
          </div>
        </div>
      </section>
    </div>

    <BaseModal :open="resetMode !== null" :title="activeCopy.title" @close="closeReset">
      <form class="space-y-4" novalidate @submit.prevent="confirmReset">
        <div class="bg-[color:var(--color-negative)]/10 border border-[color:var(--color-negative)]/30 rounded-lg p-3">
          <p class="text-sm text-[color:var(--color-negative)] font-medium">
            {{ activeCopy.warning }}
          </p>
          <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
            {{ activeCopy.detail }} Confirma con tu contraseña.
          </p>
        </div>
        <BaseInput
          v-model="password"
          type="password"
          label="Tu contraseña"
          :error="errors.password"
          autocomplete="current-password"
          required
        />
        <footer class="flex gap-2 justify-end pt-2">
          <BaseButton variant="ghost" type="button" @click="closeReset">
            Cancelar
          </BaseButton>
          <BaseButton
            type="submit"
            :loading="submitting"
            class="bg-[color:var(--color-negative)] text-white hover:opacity-90"
          >
            {{ resetMode === 'movements' ? 'Vaciar movimientos' : 'Borrar todo' }}
          </BaseButton>
        </footer>
      </form>
    </BaseModal>
  </AppLayout>
</template>
