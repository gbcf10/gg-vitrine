<script setup>
// Onboarding em 4 passos. Aparece pra quem acabou de assinar e ainda tem
// onboarding_done = false. O PanelLayout nos redireciona pra /painel/comecar
// e aqui a gente pré-carrega serviços e horários típicos do segmento
// pra pessoa não precisar começar do zero. Ao final, grava tudo no banco
// e marca o onboarding como concluído.
import { ref, computed, reactive, nextTick, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { session } from '@/lib/session'
import { WEEKDAYS } from '@/lib/format'
import { CATEGORIES } from '@/config/brand'
import { templateFor } from '@/lib/onboarding-templates'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'

const router = useRouter()
const biz = useBusiness()

const WD_SHORT = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB']

// =====================================================================
// Estado
// =====================================================================
const step = ref(1)
const direction = ref(1) // 1 = indo pra frente, -1 = voltando (p/ transição)
const saving = ref(false)
const error = ref('')
const skipConfirm = ref(false)

// Passo 1 — segmento
const category = ref(biz.business?.category || CATEGORIES[0])
const editingCategory = ref(false)

const currentTemplate = computed(() => templateFor(category.value))
const hasTemplate = computed(() => {
  const t = templateFor(category.value)
  return (t.services?.length ?? 0) > 0
})

// Passo 2 — serviços
const services = ref([])

// Passo 3 — horários (0=domingo .. 6=sábado)
const days = ref([])

// Passo 4 — primeiro profissional
const pro = reactive({ name: '', photo_url: '' })
const staffLabel = ref('Profissional')

// =====================================================================
// Preenchimento inicial via template
// =====================================================================
function applyTemplate(cat) {
  const t = templateFor(cat)
  staffLabel.value = t.staff_label || 'Profissional'
  services.value = (t.services || []).map((s) => ({ ...s }))
  const base = WEEKDAYS.map((_, weekday) => ({ weekday, open: false, start: '09:00', end: '18:00' }))
  for (const h of (t.hours || [])) {
    const d = base.find((b) => b.weekday === h.weekday)
    if (d) { d.open = true; d.start = h.start; d.end = h.end }
  }
  days.value = base
}

onMounted(() => {
  category.value = biz.business?.category || CATEGORIES[0]
  applyTemplate(category.value)
  // Nome do dono vem do metadata do auth se tiver.
  const meta = session.user?.user_metadata || {}
  pro.name = meta.full_name || meta.name || ''
})

// =====================================================================
// Navegação entre passos
// =====================================================================
const totalSteps = 4
const stepLabels = ['Segmento', 'Serviços', 'Horários', computed(() => staffLabel.value)]

const canAdvance = computed(() => {
  if (step.value === 1) return !!category.value
  if (step.value === 2) return services.value.length > 0 && services.value.every((s) =>
    (s.name ?? '').trim().length > 0 && Number(s.duration_min) >= 5)
  if (step.value === 3) return days.value.some((d) => d.open) && days.value.every((d) => !d.open || d.end > d.start)
  if (step.value === 4) return (pro.name ?? '').trim().length > 0
  return false
})

function goto(n) {
  if (saving.value) return
  direction.value = n > step.value ? 1 : -1
  step.value = n
  error.value = ''
}

function next() {
  if (!canAdvance.value) return
  if (step.value < totalSteps) goto(step.value + 1)
  else finish()
}
function back() {
  if (step.value > 1) goto(step.value - 1)
}

// =====================================================================
// Passo 1 — segmento
// =====================================================================
function changeCategory(newCat) {
  category.value = newCat
  applyTemplate(newCat)
  editingCategory.value = false
}

// =====================================================================
// Passo 2 — serviços
// =====================================================================
function addService() {
  services.value.push({ name: '', duration_min: 30, price: 0 })
  nextTick(() => {
    const inputs = document.querySelectorAll('.svc-row input[data-field="name"]')
    inputs[inputs.length - 1]?.focus()
  })
}
function removeService(i) {
  services.value.splice(i, 1)
}

// =====================================================================
// Passo 3 — horários
// =====================================================================
function toggleDay(d) {
  d.open = !d.open
}

// =====================================================================
// Finalização: grava tudo e marca onboarding_done = true
// =====================================================================
async function finish() {
  if (saving.value) return
  if (!canAdvance.value) return
  saving.value = true
  error.value = ''
  const bid = biz.business.id
  try {
    // 1) Atualiza categoria e staff_label se necessário.
    const bizPatch = {}
    if (category.value && category.value !== biz.business.category) bizPatch.category = category.value
    if (staffLabel.value && staffLabel.value !== biz.business.staff_label) bizPatch.staff_label = staffLabel.value
    if (Object.keys(bizPatch).length) {
      unwrap(await supabase.from('businesses').update(bizPatch).eq('id', bid))
    }

    // 2) Insere o profissional (FK dos horários depende dele).
    const proRow = { business_id: bid, name: pro.name.trim(), active: true }
    if (pro.photo_url?.trim()) proRow.photo_url = pro.photo_url.trim()
    const proInserted = unwrap(await supabase.from('professionals').insert(proRow).select('id').single())
    const professional_id = proInserted.id

    // 3) Insere serviços e vincula ao profissional recém-criado.
    const svcRows = services.value.map((s) => ({
      business_id: bid,
      name: (s.name || '').trim(),
      price: Number(s.price) || 0,
      duration_min: Math.max(5, Number(s.duration_min) || 30),
      active: true,
    }))
    let svcInserted = []
    if (svcRows.length) {
      svcInserted = unwrap(await supabase.from('services').insert(svcRows).select('id'))
      const links = svcInserted.map((s) => ({ business_id: bid, professional_id, service_id: s.id }))
      if (links.length) unwrap(await supabase.from('professional_services').insert(links))
    }

    // 4) Horários do profissional.
    const hourRows = days.value
      .filter((d) => d.open && d.end > d.start)
      .map((d) => ({
        business_id: bid,
        professional_id,
        weekday: d.weekday,
        start_time: d.start,
        end_time: d.end,
      }))
    if (hourRows.length) unwrap(await supabase.from('working_hours').insert(hourRows))

    // 5) Marca o onboarding como concluído.
    unwrap(await supabase.from('businesses').update({ onboarding_done: true }).eq('id', bid))

    await biz.reload()
    router.replace('/painel')
  } catch (e) {
    error.value = e.message || 'Não deu pra concluir agora. Tente de novo em um instante.'
  } finally {
    saving.value = false
  }
}

// Pular por enquanto: marca done mas sem popular nada.
async function skipNow() {
  if (saving.value) return
  if (!skipConfirm.value) { skipConfirm.value = true; return }
  saving.value = true
  error.value = ''
  try {
    unwrap(await supabase.from('businesses').update({ onboarding_done: true }).eq('id', biz.business.id))
    await biz.reload()
    router.replace('/painel')
  } catch (e) {
    error.value = e.message
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="onb-page">
    <div class="onb-bg" aria-hidden="true">
      <div class="onb-grid-lines" />
      <div class="onb-orb orb-a" />
      <div class="onb-orb orb-b" />
    </div>

    <div class="onb-shell">
      <!-- Topo -->
      <header class="onb-top">
        <AppLogo />
        <div class="onb-top-right">
          <span class="onb-biz" v-if="biz.business">
            <span class="onb-biz-initial">{{ biz.business.name.charAt(0).toUpperCase() }}</span>
            <span class="onb-biz-name">{{ biz.business.name }}</span>
          </span>
          <button type="button" class="link-btn onb-skip" :disabled="saving" @click="skipNow">
            {{ skipConfirm ? 'Confirmar pular' : 'Pular por enquanto' }}
          </button>
        </div>
      </header>

      <!-- Cabeçalho -->
      <div class="onb-head">
        <div class="hero-pill">
          <span class="dot-live" />
          Vamos montar sua agenda em 2 minutos
        </div>
        <h1 class="onb-title">
          Já pré-preenchemos<br />
          <span class="gradient-text">o essencial pra você.</span>
        </h1>
        <p class="onb-sub muted">
          Confira os serviços e horários típicos do seu segmento, ajuste se precisar
          e abra o painel já pronto pra receber clientes.
        </p>
      </div>

      <!-- Progresso -->
      <ol class="onb-steps" :aria-label="`Passo ${step} de ${totalSteps}`">
        <li v-for="(label, i) in stepLabels" :key="i"
            class="onb-step"
            :class="{
              done: i + 1 < step,
              current: i + 1 === step,
              upcoming: i + 1 > step,
            }">
          <button type="button" class="onb-step-dot"
                  :disabled="i + 1 > step || saving"
                  :aria-label="`Ir para o passo ${i + 1}: ${typeof label === 'string' ? label : label.value}`"
                  @click="i + 1 < step && goto(i + 1)">
            <Icon v-if="i + 1 < step" name="check" />
            <span v-else>{{ i + 1 }}</span>
          </button>
          <span class="onb-step-label">{{ typeof label === 'string' ? label : label.value }}</span>
        </li>
      </ol>

      <!-- Alerta de erro -->
      <transition name="onb-msg">
        <div v-if="error" class="onb-alert error">
          <span class="onb-alert-icon"><Icon name="ban" /></span>
          <span>{{ error }}</span>
        </div>
      </transition>

      <!-- Card principal -->
      <div class="onb-card-wrap">
        <transition :name="direction > 0 ? 'onb-fwd' : 'onb-bwd'" mode="out-in">
          <!-- ============ Passo 1 — Segmento ============ -->
          <section v-if="step === 1" key="s1" class="onb-card">
            <div class="section-head">
              <div class="section-badge"><Icon name="tag" /></div>
              <div>
                <p class="eyebrow">Passo 1 de 4</p>
                <h2 class="section-title">Vamos começar: confere seu segmento?</h2>
              </div>
            </div>

            <div v-if="!editingCategory" class="cat-card" :class="{ 'cat-empty': !hasTemplate }">
              <div class="cat-icon-wrap">
                <div class="cat-icon-ring" />
                <div class="cat-icon-core"><Icon name="store" /></div>
              </div>
              <p class="cat-eyebrow">Seu negócio é</p>
              <h3 class="cat-name">{{ category }}</h3>

              <p v-if="hasTemplate" class="cat-help">
                Já deixei pré-preenchidos
                <strong>{{ currentTemplate.services.length }} serviços</strong>
                e horários típicos de <strong>{{ category.toLowerCase() }}</strong>.
                Você ajusta o que quiser nos próximos passos.
              </p>
              <p v-else class="cat-help">
                Beleza, vamos começar do zero — você cadastra seus serviços e horários
                nos próximos passos.
              </p>

              <button type="button" class="link-btn cat-change" @click="editingCategory = true">
                <Icon name="pencil" />
                Trocar segmento
              </button>
            </div>

            <div v-else class="cat-edit">
              <label class="cat-edit-label">
                <Icon name="tag" />
                Escolha o segmento que mais combina
              </label>
              <select class="cat-select" :value="category" @change="(e) => changeCategory(e.target.value)">
                <option v-for="c in CATEGORIES" :key="c" :value="c">{{ c }}</option>
              </select>
              <button type="button" class="link-btn cat-cancel" @click="editingCategory = false">
                Cancelar
              </button>
            </div>
          </section>

          <!-- ============ Passo 2 — Serviços ============ -->
          <section v-else-if="step === 2" key="s2" class="onb-card">
            <div class="section-head">
              <div class="section-badge"><Icon name="briefcase" /></div>
              <div>
                <p class="eyebrow">Passo 2 de 4</p>
                <h2 class="section-title">O que você oferece?</h2>
              </div>
            </div>

            <p class="onb-tip">
              <Icon name="sparkles" />
              <span>Podem ser ajustados depois na aba <strong>Serviços</strong> — não precisa estar perfeito agora.</span>
            </p>

            <div class="svc-list">
              <div v-for="(s, i) in services" :key="i" class="svc-row">
                <div class="svc-cell svc-name">
                  <label :for="`svc-name-${i}`">Nome</label>
                  <input :id="`svc-name-${i}`" v-model="s.name" data-field="name" placeholder="Ex.: Corte masculino" required />
                </div>
                <div class="svc-cell svc-dur">
                  <label :for="`svc-dur-${i}`">Duração</label>
                  <div class="input-suffix">
                    <input :id="`svc-dur-${i}`" v-model.number="s.duration_min" type="number" min="5" step="5" />
                    <span class="suffix">min</span>
                  </div>
                </div>
                <div class="svc-cell svc-price">
                  <label :for="`svc-price-${i}`">Preço</label>
                  <div class="input-prefix">
                    <span class="prefix">R$</span>
                    <input :id="`svc-price-${i}`" v-model.number="s.price" type="number" min="0" step="0.01" />
                  </div>
                </div>
                <button type="button" class="svc-remove"
                        :aria-label="`Remover ${s.name || 'serviço'}`"
                        :disabled="services.length <= 1"
                        @click="removeService(i)">
                  <Icon name="trash" />
                </button>
              </div>
            </div>

            <button type="button" class="add-row" @click="addService">
              <Icon name="plus" />
              Adicionar serviço
            </button>

            <p v-if="!services.length" class="svc-hint muted">
              Adicione pelo menos um serviço pra continuar.
            </p>
          </section>

          <!-- ============ Passo 3 — Horários ============ -->
          <section v-else-if="step === 3" key="s3" class="onb-card">
            <div class="section-head">
              <div class="section-badge"><Icon name="clock" /></div>
              <div>
                <p class="eyebrow">Passo 3 de 4</p>
                <h2 class="section-title">Quando você atende?</h2>
              </div>
            </div>

            <p class="onb-tip">
              <Icon name="sparkles" />
              <span>É quando você recebe clientes nesse estabelecimento. Dá pra ajustar depois na aba <strong>Horários</strong>.</span>
            </p>

            <div class="days">
              <div v-for="d in days" :key="d.weekday" class="day-row" :class="{ open: d.open }">
                <button type="button" class="day-toggle" :class="{ on: d.open }" @click="toggleDay(d)">
                  <span class="day-check">
                    <Icon v-if="d.open" name="check" />
                  </span>
                  <span class="day-label">
                    <small>{{ WD_SHORT[d.weekday] }}</small>
                    <strong>{{ WEEKDAYS[d.weekday] }}</strong>
                  </span>
                </button>
                <div v-if="d.open" class="day-body">
                  <input v-model="d.start" type="time" aria-label="Início" />
                  <span class="day-sep">até</span>
                  <input v-model="d.end" type="time" aria-label="Fim" />
                </div>
                <div v-else class="day-closed">Fechado</div>
              </div>
            </div>
          </section>

          <!-- ============ Passo 4 — Primeiro profissional ============ -->
          <section v-else key="s4" class="onb-card">
            <div class="section-head">
              <div class="section-badge"><Icon name="user" /></div>
              <div>
                <p class="eyebrow">Passo 4 de 4</p>
                <h2 class="section-title">Quem vai atender?</h2>
              </div>
            </div>

            <p class="onb-tip">
              <Icon name="sparkles" />
              <span>Depois você cadastra mais {{ staffLabel.toLowerCase() }}s. Se é só você, já tá.</span>
            </p>

            <div class="pro-fields">
              <div class="float-field" :class="{ filled: pro.name }">
                <input id="pro-name" v-model="pro.name" required placeholder=" " />
                <label for="pro-name">
                  <Icon name="user" />
                  Nome do(a) {{ staffLabel.toLowerCase() }}
                </label>
              </div>

              <div class="float-field" :class="{ filled: pro.photo_url }">
                <input id="pro-photo" v-model="pro.photo_url" type="url" placeholder=" " />
                <label for="pro-photo">
                  <Icon name="image" />
                  URL da foto (opcional)
                </label>
                <small class="field-hint">Pode deixar em branco agora — você sobe foto depois.</small>
              </div>
            </div>

            <div class="finish-summary">
              <div class="summary-item">
                <span class="summary-ico"><Icon name="briefcase" /></span>
                <div>
                  <strong>{{ services.length }} serviço{{ services.length === 1 ? '' : 's' }}</strong>
                  <small class="muted">prontos pra agendar</small>
                </div>
              </div>
              <div class="summary-item">
                <span class="summary-ico"><Icon name="clock" /></span>
                <div>
                  <strong>{{ days.filter(d => d.open).length }} dia{{ days.filter(d => d.open).length === 1 ? '' : 's' }} abertos</strong>
                  <small class="muted">na semana</small>
                </div>
              </div>
              <div class="summary-item">
                <span class="summary-ico"><Icon name="user" /></span>
                <div>
                  <strong>1 {{ staffLabel.toLowerCase() }}</strong>
                  <small class="muted">cadastrado</small>
                </div>
              </div>
            </div>
          </section>
        </transition>
      </div>

      <!-- Rodapé fixo com ações -->
      <footer class="onb-foot">
        <button type="button" class="btn secondary onb-back"
                :disabled="step === 1 || saving" @click="back">
          Voltar
        </button>
        <button type="button" class="btn onb-next"
                :class="{ ok: canAdvance, finishing: step === totalSteps }"
                :disabled="!canAdvance || saving"
                @click="next">
          <span v-if="saving" class="btn-spinner" aria-hidden="true" />
          <template v-else>
            <Icon v-if="canAdvance && step < totalSteps" name="check" />
            {{ step === totalSteps ? (saving ? 'Concluindo...' : 'Concluir e abrir painel') : 'Próximo' }}
          </template>
        </button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
/* =====================================================================
   Shell (mesma linguagem do Signup: orbs + grid-lines + pills)
   ===================================================================== */
.onb-page {
  position: relative;
  min-height: 100vh;
  isolation: isolate;
  overflow: hidden;
  padding-bottom: 120px; /* espaço pro rodapé fixo no mobile */
}
.onb-bg {
  position: absolute; inset: 0; z-index: -1; pointer-events: none;
}
.onb-grid-lines {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(148, 180, 220, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 180, 220, 0.05) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 80% 50% at 50% 0%, #000 30%, transparent 85%);
  -webkit-mask-image: radial-gradient(ellipse 80% 50% at 50% 0%, #000 30%, transparent 85%);
}
.onb-orb {
  position: absolute; border-radius: 50%; filter: blur(70px); opacity: 0.45;
  animation: orbFloat 14s ease-in-out infinite;
}
.orb-a {
  width: 520px; height: 520px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.45), transparent 65%);
  top: -160px; right: -120px;
}
.orb-b {
  width: 420px; height: 420px;
  background: radial-gradient(circle, rgba(29, 78, 216, 0.35), transparent 65%);
  bottom: -200px; left: -100px;
  animation-delay: -7s;
}
@keyframes orbFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(20px, -20px) scale(1.05); }
}

