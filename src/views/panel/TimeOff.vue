<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime, formatTime, todayISO, addDaysISO, zonedToUtc } from '@/lib/format'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const allowed = computed(() => biz.hasFeature('bloqueios') || biz.hasFeature('folgas'))
const items = ref([])
const professionals = ref([])
const error = ref('')
const saved = ref('')
const emptyForm = () => ({
  kind: 'bloqueio', professional_id: '', reason: '',
  start_date: todayISO(tz.value), start_time: '12:00',
  end_date: todayISO(tz.value), end_time: '13:00', whole_day: false,
})
const form = ref(emptyForm())
const formEl = ref(null)

async function load() {
  const bid = biz.business.id
  professionals.value = unwrap(await supabase.from('professionals').select('id, name').eq('business_id', bid).eq('active', true).order('name'))
  items.value = unwrap(await supabase.from('time_off').select('*, professional:professionals(name)')
    .eq('business_id', bid).gte('ends_at', new Date().toISOString()).order('starts_at'))
}
onMounted(() => { if (allowed.value) load() })

async function add() {
  error.value = ''
  const f = form.value
  const starts = zonedToUtc(f.start_date, f.whole_day ? '00:00' : f.start_time, tz.value)
  const ends = f.whole_day
    ? zonedToUtc(addDaysISO(f.end_date, 1), '00:00', tz.value)
    : zonedToUtc(f.end_date, f.end_time, tz.value)
  const { error: err } = await supabase.from('time_off').insert({
    business_id: biz.business.id, kind: f.kind, reason: f.reason || null,
    professional_id: f.professional_id || null,
    starts_at: starts.toISOString(), ends_at: ends.toISOString(),
  })
  if (err) { error.value = err.message; return }
  saved.value = f.kind === 'folga' ? 'Folga adicionada.' : 'Bloqueio adicionado.'
  form.value = emptyForm()
  load()
}

async function remove(item) {
  if (!confirm(`Remover ${item.kind === 'folga' ? 'esta folga' : 'este bloqueio'}?`)) return
  const { error: err } = await supabase.from('time_off').delete().eq('id', item.id)
  if (err) { error.value = err.message; return }
  saved.value = `${item.kind === 'folga' ? 'Folga' : 'Bloqueio'} removido.`
  load()
}

