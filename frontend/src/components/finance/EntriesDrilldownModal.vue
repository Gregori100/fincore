<script setup>
import { computed, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { financeApi } from '@/api/finance'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import CategoryBadge from '@/components/finance/CategoryBadge.vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  // Objeto de filtros estandarizado: { kind, account_id, category_id, from, to, year_month }.
  // Cualquier campo es opcional; el backend exige al menos uno y devuelve 422 si vienen todos vacíos.
  filters: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['close'])

const router = useRouter()

const loading = ref(false)
const error = ref(null)
const entries = ref([])
const truncated = ref(false)
const totalCount = ref(0)
const bucketLabel = ref('')

function fmtMoney(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const KIND_LABEL = {
  income: 'Ingreso',
  expense: 'Gasto',
  credit_expense: 'Cargo crédito',
  debt_payment: 'Pago tarjeta',
  transfer: 'Transferencia',
  adjustment: 'Ajuste',
}
const KIND_COLOR = {
  income: 'text-[color:var(--color-positive)]',
  expense: 'text-[color:var(--color-negative)]',
  credit_expense: 'text-[color:var(--color-warning)]',
  debt_payment: 'text-[color:var(--color-accent)]',
  transfer: 'text-[color:var(--color-text-muted)]',
  adjustment: 'text-[color:var(--color-text-muted)]',
}

const total = computed(() =>
  entries.value.reduce((acc, e) => acc + Number(e.amount ?? 0), 0),
)

function pruneFilters(f) {
  // Quita campos vacíos antes de mandar al backend. `null`/`undefined`/`''`
  // se descartan; valores 0 / false se preservan.
  // EXCEPCIÓN: `category_id: null` se traduce a string vacío `''` para que
  // axios lo serialice en el query string (`?category_id=`). axios omite por
  // default los params con valor `null`/`undefined`. El backend valida con
  // `nullable` y trata `''` y `null` de forma equivalente como filtro
  // "sin categoría" (bucket "Sin categorizar" de los reportes que agrupan
  // por categoría).
  const out = {}
  for (const k of Object.keys(f)) {
    const v = f[k]
    if (k === 'category_id' && v === null) {
      out[k] = ''
      continue
    }
    if (v === null || v === undefined) continue
    if (typeof v === 'string' && v === '') continue
    out[k] = v
  }
  return out
}

async function fetchEntries() {
  loading.value = true
  error.value = null
  try {
    const { data } = await financeApi.entriesByBucket(pruneFilters(props.filters))
    entries.value = data.entries ?? []
    truncated.value = !!data.truncated
    totalCount.value = data.total_count ?? 0
    bucketLabel.value = data.bucket_label ?? ''
  } catch (e) {
    const payload = e.response?.data
    error.value = payload?.error ?? payload?.message ?? 'No se pudo cargar el detalle.'
  } finally {
    loading.value = false
  }
}

watch(
  () => props.open,
  (isOpen) => {
    if (isOpen) fetchEntries()
  },
  { immediate: true },
)

function goToEntries() {
  router.push({ name: 'entries', query: pruneFilters(props.filters) })
  emit('close')
}
</script>

<template>
  <BaseModal :open="open" :title="bucketLabel || 'Detalle de movimientos'" size="lg" @close="emit('close')">
    <div class="space-y-3">
      <!-- Resumen del bucket -->
      <div class="flex items-center justify-between text-sm">
        <span class="text-[color:var(--color-text-muted)]">
          {{ entries.length }} de {{ totalCount }} movimientos
        </span>
        <span class="font-semibold tabular-nums">{{ fmtMoney(total) }}</span>
      </div>

      <!-- Aviso de truncado -->
      <div
        v-if="truncated"
        class="bg-[color:var(--color-warning)]/10 border border-[color:var(--color-warning)]/30 rounded-lg p-3 text-xs"
      >
        Mostrando los 100 más recientes de {{ totalCount }}. Para ver todo y editar, abre en Movimientos.
      </div>

      <!-- Estados de carga / error / vacío / lista -->
      <BaseSkeleton v-if="loading" class="h-40" />
      <div v-else-if="error" class="text-sm text-[color:var(--color-negative)]">{{ error }}</div>
      <div
        v-else-if="!entries.length"
        class="text-sm text-[color:var(--color-text-subtle)] italic text-center py-6"
      >
        Sin movimientos en este bucket.
      </div>
      <div v-else class="border border-[color:var(--color-border)] rounded-lg overflow-hidden max-h-[55vh] overflow-y-auto">
        <table class="w-full text-sm">
          <thead class="bg-[color:var(--color-surface-elevated)] sticky top-0">
            <tr class="text-left text-[color:var(--color-text-muted)] text-xs uppercase tracking-wide">
              <th class="px-3 py-2">Fecha</th>
              <th class="px-3 py-2">Tipo</th>
              <th class="px-3 py-2 text-right">Monto</th>
              <th class="px-3 py-2">Cuentas</th>
              <th class="px-3 py-2">Descripción</th>
              <th class="px-3 py-2">Categoría</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="e in entries"
              :key="e.id"
              class="border-t border-[color:var(--color-border)]"
            >
              <td class="px-3 py-2 tabular-nums text-xs whitespace-nowrap">
                {{ String(e.occurred_at).slice(0, 10) }}
              </td>
              <td class="px-3 py-2 text-xs" :class="KIND_COLOR[e.kind]">
                {{ KIND_LABEL[e.kind] ?? e.kind }}
              </td>
              <td class="px-3 py-2 text-right tabular-nums font-medium">
                {{ fmtMoney(e.amount) }}
              </td>
              <td class="px-3 py-2 text-xs text-[color:var(--color-text-muted)]">
                <template v-if="e.origin">{{ e.origin.name }}</template>
                <template v-if="e.origin && e.destination"> → </template>
                <template v-if="e.destination">{{ e.destination.name }}</template>
              </td>
              <td class="px-3 py-2 text-xs">{{ e.description ?? '' }}</td>
              <td class="px-3 py-2">
                <CategoryBadge v-if="e.category" :category="e.category" />
                <span v-else class="text-[color:var(--color-text-subtle)] text-xs">—</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <footer class="flex gap-2 justify-end pt-2 border-t border-[color:var(--color-border)]">
        <BaseButton variant="ghost" type="button" @click="emit('close')">Cerrar</BaseButton>
        <BaseButton type="button" :disabled="!entries.length && !truncated" @click="goToEntries">
          Ir a Movimientos
        </BaseButton>
      </footer>
    </div>
  </BaseModal>
</template>
