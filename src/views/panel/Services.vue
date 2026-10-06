<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const services = ref([])
const error = ref('')
const saved = ref('')
const empty = () => ({ id: null, name: '', description: '', price: 0, duration_min: 30, active: true })
const form = ref(empty())
const formEl = ref(null)

const activeCount = computed(() => services.value.filter((s) => s.active).length)

async function load() {
  services.value = unwrap(await supabase.from('services').select('*')
    .eq('business_id', biz.business.id).order('active', { ascending: false }).order('name'))
}
onMounted(load)

async function save() {
  error.value = ''
  const { id, ...fields } = form.value
  const payload = { ...fields, business_id: biz.business.id }
  if (id) {
    const { error: err } = await supabase.from('services').update(payload).eq('id', id)
    if (err) { error.value = err.message; return }
    saved.value = `${fields.name} salvo.`
  } else {
    const { data, error: err } = await supabase.from('services').insert(payload).select('id').single()
    if (err) { error.value = err.message; return }
    // Serviço novo já fica disponível com todos que atendem (dá para ajustar em Profissionais).
    const { data: pros } = await supabase.from('professionals').select('id').eq('business_id', biz.business.id).eq('active', true)
    if (pros?.length) {
      await supabase.from('professional_services')
        .insert(pros.map((p) => ({ business_id: biz.business.id, professional_id: p.id, service_id: data.id })))
    }
    saved.value = `${fields.name} adicionado.`
  }
  form.value = empty()
  load()
}

