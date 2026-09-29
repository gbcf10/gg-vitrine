<script setup>
import { ref, computed, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { slugify } from '@/lib/format'
import AppLogo from '@/components/AppLogo.vue'
import { APP_DOMAIN, KINDS, CATEGORIES_BY_KIND } from '@/config/brand'
import Icon from '@/components/Icon.vue'

const router = useRouter()
const form = ref({ kind: 'agenda', name: '', slug: '', category: CATEGORIES_BY_KIND.agenda[0], phone: '', ownerName: '', email: '', password: '' })
const categories = computed(() => CATEGORIES_BY_KIND[form.value.kind])

watch(() => form.value.kind, (kind) => { form.value.category = CATEGORIES_BY_KIND[kind][0] })
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
          business_kind: form.value.kind,
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
  <div class="narrow" style="width: min(640px, calc(100% - 32px))">
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
        <label>Como seus clientes vão usar sua vitrine?</label>
        <div class="kind-grid">
          <button v-for="(k, key) in KINDS" :key="key" type="button" class="kind-option"
                  :class="{ selected: form.kind === key }" @click="form.kind = key">
            <Icon :name="k.icon" />
            <strong>{{ k.label }}</strong>
            <small>{{ k.description }}</small>
          </button>
        </div>
      </div>

      <div class="field">
        <label for="bname">Nome do estabelecimento</label>
        <input id="bname" v-model="form.name" required minlength="2" maxlength="80" />
      </div>
      <div class="field">
        <label for="slug">Seu link</label>
        <input id="slug" v-model="form.slug" required @input="slugTouched = true" />
        <small>{{ APP_DOMAIN }}/<strong>{{ form.slug || 'seu-negocio' }}</strong></small>
      </div>
      <div class="row">
        <div class="field">
          <label for="cat">Segmento</label>
          <select id="cat" v-model="form.category">
            <option v-for="c in categories" :key="c">{{ c }}</option>
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

<style scoped>
.kind-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 10px; }
.kind-option {
  display: flex; flex-direction: column; align-items: flex-start; gap: 4px; text-align: left;
  padding: 14px; border-radius: var(--radius-sm); border: 1px solid var(--border);
  background: var(--surface); color: var(--text); font: inherit; cursor: pointer;
  transition: border-color 0.15s ease, background 0.15s ease, box-shadow 0.15s ease;
}
.kind-option svg { width: 24px; height: 24px; color: var(--silver); margin-bottom: 4px; }
.kind-option small { font-size: 0.78rem; line-height: 1.35; }
.kind-option:hover { border-color: var(--brand); }
.kind-option.selected { border-color: var(--brand); background: var(--brand-soft); box-shadow: 0 0 18px var(--brand-soft); }
.kind-option.selected svg { color: var(--brand-ink); }
@media (max-width: 480px) { .kind-grid { grid-template-columns: 1fr; } }
</style>
