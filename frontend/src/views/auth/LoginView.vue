<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import AuthLayout from '@/components/layout/AuthLayout.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const auth = useAuthStore()
const toast = useToastStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const submitting = ref(false)
const errors = ref({})

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await auth.login(email.value, password.value)
    toast.success('Bienvenido de vuelta')
    const redirect = route.query.redirect ?? { name: 'dashboard' }
    router.push(redirect)
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? payload?.message ?? 'No fue posible iniciar sesión')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthLayout title="Iniciar sesión" subtitle="Accede a tu libreta de finanzas">
    <form class="space-y-4" @submit.prevent="handleSubmit">
      <BaseInput
        v-model="email"
        label="Email"
        type="email"
        autocomplete="email"
        :error="errors.email"
        required
      />
      <BaseInput
        v-model="password"
        label="Contraseña"
        type="password"
        autocomplete="current-password"
        :error="errors.password"
        required
      />

      <BaseButton type="submit" :loading="submitting" block>
        Iniciar sesión
      </BaseButton>

      <p class="text-sm text-center text-[color:var(--color-text-muted)]">
        ¿No tienes cuenta?
        <RouterLink
          :to="{ name: 'register' }"
          class="text-[color:var(--color-accent)] hover:underline"
        >
          Regístrate
        </RouterLink>
      </p>
    </form>
  </AuthLayout>
</template>