.onb-shell {
  width: min(720px, calc(100% - 32px));
  margin: 0 auto;
  padding: 24px 0 56px;
}

/* =====================================================================
   Topo
   ===================================================================== */
.onb-top {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
  margin-bottom: 28px;
}
.onb-top-right {
  display: flex; align-items: center; gap: 14px;
  min-width: 0;
}
.onb-biz {
  display: inline-flex; align-items: center; gap: 8px;
  padding: 6px 12px 6px 6px;
  border-radius: 999px;
  background: var(--surface);
  border: 1px solid var(--border);
  min-width: 0;
}
.onb-biz-initial {
  width: 24px; height: 24px; border-radius: 50%;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-weight: 800; font-size: 0.76rem;
  flex-shrink: 0;
}
.onb-biz-name {
  font-size: 0.86rem; font-weight: 700;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  max-width: 160px;
}
.onb-skip {
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--muted);
}
.onb-skip:hover { color: var(--text); }

/* =====================================================================
   Cabeçalho
   ===================================================================== */
.onb-head {
  text-align: center;
  max-width: 540px;
  margin: 0 auto 28px;
}
.hero-pill {
  display: inline-flex; align-items: center; gap: 10px;
  padding: 7px 14px 7px 10px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: var(--silver);
  font-size: 0.82rem;
  font-weight: 500;
  margin-bottom: 18px;
}
.dot-live {
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--success);
  box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.6);
  animation: pulse 2s ease-in-out infinite;
}
@keyframes pulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.5); }
  50% { box-shadow: 0 0 0 8px rgba(74, 222, 128, 0); }
}
.onb-title {
  font-size: clamp(1.7rem, 4vw, 2.4rem);
  font-weight: 800;
  line-height: 1.1;
  letter-spacing: -0.03em;
  margin: 0 0 12px;
}
.onb-sub {
  font-size: 1rem; line-height: 1.55;
  margin: 0 auto;
  max-width: 480px;
}

