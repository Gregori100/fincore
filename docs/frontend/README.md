# Frontend de FinCore

SPA en **Vue 3 + Vite + Pinia + Vue Router + Tailwind v4 + Headless UI**. Consume el backend Laravel vía la API REST documentada en [`../api/`](../api/).

## Cuándo usar el frontend vs el CLI

- **Frontend** (esta carpeta): para uso cotidiano vía navegador. Registrar movimientos, ver el dashboard, gestionar cuentas.
- **CLI** `php artisan fin:*` ([`../cli/`](../cli/)): para scripts, pruebas rápidas, o cuando no quieres abrir el navegador.

Ambos llaman a las mismas Actions del backend; las reglas de negocio aplican igual.

## Stack

| Pieza | Versión | Para qué |
|-------|---------|----------|
| Vue 3 | ^3.5 | Framework principal (Composition API + `<script setup>`) |
| Pinia | ^2.2 | State management |
| Vue Router | ^4.4 | Ruteo SPA con guards |
| Axios | ^1.7 | Cliente HTTP |
| Tailwind CSS | ^4.3 | Utility-first styling |
| @tailwindcss/vite | ^4.3 | Plugin de Vite para Tailwind v4 |
| @headlessui/vue | ^1.7 | Primitivas accesibles (Dialog, Listbox) |
| @heroicons/vue | ^2.2 | Iconos |
| @vueuse/core | ^14 | Utilities (`useStorage` para persistir token) |
| Vitest | ^4 | Tests unitarios |
| @vue/test-utils | ^2.4 | Mounting helpers para tests |

## Estructura

```
src/
├── main.js              # Bootstrap Pinia + Router + CSS + binding del client HTTP
├── App.vue              # <RouterView /> + <ToastList /> global
├── assets/main.css      # @import tailwindcss + @theme con paleta oscura
├── api/
│   ├── client.js        # Axios instance + interceptors (lazy-bound a auth + router)
│   ├── auth.js          # endpoints /api/auth/*
│   └── finance.js       # endpoints /api/finance/*
├── stores/
│   ├── auth.js          # token (localStorage), user, login/logout/register/fetchMe
│   ├── finance.js       # state, accounts, recentEntries + fetchState + mutaciones
│   └── toast.js         # messages global con push/success/error/dismiss
├── router/index.js      # rutas + beforeEach guard
├── components/
│   ├── layout/
│   │   ├── AuthLayout.vue    # card centrada para login/register
│   │   └── AppLayout.vue     # topbar + logout + slot
│   ├── ui/
│   │   ├── BaseButton.vue    # variants primary/secondary/ghost/danger
│   │   ├── BaseInput.vue     # input + label + error/hint
│   │   ├── BaseSelect.vue    # Headless UI Listbox wrapper
│   │   ├── BaseModal.vue     # Headless UI Dialog wrapper
│   │   └── ToastList.vue     # render del store toast
│   └── finance/
│       ├── StateSummary.vue
│       ├── AccountCard.vue
│       ├── AccountList.vue
│       ├── RecentEntries.vue
│       ├── AccountForm.vue
│       ├── IncomeForm.vue
│       ├── ExpenseForm.vue
│       ├── CreditExpenseForm.vue
│       ├── PayCreditForm.vue
│       └── TransferForm.vue
└── views/
    ├── auth/
    │   ├── LoginView.vue
    │   ├── RegisterView.vue
    │   └── EmailVerifiedView.vue
    └── app/DashboardView.vue
```

## Flujo de autenticación

1. **Sin token** → router guard redirige a `/login`.
2. **Login/Register** → guarda `{ token, user }` en `useAuthStore`. Token persiste en `localStorage` vía `useStorage` de `@vueuse/core`.
3. **Cada request HTTP** → Axios request interceptor (`api/client.js`) lee `useAuthStore().token` y añade `Authorization: Bearer <token>`.
4. **Si el backend responde 401** y no es endpoint de login/register → response interceptor llama `auth.clear()` y redirige a `/login`.
5. **Si el email no está verificado** → el dashboard muestra un banner con CTA "Reenviar email". El link del email apunta al backend (`/api/auth/email/verify/...`), que redirige a `/email-verified` tras marcar al user como verified.

## Patrón de stores (Composition API)

```js
export const useAuthStore = defineStore('auth', () => {
  const token = useStorage('fincore_token', null)
  const isAuthenticated = computed(() => !!token.value)

  async function login(email, password) { /* ... */ }
  async function logout() { /* ... */ }

  return { token, isAuthenticated, login, logout }
})
```

Composition API + `defineStore` con función. `useStorage` sincroniza state ↔ localStorage automáticamente.

## Patrón de formularios

Todos los `*Form.vue` siguen el mismo patrón:
- Props: ninguna (leen del store).
- Emits: `close`, `success`.
- State local con `ref()`.
- `submit()` → `try { await store.action(...) } catch (e) { /* errores por campo o toast */ }`.
- Manejo de errores del contrato HTTP:
  - `422` con `errors` (Laravel validation) → muestra error inline por campo.
  - `422`/`409` con `error` + `code` (domain exceptions) → toast.

## Tema visual

- **Paleta oscura única** definida en `assets/main.css` vía `@theme`:
  - `--color-canvas`, `--color-surface`, `--color-surface-elevated`, `--color-border`
  - `--color-text-primary`, `--color-text-muted`, `--color-text-subtle`
  - `--color-accent`, `--color-positive`, `--color-negative`, `--color-warning`
- Sin toggle día/noche por simplicidad. Si lo quieres después, las CSS variables ya están listas.
- Tipografía: sans-serif del sistema + feature settings (`cv11`, `ss01`, `ss03`).

## Cómo correr

```bash
# Dev server (dentro del container)
docker compose exec frontend npm run dev
# o si está montado en compose.yaml, ya corre solo. Abre http://localhost:5173

# Build de producción
docker compose exec frontend npm run build

# Tests
docker compose exec frontend npm run test           # one-shot
docker compose exec frontend npm run test:watch     # watch mode
```

## Tests

Cobertura mínima con Vitest (10 tests al momento de este sprint):
- `tests/stores/auth.spec.js` (3): login, logout robusto, isVerified.
- `tests/stores/finance.spec.js` (3): fetchState, getters filtrados, reset.
- `tests/router/guards.spec.js` (2): redirige a /login sin auth; a /dashboard si autenticado.
- `tests/components/StateSummary.spec.js` (2): renderiza valores y maneja ceros.

Los stores se mockean con `vi.mock('@/api/...')`. No tocan backend real.

## Lo que queda fuera (Fase 2 del frontend)

- CRUD avanzado de cuentas (editar metadata, eliminar).
- Vista de historial completa con filtros sobre `/api/finance/entries`.
- Reset de password UI (`/forgot-password` y `/reset-password`).
- Perfil de usuario / cambio de password / logout-all.
- Modo claro toggle.
- i18n.
- e2e con Playwright.

## Proxy en dev

`vite.config.js` proxea `/api` → `http://api` (el hostname del backend dentro de la red Docker). Eso evita CORS en dev sin necesitar `Access-Control-Allow-Origin` desde Laravel.
