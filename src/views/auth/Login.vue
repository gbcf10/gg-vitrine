<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { isPlatformAdmin } from '@/lib/session'
import AppLogo from '@/components/AppLogo.vue'
import BackButton from '@/components/BackButton.vue'

const route = useRoute()
const router = useRouter()
const email = ref('')
const password = ref('')
const error = ref('')
const info = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  loading.value = true
  const { error: err } = await supabase.auth.signInWithPassword({ email: email.value, password: password.value })
  loading.value = false
  if (err) {
    error.value = err.message === 'Invalid login credentials' ? 'E-mail ou senha incorretos.' : err.message
    return
  }
  // O dono da plataforma cai direto no painel de administração.
  router.push(route.query.redirect || ((await isPlatformAdmin()) ? '/admin' : '/painel'))
}

async function forgot() {
  error.value = ''
  if (!email.value) {
    error.value = 'Digite seu e-mail para receber o link de recuperação.'
    return
  }
  const { error: err } = await supabase.auth.resetPasswordForEmail(email.value, {
    redirectTo: `${location.origin}/painel/perfil`,
  })
  if (err) error.value = err.message
  else info.value = 'Enviamos um link de recuperação para o seu e-mail.'
}
</script>

<template>
  <div class="narrow">
    <BackButton label="Voltar ao início" />
    <div class="auth-logo"><AppLogo /></div>
    <form class="card glow" @submit.prevent="submit">
      <h3>Entrar no painel</h3>
      <div v-if="error" class="error">{{ error }}</div>
      <div v-if="info" class="success">{{ info }}</div>
      <div class="field">
        <label for="email">E-mail</label>
        <input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>
      <div class="field">
        <label for="password">Senha</label>
        <input id="password" v-model="password" type="password" autocomplete="current-password" required />
      </div>
      <button class="btn block" :disabled="loading">{{ loading ? 'Entrando...' : 'Entrar' }}</button>
      <p style="margin-top: 14px" class="spread">
        <button type="button" class="link-btn" @click="forgot">Esqueci minha senha</button>
        <RouterLink to="/cadastro">Cadastrar estabelecimento</RouterLink>
      </p>
    </form>
  </div>
</template>
