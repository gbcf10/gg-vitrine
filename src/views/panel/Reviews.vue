<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime, plural } from '@/lib/format'
import Stars from '@/components/public/Stars.vue'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const reviews = ref([])
const filter = ref('pending')
const error = ref('')
const msg = ref('')

const STATUS = { pending: 'Aguardando', approved: 'Publicadas', hidden: 'Ocultas' }
const visible = computed(() => reviews.value.filter((r) => r.status === filter.value))
const approved = computed(() => reviews.value.filter((r) => r.status === 'approved'))
const avg = computed(() => {
  const ok = approved.value
  return ok.length ? (ok.reduce((s, r) => s + r.rating, 0) / ok.length) : 0
})
const avgLabel = computed(() => (avg.value ? avg.value.toFixed(1).replace('.', ',') : '–'))
const pendingCount = computed(() => reviews.value.filter((r) => r.status === 'pending').length)

function initials(name) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

async function load() {
  reviews.value = unwrap(await supabase.from('reviews').select('*')
    .eq('business_id', biz.business.id).order('created_at', { ascending: false }))
  if (!reviews.value.some((r) => r.status === 'pending') && filter.value === 'pending') filter.value = 'approved'
}
onMounted(() => { if (biz.hasFeature('avaliacoes')) load() })

async function update(r, patch) {
  const { error: err } = await supabase.from('reviews').update(patch).eq('id', r.id)
  if (err) { error.value = err.message; return }
  if (patch.status === 'approved') msg.value = 'Avaliação publicada na vitrine.'
  else if (patch.status === 'hidden') msg.value = 'Avaliação ocultada.'
  else if ('reply' in patch) msg.value = 'Resposta salva.'
  load()
}
async function remove(r) {
  if (!confirm('Excluir esta avaliação?')) return
  await supabase.from('reviews').delete().eq('id', r.id)
  msg.value = 'Avaliação excluída.'
  load()
}
</script>

<template>
  <div class="page-header rv-header">
    <div>
      <p class="eyebrow rv-eyebrow">Reputação</p>
      <h1>Avaliações</h1>
      <p class="muted rv-lede">
        Seus clientes avaliam pela vitrine. Nada aparece pro público antes de você aprovar.
      </p>
    </div>
    <div v-if="biz.hasFeature('avaliacoes') && approved.length" class="rv-stat">
      <div class="rv-stat-value">
        <strong>{{ avgLabel }}</strong>
        <Stars :value="avg" />
      </div>
      <small>{{ plural(approved.length, 'avaliação publicada', 'avaliações publicadas') }}</small>
    </div>
  </div>
  <Upsell v-if="!biz.hasFeature('avaliacoes')" feature="avaliacoes" />

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span><span>{{ error }}</span>
    </div>
    <div v-if="msg" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span><span>{{ msg }}</span>
    </div>

    <div v-if="pendingCount && filter !== 'pending'" class="rv-notice">
      <Icon name="bell" />
      <span><strong>{{ pendingCount }} {{ pendingCount === 1 ? 'avaliação aguardando' : 'avaliações aguardando' }}</strong> aprovação.</span>
      <button type="button" class="btn small secondary" @click="filter = 'pending'">Revisar</button>
    </div>

    <!-- Filtros por status -->
    <div class="rv-filters" role="tablist">
      <button v-for="(label, key) in STATUS" :key="key"
              role="tab" :aria-selected="filter === key"
              class="rv-filter" :class="{ active: filter === key }"
              @click="filter = key">
        <span>{{ label }}</span>
        <span class="rv-filter-count">{{ reviews.filter((r) => r.status === key).length }}</span>
      </button>
    </div>

    <!-- Reviews -->
    <section class="rv-section">
      <div v-if="!reviews.length" class="empty-state">
        <div class="empty-icon-wrap">
          <div class="empty-icon-ring" />
          <div class="empty-icon-core"><Icon name="star" /></div>
        </div>
        <h3>Ainda sem avaliações</h3>
        <p class="muted">
          Depois de cada atendimento concluído, o cliente recebe o link pra avaliar. Peça feedback nos primeiros dias — as primeiras estrelas puxam as próximas.
        </p>
      </div>

      <div v-else-if="!visible.length" class="empty-state subtle">
        <div class="empty-icon-core small"><Icon name="search" /></div>
        <h3>Nenhuma em "{{ STATUS[filter] }}"</h3>
        <p class="muted">Troque o filtro acima pra ver outras avaliações.</p>
      </div>

      <div v-else class="rv-list">
        <article v-for="r in visible" :key="r.id" class="rv-card" :class="r.status">
          <div class="rv-card-head">
            <div class="rv-avatar">{{ initials(r.author_name) }}</div>
            <div class="rv-head-info">
              <strong>{{ r.author_name }}</strong>
              <small class="muted">{{ formatDateTime(r.created_at, biz.business.timezone) }}</small>
            </div>
            <div class="rv-head-stars">
              <Stars :value="r.rating" />
              <span class="rv-rating-num">{{ r.rating }}</span>
            </div>
          </div>

          <p v-if="r.comment" class="rv-comment">{{ r.comment }}</p>
          <p v-else class="rv-comment-empty muted">Sem comentário.</p>

          <!-- Resposta do dono -->
          <div class="rv-reply">
            <div class="rv-reply-head">
              <Icon name="whatsapp" />
              <span>Sua resposta pública</span>
            </div>
            <input class="rv-reply-input" :value="r.reply"
                   placeholder="Agradeça, se desculpe ou convide o cliente de volta — fica visível pra todos."
                   maxlength="500"
                   @change="update(r, { reply: $event.target.value || null })" />
          </div>

          <div class="rv-actions">
            <button v-if="r.status !== 'approved'" class="btn small" @click="update(r, { status: 'approved' })">
              <Icon name="check" />
              Publicar
            </button>
            <button v-if="r.status !== 'hidden'" class="btn small secondary" @click="update(r, { status: 'hidden' })">
              <Icon name="ban" />
              Ocultar
            </button>
            <button v-if="r.status === 'hidden'" class="btn small secondary" @click="update(r, { status: 'pending' })">
              <Icon name="clock" />
              Voltar p/ fila
            </button>
            <button class="btn small secondary danger-btn" aria-label="Excluir avaliação" @click="remove(r)">
              <Icon name="trash" />
              <span class="hide-sm">Excluir</span>
            </button>
          </div>
        </article>
      </div>
    </section>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.rv-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.rv-eyebrow { display: inline-block; margin-bottom: 6px; }
