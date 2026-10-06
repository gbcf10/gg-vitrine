<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { WEEKDAYS } from '@/lib/format'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const professionals = ref([])
const selected = ref(null)
const days = ref([])   // [{ weekday, open, intervals: [{ start, end }] }]
const error = ref('')
const saved = ref(false)

const label = computed(() => biz.business.staff_label || 'Profissional')
const labelLow = computed(() => label.value.toLowerCase())
const selectedName = computed(() => professionals.value.find((p) => p.id === selected.value)?.name ?? '')
const openCount = computed(() => days.value.filter((d) => d.open).length)

const WD_SHORT = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB']

function blankWeek() {
  return WEEKDAYS.map((_, weekday) => ({ weekday, open: false, intervals: [{ start: '09:00', end: '18:00' }] }))
}

async function loadProfessionals() {
  professionals.value = unwrap(await supabase.from('professionals').select('id, name')
    .eq('business_id', biz.business.id).eq('active', true).order('name'))
  selected.value = professionals.value[0]?.id ?? null
}

async function loadHours() {
  saved.value = false
  if (!selected.value) return
  const rows = unwrap(await supabase.from('working_hours').select('*')
    .eq('professional_id', selected.value).order('start_time'))
  const week = blankWeek()
  for (const day of week) {
    const mine = rows.filter((r) => r.weekday === day.weekday)
    if (mine.length) {
      day.open = true
      day.intervals = mine.map((r) => ({ start: r.start_time.slice(0, 5), end: r.end_time.slice(0, 5) }))
    }
  }
  days.value = week
}

onMounted(loadProfessionals)
watch(selected, loadHours)

async function save() {
  error.value = ''
  const rows = days.value.filter((d) => d.open).flatMap((d) =>
    d.intervals.map((i) => ({
      business_id: biz.business.id, professional_id: selected.value,
      weekday: d.weekday, start_time: i.start, end_time: i.end,
    })))
  if (rows.some((r) => r.end_time <= r.start_time)) {
    error.value = 'O horário final precisa ser depois do inicial.'
    return
  }
  try {
    unwrap(await supabase.from('working_hours').delete().eq('professional_id', selected.value))
    if (rows.length) unwrap(await supabase.from('working_hours').insert(rows))
    saved.value = true
  } catch (e) {
    error.value = e.message
  }
}

function copyToAll(day) {
  for (const d of days.value) {
    if (d !== day && d.open) d.intervals = day.intervals.map((i) => ({ ...i }))
  }
}

function toggleDay(day) {
  day.open = !day.open
  if (day.open && !day.intervals.length) {
    day.intervals = [{ start: '09:00', end: '18:00' }]
  }
}
</script>

