<script setup>
import { onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'
import AuthLayout from '@/components/layout/AuthLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { CheckCircleIcon } from '@heroicons/vue/24/solid'

const auth = useAuthStore()

// Si el usuario está autenticado, refresca su info para reflejar el cambio.
onMounted(() => {
  if (auth.isAuthenticated) {
    auth.fetchMe().catch(() => {
      /* si el token caducó, dejamos que el interceptor 401 redirija */
    })
  }
})
</script>

<template>
  <AuthLayout>
    <div class="text-center space-y-4">
      <CheckCircleIcon class="h-16 w-16 mx-auto text-[color:var(--color-positive)]" />
      <h2 class="text-2xl font-semibold">¡Email verificado!</h2>
      <p class="text-[color:var(--color-text-muted)]">
        Tu cuenta está activa. Ya puedes usar FinCore con todas sus funciones.
      </p>

      <BaseButton
        v-if="auth.isAuthenticated"
        block
        @click="$router.push({ name: 'dashboard' })"
      >
        Ir al dashboard
      </BaseButton>
      <BaseButton
        v-else
        block
        @click="$router.push({ name: 'login' })"
      >
        Iniciar sesión
      </BaseButton>
    </div>
  </AuthLayout>
</template>
