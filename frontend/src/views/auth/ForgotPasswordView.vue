<script setup>
import { ref } from 'vue'
import { authApi } from '@/api/auth'
import { useToastStore } from '@/stores/toast'
import AuthLayout from '@/components/layout/AuthLayout.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const toast = useToastStore()
const email = ref('')
const submitting = ref(false)
const sent = ref(false)
const errors = ref({})

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await authApi.forgotPassword(email.value)
    sent.value = true
    toast.success('Te enviamos el link de reset')
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.message ?? 'No se pudo enviar el email')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthLayout
    title="¿Olvidaste tu contraseña?"
    subtitle="Te enviaremos un link para crear una nueva"
  >
    <div
      v-if="sent"
      class="rounded-lg border border-[color:var(--color-positive)]/40 bg-[color:var(--color-positive)]/10 p-4 text-sm space-y-2"
    >
      <p class="font-medium text-[color:var(--color-text-primary)]">
        Email enviado.
      </p>
      <p class="text-[color:var(--color-text-muted)]">
        Revisa tu bandeja en busca del link de reset. Si no lo recibes en unos minutos,
        verifica el correo y solicítalo de nuevo.
      </p>
      <p class="text-xs text-[color:var(--color-text-subtle)]">
        En desarrollo, revisa Mailpit en
        <a
          href="http://localhost:8025"
          target="_blank"
          rel="noopener"
          class="underline text-[color:var(--color-accent)]"
        >
          localhost:8025
        </a>.
      </p>
    </div>

    <form v-else class="space-y-4" novalidate @submit.prevent="handleSubmit">
      <BaseInput
        v-model.trim="email"
        label="Email"
        type="email"
        autocomplete="email"
        :error="errors.email"
        required
      />

      <BaseButton type="submit" :loading="submitting" block>
        Enviar link de reset
      </BaseButton>

      <p class="text-sm text-center text-[color:var(--color-text-muted)]">
        <RouterLink
          :to="{ name: 'login' }"
          class="text-[color:var(--color-accent)] hover:underline"
        >
          ← Volver a iniciar sesión
        </RouterLink>
      </p>
    </form>
  </AuthLayout>
</template>