<template>
  <div class="page-header hr-header">
    <div>
      <p class="eyebrow hr-eyebrow">Agenda</p>
      <h1>Horários de atendimento</h1>
      <p class="muted hr-lede">
        Defina em quais dias e faixas cada {{ labelLow }} atende. Isso é o que aparece de "livre" na vitrine.
      </p>
    </div>
  </div>

  <!-- Sem profissionais: empty state -->
  <div v-if="!professionals.length" class="empty-state">
    <div class="empty-icon-wrap">
      <div class="empty-icon-ring" />
      <div class="empty-icon-core"><Icon name="clock" /></div>
    </div>
    <h3>Nenhum(a) {{ labelLow }} ativo(a)</h3>
    <p class="muted">
      Cadastre primeiro em "{{ label === 'Profissional' ? 'Profissionais' : `${label}s` }}" pra configurar os horários aqui.
    </p>
    <RouterLink class="btn" to="/painel/profissionais">
      <Icon name="plus" />
      Cadastrar {{ labelLow }}
    </RouterLink>
  </div>

  <template v-else>
    <!-- Seletor de profissional (abas quando são poucos, select quando são muitos) -->
    <div v-if="professionals.length <= 4" class="pro-tabs">
      <button v-for="p in professionals" :key="p.id" type="button"
              class="pro-tab" :class="{ on: selected === p.id }"
              @click="selected = p.id">
        {{ p.name }}
      </button>
    </div>
    <div v-else class="pro-select">
      <label for="hours-pro">{{ label }}</label>
      <select id="hours-pro" v-model="selected">
        <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
      </select>
    </div>

    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span>
      <span>{{ error }}</span>
    </div>
    <div v-if="saved" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span>
      <span>Horários salvos.</span>
    </div>

    <div class="hr-card">
      <div class="section-head">
        <span class="section-badge"><Icon name="clock" /></span>
        <div>
          <h3>Semana de {{ selectedName }}</h3>
          <small class="muted">
            {{ openCount === 0 ? 'Nenhum dia aberto ainda — marque abaixo.'
              : openCount === 7 ? 'Atende todos os dias.'
              : `Atende em ${openCount} ${openCount === 1 ? 'dia' : 'dias'} da semana.` }}
          </small>
        </div>
      </div>

      <div class="days">
        <div v-for="day in days" :key="day.weekday" class="day-row" :class="{ open: day.open }">
          <button type="button" class="day-toggle" :class="{ on: day.open }" @click="toggleDay(day)">
            <span class="day-check">
              <Icon v-if="day.open" name="check" />
            </span>
            <span class="day-label">
              <small>{{ WD_SHORT[day.weekday] }}</small>
              <strong>{{ WEEKDAYS[day.weekday] }}</strong>
            </span>
          </button>

          <div v-if="day.open" class="day-body">
            <div v-for="(interval, i) in day.intervals" :key="i" class="interval">
              <div class="interval-fields">
                <input v-model="interval.start" type="time" aria-label="Início" />
                <span class="interval-sep">até</span>
                <input v-model="interval.end" type="time" aria-label="Fim" />
              </div>
              <button v-if="day.intervals.length > 1" type="button" class="icon-btn"
                      aria-label="Remover intervalo" title="Remover intervalo"
                      @click="day.intervals.splice(i, 1)">
                <Icon name="minus" />
              </button>
            </div>

            <div class="day-actions">
              <button type="button" class="link-btn-small"
                      @click="day.intervals.push({ start: '14:00', end: '18:00' })">
                <Icon name="plus" />
                Adicionar intervalo
              </button>
              <button v-if="openCount > 1" type="button" class="link-btn-small"
                      @click="copyToAll(day)">
                <Icon name="copy" />
                Copiar pros outros dias abertos
              </button>
            </div>
          </div>

          <div v-else class="day-closed">Fechado</div>
        </div>
      </div>

      <div class="hr-foot">
        <button class="btn" @click="save">
          <Icon name="check" />
          Salvar horários
        </button>
      </div>
    </div>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.hr-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.hr-eyebrow { display: inline-block; margin-bottom: 6px; }
.hr-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }

