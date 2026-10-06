<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { plural, money, formatTime, formatDate, formatDateTime, todayISO, addDaysISO, zonedToUtc, APPOINTMENT_STATUS } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

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
const setup = ref(null)   // pendências de configuração que impedem o agendamento online

// Rótulo humano do dia atual ("Hoje · Qua, 10 de abril" etc).
const dayLabel = computed(() => {
  if (!date.value) return ''
  const today = todayISO(tz.value)
  const prefix = date.value === today ? 'Hoje · ' :
    date.value === addDaysISO(today, 1) ? 'Amanhã · ' :
    date.value === addDaysISO(today, -1) ? 'Ontem · ' : ''
  try {
    const d = new Date(date.value + 'T12:00:00')
    const weekday = d.toLocaleDateString('pt-BR', { weekday: 'long', timeZone: tz.value })
    const full = d.toLocaleDateString('pt-BR', { day: '2-digit', month: 'long', timeZone: tz.value })
    const wd = weekday.charAt(0).toUpperCase() + weekday.slice(1)
    return `${prefix}${wd}, ${full}`
  } catch {
    return prefix + date.value
  }
})

const dayStats = computed(() => {
  const total = visible.value.length
  const confirmed = visible.value.filter((a) => ['scheduled', 'confirmed'].includes(a.status)).length
  const completed = visible.value.filter((a) => a.status === 'completed').length
  return { total, confirmed, completed }
})

// Lembrete manual pelo WhatsApp (o automático vem com a integração paga).
function reminder(a) {
  if (!a.customer?.phone) return null
  return waLink(a.customer.phone,
    `Olá ${a.customer.name}! Passando para lembrar do seu horário em ${biz.business.name}: ` +
    `*${a.service?.name}* ${formatDateTime(a.starts_at, tz.value)} com ${a.professional?.name}. Até lá!`)
}

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

// Confere se a vitrine já consegue mostrar horários: serviço, quem atende
// ligado ao serviço e horário de atendimento.
async function checkSetup() {
  const bid = biz.business.id
  const [{ data: svc }, { data: pros }, { data: hours }] = await Promise.all([
    supabase.from('services').select('id').eq('business_id', bid).eq('active', true),
    supabase.from('professionals').select('id, name, professional_services(service_id)').eq('business_id', bid).eq('active', true),
    supabase.from('working_hours').select('professional_id').eq('business_id', bid),
  ])
  const withHours = new Set((hours ?? []).map((h) => h.professional_id))
  const label = biz.business.staff_label.toLowerCase()
  const steps = [
    { done: (svc ?? []).length > 0, text: 'Cadastre pelo menos um serviço', to: '/painel/servicos' },
    { done: (pros ?? []).length > 0, text: `Cadastre pelo menos um(a) ${label}`, to: '/painel/profissionais' },
    { done: (pros ?? []).some((p) => p.professional_services.length), text: `Marque quais serviços cada ${label} faz`, to: '/painel/profissionais' },
    { done: (pros ?? []).some((p) => withHours.has(p.id)), text: 'Defina os dias e horários de atendimento', to: '/painel/horarios' },
  ]
  setup.value = steps.every((st) => st.done) ? null : steps
}

