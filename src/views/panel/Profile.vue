<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { CATEGORIES, APP_DOMAIN, STAFF_LABELS } from '@/config/brand'
import { brandVars } from '@/lib/colors'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const form = ref({})
const msg = ref('')
const error = ref('')
const uploading = ref(false)
const dragOver = ref(false)
const newPassword = ref('')
const showPassword = ref(false)
const fileInput = ref(null)

// Paleta completa: cada linha é uma cor, do tom mais claro ao mais escuro.
const PALETTE = [
  ['Vermelho', ['#fca5a5', '#f87171', '#ef4444', '#dc2626', '#b91c1c', '#991b1b', '#7f1d1d']],
  ['Laranja', ['#fdba74', '#fb923c', '#f97316', '#ea580c', '#c2410c', '#9a3412', '#7c2d12']],
  ['Âmbar', ['#fcd34d', '#fbbf24', '#f59e0b', '#d97706', '#b45309', '#92400e', '#78350f']],
  ['Amarelo', ['#fde047', '#facc15', '#eab308', '#ca8a04', '#a16207', '#854d0e', '#713f12']],
  ['Lima', ['#bef264', '#a3e635', '#84cc16', '#65a30d', '#4d7c0f', '#3f6212', '#365314']],
  ['Verde', ['#86efac', '#4ade80', '#22c55e', '#16a34a', '#15803d', '#166534', '#14532d']],
  ['Esmeralda', ['#6ee7b7', '#34d399', '#10b981', '#059669', '#047857', '#065f46', '#064e3b']],
  ['Turquesa', ['#5eead4', '#2dd4bf', '#14b8a6', '#0d9488', '#0f766e', '#115e59', '#134e4a']],
  ['Ciano', ['#67e8f9', '#22d3ee', '#06b6d4', '#0891b2', '#0e7490', '#155e75', '#164e63']],
  ['Azul-claro', ['#7dd3fc', '#38bdf8', '#0ea5e9', '#0284c7', '#0369a1', '#075985', '#0c4a6e']],
  ['Azul', ['#93c5fd', '#60a5fa', '#3b82f6', '#2563eb', '#1d4ed8', '#1e40af', '#1e3a8a']],
  ['Anil', ['#a5b4fc', '#818cf8', '#6366f1', '#4f46e5', '#4338ca', '#3730a3', '#312e81']],
  ['Violeta', ['#c4b5fd', '#a78bfa', '#8b5cf6', '#7c3aed', '#6d28d9', '#5b21b6', '#4c1d95']],
  ['Roxo', ['#d8b4fe', '#c084fc', '#a855f7', '#9333ea', '#7e22ce', '#6b21a8', '#581c87']],
  ['Magenta', ['#f0abfc', '#e879f9', '#d946ef', '#c026d3', '#a21caf', '#86198f', '#701a75']],
  ['Rosa', ['#f9a8d4', '#f472b6', '#ec4899', '#db2777', '#be185d', '#9d174d', '#831843']],
  ['Rosa-vermelho', ['#fda4af', '#fb7185', '#f43f5e', '#e11d48', '#be123c', '#9f1239', '#881337']],
  ['Marrom', ['#d6b89c', '#c19a6b', '#a47148', '#8b5a2b', '#6f4518', '#5c3a1a', '#3e2723']],
  ['Cinza', ['#d1d5db', '#9ca3af', '#6b7280', '#4b5563', '#374151', '#1f2937', '#111827']],
  ['Preto e branco', ['#ffffff', '#f5f5f5', '#e5e5e5', '#a3a3a3', '#525252', '#262626', '#000000']],
]
const hexInput = ref('')
watch(() => form.value.primary_color, (c) => { if (c) hexInput.value = c.toUpperCase() })
function applyHex() {
  let v = hexInput.value.trim()
  if (!v.startsWith('#')) v = '#' + v
  if (/^#[0-9a-fA-F]{3}$/.test(v)) v = '#' + v.slice(1).split('').map((ch) => ch + ch).join('')
  if (/^#[0-9a-fA-F]{6}$/.test(v)) form.value.primary_color = v.toLowerCase()
  else error.value = 'Código de cor inválido. Use o formato #RRGGBB, por exemplo #FF5733.'
}

// Nome da cor atual (pra mostrar no header de identidade visual).
const currentColorName = computed(() => {
  const c = form.value.primary_color?.toLowerCase()
  if (!c) return ''
  for (const [name, shades] of PALETTE) {
    if (shades.includes(c)) return name
  }
  return 'Personalizada'
})

onMounted(() => {
  const b = biz.business
  form.value = {
    name: b.name, category: b.category, description: b.description, phone: b.phone,
    address: b.address, primary_color: b.primary_color, logo_url: b.logo_url,
    slot_interval_min: b.slot_interval_min, staff_label: b.staff_label,
  }
})

async function save() {
  msg.value = error.value = ''
  const { error: err } = await supabase.from('businesses').update(form.value).eq('id', biz.business.id)
  if (err) { error.value = err.message; return }
  msg.value = 'Perfil atualizado.'
  biz.reload()
}

async function uploadLogoFile(file) {
  if (!file) return
  if (!/^image\/(png|jpe?g|webp)$/.test(file.type)) {
    error.value = 'A logo precisa ser PNG, JPG ou WEBP.'
    return
  }
  if (file.size > 2 * 1024 * 1024) { error.value = 'A logo precisa ter no máximo 2 MB.'; return }
  uploading.value = true
  error.value = ''
  const ext = file.name.split('.').pop().toLowerCase()
  const path = `${biz.business.id}/logo-${Date.now()}.${ext}`
  const { error: err } = await supabase.storage.from('logos').upload(path, file, { upsert: true })
  uploading.value = false
  if (err) { error.value = err.message; return }
  form.value.logo_url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
}

function onFileChange(event) {
  uploadLogoFile(event.target.files[0])
  // Zera o input pra permitir re-upload do mesmo arquivo depois.
  if (event.target) event.target.value = ''
}

function onDrop(event) {
  dragOver.value = false
  uploadLogoFile(event.dataTransfer.files?.[0])
}

async function changePassword() {
  msg.value = error.value = ''
  const { error: err } = await supabase.auth.updateUser({ password: newPassword.value })
  if (err) error.value = err.message
  else { msg.value = 'Senha alterada.'; newPassword.value = '' }
}
</script>

<template>
  <div class="page-header pf-header">
    <p class="eyebrow pf-eyebrow">Conta</p>
    <h1>Perfil do estabelecimento</h1>
    <p class="muted pf-lede">
      É o que aparece pros seus clientes na vitrine. Mantém atualizado — nome, logo, cor da marca e como você quer que te encontrem.
    </p>
    <div class="pf-slug">
      <Icon name="link" />
      <span>{{ APP_DOMAIN }}/</span><strong>{{ biz.business.slug }}</strong>
    </div>
  </div>

  <div v-if="error" class="alert alert-danger">
    <span class="alert-icon"><Icon name="ban" /></span><span>{{ error }}</span>
  </div>
  <div v-if="msg" class="alert alert-success">
    <span class="alert-icon"><Icon name="check" /></span><span>{{ msg }}</span>
  </div>

  <form class="pf-section" @submit.prevent="save">
    <!-- ======================= Dados do estabelecimento ======================= -->
    <div class="section-head">
      <span class="section-badge"><Icon name="store" /></span>
      <div>
        <h3>Dados do estabelecimento</h3>
        <small class="muted">O que o cliente vê na vitrine logo de cara.</small>
      </div>
    </div>

    <div class="ff-row">
      <div class="ff ff-wide">
        <input id="pf-name" v-model="form.name" required placeholder=" " />
        <label for="pf-name">Nome do negócio</label>
      </div>
      <div class="ff">
        <select id="pf-cat" v-model="form.category" required>
          <option v-for="c in CATEGORIES" :key="c">{{ c }}</option>
        </select>
        <label for="pf-cat">Segmento</label>
      </div>
    </div>
    <div class="ff">
      <textarea id="pf-desc" v-model="form.description" rows="3" placeholder=" " />
      <label for="pf-desc">Descrição</label>
    </div>
    <div class="ff-row ff-row-2">
      <div class="ff">
        <input id="pf-phone" v-model="form.phone" type="tel" placeholder=" " />
        <label for="pf-phone">WhatsApp</label>
      </div>
      <div class="ff">
        <input id="pf-addr" v-model="form.address" placeholder=" " />
        <label for="pf-addr">Endereço</label>
      </div>
    </div>

    <!-- ======================= Identidade visual ======================= -->
    <div class="section-head pf-section-head-mt">
      <span class="section-badge"><Icon name="sparkles" /></span>
      <div>
        <h3>Identidade visual</h3>
        <small class="muted">Logo e cor principal — definem o visual da sua vitrine.</small>
      </div>
    </div>

    <div class="pf-brand-grid">
      <!-- Logo dropzone -->
      <div
        class="pf-dropzone"
        :class="{ hover: dragOver, filled: form.logo_url }"
        @click="fileInput?.click()"
        @dragover.prevent="dragOver = true"
        @dragleave.prevent="dragOver = false"
        @drop.prevent="onDrop"
      >
        <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/webp" hidden @change="onFileChange" />
        <div v-if="form.logo_url" class="pf-logo-wrap">
          <img :src="form.logo_url" alt="Logo atual" class="pf-logo" />
          <div class="pf-logo-overlay">
            <Icon name="camera" />
            <span>Trocar logo</span>
          </div>
        </div>
        <div v-else class="pf-dropzone-empty">
          <span class="pf-dropzone-icon"><Icon name="image" /></span>
          <strong>Enviar logo</strong>
          <small>Arraste aqui ou clique pra escolher</small>
          <small class="muted">PNG, JPG ou WEBP · até 2 MB</small>
        </div>
        <div v-if="uploading" class="pf-dropzone-loading">Enviando...</div>
      </div>

      <!-- Agenda inline + cor atual -->
      <div class="pf-brand-side">
        <div class="pf-current-color">
          <small class="muted pf-eyebrow-sm">Cor principal</small>
          <div class="pf-current-color-row">
            <span class="pf-color-chip" :style="{ background: form.primary_color }" />
            <div>
              <strong>{{ currentColorName }}</strong>
              <code>{{ (form.primary_color || '').toUpperCase() }}</code>
            </div>
          </div>
        </div>

        <div class="ff">
          <div class="pf-hex-wrap">
            <span class="pf-hex-prefix">#</span>
            <input
              id="pf-hex"
              v-model="hexInput"
              maxlength="7"
              placeholder="FF5733"
              style="text-transform: uppercase"
              @keydown.enter.prevent="applyHex"
            />
            <button type="button" class="btn small pf-hex-apply" @click="applyHex">Usar</button>
          </div>
          <small class="muted">Cole o hex da sua marca (ex.: #FF5733)</small>
        </div>
      </div>
    </div>

    <!-- Paleta completa -->
    <div class="ff pf-palette-field">
      <label>Todas as cores <small class="muted">(clique para escolher)</small></label>
      <div class="pf-palette">
        <div v-for="[name, shades] in PALETTE" :key="name" class="pf-palette-row" :title="name">
          <button
            v-for="c in shades"
            :key="c"
            type="button"
            class="pf-swatch"
            :style="{ background: c }"
            :class="{ on: form.primary_color?.toLowerCase() === c }"
            :aria-label="`${name} ${c}`"
            @click="form.primary_color = c"
          />
        </div>
      </div>
    </div>

    <!-- Prévia da página pública -->
    <div class="pf-preview-wrap">
      <small class="muted pf-eyebrow-sm pf-preview-label">
        <Icon name="smartphone" />
        Prévia da sua vitrine
      </small>
      <div class="pf-phone">
        <div class="pf-phone-notch" />
        <div class="pf-phone-screen" :style="brandVars(form.primary_color)">
          <div class="pf-preview-head">
            <img v-if="form.logo_url" :src="form.logo_url" alt="" class="pf-preview-logo" />
            <div class="pf-preview-info">
              <strong class="gradient-text">{{ form.name || 'Seu negócio' }}</strong>
              <small>{{ form.category }}</small>
            </div>
          </div>
          <div class="pf-preview-chips">
            <span class="pf-preview-chip">09:00</span>
            <span class="pf-preview-chip on">10:00</span>
            <span class="pf-preview-chip">11:00</span>
          </div>
          <div class="pf-preview-cta">Agendar</div>
        </div>
      </div>
    </div>

    <!-- ======================= Agenda ======================= -->
    <div class="section-head pf-section-head-mt">
      <span class="section-badge"><Icon name="calendar" /></span>
      <div>
        <h3>Agenda</h3>
        <small class="muted">Como sua agenda funciona na vitrine.</small>
      </div>
    </div>

    <div class="ff-row ff-row-2">
      <div class="ff">
        <input id="pf-staff" v-model="form.staff_label" list="pf-staff-labels" maxlength="30" required placeholder=" " />
        <label for="pf-staff">Quem atende <small>(nome na vitrine)</small></label>
        <datalist id="pf-staff-labels"><option v-for="l in STAFF_LABELS" :key="l" :value="l" /></datalist>
      </div>
      <div class="ff">
        <select id="pf-slot" v-model.number="form.slot_interval_min">
          <option v-for="m in [10, 15, 20, 30, 45, 60]" :key="m" :value="m">A cada {{ m }} min</option>
        </select>
        <label for="pf-slot">Intervalo da agenda</label>
      </div>
    </div>

    <div class="pf-foot">
      <button class="btn">
        <Icon name="check" />
        Salvar alterações
      </button>
    </div>
  </form>

  <!-- ======================= Segurança ======================= -->
  <form class="pf-section" @submit.prevent="changePassword">
    <div class="section-head">
      <span class="section-badge"><Icon name="shield" /></span>
      <div>
        <h3>Segurança</h3>
        <small class="muted">Troque sua senha de acesso ao painel.</small>
      </div>
    </div>

    <div class="ff-row ff-row-pwd">
      <div class="ff ff-wide pwd-field">
        <input id="pf-pwd" v-model="newPassword" :type="showPassword ? 'text' : 'password'" minlength="8" autocomplete="new-password" required placeholder=" " />
        <label for="pf-pwd">Nova senha <small>(mín. 8 caracteres)</small></label>
        <button type="button" class="pwd-toggle" :aria-label="showPassword ? 'Ocultar senha' : 'Mostrar senha'" @click="showPassword = !showPassword">
          <Icon :name="showPassword ? 'eye-off' : 'eye'" />
        </button>
      </div>
      <div class="ff ff-btn">
        <button class="btn secondary">
          <Icon name="key" />
          Alterar senha
        </button>
      </div>
    </div>
  </form>
</template>

<style scoped>
/* ===== Header ===== */
.pf-eyebrow { display: inline-block; margin-bottom: 6px; }
.pf-lede { font-size: 0.95rem; max-width: 580px; margin: 4px 0 0; }
.pf-slug {
  display: inline-flex; align-items: center; gap: 7px;
  margin-top: 14px;
  padding: 7px 14px;
  border-radius: 999px;
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.84rem;
  color: var(--muted);
}
.pf-slug :deep(svg) { width: 13px; height: 13px; color: var(--brand-ink); }
.pf-slug strong { color: var(--brand-ink); font-weight: 700; }

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

/* ===== Sections ===== */
.pf-section {
  padding: 22px;
  margin-bottom: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: 0 0 24px rgba(59, 130, 246, 0.06);
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
.pf-section-head-mt { margin-top: 28px; }

.pf-eyebrow-sm {
  font-size: 0.68rem;
  text-transform: uppercase; letter-spacing: 0.14em;
  font-weight: 700; color: var(--muted);
  display: block;
}

/* ===== Floating labels (compartilhado) ===== */
.ff-row {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 10px;
}
.ff-row-2 { grid-template-columns: 1fr 1fr; }
.ff-row-pwd { grid-template-columns: 1fr auto; align-items: stretch; }
.ff { position: relative; margin: 0 0 12px; }
.ff.ff-btn { display: flex; align-items: stretch; margin: 0 0 12px; }
.ff.ff-btn .btn { height: 56px; white-space: nowrap; }
.ff.ff-btn .btn :deep(svg) { width: 15px; height: 15px; }

.ff input, .ff select, .ff textarea {
  padding: 20px 14px 10px;
  min-height: 56px;
  font-size: 1rem;
  width: 100%;
}
.ff textarea { min-height: 92px; padding-top: 24px; resize: vertical; }
.ff select { appearance: none; -webkit-appearance: none; background-position: right 14px center; }

.ff label {
  position: absolute; left: 14px; top: 50%; transform: translateY(-50%);
  color: var(--muted); margin: 0; pointer-events: none;
  transition: top 0.15s ease, font-size 0.15s ease, color 0.15s ease, transform 0.15s ease;
  font-weight: 500;
}
.ff textarea + label { top: 20px; transform: none; }
.ff select + label { top: 10px; transform: translateY(0); font-size: 0.72rem; font-weight: 600; color: var(--brand-ink); letter-spacing: 0.04em; }
.ff input:focus + label,
.ff input:not(:placeholder-shown) + label,
.ff textarea:focus + label,
.ff textarea:not(:placeholder-shown) + label {
  top: 10px; transform: translateY(0);
  font-size: 0.72rem; font-weight: 600;
  color: var(--brand-ink); letter-spacing: 0.04em;
}

/* ===== Identidade visual: grid ===== */
.pf-brand-grid {
  display: grid;
  grid-template-columns: 220px 1fr;
  gap: 20px;
  align-items: start;
  margin-bottom: 14px;
}

/* ===== Dropzone de logo ===== */
.pf-dropzone {
  position: relative;
  aspect-ratio: 1;
  border-radius: 20px;
  border: 2px dashed var(--border);
  background:
    radial-gradient(circle at 50% 40%, var(--brand-soft), transparent 70%),
    rgba(5, 11, 22, 0.4);
  cursor: pointer;
  overflow: hidden;
  display: grid; place-items: center;
  transition: border-color 0.2s ease, background 0.2s ease, transform 0.15s ease;
}
.pf-dropzone:hover { border-color: var(--brand); transform: translateY(-2px); }
.pf-dropzone.hover { border-color: var(--brand); background: var(--brand-soft); }
.pf-dropzone.filled { border-style: solid; }
.pf-dropzone-empty {
  display: flex; flex-direction: column; align-items: center; gap: 4px;
  padding: 16px; text-align: center;
}
.pf-dropzone-icon {
  width: 48px; height: 48px; border-radius: 14px;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
  margin-bottom: 6px;
}
.pf-dropzone-icon :deep(svg) { width: 22px; height: 22px; }
.pf-dropzone-empty strong { font-size: 0.98rem; font-weight: 700; color: var(--text); }
.pf-dropzone-empty small { font-size: 0.78rem; color: var(--silver); line-height: 1.4; }
.pf-dropzone-empty small.muted { font-size: 0.72rem; margin-top: 2px; }

.pf-logo-wrap {
  position: relative;
  width: 100%; height: 100%;
}
.pf-logo { width: 100%; height: 100%; object-fit: cover; display: block; }
.pf-logo-overlay {
  position: absolute; inset: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px;
  background: rgba(5, 11, 22, 0.65);
  color: #fff;
  opacity: 0; transition: opacity 0.2s ease;
}
.pf-logo-overlay :deep(svg) { width: 22px; height: 22px; }
.pf-logo-overlay span { font-size: 0.85rem; font-weight: 700; }
.pf-dropzone:hover .pf-logo-overlay { opacity: 1; }
.pf-dropzone-loading {
  position: absolute; inset: 0;
  display: grid; place-items: center;
  background: rgba(5, 11, 22, 0.7);
  color: #fff; font-weight: 700; font-size: 0.9rem;
  backdrop-filter: blur(2px);
}

/* ===== Brand side: cor atual + hex ===== */
.pf-brand-side { display: flex; flex-direction: column; gap: 12px; }
.pf-current-color {
  padding: 14px 16px;
  border-radius: 14px;
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
}
.pf-current-color-row {
  display: flex; align-items: center; gap: 12px;
  margin-top: 6px;
}
.pf-color-chip {
  width: 42px; height: 42px; border-radius: 12px; flex-shrink: 0;
  box-shadow: 0 0 20px rgba(0, 0, 0, 0.35), inset 0 0 0 1px rgba(255, 255, 255, 0.15);
}
.pf-current-color strong { display: block; font-size: 0.95rem; font-weight: 700; }
.pf-current-color code {
  display: block; margin-top: 2px;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.78rem; color: var(--muted);
  background: none; padding: 0;
}

/* Hex input combinado */
.pf-hex-wrap {
  display: flex; align-items: center;
  border-radius: var(--radius-sm);
  background: var(--input);
  border: 1px solid var(--border);
  overflow: hidden;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.pf-hex-wrap:focus-within { border-color: var(--brand); box-shadow: 0 0 0 3px var(--brand-soft); }
.pf-hex-prefix {
  padding: 0 4px 0 14px;
  color: var(--muted);
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 1rem; font-weight: 700;
}
.pf-hex-wrap input {
  flex: 1; min-width: 0;
  min-height: 48px;
  padding: 10px 10px 10px 2px;
  background: transparent;
  border: none; border-radius: 0;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  letter-spacing: 0.04em;
}
.pf-hex-wrap input:focus { box-shadow: none; outline: none; }
.pf-hex-apply {
  margin: 4px; flex-shrink: 0;
  height: 40px; padding: 0 14px;
  font-size: 0.85rem;
}

/* ===== Paleta ===== */
.pf-palette-field { margin-top: 4px; }
.pf-palette-field > label { display: block; margin-bottom: 10px; }
.pf-palette {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 8px 16px;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.pf-palette-row { display: flex; gap: 4px; }
.pf-swatch {
  flex: 1;
  aspect-ratio: 1;
  min-width: 0;
  max-width: 34px;
  border-radius: 8px;
  border: 2px solid transparent;
  cursor: pointer;
  padding: 0;
  transition: transform 0.12s ease, box-shadow 0.12s ease;
}
.pf-swatch:hover { transform: scale(1.18); z-index: 1; }
.pf-swatch.on {
  border-color: #fff;
  transform: scale(1.1);
  box-shadow: 0 0 0 2px var(--bg), 0 0 14px rgba(255, 255, 255, 0.6);
  z-index: 2;
}

/* ===== Preview "mockup celular" ===== */
.pf-preview-wrap {
  margin-top: 24px;
  padding: 22px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 500px 220px at 50% 0%, var(--brand-soft), transparent 70%),
    rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
}
.pf-preview-label {
  display: inline-flex; align-items: center; gap: 6px;
  margin-bottom: 14px;
}
.pf-preview-label :deep(svg) { width: 13px; height: 13px; }

.pf-phone {
  position: relative;
  max-width: 320px;
  margin: 0 auto;
  padding: 10px;
  border-radius: 32px;
  background: linear-gradient(145deg, #1a2238, #0b1220);
  border: 1px solid var(--border);
  box-shadow: 0 25px 60px rgba(0, 0, 0, 0.5), 0 0 40px var(--brand-glow);
}
.pf-phone-notch {
  position: absolute; top: 14px; left: 50%; transform: translateX(-50%);
  width: 80px; height: 6px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.6);
  z-index: 1;
}
.pf-phone-screen {
  padding: 32px 20px 20px;
  border-radius: 24px;
  background:
    radial-gradient(ellipse 300px 180px at 50% 0%, var(--brand-glow), transparent 70%),
    linear-gradient(160deg, var(--brand-strong), #050b16);
  min-height: 180px;
  color: #fff;
}
.pf-preview-head { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
.pf-preview-logo {
  width: 44px; height: 44px; border-radius: 14px;
  object-fit: cover; background: #fff;
  flex-shrink: 0;
  box-shadow: 0 0 18px var(--brand-glow);
}
.pf-preview-info { min-width: 0; }
.pf-preview-info strong {
  display: block;
  font-size: 1.05rem; font-weight: 800;
  letter-spacing: -0.01em;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.pf-preview-info small { font-size: 0.76rem; color: rgba(255, 255, 255, 0.65); }

.pf-preview-chips { display: flex; gap: 6px; margin-bottom: 14px; flex-wrap: wrap; }
.pf-preview-chip {
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.15);
  font-size: 0.76rem; font-weight: 600;
  color: rgba(255, 255, 255, 0.85);
}
.pf-preview-chip.on {
  background: #fff;
  color: var(--brand);
  border-color: #fff;
  box-shadow: 0 0 14px rgba(255, 255, 255, 0.4);
}
.pf-preview-cta {
  padding: 10px 16px;
  border-radius: 10px;
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: var(--brand-contrast, #fff);
  text-align: center;
  font-weight: 700; font-size: 0.9rem;
  box-shadow: 0 10px 24px var(--brand-glow);
}

/* ===== Foot (botão salvar) ===== */
.pf-foot {
  display: flex; justify-content: flex-end;
  margin-top: 20px;
  padding-top: 20px;
  border-top: 1px solid var(--border);
}
.pf-foot .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Responsive ===== */
@media (max-width: 820px) {
  .pf-brand-grid { grid-template-columns: 1fr; }
  .pf-dropzone { max-width: 240px; margin: 0 auto; }
  .pf-palette { grid-template-columns: 1fr; gap: 10px; }
}

@media (max-width: 640px) {
  .pf-section { padding: 18px; }
  .ff-row, .ff-row-2 { grid-template-columns: 1fr; }
  .ff-row-pwd { grid-template-columns: 1fr; }
  .ff.ff-btn .btn { width: 100%; }
  .pf-dropzone { max-width: 100%; }
  .pf-swatch { max-width: none; }
  .pf-palette { padding: 10px; }
  .pf-slug { font-size: 0.78rem; padding: 6px 12px; }
  .pf-foot .btn { width: 100%; justify-content: center; }
}
</style>
