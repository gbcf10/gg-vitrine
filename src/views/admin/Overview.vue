<script setup>
import { ref, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { money, BUSINESS_STATUS, plural } from '@/lib/format'

const stats = ref(null)
const error = ref('')

onMounted(async () => {
  try {
    stats.value = unwrap(await supabase.rpc('admin_platform_stats'))
  } catch (e) {
    error.value = e.message
  }
})
</script>

<template>
  <div class="page-header">
    <p class="eyebrow">Plataforma</p>
    <h1>Resumo</h1>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <template v-if="stats">
    <div class="grid">
      <div class="card stat glow" style="margin: 0; border-color: rgba(59, 130, 246, 0.45)">
        <div class="label">Receita mensal recorrente</div>
        <div class="value gradient-text">{{ money(stats.mrr) }}</div>
      </div>
      <div class="card stat" style="margin: 0">
        <div class="label">Recebido este mês</div>
        <div class="value">{{ money(stats.received_this_month) }}</div>
      </div>
      <div class="card stat" style="margin: 0">
        <div class="label">Agendamentos no mês</div>
        <div class="value">{{ stats.appointments_this_month }}</div>
        <small>{{ stats.appointments_total }} no total</small>
      </div>
      <div class="card stat" style="margin: 0">
        <div class="label">Clientes finais</div>
        <div class="value">{{ stats.customers_total }}</div>
      </div>
    </div>

    <div class="grid" style="margin-top: 16px">
      <div class="card" style="margin: 0">
        <h3>Empresas</h3>
        <table>
          <tbody>
            <tr v-for="(label, key) in BUSINESS_STATUS" :key="key">
              <td>{{ label }}</td><td style="text-align: right"><strong>{{ stats.businesses_by_status[key] ?? 0 }}</strong></td>
            </tr>
          </tbody>
        </table>
        <RouterLink v-if="stats.businesses_by_status.pending" to="/admin/empresas" class="btn small" style="margin-top: 14px">
          Analisar {{ plural(stats.businesses_by_status.pending, 'pendente', 'pendentes') }}
        </RouterLink>
      </div>
      <div class="card" style="margin: 0">
        <h3>Assinaturas ativas por plano</h3>
        <table>
          <tbody>
            <tr v-for="plan in ['basico', 'profissional', 'premium']" :key="plan">
              <td style="text-transform: capitalize">{{ plan }}</td>
              <td style="text-align: right"><strong>{{ stats.active_by_plan[plan] ?? 0 }}</strong></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </template>
</template>
