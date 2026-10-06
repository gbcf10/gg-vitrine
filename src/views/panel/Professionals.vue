<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const professionals = ref([])
const services = ref([])
const error = ref('')
const saved = ref('')
// Profissional novo já vem com todos os serviços marcados (o caso mais comum).
const empty = () => ({ id: null, name: '', phone: '', email: '', active: true, service_ids: services.value.map((s) => s.id) })
const form = ref(empty())
const formEl = ref(null)

const label = computed(() => biz.business.staff_label || 'Profissional')
const labelLow = computed(() => label.value.toLowerCase())
const title = computed(() => label.value === 'Profissional' ? 'Profissionais' : `${label.value}s`)
const limit = computed(() => biz.plan?.max_professionals)
const activeCount = computed(() => professionals.value.filter((p) => p.active).length)

async function load() {
  const bid = biz.business.id
  services.value = unwrap(await supabase.from('services').select('id, name').eq('business_id', bid).order('name'))
  const rows = unwrap(await supabase.from('professionals')
    .select('*, professional_services(service_id)').eq('business_id', bid).order('name'))
  professionals.value = rows.map((p) => ({ ...p, service_ids: p.professional_services.map((x) => x.service_id) }))
  if (!form.value.id && !form.value.name) form.value = empty()
}
onMounted(load)

async function save() {
  error.value = ''
  const bid = biz.business.id
  const { id, name, active, service_ids } = form.value
  const phone = form.value.phone || null
  const email = form.value.email || null
  try {
    let profId = id
    if (id) {
      unwrap(await supabase.from('professionals').update({ name, active, phone, email }).eq('id', id))
    } else {
      profId = unwrap(await supabase.from('professionals')
        .insert({ business_id: bid, name, active, phone, email }).select('id').single()).id
    }
    // Sincroniza os serviços que o profissional atende.
    unwrap(await supabase.from('professional_services').delete().eq('professional_id', profId))
    if (service_ids.length) {
      unwrap(await supabase.from('professional_services')
        .insert(service_ids.map((service_id) => ({ business_id: bid, professional_id: profId, service_id }))))
    }
    saved.value = `${name} salvo.`
    form.value = empty()
  } catch (e) {
    error.value = e.message
  }
  load()
}

