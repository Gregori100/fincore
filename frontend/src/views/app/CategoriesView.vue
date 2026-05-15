<script setup>
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useFinanceStore } from '@/stores/finance'
import { useToastStore } from '@/stores/toast'
import { financeApi } from '@/api/finance'
import AppLayout from '@/components/layout/AppLayout.vue'
import CategoryCard from '@/components/finance/CategoryCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseSkeleton from '@/components/ui/BaseSkeleton.vue'
import BaseModal from '@/components/ui/BaseModal.vue'
import BaseConfirm from '@/components/ui/BaseConfirm.vue'
import CategoryForm from '@/components/finance/CategoryForm.vue'
import CategoryEditForm from '@/components/finance/CategoryEditForm.vue'
import { ArchiveBoxIcon, MagnifyingGlassIcon, PlusIcon } from '@heroicons/vue/24/outline'

const auth = useAuthStore()
const finance = useFinanceStore()
const toast = useToastStore()

// Lista local incluye archivadas (el store sólo trae activas).
const allCategories = ref([])
const loading = ref(false)
const error = ref(null)
const openModal = ref(null)
const editingCategory = ref(null)
const archivingCategory = ref(null)
const archivingState = ref(false)
const searchQuery = ref('')

const filtered = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return allCategories.value
  return allCategories.value.filter((c) => c.name.toLowerCase().includes(q))
})

const groups = computed(() => {
  const active = filtered.value.filter((c) => !c.deleted_at)
  return {
    expense: active.filter((c) => c.applies_to === 'expense'),
    income: active.filter((c) => c.applies_to === 'income'),
    both: active.filter((c) => c.applies_to === 'both'),
    archived: filtered.value.filter((c) => c.deleted_at),
  }
})

const hasResults = computed(
  () => groups.value.expense.length > 0
    || groups.value.income.length > 0
    || groups.value.both.length > 0
    || groups.value.archived.length > 0,
)

async function fetchAll() {
  loading.value = true
  error.value = null
  try {
    const { data } = await financeApi.listCategories({ includeArchived: true })
    allCategories.value = data.categories ?? []
  } catch (e) {
    error.value
      = e.response?.data?.message
      ?? (e.message?.includes('Network')
        ? 'No hay conexión con el servidor.'
        : 'No se pudieron cargar las categorías.')
  } finally {
    loading.value = false
  }
}

function close() {
  openModal.value = null
  editingCategory.value = null
  archivingCategory.value = null
}

function handleEdit(category) {
  editingCategory.value = category
  openModal.value = 'edit-category'
}

function handleArchive(category) {
  archivingCategory.value = category
  openModal.value = 'archive-category'
}

async function confirmArchive() {
  if (!archivingCategory.value) return
  archivingState.value = true
  try {
    await finance.archiveCategory(archivingCategory.value.id)
    toast.success(`Categoría "${archivingCategory.value.name}" archivada`)
    close()
    await fetchAll()
  } catch (e) {
    const payload = e.response?.data
    toast.error(payload?.error ?? 'No se pudo archivar la categoría')
  } finally {
    archivingState.value = false
  }
}

async function onMutationSuccess() {
  // CategoryForm/CategoryEditForm ya llaman al store; resincronizamos archivadas.
  await fetchAll()
}

onMounted(async () => {
  if (!finance.categories.length) {
    try {
      await finance.fetchState()
    } catch {
      // El interceptor 401 redirige.
    }
  }
  await fetchAll()
})
</script>

