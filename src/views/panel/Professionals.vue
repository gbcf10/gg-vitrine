<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'

const biz = useBusiness()
const professionals = ref([])
const services = ref([])
const error = ref('')
const empty = () => ({ id: null, name: '', active: true, service_ids: [] })
const form = ref(empty())

const limit = computed(() => biz.plan?.max_professionals)
const activeCount = computed(() => professionals.value.filter((p) => p.active).length)

async function load() {
  const bid = biz.business.id
  services.value = unwrap(await supabase.from('services').select('id, name').eq('business_id', bid).order('name'))
  const rows = unwrap(await supabase.from('professionals')
    .select('*, professional_services(service_id)').eq('business_id', bid).order('name'))
  professionals.value = rows.map((p) => ({ ...p, service_ids: p.professional_services.map((x) => x.service_id) }))
}
onMounted(load)

async function save() {
  error.value = ''
  const bid = biz.business.id
  const { id, name, active, service_ids } = form.value
  try {
    let profId = id
    if (id) {
      unwrap(await supabase.from('professionals').update({ name, active }).eq('id', id))
    } else {
      profId = unwrap(await supabase.from('professionals')
        .insert({ business_id: bid, name, active }).select('id').single()).id
    }
    // Sincroniza os serviços que o profissional atende.
    unwrap(await supabase.from('professional_services').delete().eq('professional_id', profId))
    if (service_ids.length) {
      unwrap(await supabase.from('professional_services')
        .insert(service_ids.map((service_id) => ({ business_id: bid, professional_id: profId, service_id }))))
    }
    form.value = empty()
  } catch (e) {
    error.value = e.message
  }
  load()
}

function edit(p) {
  form.value = { id: p.id, name: p.name, active: p.active, service_ids: [...p.service_ids] }
}

function serviceNames(ids) {
  return services.value.filter((s) => ids.includes(s.id)).map((s) => s.name).join(', ') || '—'
}
</script>

<template>
  <div class="page-header spread">
    <h1>Profissionais</h1>
    <span class="muted">{{ activeCount }} ativo(s){{ limit ? ` de ${limit} do seu plano` : '' }}</span>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <form class="card" @submit.prevent="save">
    <h3>{{ form.id ? 'Editar profissional' : 'Novo profissional' }}</h3>
    <div class="field"><label>Nome</label><input v-model="form.name" required /></div>
    <div class="field">
      <label>Serviços que realiza</label>
      <p v-if="!services.length" class="muted">Cadastre os serviços primeiro.</p>
      <div class="chips">
        <label v-for="s in services" :key="s.id" class="chip" :class="{ selected: form.service_ids.includes(s.id) }">
          <input v-model="form.service_ids" type="checkbox" :value="s.id" style="display: none" />{{ s.name }}
        </label>
      </div>
    </div>
    <div class="row">
      <label class="shrink"><input v-model="form.active" type="checkbox" /> Ativo</label>
      <div class="shrink row" style="flex: 0 0 auto">
        <button v-if="form.id" type="button" class="btn secondary" @click="form = empty()">Cancelar</button>
        <button class="btn">{{ form.id ? 'Salvar' : 'Adicionar' }}</button>
      </div>
    </div>
  </form>

  <div class="card table-wrap">
    <p v-if="!professionals.length" class="muted">Nenhum profissional cadastrado. Cadastre ao menos um (pode ser você).</p>
    <table v-else>
      <thead><tr><th>Nome</th><th>Serviços</th><th>Status</th><th></th></tr></thead>
      <tbody>
        <tr v-for="p in professionals" :key="p.id">
          <td>{{ p.name }}</td>
          <td>{{ serviceNames(p.service_ids) }}</td>
          <td><span :class="['badge', p.active ? 'green' : '']">{{ p.active ? 'Ativo' : 'Inativo' }}</span></td>
          <td style="text-align: right">
            <button class="btn small secondary" @click="edit(p)">Editar</button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
