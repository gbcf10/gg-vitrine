<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime, formatTime } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const staffLabel = computed(() => (biz.business.staff_label || 'Profissional').toLowerCase())

const OPTIONS = [
  { min: 30, label: '30 min' },
  { min: 45, label: '45 min' },
  { min: 60, label: '1 h' },
  { min: 90, label: '1 h 30' },
  { min: 120, label: '2 h' },
]

const clientOffsets = ref([...(biz.business.remind_client_offsets ?? [60])])
const staffOffsets = ref([...(biz.business.remind_staff_offsets ?? [])])
const upcoming = ref([])
const log = ref([])
const missingStaffContact = ref([])
const msg = ref('')
const error = ref('')

function toggle(list, min) {
  const i = list.value.indexOf(min)
  if (i >= 0) list.value.splice(i, 1)
  else list.value.push(min)
  list.value.sort((a, b) => a - b)
}

async function load() {
  const bid = biz.business.id
  const now = new Date()
  const in24h = new Date(now.getTime() + 24 * 3600 * 1000)
  try {
    upcoming.value = unwrap(await supabase.from('appointments')
      .select('id, starts_at, status, customer:customers(name, phone, email), service:services(name), professional:professionals(name, phone, email)')
      .eq('business_id', bid).in('status', ['scheduled', 'confirmed'])
      .gte('starts_at', now.toISOString()).lt('starts_at', in24h.toISOString()).order('starts_at'))
    log.value = unwrap(await supabase.from('reminder_log')
      .select('*, appointment:appointments(starts_at, customer:customers(name))')
      .eq('business_id', bid).order('created_at', { ascending: false }).limit(30))
    missingStaffContact.value = unwrap(await supabase.from('professionals').select('name')
      .eq('business_id', bid).eq('active', true).is('email', null)).map((p) => p.name)
  } catch (e) {
    error.value = e.message
  }
}
onMounted(() => { if (biz.hasFeature('lembretes')) load() })

async function save() {
  error.value = msg.value = ''
  const { error: err } = await supabase.from('businesses').update({
    remind_client_offsets: clientOffsets.value, remind_staff_offsets: staffOffsets.value,
  }).eq('id', biz.business.id)
  if (err) { error.value = err.message; return }
  await biz.reload()
  msg.value = 'Lembretes salvos.'
}

function clientMessage(a) {
  return waLink(a.customer?.phone,
    `Olá ${a.customer?.name}! Passando para lembrar do seu horário em ${biz.business.name}: ` +
    `*${a.service?.name}* hoje às ${formatTime(a.starts_at, tz.value)} com ${a.professional?.name}. Até já!`)
}
function staffMessage(a) {
  return waLink(a.professional?.phone,
    `Próximo atendimento às ${formatTime(a.starts_at, tz.value)}: ${a.customer?.name} (${a.service?.name}).`)
}

const STATUS = { enviado: ['Enviado', 'green'], sem_contato: ['Sem e-mail', 'yellow'], erro: ['Erro', 'red'] }
</script>

<template>
  <div class="page-header"><p class="eyebrow">Agenda</p><h1>Lembretes</h1></div>
  <Upsell v-if="!biz.hasFeature('lembretes')" feature="lembretes" />

  <template v-else>
    <div v-if="error" class="error">{{ error }}</div>
    <div v-if="msg" class="success">{{ msg }}</div>

    <form class="card" @submit.prevent="save">
      <h3>Quando lembrar?</h3>
      <p class="muted" style="font-size: 0.9rem">Marque um ou mais horários. O lembrete vai por e-mail automaticamente, antes de cada agendamento.</p>

      <div class="field">
        <label>Cliente</label>
        <div class="chips">
          <button v-for="o in OPTIONS" :key="o.min" type="button" class="chip" :class="{ selected: clientOffsets.includes(o.min) }"
                  @click="toggle(clientOffsets, o.min)">{{ o.label }} antes</button>
        </div>
        <small v-if="!clientOffsets.length">Nenhum horário marcado: o cliente não recebe lembrete.</small>
      </div>

      <div class="field">
        <label>{{ biz.business.staff_label }}</label>
        <div class="chips">
          <button v-for="o in OPTIONS" :key="o.min" type="button" class="chip" :class="{ selected: staffOffsets.includes(o.min) }"
                  @click="toggle(staffOffsets, o.min)">{{ o.label }} antes</button>
        </div>
        <small v-if="staffOffsets.length && missingStaffContact.length" style="color: var(--warning)">
          Sem e-mail cadastrado: {{ missingStaffContact.join(', ') }}. Cadastre em "{{ biz.business.staff_label }}" para receber.
        </small>
      </div>

      <button class="btn">Salvar</button>
    </form>

    <div class="notice">
      <strong>Como chegam os lembretes:</strong> por e-mail, automaticamente, para quem tem e-mail cadastrado
      (quem agenda pelo seu link sempre tem). Pelo WhatsApp, use os botões abaixo: a mensagem já vai pronta.
    </div>

    <!-- Próximas 24 horas -->
    <div class="card">
      <h3>Próximas 24 horas</h3>
      <p v-if="!upcoming.length" class="muted" style="margin: 0">Nenhum agendamento nas próximas 24 horas.</p>
      <div v-for="a in upcoming" :key="a.id" class="spread item">
        <div>
          <strong>{{ formatTime(a.starts_at, tz) }}</strong> · {{ a.customer?.name }} · {{ a.service?.name }}
          <br /><small>com {{ a.professional?.name }}</small>
        </div>
        <div class="chips">
          <a v-if="clientMessage(a)" class="btn small secondary" :href="clientMessage(a)" target="_blank" rel="noopener">
            <Icon name="whatsapp" style="width: 15px; height: 15px" />Lembrar cliente
          </a>
          <a v-if="staffMessage(a)" class="btn small secondary" :href="staffMessage(a)" target="_blank" rel="noopener">
            <Icon name="whatsapp" style="width: 15px; height: 15px" />Lembrar {{ staffLabel }}
          </a>
        </div>
      </div>
    </div>

    <!-- Histórico -->
    <div class="card table-wrap">
      <h3>Enviados automaticamente</h3>
      <p v-if="!log.length" class="muted" style="margin: 0">Ainda não houve envio automático.</p>
      <table v-else>
        <thead><tr><th>Quando</th><th>Para</th><th>Agendamento</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="l in log" :key="l.id">
            <td>{{ formatDateTime(l.created_at, tz) }}</td>
            <td>{{ l.target === 'cliente' ? 'Cliente' : biz.business.staff_label }}<br /><small>{{ l.sent_to }}</small></td>
            <td>{{ l.appointment?.customer?.name }}<br /><small v-if="l.appointment">{{ formatDateTime(l.appointment.starts_at, tz) }}</small></td>
            <td><span :class="['badge', STATUS[l.status][1]]">{{ STATUS[l.status][0] }}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
  </template>
</template>

<style scoped>
.item { padding: 10px 0; border-top: 1px solid var(--border); }
</style>