onMounted(() => { loadAppointments(); loadLists(); checkSetup() })
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
        ? `${biz.business.staff_label} já tem um agendamento nesse horário.` : err.message)
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
  <div class="page-header agenda-header">
    <div>
      <p class="eyebrow agenda-eyebrow">Agenda</p>
      <h1>{{ dayLabel }}</h1>
    </div>
    <button class="btn agenda-cta" @click="showForm = !showForm">
      <Icon v-if="!showForm" name="plus" />
      {{ showForm ? 'Fechar' : 'Novo agendamento' }}
    </button>
  </div>

  <!-- Barra de controles (dia + filtro) -->
  <div class="agenda-controls">
    <div class="date-nav">
      <button class="date-arrow" type="button" aria-label="Dia anterior" @click="date = addDaysISO(date, -1)">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6" /></svg>
      </button>
      <label class="date-field">
        <input v-model="date" type="date" />
      </label>
      <button class="date-arrow" type="button" aria-label="Próximo dia" @click="date = addDaysISO(date, 1)">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6" /></svg>
      </button>
      <button class="date-today" type="button" @click="date = todayISO(tz)">Hoje</button>
    </div>
    <select v-if="professionals.length > 1" v-model="professionalFilter" class="pro-filter">
      <option value="">Todos os {{ biz.business.staff_label.toLowerCase() }}s</option>
      <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
    </select>
  </div>

  <!-- Mini-stats (sempre visível, dá contexto rápido ao dia) -->
  <div class="day-stats">
    <div class="day-stat">
      <small>Agendamentos</small>
      <strong>{{ dayStats.total }}</strong>
    </div>
    <div class="day-stat">
      <small>Confirmados</small>
      <strong>{{ dayStats.confirmed }}</strong>
    </div>
    <div class="day-stat">
      <small>Concluídos</small>
      <strong>{{ dayStats.completed }}</strong>
    </div>
    <div class="day-stat accent">
      <small>Previsto no dia</small>
      <strong class="gradient-text">{{ money(dayTotal) }}</strong>
    </div>
  </div>

  <!-- Setup pendente -->
  <div v-if="setup" class="setup-card">
    <div class="setup-head">
      <span class="setup-badge"><Icon name="sparkles" /></span>
      <div>
        <strong>Falta pouco pros seus clientes agendarem pelo link</strong>
        <small>Enquanto estes passos não estiverem prontos, a vitrine não mostra horários livres.</small>
      </div>
    </div>
    <div class="setup-steps">
      <RouterLink v-for="(st, i) in setup" :key="i" :to="st.to" class="setup-step" :class="{ done: st.done }">
        <span class="setup-check">
          <template v-if="st.done">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
          </template>
          <template v-else>{{ i + 1 }}</template>
        </span>
        <span class="setup-text">{{ st.text }}</span>
        <svg v-if="!st.done" class="setup-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6" /></svg>
      </RouterLink>
    </div>
  </div>

  <div v-if="error" class="alert alert-danger">{{ error }}</div>

  <!-- Form de novo agendamento -->
  <form v-if="showForm" class="appt-form" @submit.prevent="createAppointment">
    <div class="appt-form-head">
      <h3>Novo agendamento</h3>
      <small class="muted">em {{ formatDate(zonedToUtc(date, '12:00', tz), tz) }}</small>
    </div>
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
        <label>{{ biz.business.staff_label }}</label>
        <select v-model="form.professional_id" required>
          <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
        </select>
      </div>
      <div class="field"><label>Horário</label><input v-model="form.time" type="time" required /></div>
    </div>
    <div class="field"><label>Observações</label><input v-model="form.notes" placeholder="Opcional" /></div>
    <button class="btn">Agendar</button>
  </form>

  <!-- Lista de agendamentos -->
  <div class="appt-section">
    <!-- Empty state forte -->
    <div v-if="!visible.length" class="empty-state">
      <div class="empty-icon-wrap">
        <div class="empty-icon-ring" />
        <div class="empty-icon-core"><Icon name="calendar" /></div>
      </div>
      <h3>Nenhum agendamento neste dia</h3>
      <p class="muted">
        Que tal divulgar seu link pra lotar a agenda? Seus clientes marcam direto pelo celular, sem você precisar atender.
      </p>
      <div class="empty-actions">
        <button class="btn" @click="showForm = true">
          <Icon name="plus" />
          Agendar manualmente
        </button>
        <RouterLink to="/painel/divulgar" class="btn secondary">
          Divulgar meu link
        </RouterLink>
      </div>
    </div>

    <!-- Desktop: tabela clean -->
    <div v-else class="appt-table card">
      <table>
        <thead><tr><th>Horário</th><th>Cliente</th><th>Serviço</th><th>{{ biz.business.staff_label }}</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="a in visible" :key="a.id" :class="{ canceled: a.status === 'canceled' }">
            <td class="col-time">
              <strong>{{ formatTime(a.starts_at, tz) }}</strong>
              <small class="muted">até {{ formatTime(a.ends_at, tz) }}</small>
            </td>
            <td>
              <strong>{{ a.customer?.name }}</strong>
              <small v-if="a.customer?.phone" class="muted">{{ a.customer.phone }}</small>
            </td>
            <td>
              <strong>{{ a.service?.name }}</strong>
              <small class="muted">{{ money(a.price) }}</small>
            </td>
            <td>{{ a.professional?.name }}</td>
            <td><span :class="['badge', STATUS_BADGE[a.status]]">{{ APPOINTMENT_STATUS[a.status] }}</span></td>
            <td class="col-actions">
              <select v-if="a.status !== 'canceled'" :value="a.status"
                      @change="setStatus(a, $event.target.value)">
                <option v-for="(label, key) in APPOINTMENT_STATUS" :key="key" :value="key">{{ label }}</option>
              </select>
              <a v-if="biz.hasFeature('lembretes') && reminder(a) && ['scheduled', 'confirmed'].includes(a.status)"
                 class="btn small secondary" :href="reminder(a)" target="_blank" rel="noopener"
                 title="Enviar lembrete pelo WhatsApp">Lembrar</a>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile: cards com hora destacada -->
    <div v-if="visible.length" class="appt-cards">
      <article v-for="a in visible" :key="`m-${a.id}`" class="appt-card" :class="{ canceled: a.status === 'canceled' }">
        <div class="appt-time">
          <strong>{{ formatTime(a.starts_at, tz) }}</strong>
          <small>{{ formatTime(a.ends_at, tz) }}</small>
        </div>
        <div class="appt-body">
          <div class="appt-row-top">
            <strong class="appt-customer">{{ a.customer?.name }}</strong>
            <span :class="['badge', STATUS_BADGE[a.status]]">{{ APPOINTMENT_STATUS[a.status] }}</span>
          </div>
          <div class="appt-meta">
            <span>{{ a.service?.name }}</span>
            <span class="dot-sep">·</span>
            <span class="muted">{{ money(a.price) }}</span>
          </div>
          <div class="appt-meta">
            <span class="muted">{{ biz.business.staff_label }}: <strong style="color: var(--text)">{{ a.professional?.name }}</strong></span>
          </div>
          <small v-if="a.customer?.phone" class="muted">{{ a.customer.phone }}</small>
          <div class="appt-actions">
            <select v-if="a.status !== 'canceled'" :value="a.status" @change="setStatus(a, $event.target.value)">
              <option v-for="(label, key) in APPOINTMENT_STATUS" :key="key" :value="key">{{ label }}</option>
            </select>
            <a v-if="biz.hasFeature('lembretes') && reminder(a) && ['scheduled', 'confirmed'].includes(a.status)"
               class="btn small secondary" :href="reminder(a)" target="_blank" rel="noopener">Lembrar</a>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>