.rv-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }

.rv-stat {
  padding: 14px 20px;
  border-radius: var(--radius-sm);
  background:
    radial-gradient(ellipse 160px 100px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  text-align: right;
  min-width: 160px;
}
.rv-stat-value {
  display: inline-flex; align-items: center; gap: 10px;
}
.rv-stat-value strong {
  font-size: 1.6rem; font-weight: 900;
  letter-spacing: -0.02em;
  background: linear-gradient(120deg, #fff 0%, var(--warning) 100%);
  -webkit-background-clip: text; background-clip: text;
  color: transparent;
}
.rv-stat small { display: block; font-size: 0.78rem; color: var(--muted); margin-top: 2px; }

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

/* ===== Notice ===== */
.rv-notice {
  display: flex; align-items: center; gap: 10px;
  padding: 12px 14px;
  margin-bottom: 16px;
  border-radius: var(--radius-sm);
  background: var(--brand-soft);
  border: 1px solid var(--border);
  color: var(--text);
  font-size: 0.9rem;
}
.rv-notice :deep(svg) { width: 15px; height: 15px; color: var(--brand-ink); flex-shrink: 0; }
.rv-notice span { flex: 1; }
.rv-notice strong { color: #fff; }

/* ===== Filtros ===== */
.rv-filters {
  display: flex; gap: 6px;
  padding: 4px;
  border-radius: 14px;
  background: var(--input);
  border: 1px solid var(--border);
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.rv-filter {
  flex: 1; min-width: 100px;
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  padding: 10px 14px; min-height: 44px;
  background: transparent; border: 1px solid transparent;
  border-radius: 10px;
  color: var(--muted); font-weight: 600; font-size: 0.9rem;
  cursor: pointer;
  transition: color 0.15s ease, background 0.15s ease, border-color 0.15s ease;
}
.rv-filter:hover { color: var(--text); }
.rv-filter.active {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff; border-color: transparent;
  box-shadow: 0 0 14px var(--brand-glow);
}
.rv-filter-count {
  min-width: 20px; padding: 1px 6px;
  border-radius: 999px;
  background: var(--surface-strong);
  color: var(--silver);
  font-size: 0.72rem; font-weight: 700;
}
.rv-filter.active .rv-filter-count { background: rgba(255, 255, 255, 0.22); color: #fff; }

/* ===== Section ===== */
.rv-section { margin-top: 4px; }

/* ===== Review card ===== */
.rv-list { display: flex; flex-direction: column; gap: 12px; }
.rv-card {
  padding: 18px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  transition: border-color 0.2s ease, box-shadow 0.2s ease, transform 0.2s ease;
}
.rv-card:hover { transform: translateY(-2px); border-color: var(--brand); box-shadow: 0 0 24px var(--brand-soft); }
.rv-card.pending { border-color: rgba(251, 191, 36, 0.35); }
.rv-card.hidden { opacity: 0.72; }

.rv-card-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 12px;
}
.rv-avatar {
  width: 44px; height: 44px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-weight: 800; font-size: 0.95rem;
  box-shadow: 0 0 14px var(--brand-soft);
}
.rv-head-info { flex: 1; min-width: 0; }
.rv-head-info strong {
  display: block;
  font-size: 1rem; font-weight: 700;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.rv-head-info small { display: block; font-size: 0.78rem; margin-top: 2px; }
.rv-head-stars {
  display: inline-flex; align-items: center; gap: 8px;
  flex-shrink: 0;
}
.rv-rating-num {
  padding: 3px 8px; border-radius: 999px;
  background: var(--warning-soft);
  color: var(--warning);
  border: 1px solid rgba(251, 191, 36, 0.3);
  font-size: 0.78rem; font-weight: 700;
}

.rv-comment {
  margin: 0 0 14px;
  padding: 12px 14px;
  border-left: 3px solid var(--brand);
  background: rgba(5, 11, 22, 0.4);
  border-radius: 0 10px 10px 0;
  font-size: 0.94rem; line-height: 1.5;
  color: var(--text);
}
.rv-comment-empty {
  margin: 0 0 14px;
  font-style: italic;
  font-size: 0.88rem;
}

/* Reply */
.rv-reply { margin: 0 0 14px; }
.rv-reply-head {
  display: flex; align-items: center; gap: 8px;
  margin-bottom: 8px;
  color: var(--muted); font-size: 0.75rem; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.08em;
}
.rv-reply-head :deep(svg) { width: 13px; height: 13px; color: #25D366; }
.rv-reply-input {
  width: 100%;
  padding: 10px 14px;
  min-height: 44px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  font-size: 0.9rem; line-height: 1.4;
  color: var(--text);
}
.rv-reply-input:focus { outline: 2px solid var(--brand); outline-offset: 1px; }
.rv-reply-input::placeholder { color: var(--muted); font-style: italic; font-size: 0.86rem; }

.rv-actions { display: flex; flex-wrap: wrap; gap: 6px; }
.rv-actions .btn { min-height: 36px; padding: 7px 12px; font-size: 0.82rem; }
.rv-actions .btn :deep(svg) { width: 14px; height: 14px; }
.rv-actions .danger-btn { color: var(--danger); }
.rv-actions .danger-btn:hover { border-color: var(--danger); color: var(--danger); }

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
.empty-state.subtle { padding: 32px 20px; }
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
.empty-icon-core.small {
  position: static; inset: auto;
  width: 56px; height: 56px;
  margin: 0 auto 14px;
  box-shadow: 0 0 20px var(--brand-soft);
}
.empty-icon-core :deep(svg) { width: 26px; height: 26px; }
.empty-icon-core.small :deep(svg) { width: 20px; height: 20px; }
.empty-state h3 { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 8px; }
.empty-state p { margin: 0 auto; max-width: 420px; font-size: 0.92rem; line-height: 1.5; }

.hide-sm { display: inline; }

/* ===== Responsive ===== */
@media (max-width: 640px) {
  .rv-stat { width: 100%; text-align: left; }
  .rv-filter { flex: 1 1 calc(50% - 4px); min-width: 0; font-size: 0.82rem; }
  .rv-card-head { flex-wrap: wrap; }
  .rv-head-stars { width: 100%; justify-content: flex-start; margin-top: 4px; }
  .rv-actions .btn { flex: 1; min-width: 0; justify-content: center; }
  .hide-sm { display: none; }
}
@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