function focusNew() {
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

// Formata o cabeçalho do card: SEX 10 OUT
function cardDate(iso) {
  const d = new Date(iso)
  const wd = d.toLocaleDateString('pt-BR', { weekday: 'short', timeZone: tz.value }).replace('.', '').toUpperCase()
  const dayNum = d.toLocaleDateString('pt-BR', { day: '2-digit', timeZone: tz.value })
  const mon = d.toLocaleDateString('pt-BR', { month: 'short', timeZone: tz.value }).replace('.', '').toUpperCase()
  return { wd, dayNum, mon }
}

// Formata o período: "dia inteiro", "das 14:00 às 18:00", "qui 10 → sex 11"
function cardPeriod(item) {
  const s = new Date(item.starts_at)
  const e = new Date(item.ends_at)
  const sameDay = s.toLocaleDateString('en-CA', { timeZone: tz.value }) ===
    new Date(e.getTime() - 60000).toLocaleDateString('en-CA', { timeZone: tz.value })
  const startDay = s.toLocaleDateString('en-CA', { timeZone: tz.value })
  const endDay = e.toLocaleDateString('en-CA', { timeZone: tz.value })
  // Dia inteiro: começa 00:00 do dia e termina 00:00 do próximo
  const isWholeDay = s.toLocaleTimeString('en-GB', { timeZone: tz.value, hour: '2-digit', minute: '2-digit' }) === '00:00' &&
    e.toLocaleTimeString('en-GB', { timeZone: tz.value, hour: '2-digit', minute: '2-digit' }) === '00:00'
  if (isWholeDay && sameDay) return 'Dia inteiro'
  if (isWholeDay) {
    // "do dia 10/10 ao dia 12/10"
    const sText = s.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', timeZone: tz.value })
    const eClose = new Date(e.getTime() - 60000)
    const eText = eClose.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', timeZone: tz.value })
    return `Dias inteiros · ${sText} → ${eText}`
  }
  if (sameDay) return `Das ${formatTime(item.starts_at, tz.value)} às ${formatTime(item.ends_at, tz.value)}`
  // Período multi-dia com horas
  return `${formatDateTime(item.starts_at, tz.value)} → ${formatDateTime(item.ends_at, tz.value)}`
}
</script>

<template>
  <div class="page-header to-header">
    <div>
      <p class="eyebrow to-eyebrow">Agenda</p>
      <h1>Folgas e bloqueios</h1>
      <p class="muted to-lede">
        Dias de folga ou faixas de horário bloqueadas somem da vitrine — ninguém consegue marcar nelas.
      </p>
    </div>
  </div>

  <!-- Plano não permite -->
  <div v-if="!allowed" class="locked-card">
    <div class="locked-icon">
      <Icon name="shield" />
    </div>
    <h3>Disponível a partir do plano Profissional</h3>
    <p class="muted">
      Folgas e bloqueios de horário fazem parte dos planos pagos. Suba o plano quando precisar.
    </p>
    <RouterLink class="btn" to="/painel/assinatura">
      <Icon name="sparkles" />
      Ver planos
    </RouterLink>
  </div>

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span>
      <span>{{ error }}</span>
    </div>
    <div v-if="saved" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span>
      <span>{{ saved }}</span>
    </div>

    <!-- Form -->
    <form ref="formEl" class="to-form" @submit.prevent="add">
      <div class="section-head">
        <span class="section-badge"><Icon name="ban" /></span>
        <div>
          <h3>Novo registro</h3>
          <small class="muted">Use folga pra dia inteiro de folga, bloqueio pra travar uma faixa específica (ex.: almoço longo).</small>
        </div>
      </div>

      <!-- Tipo (chips grandes) -->
      <div class="type-row">
        <button type="button" class="type-chip" :class="{ on: form.kind === 'bloqueio' }" @click="form.kind = 'bloqueio'">
          <span class="type-check">
            <Icon v-if="form.kind === 'bloqueio'" name="check" />
          </span>
          <div>
            <strong>Bloqueio</strong>
            <small>Faixa de horário</small>
          </div>
        </button>
        <button type="button" class="type-chip" :class="{ on: form.kind === 'folga' }" @click="form.kind = 'folga'">
          <span class="type-check">
            <Icon v-if="form.kind === 'folga'" name="check" />
          </span>
          <div>
            <strong>Folga</strong>
            <small>Dia(s) inteiro(s)</small>
          </div>
        </button>
      </div>

      <div class="ff-row">
        <div class="ff">
          <select id="to-who" v-model="form.professional_id">
            <option value="">Todo o estabelecimento</option>
            <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
          <label for="to-who" class="ff-static">Quem</label>
        </div>
        <div class="ff ff-wide">
          <input id="to-reason" v-model="form.reason" placeholder=" " />
          <label for="to-reason">Motivo (opcional)</label>
        </div>
      </div>

      <label class="to-toggle">
        <input v-model="form.whole_day" type="checkbox" />
        <span>Dia inteiro</span>
      </label>

      <div class="period-grid" :class="{ compact: form.whole_day }">
        <div class="ff">
          <input id="to-start-date" v-model="form.start_date" type="date" required placeholder=" " />
          <label for="to-start-date" class="ff-static">De</label>
        </div>
        <div v-if="!form.whole_day" class="ff">
          <input id="to-start-time" v-model="form.start_time" type="time" required placeholder=" " />
          <label for="to-start-time" class="ff-static">Hora</label>
        </div>
        <div class="ff">
          <input id="to-end-date" v-model="form.end_date" type="date" required placeholder=" " />
          <label for="to-end-date" class="ff-static">Até</label>
        </div>
        <div v-if="!form.whole_day" class="ff">
          <input id="to-end-time" v-model="form.end_time" type="time" required placeholder=" " />
          <label for="to-end-time" class="ff-static">Hora</label>
        </div>
      </div>

      <div class="to-form-foot">
        <button class="btn">
          <Icon name="plus" />
          Adicionar
        </button>
      </div>
    </form>

    <!-- Lista -->
    <section class="to-section">
      <div v-if="!items.length" class="empty-state">
        <div class="empty-icon-wrap">
          <div class="empty-icon-ring" />
          <div class="empty-icon-core"><Icon name="sun" /></div>
        </div>
        <h3>Nenhuma folga ou bloqueio futuro</h3>
        <p class="muted">
          Sua agenda está aberta normalmente. Adicione um registro acima pra marcar um dia de folga ou travar um horário.
        </p>
        <button class="btn" @click="focusNew">
          <Icon name="plus" />
          Adicionar primeiro
        </button>
      </div>

      <div v-else class="to-list">
        <article v-for="t in items" :key="t.id" class="to-card" :class="`kind-${t.kind}`">
          <div class="to-date">
            <small>{{ cardDate(t.starts_at).wd }}</small>
            <strong>{{ cardDate(t.starts_at).dayNum }}</strong>
            <small>{{ cardDate(t.starts_at).mon }}</small>
          </div>
          <div class="to-body">
            <div class="to-top">
              <span class="to-kind" :class="`kind-${t.kind}`">
                <span class="dot" />
                {{ t.kind === 'folga' ? 'Folga' : 'Bloqueio' }}
              </span>
              <span class="to-who">{{ t.professional?.name ?? 'Todos' }}</span>
            </div>
            <div class="to-period">{{ cardPeriod(t) }}</div>
            <div v-if="t.reason" class="to-reason">{{ t.reason }}</div>
          </div>
          <button class="icon-btn danger" aria-label="Remover" title="Remover" @click="remove(t)">
            <Icon name="trash" />
          </button>
        </article>
      </div>
    </section>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.to-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.to-eyebrow { display: inline-block; margin-bottom: 6px; }
.to-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }

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

