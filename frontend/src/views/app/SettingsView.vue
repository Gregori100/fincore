<script setup>
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowDownTrayIcon, ArrowUpTrayIcon, ExclamationTriangleIcon } from '@heroicons/vue/24/outline'
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

// ---- Respaldos ----
const exporting = ref(false)
const showImportModal = ref(false)
const importPassword = ref('')
const importing = ref(false)
const parsedBackup = ref(null)
const fileError = ref('')
const passwordError = ref('')

async function downloadBackup() {
  exporting.value = true
  try {
    const { data } = await settingsApi.exportBackup()
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    const today = new Date().toISOString().slice(0, 10)
    a.download = `fincore-backup-${today}.json`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
    toast.success('Respaldo descargado')
  } catch {
    toast.error('No se pudo generar el respaldo')
  } finally {
    exporting.value = false
  }
}

function openImport() {
  parsedBackup.value = null
  importPassword.value = ''
  fileError.value = ''
  passwordError.value = ''
  showImportModal.value = true
}

async function onFileChosen(event) {
  fileError.value = ''
  parsedBackup.value = null
  const file = event.target.files?.[0]
  if (!file) return
  try {
    const text = await file.text()
    const json = JSON.parse(text)
    if (!json || typeof json !== 'object' || !('version' in json)) {
      fileError.value = 'El archivo no parece un respaldo válido de FinCore.'
      return
    }
    parsedBackup.value = json
  } catch {
    fileError.value = 'No se pudo leer el archivo: no es un JSON válido.'
  }
}

async function confirmImport() {
  passwordError.value = ''
  if (!parsedBackup.value) {
    fileError.value = 'Selecciona un archivo de respaldo.'
    return
  }
  if (!importPassword.value) {
    passwordError.value = 'Ingresa tu contraseña para confirmar'
    return
  }
  importing.value = true
  try {
    const { data } = await settingsApi.importBackup(importPassword.value, parsedBackup.value)
    toast.success(
      `Respaldo aplicado: ${data.entries_imported ?? 0} movimientos restaurados`
      + (data.entries_skipped ? `, ${data.entries_skipped} omitidos` : '') + '.',
    )
    showImportModal.value = false
    plan.reset()
    await finance.fetchState().catch(() => {})
    router.push({ name: 'dashboard' })
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors?.password) {
      passwordError.value = payload.errors.password[0]
    } else {
      toast.error(payload?.message ?? payload?.error ?? 'No se pudo aplicar el respaldo')
    }
  } finally {
    importing.value = false
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

      <!-- Respaldos -->
      <section class="border border-[color:var(--color-border)] rounded-xl overflow-hidden">
        <div class="bg-[color:var(--color-surface-elevated)] px-4 py-3 border-b border-[color:var(--color-border)]">
          <h3 class="text-sm font-semibold">Respaldos</h3>
        </div>
        <div class="divide-y divide-[color:var(--color-border)]">
          <div class="p-4 flex items-start justify-between gap-4 flex-wrap">
            <div class="min-w-0 flex-1">
              <p class="font-medium text-sm">Descargar respaldo</p>
              <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
                Genera un archivo JSON con tus cuentas, categorías y movimientos.
                Guárdalo en un lugar seguro: es tu red de seguridad antes de un reset.
              </p>
            </div>
            <BaseButton variant="secondary" :loading="exporting" class="shrink-0" @click="downloadBackup">
              <ArrowDownTrayIcon class="h-4 w-4 mr-1" />
              Descargar
            </BaseButton>
          </div>
          <div class="p-4 flex items-start justify-between gap-4 flex-wrap">
            <div class="min-w-0 flex-1">
              <p class="font-medium text-sm">Aplicar respaldo</p>
              <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
                Restaura un archivo de respaldo. <strong>Reemplaza el estado actual</strong>:
                borra lo que tengas y deja exactamente lo del archivo. Pide tu contraseña.
              </p>
            </div>
            <BaseButton variant="secondary" class="shrink-0" @click="openImport">
              <ArrowUpTrayIcon class="h-4 w-4 mr-1" />
              Aplicar
            </BaseButton>
          </div>
        </div>
      </section>

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

    <BaseModal :open="showImportModal" title="Aplicar respaldo" @close="showImportModal = false">
      <form class="space-y-4" novalidate @submit.prevent="confirmImport">
        <div class="bg-[color:var(--color-warning)]/10 border border-[color:var(--color-warning)]/30 rounded-lg p-3">
          <p class="text-sm text-[color:var(--color-warning)] font-medium">
            Aplicar un respaldo reemplaza tu estado actual.
          </p>
          <p class="text-xs text-[color:var(--color-text-muted)] mt-1">
            Se borra lo que tengas ahora y se restaura exactamente lo del archivo.
            Tu Bolsa y categorías se reconcilian. No hay vuelta atrás sin otro respaldo.
          </p>
        </div>

        <div>
          <label class="block text-sm font-medium mb-1">Archivo de respaldo</label>
          <input
            type="file"
            accept="application/json,.json"
            class="block w-full text-sm text-[color:var(--color-text-muted)] file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border file:border-[color:var(--color-border)] file:bg-[color:var(--color-surface-elevated)] file:text-[color:var(--color-text-primary)] file:text-sm"
            @change="onFileChosen"
          />
          <p v-if="fileError" class="mt-1 text-xs text-[color:var(--color-negative)]">{{ fileError }}</p>
          <p v-else-if="parsedBackup" class="mt-1 text-xs text-[color:var(--color-positive)]">
            Archivo cargado: {{ parsedBackup.accounts?.length ?? 0 }} cuentas,
            {{ parsedBackup.entries?.length ?? 0 }} movimientos.
          </p>
        </div>

        <BaseInput
          v-model="importPassword"
          type="password"
          label="Tu contraseña"
          :error="passwordError"
          autocomplete="current-password"
          required
        />

        <footer class="flex gap-2 justify-end pt-2">
          <BaseButton variant="ghost" type="button" @click="showImportModal = false">
            Cancelar
          </BaseButton>
          <BaseButton
            type="submit"
            :loading="importing"
            :disabled="!parsedBackup"
            class="bg-[color:var(--color-negative)] text-white hover:opacity-90"
          >
            Aplicar respaldo
          </BaseButton>
        </footer>
      </form>
    </BaseModal>
  </AppLayout>
</template>