/* ===== Alertas ===== */
.alert {
  display: flex; align-items: flex-start; gap: 12px;
  padding: 12px 14px; border-radius: var(--radius-sm);
  border: 1px solid; margin-bottom: 16px; line-height: 1.5;
  font-size: 0.92rem;
}
.alert-danger { color: #fecaca; background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.35); }
.alert-success { color: #bbf7d0; background: var(--success-soft); border-color: rgba(74, 222, 128, 0.35); }
.alert-icon {
  flex-shrink: 0; width: 28px; height: 28px; border-radius: 10px;
  display: grid; place-items: center;
}
.alert-danger .alert-icon { background: rgba(248, 113, 113, 0.2); color: var(--danger); }
.alert-success .alert-icon { background: rgba(74, 222, 128, 0.2); color: var(--success); }
.alert-icon :deep(svg) { width: 15px; height: 15px; stroke-width: 2.4; }

/* ===== Tabs de profissional ===== */
.pro-tabs {
  display: flex; gap: 4px; padding: 4px;
  border-radius: 999px;
  background: var(--surface); border: 1px solid var(--border);
  margin-bottom: 18px;
  overflow-x: auto;
}
.pro-tab {
  padding: 10px 18px; border-radius: 999px; border: none; background: none;
  color: var(--muted); font: inherit; font-weight: 600; cursor: pointer;
  white-space: nowrap;
  transition: color 0.15s ease;
  min-height: 40px;
}
.pro-tab:hover { color: var(--text); }
.pro-tab.on {
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}

.pro-select { max-width: 320px; margin-bottom: 18px; }
.pro-select label { font-size: 0.82rem; font-weight: 600; margin-bottom: 6px; color: var(--silver); }

/* ===== Card principal ===== */
.hr-card {
  padding: 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.section-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 18px;
}
.section-badge {
  width: 40px; height: 40px; border-radius: 12px; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.section-badge :deep(svg) { width: 18px; height: 18px; }
.section-head h3 { margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head small { display: block; font-size: 0.85rem; margin-top: 2px; }

/* ===== Grid dos dias ===== */
.days { display: flex; flex-direction: column; gap: 8px; }
.day-row {
  display: grid;
  grid-template-columns: 180px 1fr;
  gap: 16px;
  align-items: start;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.35);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, background 0.15s ease;
}
.day-row.open {
  background: linear-gradient(160deg, var(--brand-soft), rgba(5, 11, 22, 0.3));
  border-color: rgba(59, 130, 246, 0.3);
}

.day-toggle {
  display: flex; align-items: center; gap: 12px;
  padding: 6px 8px 6px 6px;
  border-radius: var(--radius-sm);
  background: transparent; border: none;
  color: var(--text); font: inherit; cursor: pointer;
  text-align: left;
  transition: background 0.15s ease;
}
.day-toggle:hover { background: rgba(255, 255, 255, 0.04); }
.day-check {
  width: 26px; height: 26px; border-radius: 8px;
  display: grid; place-items: center; flex-shrink: 0;
  background: var(--surface);
  border: 1.5px solid var(--border);
  color: #fff;
  transition: background 0.15s ease, border-color 0.15s ease;
}
.day-check :deep(svg) { width: 14px; height: 14px; stroke-width: 3; }
.day-toggle.on .day-check {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent;
  box-shadow: 0 0 12px var(--brand-glow);
}
.day-label { display: flex; flex-direction: column; min-width: 0; }
.day-label small {
  font-size: 0.65rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.1em; font-weight: 700;
}
.day-label strong { font-size: 0.98rem; font-weight: 700; }

.day-body {
  display: flex; flex-direction: column; gap: 10px;
  min-width: 0;
}
.interval {
  display: flex; align-items: center; gap: 8px;
}
.interval-fields {
  flex: 1; display: flex; align-items: center; gap: 8px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: 2px;
}
.interval-fields input {
  flex: 1;
  background: transparent;
  border: none;
  padding: 10px 10px;
  font-size: 0.92rem;
  color-scheme: dark;
  min-height: 40px;
}
.interval-fields input:focus { outline: none; box-shadow: none; }
.interval-sep {
  color: var(--muted);
  font-size: 0.82rem;
  padding: 0 4px;
  font-weight: 600;
}

.icon-btn {
  width: 40px; height: 40px; min-height: 40px;
  border-radius: var(--radius-sm);
  display: grid; place-items: center;
  background: var(--surface); border: 1px solid var(--border);
  color: var(--muted); cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}
.icon-btn:hover { color: var(--danger); border-color: rgba(248, 113, 113, 0.35); background: var(--danger-soft); }
.icon-btn :deep(svg) { width: 15px; height: 15px; }

.day-actions {
  display: flex; flex-wrap: wrap; gap: 8px 16px;
  margin-top: 2px;
}
.link-btn-small {
  display: inline-flex; align-items: center; gap: 5px;
  background: none; border: none; color: var(--brand-ink);
  font: inherit; font-size: 0.82rem; font-weight: 600;
  cursor: pointer; padding: 4px 0;
}
.link-btn-small:hover { color: #fff; }
.link-btn-small :deep(svg) { width: 13px; height: 13px; }

.day-closed {
  color: var(--muted);
  font-size: 0.88rem;
  padding: 10px 0;
}

/* ===== Foot ===== */
.hr-foot { margin-top: 20px; }
.hr-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Empty state ===== */
.empty-state {
  text-align: center;
  padding: 48px 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 200px at 50% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px dashed var(--border);
}
.empty-icon-wrap { position: relative; width: 88px; height: 88px; margin: 0 auto 20px; }
.empty-icon-ring {
  position: absolute; inset: 0; border-radius: 50%;
  background: radial-gradient(circle, var(--brand-glow), transparent 70%);
  animation: ringPulse 2.4s ease-in-out infinite;
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.12); opacity: 0.35; }
}
.empty-icon-core {
  position: absolute; inset: 12px;
  border-radius: 50%; display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px var(--brand-glow);
}
.empty-icon-core :deep(svg) { width: 26px; height: 26px; }
.empty-state h3 {
  font-size: 1.2rem; font-weight: 800;
  letter-spacing: -0.02em; margin: 0 0 8px;
}
.empty-state p {
  margin: 0 auto 20px;
  max-width: 400px;
  font-size: 0.92rem; line-height: 1.5;
}
.empty-state .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Responsive ===== */
@media (max-width: 640px) {
  .hr-card { padding: 18px; }
  .day-row {
    grid-template-columns: 1fr;
    gap: 10px;
    padding: 12px;
  }
  .day-toggle { padding: 0; }
  .interval-fields { flex-wrap: wrap; }
  .interval-fields input { flex: 1 1 44%; }
  .pro-tabs { flex-wrap: nowrap; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
