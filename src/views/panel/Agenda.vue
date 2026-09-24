<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatTime, formatDate, todayISO, addDaysISO, zonedToUtc, APPOINTMENT_STATUS } from '@/lib/format'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const date = ref(todayISO(tz.value))
const professionalFilter = ref('')
const appointments = ref([])
const professionals = ref([])
const services = ref([])
const customers = ref([])
const error = ref('')
const showForm = ref(false)

const STATUS_BADGE = { scheduled: '', confirmed: 'green', completed: 'green', canceled: 'red', no_show: 'yellow' }

const visible = computed(() => appointments.value.filter((a) =>
  !professionalFilter.value || a.professional_id === professionalFilter.value))

const dayTotal = computed(() => visible.value
  .filter((a) => a.status !== 'canceled' && a.status !== 'no_show')
  .reduce((sum, a) => sum + Number(a.price), 0))

async function loadAppointments() {
  const from = zonedToUtc(date.value, '00:00', tz.value).toISOString()
  const to = zonedToUtc(addDaysISO(date.value, 1), '00:00', tz.value).toISOString()
  appointments.value = unwrap(await supabase.from('appointments')
    .select('*, customer:customers(name, phone), service:services(name), professional:professionals(name)')
    .eq('business_id', biz.business.id).gte('starts_at', from).lt('starts_at', to).order('starts_at'))
}

async function loadLists() {
  const bid = biz.business.id
  professionals.value = unwrap(await supabase.from('professionals').select('id, name').eq('business_id', bid).eq('active', true).order('name'))
  services.value = unwrap(await supabase.from('services').select('id, name, price, duration_min').eq('business_id', bid).eq('active', true).order('name'))
  customers.value = unwrap(await supabase.from('customers').select('id, name, phone').eq('business_id', bid).order('name'))
}

onMounted(() => { loadAppointments(); loadLists() })
watch(date, loadAppointments)

async function setStatus(a, status) {
  error.value = ''
  const patch = { status, canceled_at: status === 'canceled' ? new Date().toISOString() : null }
  const { error: err } = await supabase.from('appointments').update(patch).eq('id', a.id)
  if (err) error.value = err.message
  loadAppointments()
}

// Agendamento manual (cliente ligou / chegou no balcão).
const emptyForm = () => ({ customer_id: '', new_name: '', new_phone: '', service_id: '', professional_id: '', time: '09:00', notes: '' })
const form = ref(emptyForm())

async function createAppointment() {
  error.value = ''
  try {
    const service = services.value.find((s) => s.id === form.value.service_id)
    let customerId = form.value.customer_id
    if (!customerId) {
      customerId = unwrap(await supabase.from('customers')
        .insert({ business_id: biz.business.id, name: form.value.new_name, phone: form.value.new_phone || null })
        .select('id').single()).id
    }
    const starts = zonedToUtc(date.value, form.value.time, tz.value)
    const ends = new Date(starts.getTime() + service.duration_min * 60000)
    const { error: err } = await supabase.from('appointments').insert({
      business_id: biz.business.id, customer_id: customerId, service_id: service.id,
      professional_id: form.value.professional_id, starts_at: starts.toISOString(), ends_at: ends.toISOString(),
      price: service.price, notes: form.value.notes || null, status: 'confirmed',
    })
    if (err) {
      throw new Error(err.message.includes('appointments_no_overlap')
        ? 'Esse profissional já tem um agendamento nesse horário.' : err.message)
    }
    form.value = emptyForm()
    showForm.value = false
    loadAppointments()
    loadLists()
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <div class="page-header spread">
    <h1>Agenda</h1>
    <button class="btn" @click="showForm = !showForm">{{ showForm ? 'Fechar' : '+ Novo agendamento' }}</button>
  </div>

  <div class="row" style="margin-bottom: 16px">
    <button class="btn secondary shrink" @click="date = addDaysISO(date, -1)">‹</button>
    <input v-model="date" type="date" style="max-width: 180px" class="shrink" />
    <button class="btn secondary shrink" @click="date = addDaysISO(date, 1)">›</button>
    <button class="btn secondary shrink" @click="date = todayISO(tz)">Hoje</button>
    <select v-if="professionals.length > 1" v-model="professionalFilter" style="max-width: 220px">
      <option value="">Todos os profissionais</option>
      <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
    </select>
  </div>

  <div v-if="error" class="error">{{ error }}</div>

  <form v-if="showForm" class="card" @submit.prevent="createAppointment">
    <h3>Novo agendamento em {{ formatDate(zonedToUtc(date, '12:00', tz), tz) }}</h3>
    <div class="row">
      <div class="field">
        <label>Cliente</label>
        <select v-model="form.customer_id">
          <option value="">+ Novo cliente</option>
          <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.name }}{{ c.phone ? ` · ${c.phone}` : '' }}</option>
        </select>
      </div>
      <template v-if="!form.customer_id">
        <div class="field"><label>Nome</label><input v-model="form.new_name" required /></div>
        <div class="field"><label>Telefone</label><input v-model="form.new_phone" type="tel" /></div>
      </template>
    </div>
    <div class="row">
      <div class="field">
        <label>Serviço</label>
        <select v-model="form.service_id" required>
          <option v-for="s in services" :key="s.id" :value="s.id">{{ s.name }} ({{ s.duration_min }} min)</option>
        </select>
      </div>
      <div class="field">
        <label>Profissional</label>
        <select v-model="form.professional_id" required>
          <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
      </div>
      <div class="field"><label>Horário</label><input v-model="form.time" type="time" required /></div>
    </div>
    <div class="field"><label>Observações</label><input v-model="form.notes" /></div>
    <button class="btn">Agendar</button>
  </form>

  <div class="card table-wrap">
    <div class="spread" style="margin-bottom: 8px">
      <strong>{{ visible.length }} agendamento(s)</strong>
      <span class="muted">Previsto: {{ money(dayTotal) }}</span>
    </div>
    <p v-if="!visible.length" class="muted">Nenhum agendamento neste dia.</p>
    <table v-else>
      <thead><tr><th>Horário</th><th>Cliente</th><th>Serviço</th><th>Profissional</th><th>Status</th><th></th></tr></thead>
      <tbody>
        <tr v-for="a in visible" :key="a.id" :style="{ opacity: a.status === 'canceled' ? 0.5 : 1 }">
          <td style="white-space: nowrap">{{ formatTime(a.starts_at, tz) }} – {{ formatTime(a.ends_at, tz) }}</td>
          <td>{{ a.customer?.name }}<br /><small class="muted">{{ a.customer?.phone }}</small></td>
          <td>{{ a.service?.name }}<br /><small class="muted">{{ money(a.price) }}</small></td>
          <td>{{ a.professional?.name }}</td>
          <td><span :class="['badge', STATUS_BADGE[a.status]]">{{ APPOINTMENT_STATUS[a.status] }}</span></td>
          <td>
            <select v-if="a.status !== 'canceled'" :value="a.status" style="min-width: 150px"
                    @change="setStatus(a, $event.target.value)">
              <option v-for="(label, key) in APPOINTMENT_STATUS" :key="key" :value="key">{{ label }}</option>
            </select>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