function edit(p) {
  form.value = { id: p.id, name: p.name, phone: p.phone ?? '', email: p.email ?? '', active: p.active, service_ids: [...p.service_ids] }
  saved.value = ''
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function cancelEdit() {
  form.value = empty()
  saved.value = ''
}

function focusNew() {
  cancelEdit()
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

// Liga com um clique a todos os serviços cadastrados.
async function linkAll(p) {
  error.value = ''
  const bid = biz.business.id
  const rows = services.value.filter((s) => !p.service_ids.includes(s.id))
    .map((s) => ({ business_id: bid, professional_id: p.id, service_id: s.id }))
  const { error: err } = await supabase.from('professional_services').insert(rows)
  if (err) error.value = err.message
  else saved.value = `${p.name} agora faz todos os serviços.`
  load()
}

function initials(name) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

function serviceNames(ids) {
  return services.value.filter((s) => ids.includes(s.id)).map((s) => s.name)
}
</script>

<template>
  <div class="page-header pro-header">
    <div>
      <p class="eyebrow pro-eyebrow">Equipe</p>
      <h1>{{ title }}</h1>
      <p class="muted pro-lede">
        Quem (ou o quê) atende os clientes. Cada {{ labelLow }} tem seus próprios serviços e horário.
      </p>
    </div>
    <span v-if="professionals.length" class="pro-count">
      {{ plural(activeCount, 'ativo', 'ativos') }}{{ limit ? ` de ${limit} do seu plano` : '' }}
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

  <form ref="formEl" class="pro-form" :class="{ editing: form.id }" @submit.prevent="save">
    <div class="section-head">
      <span class="section-badge"><Icon name="user" /></span>
      <div>
        <h3>{{ form.id ? `Editar ${labelLow}` : `Adicionar ${labelLow}` }}</h3>
        <small class="muted">WhatsApp e e-mail são usados pelos lembretes automáticos quando ativados.</small>
      </div>
    </div>

    <div class="ff-row">
      <div class="ff">
        <input id="pro-name" v-model="form.name" required placeholder=" " />
        <label for="pro-name">Nome</label>
      </div>
      <div class="ff">
        <input id="pro-phone" v-model="form.phone" type="tel" placeholder=" " />
        <label for="pro-phone">WhatsApp (opcional)</label>
      </div>
      <div class="ff">
        <input id="pro-email" v-model="form.email" type="email" placeholder=" " />
        <label for="pro-email">E-mail (opcional)</label>
      </div>
    </div>

    <div class="field">
      <label class="field-label">Serviços que faz <small>(clique para marcar ou desmarcar)</small></label>
      <p v-if="!services.length" class="muted small">Cadastre os serviços primeiro.</p>
      <div v-else class="chips">
        <label v-for="s in services" :key="s.id" class="chip" :class="{ selected: form.service_ids.includes(s.id) }">
          <input v-model="form.service_ids" type="checkbox" :value="s.id" style="display: none" />{{ s.name }}
        </label>
      </div>
    </div>

    <div class="pro-form-foot">
      <label class="pro-toggle">
        <input v-model="form.active" type="checkbox" />
        <span>Ativo</span>
      </label>
      <div class="pro-form-actions">
        <button v-if="form.id" type="button" class="btn secondary" @click="cancelEdit">Cancelar</button>
        <button class="btn">
          <Icon :name="form.id ? 'check' : 'plus'" />
          {{ form.id ? 'Salvar' : 'Adicionar' }}
        </button>
      </div>
    </div>
  </form>

  <section class="pro-section">
    <div v-if="!professionals.length" class="empty-state">
      <div class="empty-icon-wrap">
        <div class="empty-icon-ring" />
        <div class="empty-icon-core"><Icon name="users" /></div>
      </div>
      <h3>Cadastre {{ label === 'Profissional' ? 'o primeiro profissional' : `a primeira ${labelLow}` }}</h3>
      <p class="muted">
        Pode ser você, uma quadra, uma sala, uma mesa... depende do seu negócio. Cada {{ labelLow }} tem agenda e horário próprios.
      </p>
      <button class="btn" @click="focusNew">
        <Icon name="plus" />
        Começar agora
      </button>
    </div>

    <div v-else class="pro-grid">
      <article v-for="p in professionals" :key="p.id" class="pro-card" :class="{ off: !p.active }">
        <div class="pro-card-head">
          <div class="pro-avatar-big">
            <img v-if="p.photo_url" :src="p.photo_url" :alt="p.name" />
            <span v-else>{{ initials(p.name) }}</span>
          </div>
          <div class="pro-card-info">
            <h4 class="pro-name">{{ p.name }}</h4>
            <div class="pro-contact">
              <span v-if="p.phone" class="pro-contact-item">
                <Icon name="phone" />
                {{ p.phone }}
              </span>
              <span v-if="p.email" class="pro-contact-item">
                <Icon name="mail" />
                {{ p.email }}
              </span>
            </div>
            <span class="pro-status" :class="{ on: p.active }">
              <span class="dot" />
              {{ p.active ? 'Ativo' : 'Inativo' }}
            </span>
          </div>
        </div>

        <div class="pro-services">
          <template v-if="!p.service_ids.length">
            <div class="pro-services-empty">
              <span class="badge yellow">Nenhum serviço</span>
              <button v-if="services.length" type="button" class="link-btn pro-link-all" @click="linkAll(p)">
                Ligar a todos
              </button>
            </div>
          </template>
          <template v-else>
            <small class="pro-services-label">Faz</small>
            <div class="pro-chips">
              <span v-for="name in serviceNames(p.service_ids)" :key="name" class="pro-chip-tag">{{ name }}</span>
            </div>
          </template>
        </div>

        <div class="pro-actions">
          <button class="btn small secondary" aria-label="Editar cadastro" @click="edit(p)">
            <Icon name="pencil" />
            Editar
          </button>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
/* ===== Header ===== */
.pro-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.pro-eyebrow { display: inline-block; margin-bottom: 6px; }
.pro-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.pro-count {
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

/* ===== Form ===== */
.pro-form {
  padding: 22px;
  margin-bottom: 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.pro-form.editing { border-color: var(--brand); box-shadow: 0 0 32px var(--brand-soft); }

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

.ff-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 8px;
}
.ff { position: relative; margin: 0 0 12px; }
.ff input {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
}
.ff label {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); margin: 0; pointer-events: none;
  transition: top 0.15s ease, font-size 0.15s ease, color 0.15s ease, transform 0.15s ease;
  font-weight: 500;
}
.ff input:focus + label,
.ff input:not(:placeholder-shown) + label {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}

.field-label { display: block; font-size: 0.85rem; font-weight: 600; margin-bottom: 8px; color: var(--silver); }
.field-label small { color: var(--muted); font-weight: 400; margin-left: 4px; }
.small { font-size: 0.84rem; }

.pro-form-foot {
  display: flex; align-items: center; justify-content: space-between;
  gap: 14px; flex-wrap: wrap;
  margin-top: 10px;
}
.pro-toggle {
  display: inline-flex; align-items: center; gap: 8px;
  color: var(--text); font-weight: 500; font-size: 0.92rem;
  margin: 0; cursor: pointer;
}
.pro-form-actions { display: flex; gap: 8px; flex-wrap: wrap; }
.pro-form-actions .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Lista ===== */
.pro-section { margin-top: 4px; }

.pro-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 14px;
}
.pro-card {
  position: relative;
  display: flex; flex-direction: column;
  padding: 18px;
  border-radius: var(--radius);
  background: var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  transition: transform 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
}
.pro-card:hover { transform: translateY(-2px); border-color: var(--brand); box-shadow: 0 0 24px var(--brand-soft); }
.pro-card.off { opacity: 0.6; }

.pro-card-head {
  display: flex; align-items: flex-start; gap: 14px;
  margin-bottom: 14px;
}
.pro-avatar-big {
  width: 56px; height: 56px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-weight: 800; font-size: 1.15rem;
  box-shadow: 0 0 20px var(--brand-glow);
  overflow: hidden;
  border: 2px solid rgba(255, 255, 255, 0.08);
}
.pro-avatar-big img { width: 100%; height: 100%; object-fit: cover; }
.pro-card-info { min-width: 0; flex: 1; }
.pro-name {
  font-size: 1.05rem; font-weight: 800;
  letter-spacing: -0.01em;
  margin: 0 0 4px;
}
.pro-contact {
  display: flex; flex-wrap: wrap; gap: 2px 10px;
  margin-bottom: 6px;
}
.pro-contact-item {
  display: inline-flex; align-items: center; gap: 4px;
  color: var(--muted); font-size: 0.78rem;
}
.pro-contact-item :deep(svg) { width: 11px; height: 11px; color: var(--brand-ink); }

.pro-status {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 2px 10px; border-radius: 999px;
  background: var(--surface-strong); color: var(--muted);
  border: 1px solid var(--border);
  font-size: 0.7rem; font-weight: 700;
  letter-spacing: 0.03em;
}
.pro-status .dot {
  width: 5px; height: 5px; border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 6px currentColor;
}
.pro-status.on {
  background: var(--success-soft); color: var(--success);
  border-color: rgba(74, 222, 128, 0.3);
}

.pro-services {
  flex: 1;
  margin-bottom: 12px;
  padding: 12px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.pro-services-label {
  display: block;
  font-size: 0.68rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.1em; font-weight: 700;
  margin-bottom: 8px;
}
.pro-chips { display: flex; flex-wrap: wrap; gap: 5px; }
.pro-chip-tag {
  display: inline-flex; align-items: center;
  padding: 3px 10px; border-radius: 999px;
  background: var(--brand-soft); color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
  font-size: 0.74rem; font-weight: 600;
}
.pro-services-empty {
  display: flex; align-items: center; gap: 10px;
  flex-wrap: wrap;
}
.pro-link-all { font-size: 0.82rem; font-weight: 600; }

.pro-actions {
  display: flex; gap: 6px; margin-top: auto;
}
.pro-actions .btn { flex: 1; min-height: 36px; padding: 7px 12px; font-size: 0.82rem; }
.pro-actions .btn :deep(svg) { width: 14px; height: 14px; }

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
  .pro-form-foot { flex-direction: column; align-items: stretch; }
  .pro-form-actions { justify-content: stretch; }
  .pro-form-actions .btn { flex: 1; }
  .pro-grid { grid-template-columns: 1fr; }
  .pro-avatar-big { width: 48px; height: 48px; font-size: 1rem; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
