<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDateTime, APPOINTMENT_STATUS, plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const customers = ref([])
const search = ref('')
const error = ref('')
const saved = ref('')
const selected = ref(null)
const history = ref([])
const form = ref({ name: '', phone: '', email: '', notes: '' })
const formEl = ref(null)
const detailEl = ref(null)

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return q ? customers.value.filter((c) => `${c.name} ${c.phone ?? ''} ${c.email ?? ''}`.toLowerCase().includes(q)) : customers.value
})
const limit = computed(() => biz.plan?.max_customers)

async function load() {
  customers.value = unwrap(await supabase.from('customers').select('*')
    .eq('business_id', biz.business.id).order('name'))
}
onMounted(load)

async function add() {
  error.value = ''
  const { error: err } = await supabase.from('customers').insert({ ...form.value, business_id: biz.business.id })
  if (err) { error.value = err.message; return }
  saved.value = `${form.value.name} adicionado.`
  form.value = { name: '', phone: '', email: '', notes: '' }
  load()
}

async function open(c) {
  selected.value = { ...c }
  saved.value = ''
  history.value = unwrap(await supabase.from('appointments')
    .select('id, starts_at, status, price, service:services(name), professional:professionals(name)')
    .eq('customer_id', c.id).order('starts_at', { ascending: false }).limit(50))
  // scroll pro detalhe
  setTimeout(() => detailEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 50)
}

async function saveSelected() {
  const { id, name, phone, email, notes } = selected.value
  const { error: err } = await supabase.from('customers').update({ name, phone, email, notes }).eq('id', id)
  if (err) { error.value = err.message; return }
  saved.value = `${name} salvo.`
  selected.value = null
  load()
}

