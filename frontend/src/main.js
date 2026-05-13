import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { bindAuth, bindToast, bindRouter } from './api/client'
import { useAuthStore } from './stores/auth'
import { useToastStore } from './stores/toast'
import './assets/main.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Conectamos el cliente HTTP con los stores y el router. El binding es
// perezoso: las llamadas a `useAuthStore()` / `useToastStore()` dentro de
// los interceptors solo ocurren después de montar Pinia.
bindAuth(() => useAuthStore())
bindToast(() => useToastStore())
bindRouter(router)

app.mount('#app')
