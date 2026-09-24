<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { CATEGORIES, APP_DOMAIN } from '@/config/brand'
import { brandVars } from '@/lib/colors'

const biz = useBusiness()
const form = ref({})
const msg = ref('')
const error = ref('')
const uploading = ref(false)
const newPassword = ref('')

onMounted(() => {
  const b = biz.business
  form.value = {
    name: b.name, category: b.category, description: b.description, phone: b.phone,
    address: b.address, primary_color: b.primary_color, logo_url: b.logo_url,
    slot_interval_min: b.slot_interval_min,
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
        <select v-model="form.category"><option v-for="c in CATEGORIES" :key="c">{{ c }}</option></select>
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
      <div class="field" style="max-width: 200px">
        <label>Intervalo da agenda</label>
        <select v-model.number="form.slot_interval_min">
          <option v-for="m in [10, 15, 20, 30, 45, 60]" :key="m" :value="m">A cada {{ m }} min</option>
        </select>
      </div>
    </div>

    <div class="card" :style="brandVars(form.primary_color)" style="background: rgba(5, 11, 22, 0.6)">
      <small>Prévia da sua página</small>
      <div class="row" style="align-items: center; margin-top: 10px">
        <img v-if="form.logo_url" :src="form.logo_url" alt="" class="shrink" style="width: 44px; height: 44px; border-radius: 12px; object-fit: cover; background: #fff" />
        <strong class="shrink gradient-text" style="font-size: 1.2rem">{{ form.name }}</strong>
        <span class="chip selected shrink">10:00</span>
        <span class="btn shrink" style="pointer-events: none">Confirmar agendamento</span>
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
