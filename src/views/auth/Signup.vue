<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { slugify } from '@/lib/format'
import AppLogo from '@/components/AppLogo.vue'
import { APP_NAME, APP_DOMAIN, CATEGORIES } from '@/config/brand'

const router = useRouter()
const form = ref({ name: '', slug: '', category: CATEGORIES[0], phone: '', ownerName: '', email: '', password: '' })
const slugTouched = ref(false)
const error = ref('')
const done = ref(false)
const loading = ref(false)

watch(() => form.value.name, (name) => {
  if (!slugTouched.value) form.value.slug = slugify(name)
})

async function submit() {
  error.value = ''
  const slug = slugify(form.value.slug)
  if (slug.length < 3) {
    error.value = 'O link precisa ter pelo menos 3 caracteres.'
    return
  }
  loading.value = true
  try {
    const { data: available } = await supabase.rpc('is_slug_available', { p_slug: slug })
    if (available === false) throw new Error(`O link "${slug}" já está em uso. Escolha outro.`)

    // Os dados do estabelecimento vão junto com o cadastro; o banco cria
    // o estabelecimento "em análise" automaticamente (trigger handle_new_user).
    const { data, error: err } = await supabase.auth.signUp({
      email: form.value.email,
      password: form.value.password,
      options: {
        emailRedirectTo: `${location.origin}/painel`,
        data: {
          full_name: form.value.ownerName,
          business_name: form.value.name,
          business_slug: slug,
          business_category: form.value.category,
          business_phone: form.value.phone,
        },
      },
    })
    if (err) throw err
    if (data.session) router.push('/painel')
    else done.value = true
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="narrow" style="max-width: 520px">
    <div class="auth-logo"><AppLogo /></div>

    <div v-if="done" class="card glow">
      <h3>Cadastro recebido!</h3>
      <p>Enviamos um link de confirmação para <strong>{{ form.email }}</strong>.</p>
      <p class="muted">
        Depois de confirmar o e-mail, nossa equipe vai analisar seu cadastro. Assim que for aprovado,
        você escolhe o plano e libera seu painel.
      </p>
    </div>

    <form v-else class="card glow" @submit.prevent="submit">
      <h3>Cadastre seu estabelecimento</h3>
      <div v-if="error" class="error">{{ error }}</div>

      <div class="field">
        <label for="bname">Nome do estabelecimento</label>
        <input id="bname" v-model="form.name" required minlength="2" maxlength="80" />
      </div>
      <div class="field">
        <label for="slug">Seu link de agendamento</label>
        <input id="slug" v-model="form.slug" required @input="slugTouched = true" />
        <small>{{ APP_DOMAIN }}/<strong>{{ form.slug || 'seu-negocio' }}</strong></small>
      </div>
      <div class="row">
        <div class="field">
          <label for="cat">Segmento</label>
          <select id="cat" v-model="form.category">
            <option v-for="c in CATEGORIES" :key="c">{{ c }}</option>
          </select>
        </div>
        <div class="field">
          <label for="phone">WhatsApp</label>
          <input id="phone" v-model="form.phone" type="tel" placeholder="(11) 99999-9999" required />
        </div>
      </div>

      <hr />

      <div class="field">
        <label for="owner">Seu nome</label>
        <input id="owner" v-model="form.ownerName" required />
      </div>
      <div class="field">
        <label for="email">E-mail</label>
        <input id="email" v-model="form.email" type="email" autocomplete="email" required />
      </div>
      <div class="field">
        <label for="pw">Senha</label>
        <input id="pw" v-model="form.password" type="password" minlength="8" autocomplete="new-password" required />
        <small>Mínimo de 8 caracteres.</small>
      </div>

      <button class="btn block" :disabled="loading">{{ loading ? 'Enviando...' : 'Solicitar cadastro' }}</button>
      <p class="muted" style="margin-top: 12px; font-size: 0.875rem">
        Já tem conta? <RouterLink to="/entrar">Entrar</RouterLink>
      </p>
    </form>
  </div>
</template>
