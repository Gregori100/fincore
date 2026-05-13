<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import AuthLayout from '@/components/layout/AuthLayout.vue'
import BaseInput from '@/components/ui/BaseInput.vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const auth = useAuthStore()
const toast = useToastStore()
const router = useRouter()

const form = ref({
  name: '',
  email: '',
  password: '',
  password_confirmation: '',
})
const submitting = ref(false)
const errors = ref({})

async function handleSubmit() {
  errors.value = {}
  submitting.value = true
  try {
    await auth.register(form.value)
    toast.success('Cuenta creada. Revisa tu email para verificarla.')
    router.push({ name: 'dashboard' })
  } catch (e) {
    const payload = e.response?.data
    if (payload?.errors) {
      errors.value = Object.fromEntries(
        Object.entries(payload.errors).map(([k, v]) => [k, v[0]]),
      )
    } else {
      toast.error(payload?.error ?? payload?.message ?? 'No fue posible crear la cuenta')
    }
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <AuthLayout title="Crear cuenta" subtitle="Empieza a llevar tu contabilidad personal">
    <form class="space-y-4" @submit.prevent="handleSubmit">
      <BaseInput v-model="form.name" label="Nombre" autocomplete="name" :error="errors.name" required />
      <BaseInput v-model="form.email" label="Email" type="email" autocomplete="email" :error="errors.email" required />
      <BaseInput
        v-model="form.password"
        label="Contraseña"
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
        required
      />

      <BaseButton type="submit" :loading="submitting" block>
        Crear cuenta
      </BaseButton>

      <p class="text-sm text-center text-[color:var(--color-text-muted)]">
        ¿Ya tienes cuenta?
        <RouterLink
          :to="{ name: 'login' }"
          class="text-[color:var(--color-accent)] hover:underline"
        >
          Inicia sesión
        </RouterLink>
      </p>
    </form>
  </AuthLayout>
</template>
