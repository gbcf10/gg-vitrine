<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, formatDateTime, zonedToUtc, todayISO, plural } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const byDay = computed(() => settings.value.reservation_mode === 'diaria')
const settings = ref({
  reservation_mode: biz.business.reservation_mode,
  max_party: biz.business.max_party,
  reservation_notice: biz.business.reservation_notice ?? '',
})
const units = ref([])
const reservations = ref([])
const filter = ref('proximas')
const error = ref('')
const msg = ref('')
const editingUnit = ref(null)
const uploading = ref(false)

const STATUS = {
  pendente: { label: 'Pendente', badge: 'yellow' },
  confirmada: { label: 'Confirmada', badge: 'green' },
  recusada: { label: 'Recusada', badge: 'red' },
  cancelada: { label: 'Cancelada', badge: '' },
}

const visible = computed(() => {
  const today = todayISO(tz.value)
  return reservations.value.filter((r) => {
    if (filter.value === 'pendentes') return r.status === 'pendente'
    if (filter.value === 'proximas') return r.end_date > today && ['pendente', 'confirmada'].includes(r.status)
    return true
  })
})

async function load() {
  const bid = biz.business.id
  try {
    units.value = unwrap(await supabase.from('reservation_units').select('*').eq('business_id', bid).order('name'))
    reservations.value = unwrap(await supabase.from('reservations').select('*, unit:reservation_units(name)')
      .eq('business_id', bid).order('start_date').order('at_time').limit(500))
  } catch (e) {
    error.value = e.message
  }
}
onMounted(load)

async function saveSettings() {
  error.value = msg.value = ''
  const { error: err } = await supabase.from('businesses').update({
    reservation_mode: settings.value.reservation_mode,
    max_party: Number(settings.value.max_party),
    reservation_notice: settings.value.reservation_notice || null,
  }).eq('id', biz.business.id)
  if (err) { error.value = err.message; return }
  await biz.reload()
  msg.value = 'Configurações salvas.'
}

// ---- Unidades (diárias) ----
function newUnit() {
  editingUnit.value = { id: null, name: '', description: '', capacity: 2, price: 0, photo_url: null, active: true }
}
async function saveUnit() {
  const { id, ...fields } = editingUnit.value
  const payload = { ...fields, business_id: biz.business.id, capacity: Number(fields.capacity), price: Number(fields.price) }
  const { error: err } = id
    ? await supabase.from('reservation_units').update(payload).eq('id', id)
    : await supabase.from('reservation_units').insert(payload)
  if (err) { error.value = err.message; return }
  editingUnit.value = null
  load()
}
async function uploadPhoto(event) {
  const file = event.target.files[0]
  if (!file) return
  uploading.value = true
  const path = `${biz.business.id}/units/${Date.now()}.${file.name.split('.').pop().toLowerCase()}`
  const { error: err } = await supabase.storage.from('logos').upload(path, file)
  uploading.value = false
  if (err) { error.value = err.message; return }
  editingUnit.value.photo_url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
}

// ---- Reservas ----
async function setStatus(r, status) {
  error.value = ''
  const { error: err } = await supabase.from('reservations').update({ status }).eq('id', r.id)
  if (err) {
    error.value = err.message.includes('reservations_no_overlap')
      ? 'Já existe uma reserva confirmada nessas datas para esta opção.' : err.message
    return
  }
  load()
}

const fmt = (d) => formatDate(zonedToUtc(d, '12:00', tz.value), tz.value)
function when(r) {
  return r.unit_id ? `${fmt(r.start_date)} a ${fmt(r.end_date)} · ${r.unit?.name}` : `${fmt(r.start_date)} às ${r.at_time?.slice(0, 5)}`
}
function notify(r) {
  const text = {
    confirmada: `Olá ${r.name}! Sua reserva em ${biz.business.name} está *confirmada*: ${when(r)}, ${plural(r.party_size, 'pessoa', 'pessoas')}. Até lá!`,
    recusada: `Olá ${r.name}! Infelizmente não temos disponibilidade para ${when(r)}. Podemos ver outra data?`,
    pendente: `Olá ${r.name}! Recebemos seu pedido de reserva para ${when(r)}.`,
    cancelada: `Olá ${r.name}! Sua reserva para ${when(r)} foi cancelada.`,
  }[r.status]
  return waLink(r.phone, text)
}
</script>