/* =====================================================================
   Timeline de passos
   ===================================================================== */
.onb-steps {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 0;
  list-style: none;
  margin: 0 0 24px;
  padding: 0;
  position: relative;
}
.onb-step {
  position: relative;
  display: flex; flex-direction: column; align-items: center;
  gap: 8px;
  min-width: 0;
}
.onb-step + .onb-step::before {
  content: '';
  position: absolute;
  top: 16px;
  left: -50%;
  right: 50%;
  height: 2px;
  background: var(--border);
  z-index: 0;
}
.onb-step.done + .onb-step::before,
.onb-step.current::before {
  background: linear-gradient(90deg, var(--brand-strong), var(--brand));
  box-shadow: 0 0 10px var(--brand-glow);
}
.onb-step-dot {
  position: relative;
  z-index: 1;
  width: 34px; height: 34px;
  border-radius: 50%;
  display: grid; place-items: center;
  background: var(--surface);
  border: 1.5px solid var(--border);
  color: var(--muted);
  font-weight: 800;
  font-size: 0.9rem;
  cursor: pointer;
  transition: background 0.2s ease, border-color 0.2s ease, color 0.2s ease, transform 0.15s ease;
}
.onb-step-dot:disabled { cursor: default; }
.onb-step-dot :deep(svg) { width: 14px; height: 14px; stroke-width: 3; }

