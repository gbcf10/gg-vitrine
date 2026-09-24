<script setup>
import { ref, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money } from '@/lib/format'

const biz = useBusiness()
const services = ref([])
const error = ref('')
const empty = () => ({ id: null, name: '', description: '', price: 0, duration_min: 30, active: true })
const form = ref(empty())

async function load() {
  services.value = unwrap(await supabase.from('services').select('*')
    .eq('business_id', biz.business.id).order('active', { ascending: false }).order('name'))
}
onMounted(load)

async function save() {
  error.value = ''
  const { id, ...fields } = form.value
  const payload = { ...fields, business_id: biz.business.id }
  const { error: err } = id
    ? await supabase.from('services').update(payload).eq('id', id)
    : await supabase.from('services').insert(payload)
  if (err) { error.value = err.message; return }
  form.value = empty()
  load()
}

function edit(s) {
  const { id, name, description, price, duration_min, active } = s
  form.value = { id, name, description, price, duration_min, active }
}

async function remove(s) {
  if (!confirm(`Excluir o serviço "${s.name}"?`)) return
  const { error: err } = await supabase.from('services').delete().eq('id', s.id)
  if (err) error.value = 'Este serviço já tem agendamentos. Desative-o em vez de excluir.'
  load()
}
</script>

<template>
  <div class="page-header"><h1>Serviços</h1></div>
  <div v-if="error" class="error">{{ error }}</div>

  <form class="card" @submit.prevent="save">
    <h3>{{ form.id ? 'Editar serviço' : 'Novo serviço' }}</h3>
    <div class="row">
      <div class="field" style="flex-basis: 260px"><label>Nome</label><input v-model="form.name" required /></div>
      <div class="field"><label>Preço (R$)</label><input v-model.number="form.price" type="number" min="0" step="0.01" required /></div>
      <div class="field"><label>Duração (min)</label><input v-model.number="form.duration_min" type="number" min="5" step="5" required /></div>
    </div>
    <div class="field"><label>Descrição <small>(opcional)</small></label><input v-model="form.description" /></div>
    <div class="row">
      <label class="shrink"><input v-model="form.active" type="checkbox" /> Ativo (aparece no agendamento)</label>
      <div class="shrink row" style="flex: 0 0 auto">
        <button v-if="form.id" type="button" class="btn secondary" @click="form = empty()">Cancelar</button>
        <button class="btn">{{ form.id ? 'Salvar' : 'Adicionar' }}</button>
      </div>
    </div>
  </form>

  <div class="card table-wrap">
    <p v-if="!services.length" class="muted">Nenhum serviço cadastrado ainda.</p>
    <table v-else>
      <thead><tr><th>Serviço</th><th>Preço</th><th>Duração</th><th>Status</th><th></th></tr></thead>
      <tbody>
        <tr v-for="s in services" :key="s.id">
          <td>{{ s.name }}<br /><small class="muted">{{ s.description }}</small></td>
          <td>{{ money(s.price) }}</td>
          <td>{{ s.duration_min }} min</td>
          <td><span :class="['badge', s.active ? 'green' : '']">{{ s.active ? 'Ativo' : 'Inativo' }}</span></td>
          <td style="white-space: nowrap; text-align: right">
            <button class="btn small secondary" @click="edit(s)">Editar</button>
            <button class="btn small secondary" @click="remove(s)">Excluir</button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