function edit(s) {
  const { id, name, description, price, duration_min, active } = s
  form.value = { id, name, description: description ?? '', price, duration_min, active }
  saved.value = ''
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function cancelEdit() {
  form.value = empty()
  saved.value = ''
}

async function toggleActive(s) {
  error.value = ''
  const { error: err } = await supabase.from('services').update({ active: !s.active }).eq('id', s.id)
  if (err) { error.value = err.message; return }
  saved.value = `${s.name} ${!s.active ? 'ativado' : 'desativado'}.`
  load()
}

async function remove(s) {
  if (!confirm(`Excluir o serviço "${s.name}"?`)) return
  error.value = ''
  const { error: err } = await supabase.from('services').delete().eq('id', s.id)
  if (err) {
    error.value = 'Este serviço já tem agendamentos. Desative-o em vez de excluir.'
    return
  }
  saved.value = `${s.name} excluído.`
  load()
}

function focusNew() {
  cancelEdit()
  formEl.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<template>
  <div class="page-header svc-header">
    <div>
      <p class="eyebrow svc-eyebrow">Catálogo</p>
      <h1>Serviços</h1>
      <p class="muted svc-lede">
        O que você oferece pros clientes agendarem. Nome, preço e duração aparecem na sua vitrine.
      </p>
    </div>
    <span v-if="services.length" class="svc-count">
      {{ plural(activeCount, 'ativo', 'ativos') }} · {{ plural(services.length, 'serviço', 'serviços') }} no total
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

  <form ref="formEl" class="svc-form" :class="{ editing: form.id }" @submit.prevent="save">
    <div class="section-head">
      <span class="section-badge"><Icon name="briefcase" /></span>
      <div>
        <h3>{{ form.id ? 'Editar serviço' : 'Novo serviço' }}</h3>
        <small class="muted">{{ form.id ? 'Alterações entram no ar imediatamente na sua vitrine.' : 'Preencha os dados — depois dá pra ajustar o que faz o quê em Profissionais.' }}</small>
      </div>
    </div>

    <div class="ff-row">
      <div class="ff ff-wide">
        <input id="svc-name" v-model="form.name" required placeholder=" " />
        <label for="svc-name">Nome</label>
      </div>
      <div class="ff">
        <input id="svc-price" v-model.number="form.price" type="number" min="0" step="0.01" required placeholder=" " />
        <label for="svc-price">Preço (R$)</label>
      </div>
      <div class="ff">
        <input id="svc-dur" v-model.number="form.duration_min" type="number" min="5" step="5" required placeholder=" " />
        <label for="svc-dur">Duração (min)</label>
      </div>
    </div>
    <div class="ff">
      <input id="svc-desc" v-model="form.description" placeholder=" " />
      <label for="svc-desc">Descrição (opcional)</label>
    </div>

    <div class="svc-form-foot">
      <label class="svc-toggle">
        <input v-model="form.active" type="checkbox" />
        <span>Ativo (aparece no agendamento)</span>
      </label>
      <div class="svc-form-actions">
        <button v-if="form.id" type="button" class="btn secondary" @click="cancelEdit">Cancelar</button>
        <button class="btn">
          <Icon :name="form.id ? 'check' : 'plus'" />
          {{ form.id ? 'Salvar' : 'Adicionar' }}
        </button>
      </div>
    </div>
  </form>

  <!-- Lista -->
  <section class="svc-section">
    <div v-if="!services.length" class="empty-state">
      <div class="empty-icon-wrap">
        <div class="empty-icon-ring" />
        <div class="empty-icon-core"><Icon name="briefcase" /></div>
      </div>
      <h3>Nenhum serviço cadastrado ainda</h3>
      <p class="muted">
        Cadastre seu primeiro serviço — é o que vai aparecer na sua vitrine pros clientes agendarem.
      </p>
      <button class="btn" @click="focusNew">
        <Icon name="plus" />
        Criar primeiro serviço
      </button>
    </div>

    <div v-else class="svc-grid-wrap">
      <article v-for="s in services" :key="s.id" class="svc-item" :class="{ off: !s.active }">
        <div class="svc-item-head">
          <div class="svc-item-info">
            <h4 class="svc-item-name">{{ s.name }}</h4>
            <p v-if="s.description" class="svc-item-desc muted">{{ s.description }}</p>
          </div>
          <span class="svc-item-price">{{ money(s.price) }}</span>
        </div>

        <div class="svc-item-meta">
          <span class="svc-pill">
            <Icon name="clock" />
            {{ s.duration_min }} min
          </span>
          <span class="svc-pill status" :class="{ on: s.active }">
            <span class="dot" />
            {{ s.active ? 'Ativo' : 'Inativo' }}
          </span>
        </div>

        <div class="svc-item-actions">
          <button class="btn small secondary" :title="s.active ? 'Desativar' : 'Ativar'"
                  :aria-label="s.active ? 'Desativar serviço' : 'Ativar serviço'"
                  @click="toggleActive(s)">
            <Icon :name="s.active ? 'ban' : 'check'" />
            {{ s.active ? 'Desativar' : 'Ativar' }}
          </button>
          <button class="btn small secondary" aria-label="Editar serviço" @click="edit(s)">
            <Icon name="pencil" />
            Editar
          </button>
          <button class="btn small secondary danger-btn" aria-label="Excluir serviço" @click="remove(s)">
            <Icon name="trash" />
            <span class="hide-sm">Excluir</span>
          </button>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
/* ===== Header ===== */
.svc-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.svc-eyebrow { display: inline-block; margin-bottom: 6px; }
.svc-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.svc-count {
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
.svc-form {
  padding: 22px;
  margin-bottom: 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: 0 0 24px rgba(59, 130, 246, 0.06);
  transition: box-shadow 0.2s ease, border-color 0.2s ease;
}
.svc-form.editing { border-color: var(--brand); box-shadow: 0 0 32px var(--brand-soft); }

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
  grid-template-columns: 2fr 1fr 1fr;
  gap: 10px;
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

.svc-form-foot {
  display: flex; align-items: center; justify-content: space-between;
  gap: 14px; flex-wrap: wrap;
  margin-top: 8px;
}
.svc-toggle {
  display: inline-flex; align-items: center; gap: 8px;
  color: var(--text); font-weight: 500; font-size: 0.92rem;
  margin: 0; cursor: pointer;
}
.svc-form-actions { display: flex; gap: 8px; flex-wrap: wrap; }
.svc-form-actions .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Lista ===== */
.svc-section { margin-top: 4px; }

.svc-grid-wrap {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 12px;
}
.svc-item {
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
.svc-item:hover { transform: translateY(-2px); border-color: var(--brand); box-shadow: 0 0 24px var(--brand-soft); }
.svc-item.off { opacity: 0.6; }

.svc-item-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 12px; margin-bottom: 10px;
}
.svc-item-info { min-width: 0; }
.svc-item-name {
  font-size: 1.05rem; font-weight: 800;
  letter-spacing: -0.01em;
  margin: 0 0 2px;
}
.svc-item-desc {
  margin: 0; font-size: 0.84rem; line-height: 1.4;
  overflow: hidden; display: -webkit-box;
  -webkit-line-clamp: 2; -webkit-box-orient: vertical;
}
.svc-item-price {
  font-size: 1.1rem; font-weight: 800; letter-spacing: -0.02em;
  color: var(--text);
  background: linear-gradient(120deg, var(--silver) 0%, #fff 35%, var(--brand-ink) 100%);
  -webkit-background-clip: text; background-clip: text;
  color: transparent;
  flex-shrink: 0;
}

.svc-item-meta {
  display: flex; flex-wrap: wrap; gap: 6px;
  margin-bottom: 14px;
}
.svc-pill {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 4px 10px; border-radius: 999px;
  background: var(--surface-strong); color: var(--silver);
  border: 1px solid var(--border);
  font-size: 0.75rem; font-weight: 600;
}
.svc-pill :deep(svg) { width: 12px; height: 12px; }
.svc-pill.status {
  background: var(--surface-strong); color: var(--muted);
  border-color: var(--border);
}
.svc-pill.status .dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 6px currentColor;
}
.svc-pill.status.on {
  background: var(--success-soft); color: var(--success);
  border-color: rgba(74, 222, 128, 0.3);
}

.svc-item-actions {
  display: flex; flex-wrap: wrap; gap: 6px;
  margin-top: auto;
}
.svc-item-actions .btn {
  min-height: 36px;
  padding: 7px 12px;
  font-size: 0.82rem;
}
.svc-item-actions .btn :deep(svg) { width: 14px; height: 14px; }
.svc-item-actions .danger-btn { color: var(--danger); }
.svc-item-actions .danger-btn:hover { border-color: var(--danger); color: var(--danger); }

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
  .ff-row { grid-template-columns: 1fr 1fr; }
  .ff-row .ff-wide { grid-column: 1 / -1; }
  .svc-form-foot { flex-direction: column; align-items: stretch; }
  .svc-form-actions { justify-content: stretch; }
  .svc-form-actions .btn { flex: 1; }
  .svc-grid-wrap { grid-template-columns: 1fr; }
  .svc-item-actions .btn { flex: 1; min-width: 0; }
  .svc-item-actions .hide-sm { display: none; }
}

@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
