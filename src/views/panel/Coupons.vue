<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, zonedToUtc, plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const coupons = ref([])
const error = ref('')
const msg = ref('')
const empty = () => ({ code: '', kind: 'percent', value: 10, min_order: 0, valid_until: '', max_uses: '' })
const form = ref(empty())
const formEl = ref(null)

const activeCount = computed(() => coupons.value.filter((c) => c.active && !expired(c) && !exhausted(c)).length)

async function load() {
  coupons.value = unwrap(await supabase.from('coupons').select('*')
    .eq('business_id', biz.business.id).order('created_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('cupons')) load() })

async function add() {
  error.value = ''; msg.value = ''
  const f = form.value
  const { error: err } = await supabase.from('coupons').insert({
    business_id: biz.business.id, code: f.code.trim().toUpperCase(), kind: f.kind, value: Number(f.value),
    min_order: Number(f.min_order || 0), valid_until: f.valid_until || null, max_uses: f.max_uses ? Number(f.max_uses) : null,
  })
  if (err) {
    error.value = err.message.includes('coupons_code_unique') ? 'Já existe um cupom com esse código.'
      : err.message.includes('code_check') ? 'Use de 3 a 20 letras, números, - ou _.' : err.message
    return
  }
  msg.value = `Cupom ${f.code.trim().toUpperCase()} criado.`
  form.value = empty()
  load()
}

async function toggle(c) {
  await supabase.from('coupons').update({ active: !c.active }).eq('id', c.id)
  msg.value = `${c.code} ${!c.active ? 'ativado' : 'pausado'}.`
  load()
}
async function remove(c) {
  if (!confirm(`Excluir o cupom ${c.code}?`)) return
  await supabase.from('coupons').delete().eq('id', c.id)
  msg.value = `${c.code} excluído.`
  load()
}

async function copyCode(c) {
  try {
    await navigator.clipboard.writeText(c.code)
    msg.value = `Código ${c.code} copiado.`
  } catch { /* ignore */ }
}

function focusNew() {
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

const describe = (c) => (c.kind === 'percent' ? `${Number(c.value)}% OFF` : `${money(c.value)} OFF`)
const expired = (c) => c.valid_until && c.valid_until < new Date().toISOString().slice(0, 10)
const exhausted = (c) => c.max_uses && c.uses >= c.max_uses
function status(c) {
  if (expired(c)) return { label: 'Expirado', cls: 'expired' }
  if (exhausted(c)) return { label: 'Esgotado', cls: 'exhausted' }
  if (!c.active) return { label: 'Pausado', cls: 'paused' }
  return { label: 'Ativo', cls: 'active' }
}
</script>

<template>
  <div class="page-header cp-header">
    <div>
      <p class="eyebrow cp-eyebrow">Marketing</p>
      <h1>Cupons de desconto</h1>
      <p class="muted cp-lede">
        Crie códigos pra divulgar no Instagram, Status do WhatsApp, panfletos. O cliente digita no checkout da vitrine.
      </p>
    </div>
    <span v-if="coupons.length" class="cp-count">
      {{ plural(activeCount, 'ativo', 'ativos') }} · {{ plural(coupons.length, 'cupom', 'cupons') }} no total
    </span>
  </div>
  <Upsell v-if="!biz.hasFeature('cupons')" feature="cupons" />

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span><span>{{ error }}</span>
    </div>
    <div v-if="msg" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span><span>{{ msg }}</span>
    </div>

    <form ref="formEl" class="cp-form" @submit.prevent="add">
      <div class="section-head">
        <span class="section-badge"><Icon name="tag" /></span>
        <div>
          <h3>Novo cupom</h3>
          <small class="muted">Defina o código, o tipo e as regras. Dá pra pausar ou excluir depois.</small>
        </div>
      </div>

      <div class="ff-row">
        <div class="ff ff-wide">
          <input id="cp-code" v-model="form.code" required placeholder=" " maxlength="20" style="text-transform: uppercase" />
          <label for="cp-code">Código (ex.: PROMO10)</label>
        </div>
        <div class="ff">
          <select id="cp-kind" v-model="form.kind">
            <option value="percent">Porcentagem (%)</option>
            <option value="fixed">Valor fixo (R$)</option>
          </select>
          <label for="cp-kind" class="static">Tipo</label>
        </div>
        <div class="ff">
          <input id="cp-value" v-model.number="form.value" type="number" min="0.01"
                 :max="form.kind === 'percent' ? 100 : undefined" step="0.01" required placeholder=" " />
          <label for="cp-value">{{ form.kind === 'percent' ? 'Desconto (%)' : 'Desconto (R$)' }}</label>
        </div>
      </div>

      <div class="ff-row">
        <div class="ff">
          <input id="cp-min" v-model.number="form.min_order" type="number" min="0" step="0.01" placeholder=" " />
          <label for="cp-min">Pedido mínimo (R$)</label>
        </div>
        <div class="ff">
          <input id="cp-until" v-model="form.valid_until" type="date" placeholder=" " />
          <label for="cp-until" class="static">Válido até</label>
        </div>
        <div class="ff">
          <input id="cp-max" v-model.number="form.max_uses" type="number" min="1" placeholder=" " />
          <label for="cp-max">Limite de usos</label>
        </div>
      </div>

      <div class="cp-form-foot">
        <button class="btn">
          <Icon name="plus" />
          Criar cupom
        </button>
      </div>
    </form>

    <section class="cp-section">
      <div v-if="!coupons.length" class="empty-state">
        <div class="empty-icon-wrap">
          <div class="empty-icon-ring" />
          <div class="empty-icon-core"><Icon name="tag" /></div>
        </div>
        <h3>Crie seu primeiro cupom</h3>
        <p class="muted">
          Divulgue um código no Instagram ou no Status pra atrair clientes novos. Eles digitam no checkout e ganham desconto na hora.
        </p>
        <button class="btn" @click="focusNew">
          <Icon name="plus" />
          Criar primeiro cupom
        </button>
      </div>

      <div v-else class="cp-grid">
        <article v-for="c in coupons" :key="c.id" class="cp-ticket" :class="[status(c).cls]">
          <div class="cp-ticket-main">
            <div class="cp-ticket-head">
              <span class="cp-ticket-value">{{ describe(c) }}</span>
              <span class="cp-ticket-status">{{ status(c).label }}</span>
            </div>
            <div class="cp-ticket-code" @click="copyCode(c)" :title="`Clique pra copiar: ${c.code}`">
              <strong>{{ c.code }}</strong>
              <Icon name="copy" />
            </div>
            <div class="cp-ticket-rules">
              <span v-if="Number(c.min_order)">
                <Icon name="tag" />
                A partir de {{ money(c.min_order) }}
              </span>
              <span v-if="c.valid_until">
                <Icon name="calendar" />
                Até {{ formatDate(zonedToUtc(c.valid_until, '12:00', biz.business.timezone), biz.business.timezone) }}
              </span>
              <span v-if="!Number(c.min_order) && !c.valid_until" class="cp-rule-none">
                Sem restrições
              </span>
            </div>
          </div>

          <div class="cp-ticket-stub">
            <div class="cp-stub-uses">
              <strong>{{ c.uses }}{{ c.max_uses ? ` / ${c.max_uses}` : '' }}</strong>
              <small>{{ c.max_uses ? 'usos' : plural(c.uses, 'uso', 'usos') }}</small>
            </div>
            <div class="cp-stub-actions">
              <button class="btn small secondary" :disabled="expired(c) || exhausted(c)" @click="toggle(c)">
                <Icon :name="c.active ? 'ban' : 'check'" />
                <span class="hide-sm">{{ c.active ? 'Pausar' : 'Ativar' }}</span>
              </button>
              <button class="btn small secondary danger-btn" aria-label="Excluir cupom" @click="remove(c)">
                <Icon name="trash" />
              </button>
            </div>
          </div>
        </article>
      </div>
    </section>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.cp-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.cp-eyebrow { display: inline-block; margin-bottom: 6px; }
.cp-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.cp-count {
  padding: 6px 14px; border-radius: 999px;
  background: var(--surface); border: 1px solid var(--border);
  color: var(--silver); font-size: 0.82rem; font-weight: 600;
  white-space: nowrap;
}

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

/* ===== Form ===== */
.cp-form, .cp-section {
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

/* ===== Floating labels ===== */
.ff-row {
  display: grid;
  grid-template-columns: 1.4fr 1fr 1fr;
  gap: 10px;
}
.ff { position: relative; margin: 0 0 12px; }
.ff.ff-wide { grid-column: span 1; }
.ff input, .ff select {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
  width: 100%;
}
.ff select { padding-top: 24px; }
.ff label {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); margin: 0; pointer-events: none;
  transition: top 0.15s ease, font-size 0.15s ease, color 0.15s ease, transform 0.15s ease;
  font-weight: 500;
}
.ff label.static {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}
.ff input:focus + label,
.ff input:not(:placeholder-shown) + label,
.ff input[type="date"] + label {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}

.cp-form-foot { display: flex; justify-content: flex-end; margin-top: 4px; }
.cp-form-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Ticket grid ===== */
.cp-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 14px;
}

.cp-ticket {
  position: relative;
  display: grid;
  grid-template-columns: 1fr auto;
  min-height: 180px;
  border-radius: 16px;
  background:
    radial-gradient(ellipse 220px 160px at 0% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px solid var(--border);
  overflow: hidden;
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}
.cp-ticket:hover {
  transform: translateY(-2px);
  border-color: var(--brand);
  box-shadow: 0 0 28px var(--brand-soft);
}
.cp-ticket.paused, .cp-ticket.expired, .cp-ticket.exhausted { opacity: 0.65; }

/* Scallop between main and stub using radial-gradient dots */
.cp-ticket::before, .cp-ticket::after {
  content: '';
  position: absolute;
  right: 100px;
  width: 14px; height: 14px;
  border-radius: 50%;
  background: var(--bg);
  border: 1px solid var(--border);
  z-index: 2;
}
.cp-ticket::before { top: -7px; }
.cp-ticket::after { bottom: -7px; }

.cp-ticket-main {
  padding: 18px;
  display: flex; flex-direction: column;
  gap: 10px;
  min-width: 0;
}

.cp-ticket-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 10px;
}
.cp-ticket-value {
  font-size: 1.4rem; font-weight: 900;
  letter-spacing: -0.025em;
  background: linear-gradient(120deg, #fff 0%, var(--brand-ink) 100%);
  -webkit-background-clip: text; background-clip: text;
  color: transparent;
}
.cp-ticket-status {
  padding: 3px 10px; border-radius: 999px;
  font-size: 0.68rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.08em;
  background: var(--surface-strong); color: var(--muted);
  border: 1px solid var(--border);
  white-space: nowrap;
}
.cp-ticket.active .cp-ticket-status {
  background: var(--success-soft); color: var(--success);
  border-color: rgba(74, 222, 128, 0.3);
}
.cp-ticket.expired .cp-ticket-status {
  background: var(--danger-soft); color: var(--danger);
  border-color: rgba(248, 113, 113, 0.3);
}
.cp-ticket.exhausted .cp-ticket-status {
  background: var(--warning-soft); color: var(--warning);
  border-color: rgba(251, 191, 36, 0.3);
}

.cp-ticket-code {
  display: inline-flex; align-items: center; gap: 8px;
  padding: 10px 14px;
  border-radius: 10px;
  background: rgba(5, 11, 22, 0.6);
  border: 1px dashed var(--border);
  cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease;
  align-self: flex-start;
  max-width: 100%;
}
.cp-ticket-code:hover { border-color: var(--brand); background: rgba(5, 11, 22, 0.8); }
.cp-ticket-code strong {
  font-family: ui-monospace, Menlo, monospace;
  font-size: 1.1rem; font-weight: 800;
  letter-spacing: 0.08em;
  color: var(--text);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.cp-ticket-code :deep(svg) { width: 13px; height: 13px; color: var(--muted); flex-shrink: 0; }

.cp-ticket-rules {
  display: flex; flex-direction: column; gap: 6px;
  margin-top: auto;
}
.cp-ticket-rules span {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 0.82rem; color: var(--silver);
}
.cp-ticket-rules :deep(svg) { width: 12px; height: 12px; color: var(--brand-ink); flex-shrink: 0; }
.cp-rule-none { color: var(--muted); font-style: italic; }

/* Stub (right side) */
.cp-ticket-stub {
  width: 112px;
  display: flex; flex-direction: column;
  padding: 18px 14px;
  background:
    linear-gradient(180deg, rgba(5, 11, 22, 0.4), rgba(5, 11, 22, 0.6)),
    var(--surface);
  border-left: 2px dashed var(--border);
  text-align: center;
}
.cp-stub-uses {
  flex: 1;
  display: flex; flex-direction: column; justify-content: center;
  margin-bottom: 10px;
}
.cp-stub-uses strong {
  display: block;
  font-size: 1.1rem; font-weight: 800;
  color: var(--text);
  letter-spacing: -0.01em;
}
.cp-stub-uses small {
  display: block;
  font-size: 0.72rem;
  color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.06em;
  margin-top: 2px;
}

.cp-stub-actions {
  display: flex; flex-direction: column; gap: 6px;
}
.cp-stub-actions .btn {
  min-height: 34px;
  padding: 6px 8px;
  font-size: 0.78rem;
  width: 100%;
  justify-content: center;
}
.cp-stub-actions .btn :deep(svg) { width: 13px; height: 13px; }
.cp-stub-actions .danger-btn { color: var(--danger); }
.cp-stub-actions .danger-btn:hover { border-color: var(--danger); color: var(--danger); }

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
.empty-state h3 { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 8px; }
.empty-state p { margin: 0 auto 20px; max-width: 420px; font-size: 0.92rem; line-height: 1.5; }
.empty-state .btn :deep(svg) { width: 15px; height: 15px; }

.hide-sm { display: inline; }

/* ===== Responsive ===== */
@media (max-width: 640px) {
  .ff-row { grid-template-columns: 1fr 1fr; }
  .ff.ff-wide { grid-column: 1 / -1; }
  .cp-grid { grid-template-columns: 1fr; }
  .cp-ticket-value { font-size: 1.2rem; }
  .cp-ticket-stub { width: 92px; padding: 14px 10px; }
  .hide-sm { display: none; }
}
@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