/* ===== Card bloqueado (plano) ===== */
.locked-card {
  padding: 48px 24px;
  text-align: center;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 200px at 50% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px dashed var(--border);
}
.locked-icon {
  width: 72px; height: 72px; margin: 0 auto 20px;
  border-radius: 20px; display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px var(--brand-glow);
}
.locked-icon :deep(svg) { width: 32px; height: 32px; }
.locked-card h3 { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 8px; }
.locked-card p { max-width: 420px; margin: 0 auto 20px; font-size: 0.92rem; line-height: 1.5; }
.locked-card .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Form ===== */
.to-form {
  padding: 22px;
  margin-bottom: 24px;
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
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.section-badge :deep(svg) { width: 18px; height: 18px; }
.section-head h3 { margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head small { display: block; font-size: 0.85rem; margin-top: 2px; }

/* ---- Tipo (chips grandes radio-like) ---- */
.type-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin-bottom: 14px;
}
.type-chip {
  position: relative;
  display: flex; align-items: center; gap: 12px;
  padding: 14px 14px 14px 44px;
  text-align: left;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text); font: inherit;
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease;
}
.type-chip:hover { border-color: var(--brand); transform: translateY(-1px); }
.type-chip.on {
  border-color: var(--brand);
  background: linear-gradient(160deg, var(--brand-soft), rgba(5, 11, 22, 0.3));
  box-shadow: 0 0 20px rgba(59, 130, 246, 0.18);
}
.type-check {
  position: absolute;
  left: 14px; top: 50%; transform: translateY(-50%);
  width: 20px; height: 20px; border-radius: 999px;
  display: grid; place-items: center;
  background: var(--surface);
  border: 1.5px solid var(--border);
  color: #fff;
  transition: background 0.15s ease, border-color 0.15s ease;
}
.type-chip.on .type-check {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent;
  box-shadow: 0 0 10px var(--brand-glow);
}
.type-check :deep(svg) { width: 12px; height: 12px; stroke-width: 3; }
.type-chip strong { display: block; font-size: 0.95rem; font-weight: 700; }
.type-chip small { display: block; font-size: 0.78rem; color: var(--muted); margin-top: 2px; }

