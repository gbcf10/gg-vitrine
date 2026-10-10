<script setup>
import { ref, watch, computed } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { slugify } from '@/lib/format'
import AppLogo from '@/components/AppLogo.vue'
import BackButton from '@/components/BackButton.vue'
import Icon from '@/components/Icon.vue'
import { APP_DOMAIN, CATEGORIES } from '@/config/brand'

const router = useRouter()
const form = ref({ name: '', slug: '', category: CATEGORIES[0], phone: '', ownerName: '', email: '', password: '', accepted: false })

const slugTouched = ref(false)
const error = ref('')
const codeSent = ref(false)
const code = ref('')
const loading = ref(false)
const verifying = ref(false)
const showPassword = ref(false)
const resendCooldown = ref(0)

watch(() => form.value.name, (name) => {
  if (!slugTouched.value) form.value.slug = slugify(name)
})

const slugPreview = computed(() => slugify(form.value.slug) || 'seu-negocio')

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
          terms_accepted_at: new Date().toISOString(),
        },
      },
    })
    if (err) throw err
    if (data.session) router.push('/painel')
    else { codeSent.value = true; startResendCooldown() }
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

async function verifyCode() {
  error.value = ''
  verifying.value = true
  try {
    const { error: err } = await supabase.auth.verifyOtp({
      email: form.value.email,
      token: code.value.trim(),
      type: 'signup',
    })
    if (err) throw new Error('Código inválido ou expirado. Confira o e-mail e tente de novo.')
    router.push('/painel')
  } catch (e) {
    error.value = e.message
  } finally {
    verifying.value = false
  }
}

async function resendCode() {
  if (resendCooldown.value > 0) return
  error.value = ''
  const { error: err } = await supabase.auth.resend({ type: 'signup', email: form.value.email })
  if (err) { error.value = err.message; return }
  startResendCooldown()
}

function startResendCooldown() {
  resendCooldown.value = 30
  const t = setInterval(() => {
    resendCooldown.value--
    if (resendCooldown.value <= 0) clearInterval(t)
  }, 1000)
}
</script>

