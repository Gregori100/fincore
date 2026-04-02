<template>
  <div>
    <h1>FinCore</h1>

    <div v-if="store.loading">Cargando...</div>
    <div v-else-if="store.error">Error: {{ store.error }}</div>
    <div v-else>
      <p>BO (Bolsa): {{ store.bo }}</p>
      <p>DE (Deudas): {{ store.de }}</p>
      <ul>
        <li v-for="debt in store.debts" :key="debt.name">
          {{ debt.name }}: {{ debt.current_amount }}
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'
import { useFinanceStore } from '../stores/finance'

const store = useFinanceStore()
onMounted(() => store.fetchState())
</script>