/* ---- Fields ---- */
.ff-row {
  display: grid;
  grid-template-columns: 1fr 1.5fr;
  gap: 10px;
}
.ff { position: relative; margin: 0 0 12px; }
.ff input, .ff select {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
  color-scheme: dark;
}
.ff select { padding-top: 24px; }
.ff label {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); margin: 0; pointer-events: none;
  transition: top 0.15s ease, font-size 0.15s ease, color 0.15s ease, transform 0.15s ease;
  font-weight: 500;
}
.ff input:focus + label,
.ff input:not(:placeholder-shown) + label,
.ff select + label.ff-static {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}
/* Inputs type date/time sempre têm valor, mantém label pra cima */
.ff input[type="date"] + label,
.ff input[type="time"] + label {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}

.to-toggle {
  display: inline-flex; align-items: center; gap: 8px;
  color: var(--text); font-weight: 500; font-size: 0.92rem;
  margin: 2px 0 10px; cursor: pointer;
}

.period-grid {
  display: grid;
  grid-template-columns: 1fr 120px 1fr 120px;
  gap: 10px;
}
.period-grid.compact { grid-template-columns: 1fr 1fr; }

.to-form-foot { margin-top: 6px; }
.to-form-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Lista ===== */
.to-list { display: flex; flex-direction: column; gap: 10px; }
.to-card {
  display: grid;
  grid-template-columns: 80px 1fr auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, transform 0.15s ease, box-shadow 0.15s ease;
}
.to-card:hover { transform: translateY(-1px); border-color: var(--brand); box-shadow: 0 0 20px var(--brand-soft); }

.to-date {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 10px 6px;
  border-radius: var(--radius-sm);
  background: linear-gradient(160deg, var(--brand-soft), rgba(5, 11, 22, 0.3));
  border: 1px solid rgba(59, 130, 246, 0.3);
  text-align: center;
  gap: 0;
}
.to-date small {
  font-size: 0.62rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.1em; font-weight: 700;
  line-height: 1.4;
}
.to-date strong {
  font-size: 1.3rem; font-weight: 800;
  letter-spacing: -0.02em; line-height: 1;
  color: #fff;
  margin: 2px 0;
}
.to-card.kind-folga .to-date {
  background: linear-gradient(160deg, var(--warning-soft), rgba(5, 11, 22, 0.3));
  border-color: rgba(251, 191, 36, 0.35);
}

.to-body { min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.to-top {
  display: flex; align-items: center; gap: 10px;
  flex-wrap: wrap;
}
.to-kind {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 2px 10px; border-radius: 999px;
  font-size: 0.68rem; font-weight: 700;
  letter-spacing: 0.04em;
  border: 1px solid;
}
.to-kind .dot {
  width: 5px; height: 5px; border-radius: 50%;
  background: currentColor; box-shadow: 0 0 6px currentColor;
}
.to-kind.kind-bloqueio {
  background: var(--brand-soft); color: var(--brand-ink);
  border-color: rgba(59, 130, 246, 0.3);
}
.to-kind.kind-folga {
  background: var(--warning-soft); color: var(--warning);
  border-color: rgba(251, 191, 36, 0.35);
}
.to-who { font-size: 0.88rem; font-weight: 700; color: var(--text); }
.to-period { font-size: 0.86rem; color: var(--silver); }
.to-reason {
  font-size: 0.82rem; color: var(--muted);
  padding: 4px 10px; margin-top: 2px;
  border-radius: 8px;
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
  align-self: flex-start;
}

.icon-btn {
  width: 40px; height: 40px; min-height: 40px;
  border-radius: var(--radius-sm);
  display: grid; place-items: center;
  background: var(--surface); border: 1px solid var(--border);
  color: var(--muted); cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}
.icon-btn.danger:hover { color: var(--danger); border-color: rgba(248, 113, 113, 0.35); background: var(--danger-soft); }
.icon-btn :deep(svg) { width: 15px; height: 15px; }

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
  max-width: 420px;
  font-size: 0.92rem; line-height: 1.5;
}
.empty-state .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Responsive ===== */
@media (max-width: 720px) {
  .period-grid { grid-template-columns: 1fr 1fr; }
  .period-grid.compact { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 640px) {
  .ff-row { grid-template-columns: 1fr; }
  .to-card {
    grid-template-columns: 72px 1fr;
    gap: 12px;
    position: relative;
  }
  .to-card .icon-btn {
    position: absolute;
    top: 10px; right: 10px;
  }
  .to-top { gap: 8px; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