<template>
  <div class="auth-page">
    <div class="auth-bg" aria-hidden="true">
      <div class="auth-grid-lines" />
      <div class="auth-orb orb-a" />
      <div class="auth-orb orb-b" />
    </div>

    <div class="signup-shell">
      <header class="signup-top">
        <BackButton label="Voltar" />
        <AppLogo />
      </header>

      <div class="signup-head" v-if="!codeSent">
        <div class="hero-pill">
          <span class="dot-live" />
          Cadastro gratuito · leva 2 minutos
        </div>
        <h1 class="signup-title">
          Coloque sua vitrine<br />
          <span class="gradient-text">no ar hoje mesmo.</span>
        </h1>
        <p class="signup-sub muted">
          Preencha os dados do seu negócio e crie sua conta de acesso em 2 passos.
        </p>
      </div>

      <!-- Tela de verificação por código -->
      <div v-if="codeSent" class="done-wrap">
        <form class="done-card" @submit.prevent="verifyCode">
          <div class="done-icon-wrap">
            <div class="done-icon-ring" />
            <div class="done-icon-core"><Icon name="mail" /></div>
          </div>
          <h2 class="done-title">Confirme seu e-mail</h2>
          <p class="done-text">
            Enviamos um código de 6 dígitos pra
            <strong>{{ form.email }}</strong>.
          </p>

          <div v-if="error" class="auth-alert error" style="margin: 12px 0">
            <span class="auth-alert-icon"><Icon name="ban" /></span>
            <span>{{ error }}</span>
          </div>

          <div class="ff" style="margin: 18px 0 10px">
            <input id="otp" v-model="code" inputmode="numeric" autocomplete="one-time-code"
                   maxlength="8" required placeholder=" "
                   style="font-size: 1.6rem; letter-spacing: 0.4em; text-align: center; font-weight: 700" />
            <label for="otp">Código do e-mail</label>
          </div>

          <button class="btn block" :disabled="verifying || code.length < 6">
            {{ verifying ? 'Confirmando...' : 'Confirmar e entrar' }}
          </button>

          <p class="muted" style="margin-top: 14px; font-size: 0.85rem; text-align: center">
            Não recebeu?
            <button type="button" class="link-btn" :disabled="resendCooldown > 0" @click="resendCode">
              {{ resendCooldown > 0 ? `Reenviar em ${resendCooldown}s` : 'Reenviar código' }}
            </button>
          </p>
        </form>
      </div>

      <!-- Formulário -->
      <form v-else class="signup-form" @submit.prevent="submit">
        <transition name="auth-msg">
          <div v-if="error" class="auth-alert error">
            <span class="auth-alert-icon"><Icon name="ban" /></span>
            <span>{{ error }}</span>
          </div>
        </transition>

        <!-- Bloco 1: Negócio -->
        <section class="form-section">
          <div class="section-head">
            <div class="section-badge"><Icon name="store" /></div>
            <div>
              <p class="eyebrow">Passo 1</p>
              <h2 class="section-title">Sobre o negócio</h2>
            </div>
          </div>

          <div class="float-field" :class="{ filled: form.name }">
            <input id="bname" v-model="form.name" required minlength="2" maxlength="80" placeholder=" " />
            <label for="bname">
              <Icon name="store" />
              Nome do estabelecimento
            </label>
          </div>

          <!-- Preview do slug: visual, não <small> -->
          <div class="field slug-field">
            <label for="slug" class="slug-label">
              <Icon name="link" />
              Seu link
            </label>
            <div class="slug-input-wrap" :class="{ focus: false }">
              <span class="slug-prefix">{{ APP_DOMAIN }}/</span>
              <input id="slug" v-model="form.slug" required @input="slugTouched = true" placeholder="seu-negocio" />
            </div>
            <div class="slug-preview">
              <span class="slug-preview-dots" aria-hidden="true">
                <span /><span /><span />
              </span>
              <code>{{ APP_DOMAIN }}/<strong>{{ slugPreview }}</strong></code>
            </div>
          </div>

          <div class="field-grid">
            <div class="float-field filled">
              <select id="cat" v-model="form.category">
                <option v-for="c in CATEGORIES" :key="c">{{ c }}</option>
              </select>
              <label for="cat">
                <Icon name="tag" />
                Segmento
              </label>
            </div>
            <div class="float-field" :class="{ filled: form.phone }">
              <input id="phone" v-model="form.phone" type="tel" required placeholder=" " />
              <label for="phone">
                <Icon name="whatsapp" />
                WhatsApp
              </label>
            </div>
          </div>
        </section>

        <!-- Separador visual com rótulo -->
        <div class="section-divider">
          <span />
          <small>e</small>
          <span />
        </div>

        <!-- Bloco 2: Conta -->
        <section class="form-section">
          <div class="section-head">
            <div class="section-badge"><Icon name="key" /></div>
            <div>
              <p class="eyebrow">Passo 2</p>
              <h2 class="section-title">Sua conta de acesso</h2>
            </div>
          </div>

          <div class="float-field" :class="{ filled: form.ownerName }">
            <input id="owner" v-model="form.ownerName" required placeholder=" " />
            <label for="owner">
              <Icon name="contact" />
              Seu nome
            </label>
          </div>

          <div class="float-field" :class="{ filled: form.email }">
            <input id="email" v-model="form.email" type="email" autocomplete="email" required placeholder=" " />
            <label for="email">
              <Icon name="mail" />
              E-mail
            </label>
          </div>

          <div class="float-field password-field pwd-field" :class="{ filled: form.password }">
            <input id="pw" v-model="form.password" :type="showPassword ? 'text' : 'password'" minlength="8" autocomplete="new-password" required placeholder=" " />
            <label for="pw">
              <Icon name="key" />
              Senha
            </label>
            <button type="button" class="pwd-toggle" :aria-label="showPassword ? 'Ocultar senha' : 'Mostrar senha'" @click="showPassword = !showPassword">
              <Icon :name="showPassword ? 'eye-off' : 'eye'" />
            </button>
            <small class="field-hint">Mínimo de 8 caracteres</small>
          </div>

          <label class="accept-row">
            <input v-model="form.accepted" type="checkbox" required />
            <span>
              Li e aceito os
              <RouterLink to="/termos" target="_blank">Termos de uso</RouterLink>
              e a
              <RouterLink to="/privacidade" target="_blank">Política de privacidade</RouterLink>.
            </span>
          </label>
        </section>

        <button class="btn block btn-submit" :disabled="loading || !form.accepted">
          <span v-if="loading" class="btn-spinner" aria-hidden="true" />
          {{ loading ? 'Criando conta...' : 'Criar minha conta' }}
        </button>

        <div class="form-foot">
          <span class="muted">Já tem conta?</span>
          <RouterLink to="/entrar" class="form-foot-link">Entrar no painel</RouterLink>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* =====================================================================
   Shell geral (compartilha linguagem com Login)
   ===================================================================== */