<style scoped>
/* =====================================================================
   Header da página
   ===================================================================== */
.agenda-header {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}
.agenda-eyebrow { display: inline-block; margin-bottom: 6px; }
.agenda-header h1 {
  font-size: clamp(1.4rem, 2.6vw, 1.9rem);
  letter-spacing: -0.02em;
}
.agenda-cta :deep(svg) { width: 16px; height: 16px; }

/* =====================================================================
   Controles (navegador de dia + filtro)
   ===================================================================== */
.agenda-controls {
  display: flex; align-items: center; gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 16px;
}
.date-nav {
  display: inline-flex; align-items: center;
  padding: 4px;
  border-radius: 999px;
  background: var(--surface);
  border: 1px solid var(--border);
  gap: 2px;
}
.date-arrow {
  width: 34px; height: 34px; border-radius: 999px;
  display: grid; place-items: center;
  background: transparent;
  border: none;
  color: var(--silver);
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.date-arrow:hover { background: var(--brand-soft); color: var(--brand-ink); }
.date-arrow svg { width: 15px; height: 15px; }

.date-field {
  display: inline-flex;
  padding: 0 6px;
}
.date-field input {
  padding: 6px 8px;
  background: transparent;
  border: none;
  color: var(--text);
  color-scheme: dark;
  font: inherit;
  font-weight: 600;
  font-size: 0.9rem;
  min-width: 140px;
}
.date-field input:focus { outline: none; box-shadow: none; }

.date-today {
  padding: 6px 14px;
  border-radius: 999px;
  background: var(--brand-soft);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: var(--brand-ink);
  font: inherit; font-size: 0.85rem; font-weight: 700;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}
.date-today:hover {
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff;
}

.pro-filter {
  max-width: 240px;
  padding: 10px 14px;
  border-radius: 999px;
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--text);
  font: inherit; font-size: 0.9rem;
}

