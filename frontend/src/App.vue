<script setup>
import { watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import ToastList from '@/components/ui/ToastList.vue'

const auth = useAuthStore()
const finance = useFinanceStore()
const router = useRouter()
const route = useRoute()

// Sincronización entre pestañas vía storage event (lo escucha useStorage de
// @vueuse). Si el usuario hace logout en otra pestaña, el token se vuelve
// null aquí; redirigimos a /login y limpiamos el state financiero local.
// Si hace login en otra pestaña estando en /login, lo llevamos al dashboard.
watch(
  () => auth.token,
  (newToken, oldToken) => {
    if (oldToken && !newToken) {
      // Logout desde otra pestaña.
      finance.reset()
      if (route.meta.requiresAuth) {
        router.push({ name: 'login' })
      }
    } else if (!oldToken && newToken) {
      // Login desde otra pestaña.
      if (route.meta.requiresGuest) {
        router.push({ name: 'dashboard' })
      }
    }
  },
)
</script>

<template>
  <RouterView v-slot="{ Component, route: r }">
    <transition :name="r.meta.transition || 'page'" mode="out-in">
      <component :is="Component" :key="r.fullPath" />
    </transition>
  </RouterView>
  <ToastList />
</template>

<style>
.page-enter-active,
.page-leave-active {
  transition: opacity 180ms ease, transform 220ms cubic-bezier(0.4, 0, 0.2, 1);
}
.page-enter-from {
  opacity: 0;
  transform: translateY(8px);
}
.page-leave-to {
  opacity: 0;
  transform: translateY(-4px);
}
</style>
