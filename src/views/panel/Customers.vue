<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDateTime, APPOINTMENT_STATUS, plural } from '@/lib/format'

const biz = useBusiness()
const customers = ref([])
const search = ref('')
const error = ref('')
const selected = ref(null)
const history = ref([])
const form = ref({ name: '', phone: '', email: '', notes: '' })

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return q ? customers.value.filter((c) => `${c.name} ${c.phone ?? ''} ${c.email ?? ''}`.toLowerCase().includes(q)) : customers.value
})
const limit = computed(() => biz.plan?.max_customers)

async function load() {
  customers.value = unwrap(await supabase.from('customers').select('*')
    .eq('business_id', biz.business.id).order('name'))
}
onMounted(load)

async function add() {
  error.value = ''
  const { error: err } = await supabase.from('customers').insert({ ...form.value, business_id: biz.business.id })
  if (err) { error.value = err.message; return }
  form.value = { name: '', phone: '', email: '', notes: '' }
  load()
}

async function open(c) {
  selected.value = { ...c }
  window.scrollTo({ top: 0, behavior: 'smooth' })
  history.value = unwrap(await supabase.from('appointments')
    .select('id, starts_at, status, price, service:services(name), professional:professionals(name)')
    .eq('customer_id', c.id).order('starts_at', { ascending: false }).limit(50))
}

async function saveSelected() {
  const { id, name, phone, email, notes } = selected.value
  const { error: err } = await supabase.from('customers').update({ name, phone, email, notes }).eq('id', id)
  if (err) error.value = err.message
  else { selected.value = null; load() }
}
</script>

<template>
  <div class="page-header spread">
    <h1>Clientes</h1>
    <span class="muted">{{ limit ? `${customers.length} de ${limit} clientes` : plural(customers.length, 'cliente', 'clientes') }}</span>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <div v-if="selected" class="card">
    <div class="spread"><h3>{{ selected.name }}</h3><button class="btn small secondary" @click="selected = null">Fechar</button></div>
    <div class="row">
      <div class="field"><label>Nome</label><input v-model="selected.name" /></div>
      <div class="field"><label>Telefone</label><input v-model="selected.phone" /></div>
      <div class="field"><label>E-mail</label><input v-model="selected.email" /></div>
    </div>
    <div class="field"><label>Observações</label><textarea v-model="selected.notes" rows="2" /></div>
    <button class="btn" @click="saveSelected">Salvar</button>

    <h3 style="margin-top: 20px">Histórico</h3>
    <p v-if="!history.length" class="muted">Nenhum agendamento.</p>
    <table v-else>
      <tbody>
        <tr v-for="a in history" :key="a.id">
          <td>{{ formatDateTime(a.starts_at, biz.business.timezone) }}</td>
          <td>{{ a.service?.name }}</td>
          <td>{{ a.professional?.name }}</td>
          <td>{{ money(a.price) }}</td>
          <td>{{ APPOINTMENT_STATUS[a.status] }}</td>
        </tr>
      </tbody>
    </table>
  </div>

  <form class="card" @submit.prevent="add">
    <h3>Novo cliente</h3>
    <div class="row">
      <div class="field"><label>Nome</label><input v-model="form.name" required /></div>
      <div class="field"><label>Telefone</label><input v-model="form.phone" type="tel" /></div>
      <div class="field"><label>E-mail</label><input v-model="form.email" type="email" /></div>
      <div class="field shrink"><button class="btn">Adicionar</button></div>
    </div>
  </form>

  <div class="card table-wrap">
    <input v-model="search" placeholder="Buscar por nome, telefone ou e-mail" style="margin-bottom: 12px" />
    <p v-if="!filtered.length" class="muted">Nenhum cliente encontrado.</p>
    <table v-else>
      <thead><tr><th>Nome</th><th>Telefone</th><th>E-mail</th><th></th></tr></thead>
      <tbody>
        <tr v-for="c in filtered" :key="c.id">
          <td>{{ c.name }} <span v-if="c.auth_user_id" class="badge" title="Agenda pelo link">online</span></td>
          <td>{{ c.phone }}</td>
          <td>{{ c.email }}</td>
          <td style="text-align: right"><button class="btn small secondary" @click="open(c)">Ver</button></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