function focusNew() {
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function initials(name) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

const STATUS_BADGE = { scheduled: '', confirmed: 'green', completed: 'green', canceled: 'red', no_show: 'yellow' }
</script>

<template>
  <div class="page-header cst-header">
    <div>
      <p class="eyebrow cst-eyebrow">Base</p>
      <h1>Clientes</h1>
      <p class="muted cst-lede">
        Quem já marcou com você. Eles aparecem aqui conforme agendam na vitrine ou você cadastra manualmente.
      </p>
    </div>
    <span v-if="customers.length" class="cst-count">
      {{ limit ? `${customers.length} de ${limit} do seu plano` : plural(customers.length, 'cliente', 'clientes') }}
    </span>
  </div>

  <div v-if="error" class="alert alert-danger">
    <span class="alert-icon"><Icon name="ban" /></span>
    <span>{{ error }}</span>
  </div>
  <div v-if="saved" class="alert alert-success">
    <span class="alert-icon"><Icon name="check" /></span>
    <span>{{ saved }}</span>
  </div>

  <!-- Detalhe do cliente selecionado -->
  <div v-if="selected" ref="detailEl" class="detail-card">
    <div class="detail-head">
      <div class="detail-avatar">{{ initials(selected.name) }}</div>
      <div class="detail-info">
        <h3>{{ selected.name }}</h3>
        <small class="muted">Edite dados, veja histórico e salve as mudanças.</small>
      </div>
      <button class="btn small secondary" aria-label="Fechar detalhe" @click="selected = null">Fechar</button>
    </div>

    <div class="ff-row">
      <div class="ff">
        <input id="cst-sel-name" v-model="selected.name" placeholder=" " />
        <label for="cst-sel-name">Nome</label>
      </div>
      <div class="ff">
        <input id="cst-sel-phone" v-model="selected.phone" placeholder=" " />
        <label for="cst-sel-phone">Telefone</label>
      </div>
      <div class="ff">
        <input id="cst-sel-email" v-model="selected.email" placeholder=" " />
        <label for="cst-sel-email">E-mail</label>
      </div>
    </div>
    <div class="ff ff-area">
      <textarea id="cst-sel-notes" v-model="selected.notes" rows="2" placeholder=" " />
      <label for="cst-sel-notes">Observações</label>
    </div>

    <div class="detail-actions">
      <button class="btn" @click="saveSelected">
        <Icon name="check" />
        Salvar
      </button>
    </div>

    <div class="history-head">
      <span class="section-badge small"><Icon name="clock" /></span>
      <div>
        <h4>Histórico</h4>
        <small class="muted">Últimos {{ history.length ? history.length : 0 }} agendamentos.</small>
      </div>
    </div>

    <div v-if="!history.length" class="history-empty muted">
      Nenhum agendamento registrado.
    </div>
    <div v-else class="history-list">
      <div v-for="a in history" :key="a.id" class="history-row">
        <div class="history-when">
          <strong>{{ formatDateTime(a.starts_at, biz.business.timezone) }}</strong>
          <small class="muted">{{ a.professional?.name }}</small>
        </div>
        <div class="history-what">
          <strong>{{ a.service?.name }}</strong>
          <small class="muted">{{ money(a.price) }}</small>
        </div>
        <span :class="['badge', STATUS_BADGE[a.status]]">{{ APPOINTMENT_STATUS[a.status] }}</span>
      </div>
    </div>
  </div>

  <!-- Form de novo cliente -->
  <form ref="formEl" class="cst-form" @submit.prevent="add">
    <div class="section-head">
      <span class="section-badge"><Icon name="contact" /></span>
      <div>
        <h3>Novo cliente</h3>
        <small class="muted">Útil pra quem liga ou chega no balcão sem usar a vitrine.</small>
      </div>
    </div>
    <div class="ff-row">
      <div class="ff">
        <input id="cst-name" v-model="form.name" required placeholder=" " />
        <label for="cst-name">Nome</label>
      </div>
      <div class="ff">
        <input id="cst-phone" v-model="form.phone" type="tel" placeholder=" " />
        <label for="cst-phone">Telefone</label>
      </div>
      <div class="ff">
        <input id="cst-email" v-model="form.email" type="email" placeholder=" " />
        <label for="cst-email">E-mail</label>
      </div>
    </div>
    <div class="cst-form-foot">
      <button class="btn">
        <Icon name="plus" />
        Adicionar cliente
      </button>
    </div>
  </form>

  <!-- Lista -->
  <section class="cst-section">
    <div v-if="!customers.length" class="empty-state">
      <div class="empty-icon-wrap">
        <div class="empty-icon-ring" />
        <div class="empty-icon-core"><Icon name="contact" /></div>
      </div>
      <h3>Seus clientes vão aparecer aqui</h3>
      <p class="muted">
        Conforme eles marcam horário pela sua vitrine, ficam salvos aqui automaticamente. Dá pra cadastrar manualmente também.
      </p>
      <button class="btn" @click="focusNew">
        <Icon name="plus" />
        Cadastrar manualmente
      </button>
    </div>

    <template v-else>
      <div class="search-wrap">
        <span class="search-icon"><Icon name="search" /></span>
        <input v-model="search" placeholder="Buscar por nome, telefone ou e-mail" />
      </div>

      <div v-if="!filtered.length" class="search-empty">
        <Icon name="search" />
        <p>Nenhum cliente bate com "<strong>{{ search }}</strong>".</p>
      </div>

      <div v-else class="cst-list">
        <article v-for="c in filtered" :key="c.id" class="cst-row">
          <div class="cst-row-avatar">{{ initials(c.name) }}</div>
          <div class="cst-row-info">
            <div class="cst-row-name">
              <strong>{{ c.name }}</strong>
              <span v-if="c.auth_user_id" class="badge blue" title="Marcou pelo link da vitrine">online</span>
            </div>
            <div class="cst-row-contact">
              <span v-if="c.phone">
                <Icon name="phone" />
                {{ c.phone }}
              </span>
              <span v-if="c.email">
                <Icon name="mail" />
                {{ c.email }}
              </span>
              <span v-if="!c.phone && !c.email" class="muted">Sem contato cadastrado</span>
            </div>
          </div>
          <button class="btn small secondary" aria-label="Ver detalhes do cliente" @click="open(c)">
            Ver detalhes
          </button>
        </article>
      </div>
    </template>
  </section>
</template>

<style scoped>
/* ===== Header ===== */
.cst-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.cst-eyebrow { display: inline-block; margin-bottom: 6px; }
.cst-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.cst-count {
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
.alert-icon {
  flex-shrink: 0; width: 28px; height: 28px; border-radius: 10px;
  display: grid; place-items: center;
}
.alert-danger .alert-icon { background: rgba(248, 113, 113, 0.2); color: var(--danger); }
.alert-success .alert-icon { background: rgba(74, 222, 128, 0.2); color: var(--success); }
.alert-icon :deep(svg) { width: 15px; height: 15px; stroke-width: 2.4; }

/* ===== Form padrão (section-head + ff) ===== */
.cst-form, .detail-card {
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
.detail-card {
  border-color: var(--brand);
  box-shadow: 0 0 32px var(--brand-soft);
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
.section-badge.small { width: 32px; height: 32px; border-radius: 10px; }
.section-badge :deep(svg) { width: 18px; height: 18px; }
.section-badge.small :deep(svg) { width: 14px; height: 14px; }
.section-head h3 { margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head h4 { margin: 0; font-size: 0.98rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head small { display: block; font-size: 0.85rem; margin-top: 2px; }

.ff-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}
.ff { position: relative; margin: 0 0 12px; }
.ff input, .ff textarea {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
  width: 100%;
}
.ff textarea { min-height: 76px; padding-top: 24px; resize: vertical; }
.ff label {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); margin: 0; pointer-events: none;
  transition: top 0.15s ease, font-size 0.15s ease, color 0.15s ease, transform 0.15s ease;
  font-weight: 500;
}
.ff.ff-area label { top: 20px; transform: translateY(0); }
.ff input:focus + label,
.ff input:not(:placeholder-shown) + label,
.ff textarea:focus + label,
.ff textarea:not(:placeholder-shown) + label {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}

.cst-form-foot { margin-top: 4px; }
.cst-form-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Detail card ===== */
.detail-head {
  display: flex; align-items: center; gap: 14px;
  margin-bottom: 18px;
}
.detail-avatar {
  width: 48px; height: 48px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff; font-weight: 800; font-size: 1.05rem;
  box-shadow: 0 0 18px var(--brand-glow);
}
.detail-info { flex: 1; min-width: 0; }
.detail-info h3 { margin: 0 0 2px; font-size: 1.15rem; font-weight: 800; letter-spacing: -0.015em; }
.detail-info small { font-size: 0.85rem; }

.detail-actions { margin: 6px 0 20px; }
.detail-actions .btn :deep(svg) { width: 15px; height: 15px; }

.history-head {
  display: flex; align-items: center; gap: 10px;
  padding-top: 18px; margin-bottom: 12px;
  border-top: 1px solid var(--border);
}

.history-empty {
  padding: 20px; text-align: center;
  background: rgba(5, 11, 22, 0.4);
  border: 1px dashed var(--border);
  border-radius: var(--radius-sm);
  font-size: 0.9rem;
}

.history-list { display: flex; flex-direction: column; gap: 2px; }
.history-row {
  display: grid;
  grid-template-columns: 1.3fr 1fr auto;
  gap: 12px;
  align-items: center;
  padding: 10px 2px;
  border-top: 1px solid var(--border);
}
.history-row:first-child { border-top: none; }
.history-when strong,
.history-what strong {
  display: block;
  font-size: 0.88rem; font-weight: 600;
  color: var(--text);
}
.history-when small,
.history-what small {
  display: block;
  font-size: 0.76rem;
}

/* ===== Busca ===== */
.search-wrap {
  position: relative;
  margin-bottom: 14px;
}
.search-wrap input {
  padding-left: 42px;
  min-height: 48px;
}
.search-icon {
  position: absolute;
  left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted);
  pointer-events: none;
}
.search-icon :deep(svg) { width: 16px; height: 16px; }

.search-empty {
  text-align: center;
  padding: 32px 20px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px dashed var(--border);
  color: var(--muted);
}
.search-empty :deep(svg) { width: 24px; height: 24px; opacity: 0.5; }
.search-empty p { margin: 10px 0 0; font-size: 0.9rem; }
.search-empty strong { color: var(--text); }

/* ===== Lista de clientes ===== */
.cst-section { margin-top: 4px; }
.cst-list { display: flex; flex-direction: column; gap: 8px; }
.cst-row {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 14px;
  align-items: center;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, background 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.cst-row:hover {
  border-color: var(--brand);
  background: rgba(59, 130, 246, 0.04);
  transform: translateY(-1px);
  box-shadow: 0 0 20px var(--brand-soft);
}
.cst-row-avatar {
  width: 42px; height: 42px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-weight: 800; font-size: 0.92rem;
  box-shadow: 0 0 14px var(--brand-soft);
}
.cst-row-info { min-width: 0; }
.cst-row-name {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 2px;
}
.cst-row-name strong {
  font-size: 0.98rem; font-weight: 700;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.cst-row-contact {
  display: flex; flex-wrap: wrap; gap: 4px 14px;
  color: var(--muted); font-size: 0.82rem;
}
.cst-row-contact span { display: inline-flex; align-items: center; gap: 4px; }
.cst-row-contact :deep(svg) { width: 12px; height: 12px; color: var(--brand-ink); }

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
@media (max-width: 640px) {
  .ff-row { grid-template-columns: 1fr; }
  .cst-row {
    grid-template-columns: auto 1fr;
    gap: 10px;
  }
  .cst-row .btn {
    grid-column: 1 / -1;
    width: 100%;
    margin-top: 4px;
  }
  .history-row {
    grid-template-columns: 1fr auto;
  }
  .history-what { grid-column: 1 / -1; grid-row: 2; }
  .history-row .badge { grid-column: 2; grid-row: 1; }
  .detail-head { flex-wrap: wrap; }
  .detail-head .btn { margin-left: auto; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
