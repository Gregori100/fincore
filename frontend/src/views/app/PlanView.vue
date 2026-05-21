<script setup>
import { computed, onMounted, ref } from 'vue'
import { PlusIcon, TrashIcon } from '@heroicons/vue/24/outline'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { usePlanStore } from '@/stores/plan'
import { useToastStore } from '@/stores/toast'
import AppLayout from '@/components/layout/AppLayout.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import PlannedEventList from '@/components/finance/PlannedEventList.vue'
import PlannedEventForm from '@/components/finance/PlannedEventForm.vue'
import PlannedEventOverrideForm from '@/components/finance/PlannedEventOverrideForm.vue'
import PlanProjectionTable from '@/components/finance/PlanProjectionTable.vue'
import PlanProjectionChart from '@/components/finance/PlanProjectionChart.vue'

const auth = useAuthStore()
const finance = useFinanceStore()
const plan = usePlanStore()
const toast = useToastStore()

const openModal = ref(null) // 'event' | 'override' | null
const editingEvent = ref(null)
const overrideContext = ref(null)
const confirmDeleteEvent = ref(null)
const confirmClearAll = ref(false)

function fmt(n) {
  return new Intl.NumberFormat('es-MX', {
    style: 'currency',
    currency: 'MXN',
    maximumFractionDigits: 2,
  }).format(Number(n ?? 0))
}

const tab = ref('chart')

const projection = computed(() => plan.projection)

const projectedBO = computed(() => {
  const accs = projection.value?.accounts ?? []
  return accs
    .filter((a) => a.type === 'cash' || a.type === 'debit')
    .reduce((sum, a) => sum + Number(a.final_balance), 0)
})
const projectedDE = computed(() => {
  const accs = projection.value?.accounts ?? []
  return accs
    .filter((a) => a.type === 'credit')
    .reduce((sum, a) => sum + Number(a.final_balance), 0)
})
const firstDebtZero = computed(() => {
  const accs = projection.value?.accounts ?? []
  const debts = accs.filter((a) => a.type === 'credit' && a.initial_balance > 0)
  if (debts.length === 0) return null
  // Buscar primer evento que lleve una tarjeta a balance <= 0.
  const series = projection.value?.series ?? {}
  let earliest = null
  for (const debt of debts) {
    const points = series[debt.id] ?? []
    const zeroPoint = points.find((p) => p.balance <= 0)
    if (zeroPoint) {
      if (!earliest || zeroPoint.date < earliest.date) {
        earliest = { name: debt.name, date: zeroPoint.date }
      }
    }
  }
  return earliest
})

onMounted(async () => {
  // Si el usuario entra directo a /plan, asegurar que el state base está cargado.
  await finance.fetchState().catch(() => {})
  await plan.fetchEvents()
  await plan.fetchProjection()
})

function openCreate() {
  editingEvent.value = null
  openModal.value = 'event'
}

function openEdit(event) {
  editingEvent.value = event
  openModal.value = 'event'
}

function askDelete(event) {
  confirmDeleteEvent.value = event
}

async function confirmDelete() {
  const event = confirmDeleteEvent.value
  if (!event) return
  confirmDeleteEvent.value = null
  await plan.deleteEvent(event.id)
  toast.success('Evento eliminado')
}

async function clearAll() {
  confirmClearAll.value = false
  await plan.clearAll()
  toast.success('Plan limpiado')
}

function openOverride({ eventId, occurrenceDate, defaultAmount, overrideId }) {
  const event = plan.events.find((e) => e.id === eventId)
  const existing = (event?.overrides ?? []).find((o) => o.id === overrideId)
  overrideContext.value = {
    eventId,
    occurrenceDate,
    defaultAmount,
    override: existing ?? null,
  }
  openModal.value = 'override'
}