.onb-step.done .onb-step-dot {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent;
  color: #fff;
  box-shadow: 0 0 14px var(--brand-glow);
}
.onb-step.done .onb-step-dot:hover { transform: translateY(-1px); }
.onb-step.current .onb-step-dot {
  background: var(--surface);
  border-color: var(--brand);
  color: var(--brand-ink);
  box-shadow: 0 0 0 4px var(--brand-soft);
}
.onb-step-label {
  font-size: 0.74rem;
  font-weight: 600;
  color: var(--muted);
  letter-spacing: 0.02em;
  text-align: center;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}
.onb-step.current .onb-step-label { color: var(--text); }
.onb-step.done .onb-step-label { color: var(--silver); }

/* =====================================================================
   Card + transição entre passos
   ===================================================================== */
.onb-card-wrap {
  position: relative;
  min-height: 320px;
}
.onb-card {
  background:
    radial-gradient(ellipse 500px 240px at 100% 0%, rgba(59, 130, 246, 0.12), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 32px;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.08);
}

.onb-fwd-enter-active,
.onb-fwd-leave-active,
.onb-bwd-enter-active,
.onb-bwd-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}
.onb-fwd-enter-from { opacity: 0; transform: translateX(14px); }
.onb-fwd-leave-to   { opacity: 0; transform: translateX(-14px); }
.onb-bwd-enter-from { opacity: 0; transform: translateX(-14px); }
.onb-bwd-leave-to   { opacity: 0; transform: translateX(14px); }

