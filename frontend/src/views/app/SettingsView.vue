<script setup>
import { ref } from 'vue'
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

const showResetModal = ref(false)
const password = ref('')

function validate() {
  const e = {}
  if (!password.value) e.password = 'Ingresa tu contraseña para confirmar'
  return e
}

const { errors, submitting, submit } = useFormErrors(validate)

function openReset() {
  password.value = ''
  showResetModal.value = true
}

async function confirmReset() {
  let summary = {}
  const result = await submit(async () => {
    const { data } = await settingsApi.hardReset(password.value)
    summary = data ?? {}
  })
  if (result.ok) {
    toast.success(
      `Cuenta restablecida: ${summary.deleted_entries ?? 0} movimientos y ${summary.deleted_accounts ?? 0} cuentas eliminados.`,
    )
    showResetModal.value = false
    password.value = ''
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
        <div class="p-4 space-y-3">
          <div>
            <p class="font-medium text-sm">Restablecer cuenta (hard reset)</p>
            <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
              Borra <strong>permanentemente</strong> todos tus movimientos, cuentas adicionales
              y eventos del plan. Tu Bolsa queda vacía y tus categorías se conservan.
              Esta acción <strong>no se puede deshacer</strong>.
            </p>
          </div>
          <BaseButton
            variant="ghost"
            class="text-[color:var(--color-negative)] border border-[color:var(--color-negative)]/40"
            @click="openReset"
          >
            Restablecer mi cuenta
          </BaseButton>
        </div>
      </section>
    </div>

    <BaseModal :open="showResetModal" title="Restablecer cuenta" @close="showResetModal = false">
      <form class="space-y-4" novalidate @submit.prevent="confirmReset">
        <div class="bg-[color:var(--color-negative)]/10 border border-[color:var(--color-negative)]/30 rounded-lg p-3">
          <p class="text-sm text-[color:var(--color-negative)] font-medium">
            Vas a borrar todo de forma permanente.
          </p>
          <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
            Movimientos, cuentas adicionales y plan. No hay vuelta atrás. Confirma con tu contraseña.
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
          <BaseButton variant="ghost" type="button" @click="showResetModal = false">
            Cancelar
          </BaseButton>
          <BaseButton
            type="submit"
            :loading="submitting"
            class="bg-[color:var(--color-negative)] text-white hover:opacity-90"
          >
            Borrar todo
          </BaseButton>
        </footer>
      </form>
    </BaseModal>
  </AppLayout>
</template>