.auth-page {
  position: relative;
  min-height: 100vh;
  isolation: isolate;
  overflow: hidden;
}
.auth-bg {
  position: absolute; inset: 0; z-index: -1; pointer-events: none;
}
.auth-grid-lines {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(148, 180, 220, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 180, 220, 0.05) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 80% 50% at 50% 0%, #000 30%, transparent 85%);
  -webkit-mask-image: radial-gradient(ellipse 80% 50% at 50% 0%, #000 30%, transparent 85%);
}
.auth-orb {
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

.signup-shell {
  width: min(640px, calc(100% - 32px));
  margin: 0 auto;
  padding: 24px 0 56px;
}

.signup-top {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
  margin-bottom: 36px;
}

.signup-head {
  text-align: center;
  max-width: 540px;
  margin: 0 auto 32px;
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
  margin-bottom: 20px;
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
.signup-title {
  font-size: clamp(1.8rem, 4.2vw, 2.6rem);
  font-weight: 800;
  line-height: 1.08;
  letter-spacing: -0.03em;
  margin: 0 0 14px;
}
.signup-sub { font-size: 1rem; line-height: 1.55; margin: 0 auto; max-width: 460px; }

/* =====================================================================
   Form card (envelope único; blocos internos separados visualmente)
   ===================================================================== */
.signup-form {
  background:
    radial-gradient(ellipse 500px 240px at 100% 0%, rgba(59, 130, 246, 0.12), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 32px;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.08);
  position: relative;
}

.form-section + .form-section { margin-top: 8px; }

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
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.015em;
  margin: 0;
}

/* Divider "e" entre blocos */
.section-divider {
  display: flex; align-items: center; gap: 12px;
  margin: 32px 0;
  color: var(--muted);
}
.section-divider span {
  flex: 1; height: 1px;
  background: linear-gradient(90deg, transparent, var(--border), transparent);
}
.section-divider small {
  font-size: 0.7rem; letter-spacing: 0.2em;
  text-transform: uppercase; font-weight: 700;
  color: var(--muted);
  padding: 2px 10px;
  border-radius: 999px;
  background: var(--surface);
  border: 1px solid var(--border);
}

/* =====================================================================
   Alertas inline
   ===================================================================== */
.auth-alert {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  border: 1px solid;
  font-size: 0.9rem;
  line-height: 1.4;
  margin-bottom: 20px;
}
.auth-alert.error {
  color: #fecaca;
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.35);
}
.auth-alert-icon {
  width: 20px; height: 20px; flex-shrink: 0;
  display: grid; place-items: center;
  margin-top: 1px;
}
.auth-alert-icon :deep(svg) { width: 16px; height: 16px; stroke-width: 2.4; }
.auth-msg-enter-active, .auth-msg-leave-active { transition: opacity 0.2s ease, transform 0.2s ease; }
.auth-msg-enter-from, .auth-msg-leave-to { opacity: 0; transform: translateY(-4px); }

/* =====================================================================
   Floating-label fields
   ===================================================================== */
.float-field {
  position: relative;
  margin-bottom: 14px;
}
.float-field input,
.float-field select {
  width: 100%;
  min-width: 0;
  padding: 22px 14px 10px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  color: var(--text);
  font: inherit;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
  box-sizing: border-box;
}
.float-field select {
  appearance: none;
  -webkit-appearance: none;
  padding-right: 38px;
  background-image: url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8' fill='none' stroke='%2394a3b8' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M1 1.5l5 5 5-5'/></svg>");
  background-repeat: no-repeat;
  background-position: right 14px center;
}
.float-field { min-width: 0; }
.float-field input:hover,
.float-field select:hover { border-color: var(--border-strong); }
.float-field input:focus,
.float-field select:focus {
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

.password-field { margin-bottom: 10px; }
.field-hint {
  display: block;
  margin: 6px 2px 0;
  font-size: 0.78rem;
  color: var(--muted);
}

/* Grid 2 colunas (segmento + whatsapp) */
.field-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.field-grid .field { margin-bottom: 14px; }
.field-grid .float-field { margin-bottom: 14px; }

.field label {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 0.85rem; font-weight: 600;
  color: var(--silver);
  margin-bottom: 8px;
}
.field label :deep(svg) {
  width: 14px; height: 14px;
  color: var(--brand-ink);
}

/* =====================================================================
   Slug: prefixo embutido + preview visual (tipo URL bar)
   ===================================================================== */
.slug-field { margin-bottom: 18px; }
.slug-label { margin-bottom: 8px; }

.slug-input-wrap {
  display: flex; align-items: stretch;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  overflow: hidden;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
}
.slug-input-wrap:hover { border-color: var(--border-strong); }
.slug-input-wrap:focus-within {
  border-color: var(--brand);
  background: rgba(5, 11, 22, 0.75);
  box-shadow: 0 0 0 3px var(--brand-soft);
}
.slug-prefix {
  display: inline-flex; align-items: center;
  padding: 0 2px 0 14px;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.92rem;
  color: var(--muted);
  user-select: none;
  white-space: nowrap;
}
.slug-input-wrap input {
  flex: 1;
  padding: 12px 14px 12px 2px;
  border: none;
  background: transparent;
  color: var(--text);
  font: inherit;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.92rem;
}
.slug-input-wrap input:focus { outline: none; box-shadow: none; }

.slug-preview {
  display: flex; align-items: center; gap: 10px;
  margin-top: 10px;
  padding: 10px 14px;
  border-radius: 10px;
  background: rgba(5, 11, 22, 0.6);
  border: 1px solid var(--border);
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.82rem;
  color: var(--silver);
}
.slug-preview code { background: none; padding: 0; color: var(--muted); }
.slug-preview code strong { color: var(--brand-ink); font-weight: 600; }
.slug-preview-dots {
  display: inline-flex; gap: 5px; align-items: center;
  flex-shrink: 0;
}
.slug-preview-dots span {
  width: 8px; height: 8px; border-radius: 50%;
  background: rgba(148, 180, 220, 0.3);
}
.slug-preview-dots span:nth-child(1) { background: rgba(248, 113, 113, 0.6); }
.slug-preview-dots span:nth-child(2) { background: rgba(251, 191, 36, 0.6); }
.slug-preview-dots span:nth-child(3) { background: rgba(74, 222, 128, 0.6); }

/* =====================================================================
   Accept (termos)
   ===================================================================== */
.accept-row {
  display: flex !important;
  gap: 12px;
  align-items: flex-start;
  margin: 16px 0 0;
  padding: 14px 16px;
  background: rgba(5, 11, 22, 0.4);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  font-weight: 400;
  color: var(--silver);
  line-height: 1.5;
  font-size: 0.9rem;
  cursor: pointer;
  transition: border-color 0.18s ease;
}
.accept-row:hover { border-color: var(--border-strong); }
.accept-row input { margin-top: 3px; flex-shrink: 0; }

/* =====================================================================
   Submit
   ===================================================================== */
.btn-submit {
  margin-top: 24px;
  padding: 14px 22px;
  font-size: 1rem;
}
.btn-spinner {
  width: 16px; height: 16px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

.form-foot {
  display: flex; justify-content: center; align-items: center; gap: 6px;
  flex-wrap: wrap;
  margin-top: 18px;
  font-size: 0.9rem;
}
.form-foot-link { font-weight: 600; }

/* =====================================================================
   Tela "cadastro recebido"
   ===================================================================== */
.done-wrap { padding-top: 24px; }
.done-card {
  background:
    radial-gradient(ellipse 400px 240px at 50% 0%, rgba(59, 130, 246, 0.18), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 48px 32px;
  text-align: center;
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.12);
}
.done-icon-wrap {
  position: relative;
  width: 84px; height: 84px;
  margin: 0 auto 24px;
}
.done-icon-ring {
  position: absolute; inset: 0;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.35), transparent 70%);
  animation: ringPulse 2.4s ease-in-out infinite;
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.15); opacity: 0.3; }
}
.done-icon-core {
  position: absolute; inset: 10px;
  border-radius: 50%;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px rgba(59, 130, 246, 0.5);
}
.done-icon-core :deep(svg) { width: 28px; height: 28px; }
.done-title {
  font-size: 1.6rem; font-weight: 800;
  letter-spacing: -0.02em;
  margin: 0 0 12px;
}
.done-text { font-size: 0.95rem; margin: 0 0 10px; line-height: 1.55; }
.done-card .btn { margin-top: 20px; }

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 640px) {
  .signup-form { padding: 24px 20px; }
  .section-head { gap: 12px; margin-bottom: 18px; }
  .section-badge { width: 40px; height: 40px; border-radius: 12px; }
  .section-badge :deep(svg) { width: 18px; height: 18px; }
  .field-grid { grid-template-columns: 1fr; gap: 0; }
  .signup-head { margin-bottom: 24px; }
  .signup-top { margin-bottom: 24px; }
  .done-card { padding: 36px 22px; }
}

@media (max-width: 420px) {
  .signup-shell { padding: 16px 0 40px; width: calc(100% - 24px); }
  .signup-form { padding: 22px 16px; border-radius: 16px; }
  .section-divider { margin: 24px 0; }
  .slug-prefix { padding-left: 12px; font-size: 0.84rem; }
  .slug-input-wrap input { font-size: 0.84rem; }
  .slug-preview { font-size: 0.76rem; padding: 10px 12px; }
}
</style>