<template>
  <AppLayout>
    <div class="space-y-6">
      <header class="flex items-center justify-between">
        <div>
          <h2 class="text-xl font-semibold tracking-tight">Categorías</h2>
          <p class="text-sm text-[color:var(--color-text-muted)] mt-0.5">
            Etiqueta tus movimientos para reportes precisos
          </p>
        </div>
        <div class="flex items-center gap-3">
          <RouterLink
            :to="{ name: 'dashboard' }"
            class="text-sm text-[color:var(--color-text-muted)] hover:text-[color:var(--color-text-primary)] transition"
          >
            ← Dashboard
          </RouterLink>
          <BaseButton
            variant="secondary"
            :disabled="!auth.isVerified"
            :title="auth.isVerified ? '' : 'Verifica tu email primero'"
            @click="openModal = 'category'"
          >
            <PlusIcon class="h-4 w-4" />
            Nueva categoría
          </BaseButton>
        </div>
      </header>

      <div v-if="loading && !allCategories.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <BaseSkeleton v-for="n in 6" :key="n" height="h-20" rounded="rounded-xl" />
      </div>

      <div
        v-else-if="error && !allCategories.length"
        class="rounded-xl border border-[color:var(--color-negative)]/40 bg-[color:var(--color-negative)]/10 p-6 text-center"
      >
        <p class="text-sm text-[color:var(--color-text-primary)]">{{ error }}</p>
        <BaseButton variant="secondary" class="mt-4" @click="fetchAll">Reintentar</BaseButton>
      </div>

      <template v-else>
        <div v-if="allCategories.length > 5" class="relative max-w-md">
          <MagnifyingGlassIcon class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-[color:var(--color-text-subtle)] pointer-events-none" />
          <input
            v-model="searchQuery"
            type="search"
            placeholder="Buscar categoría..."
            class="w-full pl-9 pr-3 py-2 rounded-md bg-[color:var(--color-surface-elevated)] border border-[color:var(--color-border)] text-[color:var(--color-text-primary)] placeholder:text-[color:var(--color-text-subtle)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[color:var(--color-accent)] transition text-sm"
          />
        </div>

        <div
          v-if="searchQuery && !hasResults"
          class="rounded-xl border border-[color:var(--color-border)] p-8 text-center"
        >
          <p class="text-sm text-[color:var(--color-text-muted)]">
            Ninguna categoría coincide con
            <span class="text-[color:var(--color-text-primary)] font-medium">"{{ searchQuery }}"</span>
          </p>
        </div>

        <section v-if="groups.expense.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3">
            Gastos <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ groups.expense.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <CategoryCard
              v-for="c in groups.expense"
              :key="c.id"
              :category="c"
              @edit="handleEdit"
              @archive="handleArchive"
            />
          </div>
        </section>

        <section v-if="groups.income.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3">
            Ingresos <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ groups.income.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <CategoryCard
              v-for="c in groups.income"
              :key="c.id"
              :category="c"
              @edit="handleEdit"
              @archive="handleArchive"
            />
          </div>
        </section>

        <section v-if="groups.both.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3">
            Ambos <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ groups.both.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <CategoryCard
              v-for="c in groups.both"
              :key="c.id"
              :category="c"
              @edit="handleEdit"
              @archive="handleArchive"
            />
          </div>
        </section>

        <section v-if="groups.archived.length">
          <h3 class="text-xs font-semibold uppercase tracking-[0.08em] text-[color:var(--color-text-subtle)] mb-3 flex items-center gap-2">
            <ArchiveBoxIcon class="h-3.5 w-3.5" />
            Archivadas <span class="text-[color:var(--color-text-muted)] normal-case font-normal">({{ groups.archived.length }})</span>
          </h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <CategoryCard
              v-for="c in groups.archived"
              :key="c.id"
              :category="c"
            />
          </div>
        </section>
      </template>
    </div>

    <BaseModal :open="openModal === 'category'" title="Nueva categoría" @close="close">
      <CategoryForm @close="close" @success="onMutationSuccess" />
    </BaseModal>
    <BaseModal
      :open="openModal === 'edit-category'"
      :title="editingCategory ? `Editar ${editingCategory.name}` : 'Editar categoría'"
      @close="close"
    >
      <CategoryEditForm
        v-if="editingCategory"
        :category="editingCategory"
        @close="close"
        @success="onMutationSuccess"
      />
    </BaseModal>
    <BaseConfirm
      :open="openModal === 'archive-category'"
      :title="`Archivar ${archivingCategory?.name ?? 'categoría'}`"
      message="La categoría dejará de aparecer en los formularios. Tus movimientos existentes mantienen la referencia, pero el badge desaparece. Esta acción no se puede deshacer."
      confirm-label="Archivar"
      variant="danger"
      :loading="archivingState"
      @confirm="confirmArchive"
      @cancel="close"
    />
  </AppLayout>
</template>