/* =====================================================================
   Mini-stats do dia
   ===================================================================== */
.day-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  margin-bottom: 18px;
}
.day-stat {
  padding: 14px 16px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  display: flex; flex-direction: column; gap: 4px;
}
.day-stat small {
  font-size: 0.68rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.1em; font-weight: 700;
}
.day-stat strong {
  font-size: 1.4rem; font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--text);
}
.day-stat.accent {
  background:
    radial-gradient(ellipse 180px 100px at 100% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border-color: rgba(59, 130, 246, 0.3);
}

/* =====================================================================
   Setup pendente
   ===================================================================== */
.setup-card {
  margin-bottom: 20px;
  padding: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 180px at 0% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px solid rgba(59, 130, 246, 0.3);
  box-shadow: 0 0 32px rgba(59, 130, 246, 0.1);
}
.setup-head {
  display: flex; align-items: center; gap: 14px;
  margin-bottom: 16px;
}
.setup-badge {
  width: 40px; height: 40px; border-radius: 12px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.setup-badge :deep(svg) { width: 18px; height: 18px; }
.setup-head strong { display: block; font-size: 1rem; letter-spacing: -0.01em; }
.setup-head small { display: block; color: var(--muted); font-size: 0.86rem; margin-top: 2px; }

.setup-steps { display: flex; flex-direction: column; gap: 2px; }
.setup-step {
  display: flex; align-items: center; gap: 14px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  color: var(--text);
  transition: background 0.15s ease, color 0.15s ease;
}
.setup-step:hover { background: rgba(59, 130, 246, 0.08); color: var(--brand-ink); }
.setup-step.done { color: var(--muted); }
.setup-step.done .setup-text { text-decoration: line-through; }
.setup-check {
  width: 28px; height: 28px; border-radius: 999px;
  display: grid; place-items: center; flex-shrink: 0;
  font-size: 0.82rem; font-weight: 800;
  background: var(--brand-soft);
  color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
}
.setup-check svg { width: 13px; height: 13px; }
.setup-step.done .setup-check {
  background: var(--success-soft);
  color: var(--success);
  border-color: rgba(74, 222, 128, 0.3);
}
.setup-text { flex: 1; font-size: 0.94rem; }
.setup-arrow { width: 14px; height: 14px; opacity: 0.5; }

/* =====================================================================
   Alerta
   ===================================================================== */
.alert {
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  border: 1px solid;
  margin-bottom: 16px;
  font-size: 0.92rem;
}
.alert-danger { color: #fecaca; background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.35); }

/* =====================================================================
   Form novo agendamento
   ===================================================================== */
.appt-form {
  padding: 22px;
  margin-bottom: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 300px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  box-shadow: 0 0 24px rgba(59, 130, 246, 0.08);
}
.appt-form-head {
  display: flex; align-items: baseline; gap: 10px;
  margin-bottom: 14px;
  flex-wrap: wrap;
}
.appt-form-head h3 {
  margin: 0;
  font-size: 1.1rem; font-weight: 700;
  letter-spacing: -0.01em;
}

/* =====================================================================
   Empty state
   ===================================================================== */
.empty-state {
  text-align: center;
  padding: 48px 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 200px at 50% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px dashed var(--border);
}
.empty-icon-wrap {
  position: relative;
  width: 88px; height: 88px;
  margin: 0 auto 20px;
}
.empty-icon-ring {
  position: absolute; inset: 0;
  border-radius: 50%;
  background: radial-gradient(circle, var(--brand-glow), transparent 70%);
  animation: ringPulse 2.4s ease-in-out infinite;
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.12); opacity: 0.35; }
}
.empty-icon-core {
  position: absolute; inset: 12px;
  border-radius: 50%;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px var(--brand-glow);
}
.empty-icon-core :deep(svg) { width: 28px; height: 28px; }
.empty-state h3 {
  font-size: 1.25rem; font-weight: 800;
  letter-spacing: -0.02em;
  margin: 0 0 10px;
}
.empty-state p {
  margin: 0 auto 20px;
  max-width: 420px;
  font-size: 0.95rem;
  line-height: 1.5;
}
.empty-actions {
  display: flex; justify-content: center; gap: 10px;
  flex-wrap: wrap;
}
.empty-actions .btn :deep(svg) { width: 16px; height: 16px; }

/* =====================================================================
   Tabela desktop
   ===================================================================== */
.appt-table {
  margin: 0;
  overflow-x: auto;
}
.appt-table table { width: 100%; }
.appt-table th,
.appt-table td {
  padding: 14px 12px;
  vertical-align: middle;
}
.appt-table tbody tr {
  transition: background 0.15s ease;
}
.appt-table tbody tr:hover { background: rgba(59, 130, 246, 0.05); }
.appt-table tr.canceled { opacity: 0.5; }
.appt-table .col-time strong {
  display: block;
  font-size: 1.05rem;
  font-weight: 800;
  letter-spacing: -0.01em;
  color: var(--text);
}
.appt-table .col-time small {
  display: block;
  font-size: 0.74rem;
}
.appt-table td strong { display: block; font-weight: 600; }
.appt-table td small { display: block; font-size: 0.78rem; margin-top: 2px; }
.appt-table .col-actions {
  white-space: nowrap;
  display: flex; gap: 6px; align-items: center;
  justify-content: flex-end;
}
.appt-table .col-actions select {
  min-width: 150px;
  width: auto;
  padding: 8px 10px;
  font-size: 0.86rem;
}

/* Mobile cards ficam escondidos no desktop */
.appt-cards { display: none; }

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 900px) {
  .day-stats { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 720px) {
  .agenda-header h1 { font-size: 1.3rem; }
  .agenda-controls { gap: 8px; }
  .pro-filter { max-width: 100%; width: 100%; }

  /* Esconde tabela, mostra cards */
  .appt-table { display: none; }
  .appt-cards {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .appt-card {
    display: grid;
    grid-template-columns: 72px 1fr;
    gap: 14px;
    padding: 14px;
    border-radius: var(--radius-sm);
    background: var(--surface);
    border: 1px solid var(--border);
    transition: border-color 0.15s ease, box-shadow 0.15s ease;
  }
  .appt-card:hover { border-color: var(--brand); }
  .appt-card.canceled { opacity: 0.5; }
  .appt-time {
    display: flex; flex-direction: column;
    align-items: center; justify-content: center;
    padding: 10px 6px;
    border-radius: var(--radius-sm);
    background: linear-gradient(160deg, var(--brand-soft), rgba(5, 11, 22, 0.3));
    border: 1px solid rgba(59, 130, 246, 0.3);
    text-align: center;
  }
  .appt-time strong {
    font-size: 1.15rem; font-weight: 800;
    letter-spacing: -0.02em;
    color: #fff;
  }
  .appt-time small {
    font-size: 0.68rem;
    color: var(--muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
  .appt-body { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  .appt-row-top {
    display: flex; align-items: center; justify-content: space-between;
    gap: 8px;
    margin-bottom: 2px;
  }
  .appt-customer {
    font-size: 0.98rem; font-weight: 700;
    letter-spacing: -0.01em;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .appt-meta {
    display: flex; align-items: center; gap: 6px;
    flex-wrap: wrap;
    font-size: 0.84rem;
  }
  .appt-meta .dot-sep { color: var(--muted); }
  .appt-actions {
    display: flex; gap: 6px;
    margin-top: 10px;
    flex-wrap: wrap;
  }
  .appt-actions select {
    flex: 1;
    min-width: 0;
    padding: 8px 10px;
    font-size: 0.85rem;
  }
}

@media (max-width: 480px) {
  .day-stats { grid-template-columns: 1fr 1fr; gap: 8px; }
  .day-stat { padding: 12px 14px; }
  .day-stat strong { font-size: 1.2rem; }
  .date-nav { width: 100%; justify-content: space-between; }
  .date-field { flex: 1; }
  .date-field input { width: 100%; min-width: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