function close() {
  openModal.value = null
  editingEvent.value = null
  overrideContext.value = null
}
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Plan</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Proyección de saldos a 6 meses según los eventos que declares
          </p>
        </div>
        <div class="flex items-center gap-2">
          <BaseButton
            v-if="plan.events.length > 0"
            variant="ghost"
            :disabled="!auth.isVerified"
            class="text-[color:var(--color-negative)]"
            title="Borrar todos los eventos planeados"
            @click="confirmClearAll = true"
          >
            <TrashIcon class="h-4 w-4 mr-1" />
            Limpiar plan
          </BaseButton>
          <BaseButton :disabled="!auth.isVerified" @click="openCreate">
            <PlusIcon class="h-4 w-4 mr-1" />
            Nuevo evento
          </BaseButton>
        </div>
      </header>

      <!-- Hero: tres tiles con métricas proyectadas. -->
      <section class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-4">
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4">
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            BO proyectado en 6 meses
          </p>
          <p
            class="text-2xl font-semibold mt-1 tabular-nums"
            :class="projectedBO < 0 ? 'text-[color:var(--color-negative)]' : 'text-[color:var(--color-positive)]'"
          >
            {{ fmt(projectedBO) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4">
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Deuda proyectada en 6 meses
          </p>
          <p class="text-2xl font-semibold mt-1 tabular-nums text-[color:var(--color-negative)]">
            {{ fmt(projectedDE) }}
          </p>
        </article>
        <article class="bg-[color:var(--color-surface)] border border-[color:var(--color-border)] rounded-xl p-4">
          <p class="text-[10px] font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)]">
            Primera deuda a $0
          </p>
          <p v-if="firstDebtZero" class="text-sm font-medium mt-1">
            <span class="text-[color:var(--color-positive)]">{{ firstDebtZero.name }}</span>
            <span class="text-[color:var(--color-text-muted)]"> · {{ firstDebtZero.date }}</span>
          </p>
          <p v-else class="text-sm text-[color:var(--color-text-subtle)] italic mt-1">
            Ninguna llega a cero en el horizonte
          </p>
        </article>
      </section>

      <section>
        <h3 class="text-sm font-semibold uppercase tracking-wide text-[color:var(--color-text-subtle)] mb-3">
          Eventos planeados
        </h3>
        <PlannedEventList :events="plan.events" @edit="openEdit" @delete="askDelete" />
      </section>

      <section>
        <div class="flex items-center justify-between gap-3 mb-3">
          <h3 class="text-sm font-semibold uppercase tracking-wide text-[color:var(--color-text-subtle)]">
            Proyección
          </h3>
          <div class="flex gap-1 text-xs">
            <button
              type="button"
              class="px-2.5 py-1 rounded"
              :class="tab === 'chart' ? 'bg-[color:var(--color-accent)] text-black' : 'text-[color:var(--color-text-muted)] hover:bg-[color:var(--color-surface-elevated)]'"
              @click="tab = 'chart'"
            >
              Gráfica
            </button>
            <button
              type="button"
              class="px-2.5 py-1 rounded"
              :class="tab === 'table' ? 'bg-[color:var(--color-accent)] text-black' : 'text-[color:var(--color-text-muted)] hover:bg-[color:var(--color-surface-elevated)]'"
              @click="tab = 'table'"
            >
              Tabla
            </button>
          </div>
        </div>
        <PlanProjectionChart
          v-if="tab === 'chart' && projection"
          :accounts="projection.accounts"
          :series="projection.series"
          :events="projection.events"
        />
        <PlanProjectionTable
          v-if="tab === 'table' && projection"
          :events="projection.events"
          @edit="openOverride"
        />
      </section>
    </div>

    <BaseModal
      :open="openModal === 'event'"
      :title="editingEvent ? 'Editar evento planeado' : 'Nuevo evento planeado'"
      @close="close"
    >
      <PlannedEventForm
        :key="editingEvent?.id ?? 'new'"
        :event="editingEvent"
        @close="close"
        @success="close"
      />
    </BaseModal>

    <BaseModal
      :open="openModal === 'override'"
      title="Editar ocurrencia"
      @close="close"
    >
      <PlannedEventOverrideForm
        v-if="overrideContext"
        :event-id="overrideContext.eventId"
        :occurrence-date="overrideContext.occurrenceDate"
        :default-amount="overrideContext.defaultAmount"
        :override="overrideContext.override"
        @close="close"
        @success="close"
      />
    </BaseModal>

    <BaseConfirm
      :open="!!confirmDeleteEvent"
      title="Eliminar evento"
      :message="`¿Eliminar el evento ${confirmDeleteEvent ? 'seleccionado' : ''}? Se borrarán también sus overrides.`"
      confirm-label="Eliminar"
      variant="danger"
      @confirm="confirmDelete"
      @cancel="confirmDeleteEvent = null"
    />

    <BaseConfirm
      :open="confirmClearAll"
      title="Limpiar plan completo"
      message="¿Borrar todos los eventos planeados y sus overrides? La acción no se puede deshacer."
      confirm-label="Limpiar todo"
      variant="danger"
      @confirm="clearAll"
      @cancel="confirmClearAll = false"
    />
  </AppLayout>
</template>
