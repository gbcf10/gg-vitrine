<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDateTime, zonedToUtc } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const events = ref([])
const error = ref('')
const editing = ref(null)
const openId = ref(null)
const uploading = ref(false)
const showPast = ref(false)

const visible = computed(() => events.value.filter((e) => showPast.value || new Date(e.starts_at) > new Date()))

async function load() {
  try {
    events.value = unwrap(await supabase.from('events').select('*, event_registrations(*)')
      .eq('business_id', biz.business.id).order('starts_at'))
  } catch (e) {
    error.value = e.message
  }
}
onMounted(load)

const taken = (e) => e.event_registrations.filter((r) => r.status === 'confirmada').reduce((s, r) => s + r.quantity, 0)
const revenue = (e) => e.event_registrations.filter((r) => r.status === 'confirmada').reduce((s, r) => s + Number(r.total), 0)

// datetime-local <-> timestamptz no fuso do estabelecimento
function toLocalInput(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  const date = d.toLocaleDateString('en-CA', { timeZone: tz.value })
  const time = d.toLocaleTimeString('pt-BR', { timeZone: tz.value, hour: '2-digit', minute: '2-digit' })
  return `${date}T${time}`
}
function fromLocalInput(v) {
  if (!v) return null
  const [date, time] = v.split('T')
  return zonedToUtc(date, time, tz.value).toISOString()
}

function newEvent() {
  editing.value = { id: null, title: '', description: '', starts: '', ends: '', location: biz.business.address ?? '', price: 0, capacity: '', photo_url: null, active: true }
}
function editEvent(e) {
  editing.value = { ...e, starts: toLocalInput(e.starts_at), ends: toLocalInput(e.ends_at), capacity: e.capacity ?? '' }
}

async function save() {
  error.value = ''
  const e = editing.value
  const payload = {
    business_id: biz.business.id, title: e.title, description: e.description || null,
    starts_at: fromLocalInput(e.starts), ends_at: fromLocalInput(e.ends), location: e.location || null,
    price: Number(e.price || 0), capacity: e.capacity === '' ? null : Number(e.capacity),
    photo_url: e.photo_url, active: e.active,
  }
  const { error: err } = e.id
    ? await supabase.from('events').update(payload).eq('id', e.id)
    : await supabase.from('events').insert(payload)
  if (err) { error.value = err.message; return }
  editing.value = null
  load()
}

async function uploadPhoto(event) {
  const file = event.target.files[0]
  if (!file) return
  uploading.value = true
  const path = `${biz.business.id}/events/${Date.now()}.${file.name.split('.').pop().toLowerCase()}`
  const { error: err } = await supabase.storage.from('logos').upload(path, file)
  uploading.value = false
  if (err) { error.value = err.message; return }
  editing.value.photo_url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
}

async function cancelRegistration(r) {
  if (!confirm(`Cancelar a inscrição de ${r.name}?`)) return
  await supabase.from('event_registrations').update({ status: 'cancelada' }).eq('id', r.id)
  load()
}

function remind(e, r) {
  return waLink(r.phone, `Olá ${r.name}! Passando para lembrar: *${e.title}* é ${formatDateTime(e.starts_at, tz.value)}${e.location ? ` em ${e.location}` : ''}. Te esperamos!`)
}
</script>

<template>
  <div class="page-header spread">
    <div>
      <p class="eyebrow">Eventos e turmas</p>
      <h1>Eventos</h1>
    </div>
    <button class="btn" @click="newEvent"><Icon name="plus" style="width: 16px; height: 16px" />Novo evento</button>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <form v-if="editing" class="card glow" @submit.prevent="save">
    <div class="spread"><h3>{{ editing.id ? 'Editar evento' : 'Novo evento' }}</h3><button type="button" class="btn small secondary" @click="editing = null">Fechar</button></div>
    <div class="field"><label>Título</label><input v-model="editing.title" required placeholder="Ex.: Workshop de maquiagem" /></div>
    <div class="row">
      <div class="field"><label>Início</label><input v-model="editing.starts" type="datetime-local" required /></div>
      <div class="field"><label>Término <small>(opcional)</small></label><input v-model="editing.ends" type="datetime-local" /></div>
    </div>
    <div class="row">
      <div class="field" style="flex-basis: 260px"><label>Local</label><input v-model="editing.location" placeholder="Endereço ou 'Online'" /></div>
      <div class="field"><label>Valor por vaga (R$)</label><input v-model="editing.price" type="number" min="0" step="0.01" /></div>
      <div class="field"><label>Vagas <small>(vazio = sem limite)</small></label><input v-model="editing.capacity" type="number" min="1" /></div>
    </div>
    <div class="field"><label>Descrição</label><textarea v-model="editing.description" rows="3" placeholder="O que vai rolar, o que levar, para quem é..." /></div>
    <div class="row" style="align-items: center">
      <img v-if="editing.photo_url" :src="editing.photo_url" alt="" class="shrink" style="width: 110px; height: 70px; border-radius: 10px; object-fit: cover" />
      <div class="field"><label>Imagem de capa</label><input type="file" accept="image/*" @change="uploadPhoto" /></div>
    </div>
    <div class="spread">
      <label><input v-model="editing.active" type="checkbox" /> Inscrições abertas</label>
      <button class="btn" :disabled="uploading">Salvar</button>
    </div>
  </form>

  <label style="margin-bottom: 12px"><input v-model="showPast" type="checkbox" /> Mostrar eventos que já passaram</label>
  <p v-if="!visible.length" class="card muted" style="text-align: center">Nenhum evento. Crie o primeiro para abrir as inscrições.</p>

  <div v-for="e in visible" :key="e.id" class="card">
    <div class="spread">
      <div>
        <h3 style="margin: 0">{{ e.title }} <span v-if="!e.active" class="badge">Inscrições fechadas</span></h3>
        <small>{{ formatDateTime(e.starts_at, tz) }}<template v-if="e.location"> · {{ e.location }}</template></small>
      </div>
      <div class="chips">
        <button class="btn small secondary" @click="openId = openId === e.id ? null : e.id">Inscritos ({{ taken(e) }}{{ e.capacity ? `/${e.capacity}` : '' }})</button>
        <button class="btn small secondary" @click="editEvent(e)">Editar</button>
      </div>
    </div>
    <p class="muted" style="margin: 8px 0 0">{{ Number(e.price) ? `${money(e.price)} por vaga · arrecadado ${money(revenue(e))}` : 'Gratuito' }}</p>

    <div v-if="openId === e.id" class="table-wrap" style="margin-top: 12px">
      <p v-if="!e.event_registrations.length" class="muted">Ninguém inscrito ainda.</p>
      <table v-else>
        <thead><tr><th>Nome</th><th>Contato</th><th>Vagas</th><th>Valor</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in e.event_registrations" :key="r.id" :style="{ opacity: r.status === 'cancelada' ? 0.5 : 1 }">
            <td>{{ r.name }}<small v-if="r.coupon_code"> · cupom {{ r.coupon_code }}</small></td>
            <td>{{ r.phone }}<br /><small>{{ r.email }}</small></td>
            <td>{{ r.quantity }}</td>
            <td>{{ money(r.total) }}</td>
            <td style="text-align: right; white-space: nowrap">
              <template v-if="r.status === 'confirmada'">
                <a class="btn small secondary" :href="remind(e, r)" target="_blank" rel="noopener">Lembrar</a>
                <button class="btn small secondary" @click="cancelRegistration(r)">Cancelar</button>
              </template>
              <span v-else class="badge red">Cancelada</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
