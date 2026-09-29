<script setup>
import { ref, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { CATEGORIES_BY_KIND, APP_DOMAIN, STAFF_LABELS, KINDS } from '@/config/brand'
import { brandVars } from '@/lib/colors'

const biz = useBusiness()
const form = ref({})
const msg = ref('')
const error = ref('')
const uploading = ref(false)
const newPassword = ref('')

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

async function uploadLogo(event) {
  const file = event.target.files[0]
  if (!file) return
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

async function changePassword() {
  msg.value = error.value = ''
  const { error: err } = await supabase.auth.updateUser({ password: newPassword.value })
  if (err) error.value = err.message
  else { msg.value = 'Senha alterada.'; newPassword.value = '' }
}
</script>

<template>
  <div class="page-header"><h1>Perfil do estabelecimento</h1></div>
  <div v-if="error" class="error">{{ error }}</div>
  <div v-if="msg" class="success">{{ msg }}</div>

  <form class="card" @submit.prevent="save">
    <p class="muted">Seu link: {{ APP_DOMAIN }}/<strong>{{ biz.business.slug }}</strong></p>
    <div class="row">
      <div class="field"><label>Nome</label><input v-model="form.name" required /></div>
      <div class="field">
        <label>Segmento</label>
        <select v-model="form.category"><option v-for="c in CATEGORIES_BY_KIND[biz.business.kind]" :key="c">{{ c }}</option></select>
      </div>
    </div>
    <div class="field"><label>Descrição</label><textarea v-model="form.description" rows="3" /></div>
    <div class="row">
      <div class="field"><label>WhatsApp</label><input v-model="form.phone" type="tel" /></div>
      <div class="field"><label>Endereço</label><input v-model="form.address" /></div>
    </div>

    <div class="row">
      <div class="field">
        <label>Logo</label>
        <div class="row" style="align-items: center">
          <img v-if="form.logo_url" :src="form.logo_url" alt="Logo"
               class="shrink" style="width: 56px; height: 56px; border-radius: 10px; object-fit: cover" />
          <input type="file" accept="image/png,image/jpeg,image/webp" @change="uploadLogo" />
        </div>
        <small v-if="uploading">Enviando...</small>
      </div>
      <div class="field" style="max-width: 160px">
        <label>Cor principal</label>
        <input v-model="form.primary_color" type="color" />
      </div>
      <div v-if="biz.business.kind === 'agenda'" class="field" style="max-width: 200px">
        <label>Quem atende <small>(nome na vitrine)</small></label>
        <input v-model="form.staff_label" list="staff-labels" maxlength="30" required />
        <datalist id="staff-labels"><option v-for="l in STAFF_LABELS" :key="l" :value="l" /></datalist>
      </div>
      <div v-if="biz.business.kind === 'agenda'" class="field" style="max-width: 200px">
        <label>Intervalo da agenda</label>
        <select v-model.number="form.slot_interval_min">
          <option v-for="m in [10, 15, 20, 30, 45, 60]" :key="m" :value="m">A cada {{ m }} min</option>
        </select>
      </div>
    </div>

    <div class="field">
      <label>Todas as cores <small>(clique para escolher)</small></label>
      <div class="palette">
        <div v-for="[name, shades] in PALETTE" :key="name" class="palette-row" :title="name">
          <button v-for="c in shades" :key="c" type="button" class="swatch" :style="{ background: c }"
                  :class="{ on: form.primary_color?.toLowerCase() === c }" :aria-label="`${name} ${c}`" @click="form.primary_color = c" />
        </div>
      </div>
    </div>
    <div class="field" style="max-width: 320px">
      <label>Código da cor da sua marca <small>(ex.: #FF5733)</small></label>
      <div class="row">
        <input v-model="hexInput" maxlength="7" placeholder="#FF5733" style="text-transform: uppercase" @keydown.enter.prevent="applyHex" />
        <button type="button" class="btn secondary shrink" @click="applyHex">Usar</button>
      </div>
    </div>

    <div class="card" :style="brandVars(form.primary_color)" style="background: rgba(5, 11, 22, 0.6)">
      <small>Prévia da sua página</small>
      <div class="row" style="align-items: center; margin-top: 10px">
        <img v-if="form.logo_url" :src="form.logo_url" alt="" class="shrink" style="width: 44px; height: 44px; border-radius: 12px; object-fit: cover; background: #fff" />
        <strong class="shrink gradient-text" style="font-size: 1.2rem">{{ form.name }}</strong>
        <span class="chip selected shrink">{{ biz.business.kind === 'agenda' ? '10:00' : 'Opção' }}</span>
        <span class="btn shrink" style="pointer-events: none">{{ KINDS[biz.business.kind].action }}</span>
      </div>
    </div>

    <button class="btn" style="margin-top: 16px">Salvar</button>
  </form>

  <form class="card" @submit.prevent="changePassword">
    <h3>Alterar senha</h3>
    <div class="row">
      <div class="field"><input v-model="newPassword" type="password" minlength="8" placeholder="Nova senha" autocomplete="new-password" required /></div>
      <div class="field shrink"><button class="btn secondary">Alterar</button></div>
    </div>
  </form>
</template>

<style scoped>
.palette { display: grid; grid-template-columns: repeat(auto-fill, minmax(236px, 1fr)); gap: 6px 14px; }
.palette-row { display: flex; gap: 4px; }
.swatch { width: 30px; height: 30px; border-radius: 8px; border: 2px solid transparent; cursor: pointer; padding: 0; transition: transform 0.12s ease; }
.swatch:hover { transform: scale(1.15); z-index: 1; }
.swatch.on { border-color: #fff; box-shadow: 0 0 0 2px var(--bg), 0 0 12px rgba(255, 255, 255, 0.5); }
</style>