<template>
  <div class="page-header">
    <p class="eyebrow">Reservas</p>
    <h1>Reservas</h1>
  </div>
  <div v-if="error" class="error">{{ error }}</div>
  <div v-if="msg" class="success">{{ msg }}</div>

  <!-- Lista -->
  <div class="chips" style="margin-bottom: 16px">
    <button class="chip" :class="{ selected: filter === 'proximas' }" @click="filter = 'proximas'">Próximas</button>
    <button class="chip" :class="{ selected: filter === 'pendentes' }" @click="filter = 'pendentes'">
      Aguardando confirmação ({{ reservations.filter((r) => r.status === 'pendente').length }})
    </button>
    <button class="chip" :class="{ selected: filter === 'todas' }" @click="filter = 'todas'">Todas</button>
  </div>

  <p v-if="!visible.length" class="card muted" style="text-align: center">Nenhuma reserva aqui. Os pedidos feitos pelo seu link aparecem nesta tela.</p>
  <div v-for="r in visible" :key="r.id" class="card">
    <div class="spread">
      <h3 style="margin: 0">{{ r.name }} · {{ plural(r.party_size, 'pessoa', 'pessoas') }}</h3>
      <span :class="['badge', STATUS[r.status].badge]">{{ STATUS[r.status].label }}</span>
    </div>
    <p style="margin: 8px 0"><strong>{{ when(r) }}</strong><template v-if="Number(r.total)"> · {{ money(r.total) }}</template></p>
    <small>{{ r.phone }}<template v-if="r.email"> · {{ r.email }}</template> · pedido em {{ formatDateTime(r.created_at, tz) }}</small>
    <p v-if="r.notes" class="muted" style="margin: 8px 0 0">Obs.: {{ r.notes }}</p>
    <div class="chips" style="margin-top: 12px">
      <button v-if="r.status === 'pendente'" class="btn small" @click="setStatus(r, 'confirmada')">Confirmar</button>
      <button v-if="r.status === 'pendente'" class="btn small danger" @click="setStatus(r, 'recusada')">Recusar</button>
      <button v-if="r.status === 'confirmada'" class="btn small secondary" @click="setStatus(r, 'cancelada')">Cancelar</button>
      <a class="btn small secondary" :href="notify(r)" target="_blank" rel="noopener">
        <Icon name="whatsapp" style="width: 15px; height: 15px" />Avisar cliente
      </a>
    </div>
  </div>

  <!-- Configurações -->
  <form class="card" style="margin-top: 24px" @submit.prevent="saveSettings">
    <h3>Como você recebe reservas?</h3>
    <div class="chips" style="margin-bottom: 14px">
      <button type="button" class="chip" :class="{ selected: settings.reservation_mode === 'horario' }" @click="settings.reservation_mode = 'horario'">
        Por horário <small>(mesa, horário marcado)</small>
      </button>
      <button type="button" class="chip" :class="{ selected: settings.reservation_mode === 'diaria' }" @click="settings.reservation_mode = 'diaria'">
        Por diária <small>(chalé, casa, aluguel)</small>
      </button>
    </div>
    <div class="row">
      <div v-if="!byDay" class="field" style="max-width: 220px">
        <label>Máximo de pessoas por reserva</label>
        <input v-model="settings.max_party" type="number" min="1" max="500" />
      </div>
      <div class="field">
        <label>Aviso para o cliente <small>(opcional)</small></label>
        <input v-model="settings.reservation_notice" placeholder="Ex.: tolerância de 15 minutos; sinal de 30% para confirmar" />
      </div>
    </div>
    <button class="btn">Salvar</button>
  </form>

  <!-- Unidades -->
  <div v-if="byDay && biz.business.reservation_mode === 'diaria'" class="card">
    <div class="spread">
      <h3 style="margin: 0">Opções para reservar</h3>
      <button class="btn small" @click="newUnit"><Icon name="plus" style="width: 15px; height: 15px" />Nova opção</button>
    </div>
    <p class="muted" style="font-size: 0.88rem">Cada chalé, quarto, casa ou item que o cliente pode reservar.</p>

    <form v-if="editingUnit" class="card" style="background: rgba(5, 11, 22, 0.5)" @submit.prevent="saveUnit">
      <div class="row">
        <div class="field" style="flex-basis: 240px"><label>Nome</label><input v-model="editingUnit.name" required placeholder="Ex.: Chalé com hidro" /></div>
        <div class="field"><label>Pessoas</label><input v-model="editingUnit.capacity" type="number" min="1" required /></div>
        <div class="field"><label>Valor da diária (R$)</label><input v-model="editingUnit.price" type="number" min="0" step="0.01" required /></div>
      </div>
      <div class="field"><label>Descrição</label><input v-model="editingUnit.description" placeholder="Ex.: cama de casal, lareira, vista para a serra" /></div>
      <div class="row" style="align-items: center">
        <img v-if="editingUnit.photo_url" :src="editingUnit.photo_url" alt="" class="shrink" style="width: 70px; height: 70px; border-radius: 12px; object-fit: cover" />
        <div class="field"><label>Foto</label><input type="file" accept="image/*" @change="uploadPhoto" /></div>
      </div>
      <div class="spread">
        <label><input v-model="editingUnit.active" type="checkbox" /> Disponível para reserva</label>
        <div class="chips">
          <button type="button" class="btn secondary" @click="editingUnit = null">Cancelar</button>
          <button class="btn" :disabled="uploading">Salvar</button>
        </div>
      </div>
    </form>

    <p v-if="!units.length && !editingUnit" class="notice" style="margin-top: 12px">Cadastre pelo menos uma opção para receber reservas.</p>
    <div v-for="u in units" :key="u.id" class="spread unit">
      <div class="row" style="align-items: center; flex: 1">
        <img v-if="u.photo_url" :src="u.photo_url" alt="" class="shrink" style="width: 48px; height: 48px; border-radius: 10px; object-fit: cover" />
        <div>
          <strong>{{ u.name }}</strong> <span v-if="!u.active" class="badge">Inativa</span><br />
          <small>{{ money(u.price) }}/diária · até {{ u.capacity }} pessoas</small>
        </div>
      </div>
      <button class="btn small secondary" @click="editingUnit = { ...u }">Editar</button>
    </div>
  </div>
  <p v-else-if="byDay" class="notice">Salve as configurações para cadastrar as opções de diária.</p>
</template>

<style scoped>
.unit { padding: 12px 0; border-top: 1px solid var(--border); }
</style>
