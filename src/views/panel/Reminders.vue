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
const staffLabel = computed(() => biz.business.staff_label || 'Profissional')
const staffLabelLower = computed(() => staffLabel.value.toLowerCase())

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
const activeTab = ref('cliente')

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

const activeList = computed(() => (activeTab.value === 'cliente' ? clientOffsets.value : staffOffsets.value))
const sortedActive = computed(() => [...activeList.value].sort((a, b) => b - a))

function previewText() {
  const svc = 'Corte de cabelo'
  if (activeTab.value === 'cliente') {
    return `Olá! Passando para lembrar do seu horário em ${biz.business.name}: *${svc}* amanhã às 14h. Até já!`
  }
  return `Próximo atendimento às 14h: Ana (${svc}).`
}

const STATUS = { enviado: ['Enviado', 'green'], sem_contato: ['Sem e-mail', 'yellow'], erro: ['Erro', 'red'] }
</script>

<template>
  <div class="page-header rm-header">
    <div>
      <p class="eyebrow rm-eyebrow">Agenda</p>
      <h1>Lembretes</h1>
      <p class="muted rm-lede">
        Dispare lembretes automáticos por e-mail antes de cada horário. Menos faltas, menos "esqueci do agendamento".
      </p>
    </div>
  </div>
  <Upsell v-if="!biz.hasFeature('lembretes')" feature="lembretes" />

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span>
      <span>{{ error }}</span>
    </div>
    <div v-if="msg" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span>
      <span>{{ msg }}</span>
    </div>

    <form class="rm-config" @submit.prevent="save">
      <div class="section-head">
        <span class="section-badge"><Icon name="bell" /></span>
        <div>
          <h3>Quando lembrar?</h3>
          <small class="muted">Marque um ou mais momentos. Enviamos por e-mail automaticamente — pelo WhatsApp, use os botões abaixo.</small>
        </div>
      </div>

      <div class="rm-tabs" role="tablist">
        <button type="button" role="tab" :aria-selected="activeTab === 'cliente'"
                class="rm-tab" :class="{ active: activeTab === 'cliente' }" @click="activeTab = 'cliente'">
          <Icon name="user" />
          <span>Para o cliente</span>
          <span v-if="clientOffsets.length" class="rm-tab-count">{{ clientOffsets.length }}</span>
        </button>
        <button type="button" role="tab" :aria-selected="activeTab === 'staff'"
                class="rm-tab" :class="{ active: activeTab === 'staff' }" @click="activeTab = 'staff'">
          <Icon name="briefcase" />
          <span>Para o {{ staffLabelLower }}</span>
          <span v-if="staffOffsets.length" class="rm-tab-count">{{ staffOffsets.length }}</span>
        </button>
      </div>

      <div class="rm-chips">
        <button v-for="o in OPTIONS" :key="o.min" type="button"
                class="rm-chip" :class="{ on: activeList.includes(o.min) }"
                @click="toggle(activeTab === 'cliente' ? clientOffsets : staffOffsets, o.min)">
          <Icon :name="activeList.includes(o.min) ? 'check' : 'clock'" />
          {{ o.label }} antes
        </button>
      </div>

      <div v-if="sortedActive.length" class="rm-timeline">
        <div v-for="(m, i) in sortedActive" :key="m" class="rm-tl-item" :style="{ animationDelay: `${i * 60}ms` }">
          <div class="rm-tl-dot"><Icon name="bell" /></div>
          <div class="rm-tl-info">
            <strong>{{ OPTIONS.find((o) => o.min === m)?.label ?? `${m} min` }} antes</strong>
            <small>{{ activeTab === 'cliente' ? 'Para o cliente' : `Para o ${staffLabelLower}` }} · e-mail</small>
          </div>
        </div>
        <div class="rm-tl-item rm-tl-end">
          <div class="rm-tl-dot rm-tl-dot-end"><Icon name="calendar" /></div>
          <div class="rm-tl-info">
            <strong>Horário do agendamento</strong>
            <small>Hora marcada</small>
          </div>
        </div>
      </div>
      <div v-else class="rm-tl-empty">
        <Icon name="ban" />
        <span>Nenhum momento marcado — {{ activeTab === 'cliente' ? 'o cliente' : `o ${staffLabelLower}` }} não vai receber lembrete automático.</span>
      </div>

      <div v-if="activeTab === 'staff' && staffOffsets.length && missingStaffContact.length" class="rm-warn">
        <Icon name="ban" />
        <span>Sem e-mail cadastrado: <strong>{{ missingStaffContact.join(', ') }}</strong>. Adicione em "{{ staffLabel }}".</span>
      </div>

      <div class="rm-preview">
        <div class="rm-preview-head">
          <Icon name="whatsapp" />
          <span>Prévia da mensagem</span>
        </div>
        <div class="rm-bubble">
          <p>{{ previewText() }}</p>
          <span class="rm-bubble-time">agora</span>
        </div>
      </div>

      <div class="rm-config-foot">
        <button class="btn">
          <Icon name="check" />
          Salvar configuração
        </button>
      </div>
    </form>

    <section class="rm-section">
      <div class="section-head">
        <span class="section-badge"><Icon name="clock" /></span>
        <div>
          <h3>Próximas 24 horas</h3>
          <small class="muted">Dispare um lembrete manual pelo WhatsApp — a mensagem já vai pronta.</small>
        </div>
      </div>

      <div v-if="!upcoming.length" class="rm-empty muted">
        Nenhum agendamento nas próximas 24 horas.
      </div>
      <div v-else class="rm-upcoming">
        <article v-for="a in upcoming" :key="a.id" class="rm-up-card">
          <div class="rm-up-time">
            <strong>{{ formatTime(a.starts_at, tz) }}</strong>
            <small class="muted">hoje</small>
          </div>
          <div class="rm-up-info">
            <strong>{{ a.customer?.name }}</strong>
            <small>{{ a.service?.name }} · com {{ a.professional?.name }}</small>
          </div>
          <div class="rm-up-actions">
            <a v-if="clientMessage(a)" class="btn small secondary" :href="clientMessage(a)" target="_blank" rel="noopener">
              <Icon name="whatsapp" />
              <span class="hide-sm">Cliente</span>
            </a>
            <a v-if="staffMessage(a)" class="btn small secondary" :href="staffMessage(a)" target="_blank" rel="noopener">
              <Icon name="whatsapp" />
              <span class="hide-sm">{{ staffLabel }}</span>
            </a>
          </div>
        </article>
      </div>
    </section>

    <section class="rm-section">
      <div class="section-head">
        <span class="section-badge"><Icon name="mail" /></span>
        <div>
          <h3>Enviados automaticamente</h3>
          <small class="muted">Últimos lembretes disparados pelo sistema.</small>
        </div>
      </div>

      <div v-if="!log.length" class="rm-empty muted">
        Ainda não houve envio automático.
      </div>
      <div v-else class="rm-log">
        <article v-for="l in log" :key="l.id" class="rm-log-row">
          <div class="rm-log-when">
            <strong>{{ formatDateTime(l.created_at, tz) }}</strong>
            <small class="muted">{{ l.target === 'cliente' ? 'Cliente' : staffLabel }} · {{ l.sent_to }}</small>
          </div>
          <div class="rm-log-what">
            <strong>{{ l.appointment?.customer?.name || '—' }}</strong>
            <small v-if="l.appointment" class="muted">{{ formatDateTime(l.appointment.starts_at, tz) }}</small>
          </div>
          <span :class="['badge', STATUS[l.status][1]]">{{ STATUS[l.status][0] }}</span>
        </article>
      </div>
    </section>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.rm-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.rm-eyebrow { display: inline-block; margin-bottom: 6px; }
