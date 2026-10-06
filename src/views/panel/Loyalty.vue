<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDate, plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const program = ref({ active: false, stamps_required: 10, reward: '1 serviço grátis' })
const exists = ref(false)
const cards = ref([])
const search = ref('')
const newCard = ref({ phone: '', name: '' })
const error = ref('')
const msg = ref('')

const digits = (v) => (v ?? '').replace(/\D/g, '')
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return q ? cards.value.filter((c) => c.phone.includes(digits(q) || '§') || (c.name ?? '').toLowerCase().includes(q)) : cards.value
})
const stampsRequired = computed(() => Number(program.value.stamps_required) || 10)
const previewSlots = computed(() => Math.min(stampsRequired.value, 12))
const previewFilled = computed(() => Math.min(Math.round(previewSlots.value * 0.4), previewSlots.value))

function initials(name, phone) {
  if (name) {
    const parts = name.trim().split(/\s+/)
    return parts.length === 1 ? parts[0].slice(0, 2).toUpperCase() : (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
  }
  return (phone || '?').slice(-2)
}

async function load() {
  const bid = biz.business.id
  const p = unwrap(await supabase.from('loyalty_programs').select('*').eq('business_id', bid).maybeSingle())
  if (p) { program.value = p; exists.value = true }
  cards.value = unwrap(await supabase.from('loyalty_cards').select('*').eq('business_id', bid).order('updated_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('fidelidade')) load() })

async function saveProgram() {
  error.value = msg.value = ''
  const { active, stamps_required, reward } = program.value
  const { error: err } = await supabase.from('loyalty_programs')
    .upsert({ business_id: biz.business.id, active, stamps_required: Number(stamps_required), reward })
  if (err) { error.value = err.message; return }
  exists.value = true
  msg.value = active ? 'Programa ativo e na vitrine.' : 'Programa salvo (ainda não aparece na vitrine).'
}

async function toggleActive() {
  program.value.active = !program.value.active
  await saveProgram()
}

async function stamp(c, delta) {
  const stamps = Math.max(c.stamps + delta, 0)
  await supabase.from('loyalty_cards').update({ stamps, updated_at: new Date().toISOString() }).eq('id', c.id)
  load()
}

async function redeem(c) {
  if (!confirm(`Resgatar "${program.value.reward}" para ${c.name || c.phone}?`)) return
  await supabase.from('loyalty_cards').update({
    stamps: c.stamps - stampsRequired.value, rewards_redeemed: c.rewards_redeemed + 1, updated_at: new Date().toISOString(),
  }).eq('id', c.id)
  load()
}

async function addCard() {
  error.value = ''
  const phone = digits(newCard.value.phone)
  const existing = cards.value.find((c) => c.phone === phone)
  if (existing) { await stamp(existing, 1); newCard.value = { phone: '', name: '' }; msg.value = `+1 carimbo para ${existing.name || phone}.`; return }
  const { error: err } = await supabase.from('loyalty_cards')
    .insert({ business_id: biz.business.id, phone, name: newCard.value.name || null, stamps: 1 })
  if (err) { error.value = err.message.includes('phone') ? 'Telefone inválido.' : err.message; return }
  msg.value = `${newCard.value.name || phone} ganhou o 1º carimbo.`
  newCard.value = { phone: '', name: '' }
  load()
}
</script>

<template>
  <div class="page-header ly-header">
    <div>
      <p class="eyebrow ly-eyebrow">Retenção</p>
      <h1>Cartão fidelidade</h1>
      <p class="muted ly-lede">
        A cada atendimento concluído, o cliente ganha um carimbo. Completou o cartão, ganha o prêmio — e volta mais.
      </p>
    </div>
    <span v-if="exists && cards.length" class="ly-count">
      {{ plural(cards.length, 'cartão', 'cartões') }}
    </span>
  </div>
  <Upsell v-if="!biz.hasFeature('fidelidade')" feature="fidelidade" />

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span><span>{{ error }}</span>
    </div>
    <div v-if="msg" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span><span>{{ msg }}</span>
    </div>

    <!-- Aviso de inativo -->
    <div v-if="exists && !program.active" class="ly-inactive">
      <div class="ly-inactive-icon"><Icon name="ban" /></div>
      <div class="ly-inactive-info">
        <strong>Programa pausado</strong>
        <small>O cartão fidelidade ainda não aparece na sua vitrine pública. Ative pra começar a divulgar.</small>
      </div>
      <button type="button" class="btn small" @click="toggleActive">
        <Icon name="check" />
        Ativar agora
      </button>
    </div>

    <form class="ly-config" @submit.prevent="saveProgram">
      <div class="section-head">
        <span class="section-badge"><Icon name="gift" /></span>
        <div>
          <h3>Como funciona</h3>
          <small class="muted">Cada atendimento concluído dá 1 carimbo. Dá pra carimbar manualmente também.</small>
        </div>
      </div>

      <div class="ly-config-grid">
        <!-- Form -->
        <div class="ly-config-form">
          <div class="ff-row">
            <div class="ff">
              <input id="ly-stamps" v-model.number="program.stamps_required" type="number" min="2" max="50" required placeholder=" " />
              <label for="ly-stamps">Carimbos p/ ganhar</label>
            </div>
            <div class="ff ff-wide">
              <input id="ly-reward" v-model="program.reward" required maxlength="100" placeholder=" " />
              <label for="ly-reward">Prêmio</label>
            </div>
          </div>

          <label class="ly-toggle">
            <input v-model="program.active" type="checkbox" />
            <span class="ly-switch"><span class="ly-switch-dot" /></span>
            <span>
              <strong>Programa ativo</strong>
              <small class="muted">Aparece na sua vitrine pública</small>
            </span>
          </label>

          <div class="ly-config-foot">
            <button class="btn">
              <Icon name="check" />
              {{ exists ? 'Salvar' : 'Ativar fidelidade' }}
            </button>
          </div>
        </div>

        <!-- Preview do cartão -->
        <div class="ly-preview">
          <div class="ly-card">
            <div class="ly-card-head">
              <div class="ly-card-brand">
                <Icon name="gift" />
                <span>Cartão fidelidade</span>
              </div>
              <small>{{ biz.business.name }}</small>
            </div>
            <div class="ly-slots" :style="{ '--cols': previewSlots > 6 ? 6 : previewSlots }">
              <span v-for="i in previewSlots" :key="i" class="ly-slot" :class="{ filled: i <= previewFilled }">
                <Icon v-if="i <= previewFilled" name="check" />
                <span v-else class="ly-slot-num">{{ i }}</span>
              </span>
            </div>
            <div class="ly-card-foot">
              <div class="ly-progress">
                <div class="ly-progress-bar" :style="{ width: `${(previewFilled / previewSlots) * 100}%` }" />
              </div>
              <strong>{{ program.reward || 'Prêmio' }}</strong>
            </div>
          </div>
          <small class="muted ly-preview-note">Prévia · como seu cliente vai ver</small>
        </div>
      </div>
    </form>

    <template v-if="exists">
      <!-- Carimbar manualmente -->
      <form class="ly-config" @submit.prevent="addCard">
        <div class="section-head">
          <span class="section-badge"><Icon name="plus" /></span>
          <div>
            <h3>Carimbar manualmente</h3>
            <small class="muted">Pra cliente que chegou sem agendar. Se já tiver cartão, soma +1.</small>
          </div>
        </div>
        <div class="ff-row">
          <div class="ff">
            <input id="ly-new-phone" v-model="newCard.phone" type="tel" required placeholder=" " />
            <label for="ly-new-phone">WhatsApp</label>
          </div>
          <div class="ff ff-wide">
            <input id="ly-new-name" v-model="newCard.name" placeholder=" " />
            <label for="ly-new-name">Nome (opcional)</label>
          </div>
          <div class="ff ff-btn">
            <button class="btn">
              <Icon name="plus" />
              1 carimbo
            </button>
          </div>
        </div>
      </form>

      <!-- Lista de clientes -->
      <section class="ly-section">
        <div class="section-head">
          <span class="section-badge"><Icon name="users" /></span>
          <div>
            <h3>Clientes com cartão</h3>
            <small class="muted">Os que já começaram a carimbar.</small>
          </div>
        </div>

        <div v-if="!cards.length" class="empty-state">
          <div class="empty-icon-wrap">
            <div class="empty-icon-ring" />
            <div class="empty-icon-core"><Icon name="gift" /></div>
          </div>
          <h3>Nenhum cliente carimbou ainda</h3>
          <p class="muted">Divulgue o programa — assim que o primeiro atendimento for concluído, o cliente aparece aqui.</p>
        </div>

        <template v-else>
          <div class="search-wrap">
            <span class="search-icon"><Icon name="search" /></span>
            <input v-model="search" placeholder="Buscar por nome ou telefone" />
          </div>

          <div v-if="!filtered.length" class="search-empty">
            <Icon name="search" />
            <p>Nenhum cliente bate com "<strong>{{ search }}</strong>".</p>
          </div>

          <div v-else class="ly-grid">
            <article v-for="c in filtered" :key="c.id" class="ly-row" :class="{ ready: c.stamps >= stampsRequired }">
              <div class="ly-row-head">
                <div class="ly-avatar">{{ initials(c.name, c.phone) }}</div>
                <div class="ly-row-info">
                  <strong>{{ c.name || '—' }}</strong>
                  <small class="muted">{{ c.phone }} · {{ formatDate(c.updated_at, biz.business.timezone) }}</small>
                </div>
                <span v-if="c.rewards_redeemed" class="ly-badge-rewards" :title="`${c.rewards_redeemed} prêmios já resgatados`">
                  <Icon name="star" /> {{ c.rewards_redeemed }}
                </span>
              </div>

              <div class="ly-row-progress">
                <div class="ly-progress">
                  <div class="ly-progress-bar" :style="{ width: `${Math.min((c.stamps / stampsRequired) * 100, 100)}%` }" />
                </div>
                <strong class="ly-row-count" :class="{ ready: c.stamps >= stampsRequired }">
                  {{ c.stamps }} / {{ stampsRequired }}
                </strong>
              </div>

              <div class="ly-row-actions">
                <button class="btn small secondary" aria-label="Remover um carimbo" @click="stamp(c, -1)">
                  <Icon name="minus" />
                </button>
                <button class="btn small secondary" aria-label="Adicionar um carimbo" @click="stamp(c, 1)">
                  <Icon name="plus" />
                </button>
                <button class="btn small" :disabled="c.stamps < stampsRequired" @click="redeem(c)">
                  <Icon name="gift" />
                  Resgatar
                </button>
              </div>
            </article>
          </div>
        </template>
      </section>
    </template>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.ly-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.ly-eyebrow { display: inline-block; margin-bottom: 6px; }
.ly-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.ly-count {
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

/* ===== Inactive banner ===== */
.ly-inactive {
  display: flex; align-items: center; gap: 14px;
  padding: 14px 16px;
  margin-bottom: 16px;
  border-radius: var(--radius-sm);
  background: var(--warning-soft);
  border: 1px dashed rgba(251, 191, 36, 0.4);
}
.ly-inactive-icon {
  width: 36px; height: 36px; flex-shrink: 0;
  border-radius: 10px;
  background: rgba(251, 191, 36, 0.2); color: var(--warning);
  display: grid; place-items: center;
}
.ly-inactive-icon :deep(svg) { width: 16px; height: 16px; }
.ly-inactive-info { flex: 1; min-width: 0; }
.ly-inactive-info strong { display: block; font-size: 0.95rem; color: #fff; }
.ly-inactive-info small { display: block; font-size: 0.82rem; color: var(--silver); margin-top: 2px; }
.ly-inactive .btn :deep(svg) { width: 14px; height: 14px; }

/* ===== Config card ===== */
.ly-config, .ly-section {
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

/* ===== Config grid ===== */
.ly-config-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
  align-items: start;
}

/* ===== Floating labels ===== */
.ff-row {
  display: grid;
  grid-template-columns: 160px 1fr auto;
  gap: 10px;
  margin-bottom: 12px;
}
.ff { position: relative; margin: 0; }
.ff.ff-wide { grid-column: span 1; }
.ff.ff-btn { display: flex; align-items: stretch; }
.ff.ff-btn .btn { height: 56px; white-space: nowrap; }
.ff.ff-btn .btn :deep(svg) { width: 15px; height: 15px; }
.ff input {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
  width: 100%;
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

/* ===== Switch toggle ===== */
.ly-toggle {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  background: var(--input);
  border: 1px solid var(--border);
  cursor: pointer;
  margin: 0 0 12px;
}
.ly-toggle input { display: none; }
.ly-switch {
  position: relative;
  width: 42px; height: 24px; flex-shrink: 0;
  border-radius: 999px;
  background: var(--surface-strong);
  border: 1px solid var(--border);
  transition: background 0.2s ease, border-color 0.2s ease;
}
.ly-switch-dot {
  position: absolute; left: 2px; top: 2px;
  width: 18px; height: 18px; border-radius: 50%;
  background: var(--muted);
  transition: left 0.2s ease, background 0.2s ease;
}
.ly-toggle input:checked + .ly-switch {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent;
  box-shadow: 0 0 14px var(--brand-glow);
}
.ly-toggle input:checked + .ly-switch .ly-switch-dot {
  left: 20px; background: #fff;
}
.ly-toggle strong { display: block; font-size: 0.92rem; font-weight: 700; }
.ly-toggle small { display: block; font-size: 0.78rem; margin-top: 1px; }

.ly-config-foot { display: flex; justify-content: flex-end; margin-top: 4px; }
.ly-config-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Preview card ===== */
.ly-preview { display: flex; flex-direction: column; align-items: center; gap: 10px; }
.ly-card {
  width: 100%; max-width: 340px;
  padding: 18px;
  border-radius: 20px;
  background:
    radial-gradient(ellipse 220px 140px at 100% 0%, rgba(255, 255, 255, 0.08), transparent 70%),
    linear-gradient(140deg, var(--brand-strong), #0b1730);
  border: 1px solid rgba(148, 180, 220, 0.3);
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.45), 0 0 32px var(--brand-soft);
  color: #fff;
}
.ly-card-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  margin-bottom: 14px;
}
.ly-card-brand {
  display: inline-flex; align-items: center; gap: 7px;
  font-size: 0.72rem; font-weight: 700; letter-spacing: 0.1em;
  text-transform: uppercase; color: rgba(255, 255, 255, 0.85);
}
.ly-card-brand :deep(svg) { width: 14px; height: 14px; }
.ly-card-head small { font-size: 0.78rem; color: rgba(255, 255, 255, 0.7); text-align: right; max-width: 60%; }

.ly-slots {
  display: grid;
  grid-template-columns: repeat(var(--cols, 5), 1fr);
  gap: 6px;
  margin-bottom: 14px;
}
.ly-slot {
  aspect-ratio: 1;
  display: grid; place-items: center;
  border-radius: 10px;
  background: rgba(5, 11, 22, 0.4);
  border: 1px dashed rgba(255, 255, 255, 0.2);
  color: rgba(255, 255, 255, 0.3);
  font-weight: 700;
  transition: transform 0.2s ease;
}
.ly-slot.filled {
  background: #fff;
  color: var(--brand);
  border-style: solid;
  border-color: #fff;
  box-shadow: 0 0 12px rgba(255, 255, 255, 0.5);
  transform: scale(1.05);
}
.ly-slot :deep(svg) { width: 14px; height: 14px; stroke-width: 3; }
.ly-slot-num { font-size: 0.72rem; }

.ly-card-foot { display: flex; flex-direction: column; gap: 8px; }
.ly-card-foot strong {
  font-size: 0.92rem; font-weight: 700;
  color: #fff;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}

.ly-preview-note { font-size: 0.78rem; }

/* ===== Progress bar ===== */
.ly-progress {
  height: 6px; width: 100%;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.14);
  overflow: hidden;
}
.ly-progress-bar {
  height: 100%;
  background: linear-gradient(90deg, var(--brand) 0%, #fff 100%);
  border-radius: 999px;
  transition: width 0.3s ease;
}

/* ===== Search ===== */
.search-wrap { position: relative; margin-bottom: 14px; }
.search-wrap input { padding-left: 42px; min-height: 48px; }
.search-icon {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); pointer-events: none;
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

/* ===== Clientes grid ===== */
.ly-grid { display: flex; flex-direction: column; gap: 10px; }
.ly-row {
  padding: 14px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, background 0.15s ease, transform 0.15s ease, box-shadow 0.15s ease;
}
.ly-row:hover {
  border-color: var(--brand);
  transform: translateY(-1px);
  box-shadow: 0 0 20px var(--brand-soft);
}
.ly-row.ready {
  border-color: rgba(74, 222, 128, 0.4);
  background: rgba(74, 222, 128, 0.05);
}

.ly-row-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 12px;
}
.ly-avatar {
  width: 40px; height: 40px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-weight: 800; font-size: 0.9rem;
  box-shadow: 0 0 14px var(--brand-soft);
}
.ly-row-info { flex: 1; min-width: 0; }
.ly-row-info strong {
  display: block;
  font-size: 0.95rem; font-weight: 700;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.ly-row-info small { display: block; font-size: 0.8rem; margin-top: 2px; }
.ly-badge-rewards {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 4px 10px; border-radius: 999px;
  background: var(--warning-soft);
  color: var(--warning);
  border: 1px solid rgba(251, 191, 36, 0.3);
  font-size: 0.78rem; font-weight: 700;
}
.ly-badge-rewards :deep(svg) { width: 12px; height: 12px; fill: currentColor; }

.ly-row-progress {
  display: flex; align-items: center; gap: 10px;
  margin-bottom: 12px;
}
.ly-row-progress .ly-progress { flex: 1; background: var(--surface-strong); }
.ly-row-count {
  flex-shrink: 0; font-size: 0.85rem; font-weight: 700;
  color: var(--silver);
}
.ly-row-count.ready { color: var(--success); }

.ly-row-actions { display: flex; gap: 6px; flex-wrap: wrap; }
.ly-row-actions .btn { min-height: 36px; padding: 7px 12px; font-size: 0.82rem; }
.ly-row-actions .btn :deep(svg) { width: 13px; height: 13px; }

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

/* ===== Responsive ===== */
@media (max-width: 820px) {
  .ly-config-grid { grid-template-columns: 1fr; }
  .ly-preview { order: -1; }
}
@media (max-width: 640px) {
  .ff-row { grid-template-columns: 1fr; }
  .ff.ff-btn .btn { width: 100%; }
  .ly-inactive { flex-wrap: wrap; }
  .ly-inactive .btn { flex: 1; }
  .ly-row-actions .btn { flex: 1; min-width: 0; justify-content: center; }
  .ly-slots { grid-template-columns: repeat(5, 1fr) !important; }
}
@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring { animation: none; }
}
</style>
