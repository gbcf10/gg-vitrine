<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { plural } from '@/lib/format'

const biz = useBusiness()
const professionals = ref([])
const services = ref([])
const error = ref('')
// Profissional novo já vem com todos os serviços marcados (o caso mais comum).
const empty = () => ({ id: null, name: '', phone: '', email: '', active: true, service_ids: services.value.map((s) => s.id) })
const form = ref(empty())

const label = computed(() => biz.business.staff_label || 'Profissional')
const limit = computed(() => biz.plan?.max_professionals)
const activeCount = computed(() => professionals.value.filter((p) => p.active).length)

async function load() {
  const bid = biz.business.id
  services.value = unwrap(await supabase.from('services').select('id, name').eq('business_id', bid).order('name'))
  const rows = unwrap(await supabase.from('professionals')
    .select('*, professional_services(service_id)').eq('business_id', bid).order('name'))
  professionals.value = rows.map((p) => ({ ...p, service_ids: p.professional_services.map((x) => x.service_id) }))
  if (!form.value.id && !form.value.name) form.value = empty()
}
onMounted(load)

async function save() {
  error.value = ''
  const bid = biz.business.id
  const { id, name, active, service_ids } = form.value
  const phone = form.value.phone || null
  const email = form.value.email || null
  try {
    let profId = id
    if (id) {
      unwrap(await supabase.from('professionals').update({ name, active, phone, email }).eq('id', id))
    } else {
      profId = unwrap(await supabase.from('professionals')
        .insert({ business_id: bid, name, active, phone, email }).select('id').single()).id
    }
    // Sincroniza os serviços que o profissional atende.
    unwrap(await supabase.from('professional_services').delete().eq('professional_id', profId))
    if (service_ids.length) {
      unwrap(await supabase.from('professional_services')
        .insert(service_ids.map((service_id) => ({ business_id: bid, professional_id: profId, service_id }))))
    }
    saved.value = `${name} salvo.`
    form.value = empty()
  } catch (e) {
    error.value = e.message
  }
  load()
}

const formEl = ref(null)
const saved = ref('')

function edit(p) {
  form.value = { id: p.id, name: p.name, phone: p.phone ?? '', email: p.email ?? '', active: p.active, service_ids: [...p.service_ids] }
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

// Liga com um clique a todos os serviços cadastrados.
async function linkAll(p) {
  error.value = ''
  const bid = biz.business.id
  const rows = services.value.filter((s) => !p.service_ids.includes(s.id))
    .map((s) => ({ business_id: bid, professional_id: p.id, service_id: s.id }))
  const { error: err } = await supabase.from('professional_services').insert(rows)
  if (err) error.value = err.message
  else saved.value = `${p.name} agora faz todos os serviços.`
  load()
}

function serviceNames(ids) {
  return services.value.filter((s) => ids.includes(s.id)).map((s) => s.name).join(', ') || '—'
}
</script>

<template>
  <div class="page-header spread">
    <h1>{{ label === 'Profissional' ? 'Profissionais' : `${label}s` }}</h1>
    <span class="muted">{{ plural(activeCount, 'ativo', 'ativos') }}{{ limit ? ` de ${limit} do seu plano` : '' }}</span>
  </div>
  <div v-if="error" class="error">{{ error }}</div>
  <div v-if="saved" class="success">{{ saved }}</div>

  <form ref="formEl" class="card" :class="{ glow: form.id }" @submit.prevent="save">
    <h3>{{ form.id ? `Editar ${label.toLowerCase()}` : `Adicionar ${label.toLowerCase()}` }}</h3>
    <div class="row">
      <div class="field"><label>Nome</label><input v-model="form.name" required /></div>
      <div class="field"><label>WhatsApp <small>(opcional, para lembretes)</small></label><input v-model="form.phone" type="tel" /></div>
      <div class="field"><label>E-mail <small>(opcional, para lembretes)</small></label><input v-model="form.email" type="email" /></div>
    </div>
    <div class="field">
      <label>Serviços que faz <small>(clique para marcar ou desmarcar)</small></label>
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
    <p v-if="!professionals.length" class="muted">Nenhum cadastro ainda. Cadastre ao menos um (pode ser você, uma quadra, uma sala...).</p>
    <table v-else>
      <thead><tr><th>Nome</th><th>Serviços</th><th>Status</th><th></th></tr></thead>
      <tbody>
        <tr v-for="p in professionals" :key="p.id">
          <td>{{ p.name }}</td>
          <td>
            <template v-if="!p.service_ids.length">
              <span class="badge yellow">Nenhum serviço</span>
              <button v-if="services.length" class="btn small" style="margin-left: 8px" @click="linkAll(p)">Ligar a todos os serviços</button>
            </template>
            <template v-else>{{ serviceNames(p.service_ids) }}</template>
          </td>
          <td><span :class="['badge', p.active ? 'green' : '']">{{ p.active ? 'Ativo' : 'Inativo' }}</span></td>
          <td style="text-align: right">
            <button class="btn small secondary" @click="edit(p)">Editar</button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
