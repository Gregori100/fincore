<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { authApi } from '@/api/auth'
import { useToastStore } from '@/stores/toast'
import AuthLayout from '@/components/layout/AuthLayout.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const route = useRoute()
const router = useRouter()
const toast = useToastStore()

// token y email vienen del link del email enviado por el backend.
const token = computed(() => route.query.token ?? '')
const initialEmail = computed(() => route.query.email ?? '')

const form = ref({
  email: initialEmail.value,
  password: '',
  password_confirmation: '',
})
const submitting = ref(false)
const errors = ref({})
const success = ref(false)

const hasTokenAndEmail = computed(() => token.value && initialEmail.value)

async function handleSubmit() {
  errors.value = {}
  if (!form.value.password) {
    errors.value.password = 'Ingresa una contraseña'
    return
  }
  if (form.value.password !== form.value.password_confirmation) {
    errors.value.password_confirmation = 'Las contraseñas no coinciden'
    return
  }

  submitting.value = true
  try {
    await authApi.resetPassword({
      token: token.value,
      email: form.value.email,
      password: form.value.password,
      password_confirmation: form.value.password_confirmation,
    })
    success.value = true
    toast.success('Contraseña actualizada. Inicia sesión.')
    setTimeout(() => router.push({ name: 'login' }), 1500)
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.message ?? 'No se pudo restablecer la contraseña')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthLayout
    title="Nueva contraseña"
    :subtitle="hasTokenAndEmail ? 'Ingresa tu nueva contraseña' : 'Link inválido'"
  >
    <div
      v-if="!hasTokenAndEmail"
      class="rounded-lg border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-4 text-sm"
    >
      <p class="font-medium">El link es inválido o está incompleto.</p>
      <p class="text-[color:var(--color-text-muted)] mt-1">
        Solicita uno nuevo desde "¿Olvidaste tu contraseña?".
      </p>
      <p class="mt-3">
        <RouterLink
          :to="{ name: 'forgot-password' }"
          class="text-[color:var(--color-accent)] hover:underline"
        >
          Pedir nuevo link →
        </RouterLink>
      </p>
    </div>

    <div
      v-else-if="success"
      class="rounded-lg border border-[color:var(--color-positive)]/40 bg-[color:var(--color-positive)]/10 p-4 text-sm"
    >
      <p class="font-medium">¡Contraseña restablecida!</p>
      <p class="text-[color:var(--color-text-muted)] mt-1">
        Te llevamos al login en un momento…
      </p>
    </div>

    <form v-else class="space-y-4" novalidate @submit.prevent="handleSubmit">
      <BaseInput
        v-model.trim="form.email"
        label="Email"
        type="email"
        autocomplete="email"
        :error="errors.email"
        required
      />
      <BaseInput
        v-model="form.password"
        label="Nueva contraseña"
        type="password"
        autocomplete="new-password"
        :error="errors.password"
        hint="Mínimo 8 caracteres"
        required
      />
      <BaseInput
        v-model="form.password_confirmation"
        label="Confirmar contraseña"
        type="password"
        autocomplete="new-password"
        :error="errors.password_confirmation"
        required
      />

      <BaseButton type="submit" :loading="submitting" block>
        Actualizar contraseña
      </BaseButton>
    </form>
  </AuthLayout>
</template>