.rm-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }

/* ===== Alertas ===== */
.alert {
  display: flex; align-items: flex-start; gap: 12px;
  padding: 12px 14px; border-radius: var(--radius-sm);
  border: 1px solid; margin-bottom: 16px; line-height: 1.5;
  font-size: 0.92rem;
}
.alert-danger { color: #fecaca; background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.35); }
.alert-success { color: #bbf7d0; background: var(--success-soft); border-color: rgba(74, 222, 128, 0.35); }
.alert-icon { flex-shrink: 0; width: 28px; height: 28px; border-radius: 10px; display: grid; place-items: center; }
.alert-danger .alert-icon { background: rgba(248, 113, 113, 0.2); color: var(--danger); }
.alert-success .alert-icon { background: rgba(74, 222, 128, 0.2); color: var(--success); }
.alert-icon :deep(svg) { width: 15px; height: 15px; stroke-width: 2.4; }

/* ===== Card base ===== */
.rm-config, .rm-section {
  padding: 22px;
  margin-bottom: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.section-head { display: flex; align-items: center; gap: 12px; margin-bottom: 18px; }
.section-badge {
  width: 40px; height: 40px; border-radius: 12px; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff; box-shadow: 0 0 18px var(--brand-glow);
}
.section-badge :deep(svg) { width: 18px; height: 18px; }
.section-head h3 { margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head small { display: block; font-size: 0.85rem; margin-top: 2px; }

/* ===== Tabs ===== */
.rm-tabs {
  display: flex; gap: 6px;
  padding: 4px;
  border-radius: 14px;
  background: var(--input);
  border: 1px solid var(--border);
  margin-bottom: 16px;
}
.rm-tab {
  flex: 1;
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  padding: 10px 14px; min-height: 44px;
  background: transparent; border: 1px solid transparent;
  border-radius: 10px;
  color: var(--muted); font-weight: 600; font-size: 0.9rem;
  cursor: pointer;
  transition: color 0.15s ease, background 0.15s ease, border-color 0.15s ease;
}
.rm-tab:hover { color: var(--text); }
.rm-tab.active {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff; border-color: transparent;
  box-shadow: 0 0 14px var(--brand-glow);
}
.rm-tab :deep(svg) { width: 15px; height: 15px; }
.rm-tab-count {
  min-width: 20px; padding: 1px 6px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.22);
  font-size: 0.72rem; font-weight: 700;
}
.rm-tab:not(.active) .rm-tab-count { background: var(--surface-strong); color: var(--silver); }

/* ===== Chips ===== */
.rm-chips { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 18px; }
.rm-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 8px 14px; min-height: 40px;
  border-radius: 999px;
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--silver); font-weight: 600; font-size: 0.86rem;
  cursor: pointer;
  transition: all 0.15s ease;
}
.rm-chip:hover { border-color: var(--brand); color: var(--text); }
.rm-chip.on {
  background: var(--brand-soft);
  border-color: var(--brand);
  color: var(--text);
  box-shadow: 0 0 14px var(--brand-soft);
}
.rm-chip :deep(svg) { width: 13px; height: 13px; }

/* ===== Timeline ===== */
.rm-timeline {
  padding: 16px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
  margin-bottom: 16px;
  display: flex; flex-direction: column; gap: 2px;
}
.rm-tl-item {
  display: flex; align-items: center; gap: 14px;
  padding: 8px 0;
  position: relative;
  animation: tlIn 0.3s ease-out both;
}
.rm-tl-item::before {
  content: ''; position: absolute;
  left: 15px; top: 32px; bottom: -2px;
  width: 2px;
  background: linear-gradient(to bottom, var(--brand), var(--border));
}
.rm-tl-item:last-child::before { display: none; }
@keyframes tlIn { from { opacity: 0; transform: translateX(-6px); } to { opacity: 1; transform: translateX(0); } }
.rm-tl-dot {
  width: 32px; height: 32px; border-radius: 50%;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 12px var(--brand-glow);
  z-index: 1;
}
.rm-tl-dot :deep(svg) { width: 14px; height: 14px; }
.rm-tl-dot-end {
  background: var(--surface-strong);
  color: var(--success);
  box-shadow: 0 0 10px rgba(74, 222, 128, 0.3);
}
.rm-tl-info strong { display: block; font-size: 0.92rem; font-weight: 700; }
.rm-tl-info small { display: block; font-size: 0.78rem; color: var(--muted); margin-top: 1px; }

.rm-tl-empty {
  display: flex; align-items: center; gap: 10px;
  padding: 14px 16px;
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  border: 1px dashed rgba(251, 191, 36, 0.35);
  color: var(--warning); font-size: 0.88rem;
  margin-bottom: 16px;
}
.rm-tl-empty :deep(svg) { width: 16px; height: 16px; flex-shrink: 0; }

.rm-warn {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  border: 1px solid rgba(251, 191, 36, 0.35);
  color: var(--warning); font-size: 0.86rem;
  margin-bottom: 16px;
}
.rm-warn :deep(svg) { width: 15px; height: 15px; flex-shrink: 0; margin-top: 2px; }
.rm-warn strong { color: #fff; }

/* ===== Preview WhatsApp ===== */
.rm-preview {
  padding: 16px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.6);
  border: 1px solid var(--border);
  margin-bottom: 16px;
}
.rm-preview-head {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 12px;
  color: var(--muted); font-size: 0.75rem; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.08em;
}
.rm-preview-head :deep(svg) { width: 14px; height: 14px; color: #25D366; }
.rm-bubble {
  position: relative;
  max-width: 90%;
  padding: 10px 54px 18px 14px;
  border-radius: 14px 14px 14px 2px;
  background: #075E54;
  color: #f3f4f6;
  font-size: 0.9rem; line-height: 1.45;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
}
.rm-bubble p { margin: 0; }
.rm-bubble-time {
  position: absolute; right: 10px; bottom: 4px;
  font-size: 0.68rem; color: rgba(255, 255, 255, 0.6);
}

.rm-config-foot { display: flex; justify-content: flex-end; }
.rm-config-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Próximas 24h ===== */
.rm-upcoming { display: flex; flex-direction: column; gap: 8px; }
.rm-up-card {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 14px; align-items: center;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease, box-shadow 0.15s ease;
}
.rm-up-card:hover {
  border-color: var(--brand);
  background: rgba(59, 130, 246, 0.04);
  transform: translateY(-1px);
  box-shadow: 0 0 20px var(--brand-soft);
}
.rm-up-time {
  min-width: 64px; text-align: center;
  padding: 6px 10px; border-radius: 10px;
  background: var(--brand-soft);
  border: 1px solid var(--border);
}
.rm-up-time strong { display: block; font-size: 1rem; font-weight: 800; color: var(--text); letter-spacing: -0.01em; }
.rm-up-time small { display: block; font-size: 0.68rem; text-transform: uppercase; letter-spacing: 0.08em; }
.rm-up-info { min-width: 0; }
.rm-up-info strong { display: block; font-size: 0.95rem; font-weight: 700; }
.rm-up-info small { display: block; font-size: 0.82rem; color: var(--muted); margin-top: 2px; }
.rm-up-actions { display: flex; gap: 6px; flex-wrap: wrap; }
.rm-up-actions .btn :deep(svg) { width: 14px; height: 14px; color: #25D366; }
.rm-up-actions .btn { min-height: 36px; padding: 7px 12px; font-size: 0.82rem; }

/* ===== Log ===== */
.rm-log { display: flex; flex-direction: column; gap: 2px; }
.rm-log-row {
  display: grid;
  grid-template-columns: 1.3fr 1fr auto;
  gap: 12px;
  align-items: center;
  padding: 12px 2px;
  border-top: 1px solid var(--border);
}
.rm-log-row:first-child { border-top: none; }
.rm-log-when strong, .rm-log-what strong { display: block; font-size: 0.88rem; font-weight: 600; color: var(--text); }
.rm-log-when small, .rm-log-what small { display: block; font-size: 0.76rem; margin-top: 2px; }

.rm-empty {
  padding: 20px; text-align: center;
  background: rgba(5, 11, 22, 0.4);
  border: 1px dashed var(--border);
  border-radius: var(--radius-sm);
  font-size: 0.9rem;
}

.hide-sm { display: inline; }

/* ===== Responsive ===== */
@media (max-width: 640px) {
  .rm-tab span:not(.rm-tab-count) { font-size: 0.82rem; }
  .rm-up-card { grid-template-columns: auto 1fr; }
  .rm-up-actions { grid-column: 1 / -1; justify-content: stretch; }
  .rm-up-actions .btn { flex: 1; min-width: 0; justify-content: center; }
  .hide-sm { display: none; }
  .rm-log-row { grid-template-columns: 1fr auto; }
  .rm-log-what { grid-column: 1 / -1; grid-row: 2; }
  .rm-log-row .badge { grid-column: 2; grid-row: 1; }
}

@media (prefers-reduced-motion: reduce) {
  .rm-tl-item { animation: none; }
}
</style>