/* Section head reutilizado */
.section-head {
  display: flex; align-items: center; gap: 14px;
  margin-bottom: 22px;
}
.section-badge {
  width: 44px; height: 44px; border-radius: 14px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 22px rgba(59, 130, 246, 0.4);
}
.section-badge :deep(svg) { width: 20px; height: 20px; }
.section-head .eyebrow {
  margin: 0 0 2px;
  font-size: 0.7rem;
  letter-spacing: 0.2em;
}
.section-title {
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: -0.015em;
  margin: 0;
}

/* Dica em azul suave reutilizada em vários passos */
.onb-tip {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  background: var(--brand-soft);
  border: 1px solid rgba(59, 130, 246, 0.25);
  color: var(--silver);
  font-size: 0.88rem;
  line-height: 1.5;
  margin: 0 0 18px;
}
.onb-tip :deep(svg) {
  width: 16px; height: 16px;
  color: var(--brand-ink);
  flex-shrink: 0;
  margin-top: 1px;
}
.onb-tip strong { color: var(--text); font-weight: 700; }

/* =====================================================================
   Alertas
   ===================================================================== */
.onb-alert {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  border: 1px solid;
  font-size: 0.9rem;
  line-height: 1.4;
  margin: 0 0 16px;
}
.onb-alert.error {
  color: #fecaca;
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.35);
}
.onb-alert-icon {
  width: 20px; height: 20px; flex-shrink: 0;
  display: grid; place-items: center;
  margin-top: 1px;
}
.onb-alert-icon :deep(svg) { width: 16px; height: 16px; stroke-width: 2.4; }
.onb-msg-enter-active, .onb-msg-leave-active { transition: opacity 0.2s ease, transform 0.2s ease; }
.onb-msg-enter-from, .onb-msg-leave-to { opacity: 0; transform: translateY(-4px); }

