import { defineConfig, devices } from '@playwright/test'

/**
 * Config de Playwright para FinCore.
 *
 * Asume que el stack Docker ya está arriba (`./scripts/fincore start`) y expone:
 *   - Frontend en http://localhost:5173
 *   - API en http://localhost:83
 *   - Mailpit en http://localhost:8025
 *
 * No arrancamos el stack desde aquí (`webServer`) para no acoplar los tests al
 * ciclo de vida del compose — se asume que el dev tiene el stack corriendo.
 */
export default defineConfig({
  testDir: './specs',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  globalSetup: './global-setup.js',

  // Los E2E comparten BD/Redis/Mailpit; corremos secuencial para evitar
  // rate-limit cruzado en /auth/* (throttle:6,1) y emails entrecruzados.
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 2 : 0,

  reporter: [['html', { open: 'never' }], ['list']],

  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
})