/* =====================================================================
   Passo 1 — Segmento
   ===================================================================== */
.cat-card {
  text-align: center;
  padding: 32px 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 420px 220px at 50% 0%, var(--brand-soft), transparent 70%),
    rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.cat-icon-wrap { position: relative; width: 84px; height: 84px; margin: 0 auto 18px; }
.cat-icon-ring {
  position: absolute; inset: 0; border-radius: 50%;
  background: radial-gradient(circle, var(--brand-glow), transparent 70%);
  animation: ringPulse 2.4s ease-in-out infinite;
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.12); opacity: 0.35; }
}
.cat-icon-core {
  position: absolute; inset: 12px;
  border-radius: 50%; display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px var(--brand-glow);
}
.cat-icon-core :deep(svg) { width: 26px; height: 26px; }
.cat-eyebrow {
  margin: 0 0 4px;
  font-size: 0.72rem;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.18em;
  font-weight: 700;
}
.cat-name {
  font-size: 1.6rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  margin: 0 0 14px;
  background: linear-gradient(120deg, var(--silver) 0%, #fff 35%, var(--brand-ink) 100%);
  -webkit-background-clip: text; background-clip: text;
  color: transparent;
}
.cat-help {
  max-width: 420px;
  margin: 0 auto 20px;
  color: var(--silver);
  font-size: 0.95rem;
  line-height: 1.5;
}
.cat-help strong { color: var(--text); font-weight: 700; }
.cat-change {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 0.88rem;
  color: var(--brand-ink);
  font-weight: 600;
}
.cat-change :deep(svg) { width: 13px; height: 13px; }
.cat-change:hover { color: #fff; }

.cat-edit {
  padding: 20px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.cat-edit-label {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--silver);
  margin-bottom: 10px;
}
.cat-edit-label :deep(svg) {
  width: 14px; height: 14px;
  color: var(--brand-ink);
}
.cat-select { width: 100%; }
.cat-cancel {
  display: inline-block;
  margin-top: 12px;
  font-size: 0.85rem;
  color: var(--muted);
}
.cat-cancel:hover { color: var(--text); }

/* =====================================================================
   Passo 2 — Serviços
   ===================================================================== */
.svc-list {
  display: flex; flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}
.svc-row {
  display: grid;
  grid-template-columns: minmax(0, 2.2fr) minmax(0, 1fr) minmax(0, 1fr) 44px;
  gap: 10px;
  align-items: end;
  padding: 12px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.35);
  border: 1px solid var(--border);
  transition: border-color 0.15s ease, background 0.15s ease;
}
.svc-row:hover { border-color: var(--border-strong); }

.svc-cell { display: flex; flex-direction: column; min-width: 0; }
.svc-cell label {
  font-size: 0.68rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  font-weight: 700;
  color: var(--muted);
  margin-bottom: 4px;
}
.svc-cell input {
  padding: 10px 12px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: 10px;
  color: var(--text);
  font: inherit;
  font-size: 0.92rem;
  min-width: 0;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.svc-cell input:focus {
  outline: none;
  border-color: var(--brand);
  box-shadow: 0 0 0 3px var(--brand-soft);
}

.input-prefix,
.input-suffix {
  display: flex; align-items: stretch;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: 10px;
  overflow: hidden;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.input-prefix:focus-within,
.input-suffix:focus-within {
  border-color: var(--brand);
  box-shadow: 0 0 0 3px var(--brand-soft);
}
.input-prefix .prefix,
.input-suffix .suffix {
  display: inline-flex; align-items: center;
  padding: 0 10px;
  background: rgba(255, 255, 255, 0.04);
  color: var(--muted);
  font-size: 0.84rem;
  font-weight: 600;
}
.input-prefix input,
.input-suffix input {
  flex: 1;
  background: transparent;
  border: none;
  padding: 10px 10px;
  color: var(--text);
  font: inherit;
  font-size: 0.92rem;
  min-width: 0;
}
.input-prefix input:focus,
.input-suffix input:focus { outline: none; box-shadow: none; }

.svc-remove {
  width: 44px; height: 44px;
  border-radius: 10px;
  display: grid; place-items: center;
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--muted);
  cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}
.svc-remove:hover:not(:disabled) {
  color: var(--danger);
  border-color: rgba(248, 113, 113, 0.35);
  background: var(--danger-soft);
}
.svc-remove:disabled { opacity: 0.35; cursor: not-allowed; }
.svc-remove :deep(svg) { width: 15px; height: 15px; }

.add-row {
  width: 100%;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  border: 1px dashed var(--border-strong);
  background: transparent;
  color: var(--brand-ink);
  font: inherit;
  font-weight: 600;
  font-size: 0.92rem;
  cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  transition: border-color 0.15s ease, background 0.15s ease, color 0.15s ease;
}
.add-row:hover {
  border-color: var(--brand);
  background: var(--brand-soft);
  color: #fff;
}
.add-row :deep(svg) { width: 15px; height: 15px; }

.svc-hint { margin-top: 10px; font-size: 0.88rem; }

/* =====================================================================
   Passo 3 — Horários
   ===================================================================== */
.days { display: flex; flex-direction: column; gap: 6px; }
.day-row {
  display: grid;
  grid-template-columns: 180px 1fr;
  gap: 14px;
  align-items: center;
  padding: 10px 14px;
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
  background: transparent;
  border: none;
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
.day-label strong { font-size: 0.95rem; font-weight: 700; }

.day-body {
  display: flex; align-items: center; gap: 8px;
  min-width: 0;
}
.day-body input {
  flex: 1 1 110px;
  padding: 9px 10px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: 10px;
  color: var(--text);
  color-scheme: dark;
  font: inherit;
  font-size: 0.9rem;
  min-height: 40px;
}
.day-body input:focus {
  outline: none;
  border-color: var(--brand);
  box-shadow: 0 0 0 3px var(--brand-soft);
}
.day-sep {
  color: var(--muted);
  font-size: 0.82rem;
  font-weight: 600;
  padding: 0 2px;
}
.day-closed {
  color: var(--muted);
  font-size: 0.88rem;
  padding: 0 2px;
}

/* =====================================================================
   Passo 4 — Primeiro profissional
   ===================================================================== */
.pro-fields {
  display: flex; flex-direction: column;
  gap: 14px;
  margin-bottom: 20px;
}
.float-field { position: relative; }
.float-field input {
  width: 100%;
  padding: 22px 14px 10px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text);
  font: inherit;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
}
.float-field input:hover { border-color: var(--border-strong); }
.float-field input:focus {
  outline: none;
  border-color: var(--brand);
  background: rgba(5, 11, 22, 0.75);
  box-shadow: 0 0 0 3px var(--brand-soft);
}
.float-field label {
  position: absolute;
  left: 14px;
  top: 14px;
  display: inline-flex; align-items: center; gap: 6px;
  color: var(--muted);
  font-size: 0.95rem;
  font-weight: 500;
  pointer-events: none;
  transform-origin: left top;
  transition: transform 0.18s ease, color 0.18s ease;
  margin: 0;
}
.float-field label :deep(svg) {
  width: 14px; height: 14px;
  transition: color 0.18s ease;
}
.float-field input:focus + label,
.float-field.filled label {
  transform: translateY(-9px) scale(0.78);
  color: var(--brand-ink);
}
.field-hint {
  display: block;
  margin: 6px 2px 0;
  font-size: 0.78rem;
  color: var(--muted);
}

.finish-summary {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 10px;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.summary-item {
  display: flex; align-items: center; gap: 10px;
  min-width: 0;
}
.summary-ico {
  width: 34px; height: 34px; border-radius: 10px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 14px var(--brand-glow);
}
.summary-ico :deep(svg) { width: 16px; height: 16px; }
.summary-item strong {
  display: block;
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--text);
}
.summary-item small {
  display: block;
  font-size: 0.74rem;
}

/* =====================================================================
   Rodapé com Voltar / Próximo
   ===================================================================== */
.onb-foot {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
  margin-top: 20px;
}
.onb-back,
.onb-next {
  min-height: 48px;
  padding: 12px 22px;
  font-size: 0.95rem;
}
.onb-next { min-width: 180px; }
.onb-next.ok:not(.finishing) {
  background: linear-gradient(120deg, #22c55e, #15803d);
  box-shadow: 0 0 18px rgba(74, 222, 128, 0.45);
}
.onb-next :deep(svg) { width: 15px; height: 15px; stroke-width: 2.5; }

.btn-spinner {
  width: 16px; height: 16px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 640px) {
  .onb-shell { padding: 20px 0 32px; }
  .onb-top { margin-bottom: 20px; flex-wrap: wrap; }
  .onb-head { margin-bottom: 20px; }
  .onb-biz-name { max-width: 110px; }
  .onb-card { padding: 22px 18px; border-radius: 16px; }
  .section-head { gap: 12px; margin-bottom: 18px; }
  .section-badge { width: 40px; height: 40px; border-radius: 12px; }
  .section-badge :deep(svg) { width: 18px; height: 18px; }
  .section-title { font-size: 1.05rem; }

  /* Steps mais compactos */
  .onb-step-dot { width: 30px; height: 30px; font-size: 0.82rem; }
  .onb-step + .onb-step::before { top: 14px; }
  .onb-step-label { font-size: 0.68rem; }

  .cat-card { padding: 24px 16px; }
  .cat-name { font-size: 1.3rem; }

  .svc-row {
    grid-template-columns: 1fr 1fr;
    grid-template-areas:
      'name name'
      'dur price'
      'remove remove';
    gap: 8px;
  }
  .svc-name { grid-area: name; }
  .svc-dur { grid-area: dur; }
  .svc-price { grid-area: price; }
  .svc-remove {
    grid-area: remove;
    width: 100%; height: 36px;
    border-radius: 10px;
  }

  .day-row {
    grid-template-columns: 1fr;
    gap: 10px;
    padding: 12px;
  }

  /* Rodapé fixo embaixo no mobile pra ação sempre visível */
  .onb-foot {
    position: fixed;
    left: 0; right: 0; bottom: 0;
    z-index: 20;
    padding: 12px 16px calc(12px + env(safe-area-inset-bottom, 0px));
    background: rgba(5, 11, 22, 0.92);
    backdrop-filter: blur(14px);
    -webkit-backdrop-filter: blur(14px);
    border-top: 1px solid var(--border);
    margin-top: 0;
  }
  .onb-back { flex: 0 0 auto; min-width: 100px; }
  .onb-next { flex: 1; min-width: 0; }
}

@media (max-width: 420px) {
  .onb-title { font-size: 1.6rem; }
  .onb-sub { font-size: 0.92rem; }
  .onb-step-label { font-size: 0.62rem; letter-spacing: 0; }
}

@media (prefers-reduced-motion: reduce) {
  .onb-orb, .dot-live, .cat-icon-ring { animation: none; }
  .onb-fwd-enter-active, .onb-fwd-leave-active,
  .onb-bwd-enter-active, .onb-bwd-leave-active { transition: opacity 0.15s ease; }
  .onb-fwd-enter-from, .onb-fwd-leave-to,
  .onb-bwd-enter-from, .onb-bwd-leave-to { transform: none; }
}
</style>
