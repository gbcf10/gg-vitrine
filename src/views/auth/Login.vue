<script setup>
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { isPlatformAdmin } from '@/lib/session'
import AppLogo from '@/components/AppLogo.vue'
import BackButton from '@/components/BackButton.vue'
import Icon from '@/components/Icon.vue'
import { APP_DOMAIN } from '@/config/brand'

const route = useRoute()
const router = useRouter()
const mode = ref('password')     // 'password' | 'code'
const email = ref('')
const password = ref('')
const code = ref('')
const codeSent = ref(false)
const error = ref('')
const info = ref('')
const loading = ref(false)
const resendIn = ref(0)
const showPassword = ref(false)

function switchMode(m) {
  mode.value = m
  error.value = info.value = ''
  codeSent.value = false
  code.value = ''
}

function startResendTimer() {
  resendIn.value = 60
  const t = setInterval(() => {
    resendIn.value--
    if (resendIn.value <= 0) clearInterval(t)
  }, 1000)
}

async function submit() {
  error.value = info.value = ''
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

async function sendCode() {
  error.value = info.value = ''
  if (!email.value) { error.value = 'Digite seu e-mail.'; return }
  loading.value = true
  const { error: err } = await supabase.auth.signInWithOtp({
    email: email.value,
    options: { shouldCreateUser: false },
  })
  loading.value = false
  if (err) {
    error.value = /not found/i.test(err.message)
      ? 'Não encontramos uma conta com esse e-mail.'
      : err.message
    return
  }
  codeSent.value = true
  startResendTimer()
}

async function verifyCode() {
  error.value = ''
  loading.value = true
  const { error: err } = await supabase.auth.verifyOtp({
    email: email.value, token: code.value.trim(), type: 'email',
  })
  loading.value = false
  if (err) { error.value = 'Código inválido ou expirado.'; return }
  router.push(route.query.redirect || '/painel')
}

async function resendCode() {
  if (resendIn.value > 0 || loading.value) return
  await sendCode()
}

function changeEmail() {
  codeSent.value = false
  code.value = ''
  resendIn.value = 0
  error.value = ''
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
  <div class="auth-page">
    <div class="auth-bg" aria-hidden="true">
      <div class="auth-grid-lines" />
      <div class="auth-orb orb-a" />
      <div class="auth-orb orb-b" />
    </div>

    <div class="auth-shell">
      <!-- Lado esquerdo: pitch da marca -->
      <aside class="auth-pitch" aria-hidden="true">
        <div class="auth-top">
          <AppLogo />
        </div>

        <div class="pitch-body">
          <div class="hero-pill">
            <span class="dot-live" />
            Bem-vindo de volta
          </div>
          <h1 class="pitch-title">
            Sua vitrine está<br />
            <span class="gradient-text">esperando você.</span>
          </h1>
          <p class="pitch-sub">
            Entre no painel pra conferir os agendamentos de hoje, ajustar horários
            e manter sua agenda sempre em dia.
          </p>

          <ul class="pitch-list">
            <li>
              <span class="pitch-check"><Icon name="check" /></span>
              Agenda em tempo real
            </li>
            <li>
              <span class="pitch-check"><Icon name="check" /></span>
              Lembretes automáticos no WhatsApp
            </li>
            <li>
              <span class="pitch-check"><Icon name="check" /></span>
              Seu link em <strong>{{ APP_DOMAIN }}</strong>
            </li>
          </ul>
        </div>

        <div class="pitch-foot muted">Um produto G&amp;G Soluções</div>
      </aside>

      <!-- Lado direito: formulário -->
      <main class="auth-form-side">
        <div class="auth-form-top">
          <BackButton label="Voltar" />
          <div class="auth-logo-sm"><AppLogo /></div>
        </div>

        <div class="auth-form-wrap">
          <div class="auth-card">
            <div class="form-head">
              <p class="eyebrow">Acessar painel</p>
              <h2 class="form-title">Entrar na sua conta</h2>
            </div>

            <!-- Tabs: senha vs código -->
            <div class="mode-tabs" role="tablist">
              <button type="button" role="tab" class="mode-tab" :class="{ on: mode === 'password' }" @click="switchMode('password')">
                <Icon name="key" />
                Com senha
              </button>
              <button type="button" role="tab" class="mode-tab" :class="{ on: mode === 'code' }" @click="switchMode('code')">
                <Icon name="mail" />
                Com código no e-mail
              </button>
            </div>

            <transition name="auth-msg">
              <div v-if="error" class="auth-alert error">
                <span class="auth-alert-icon"><Icon name="ban" /></span>
                <span>{{ error }}</span>
              </div>
            </transition>
            <transition name="auth-msg">
              <div v-if="info" class="auth-alert success">
                <span class="auth-alert-icon"><Icon name="check" /></span>
                <span>{{ info }}</span>
              </div>
            </transition>

            <!-- Modo senha -->
            <form v-if="mode === 'password'" @submit.prevent="submit">
              <div class="float-field" :class="{ filled: email }">
                <input id="email" v-model="email" type="email" autocomplete="email" required placeholder=" " />
                <label for="email"><Icon name="mail" />E-mail</label>
              </div>
              <div class="float-field pwd-field" :class="{ filled: password }">
                <input id="password" v-model="password" :type="showPassword ? 'text' : 'password'" autocomplete="current-password" required placeholder=" " />
                <label for="password"><Icon name="key" />Senha</label>
                <button type="button" class="pwd-toggle" :aria-label="showPassword ? 'Ocultar senha' : 'Mostrar senha'" @click="showPassword = !showPassword">
                  <Icon :name="showPassword ? 'eye-off' : 'eye'" />
                </button>
              </div>
              <div class="form-row-helper">
                <button type="button" class="link-btn" @click="forgot">Esqueci minha senha</button>
              </div>
              <button class="btn block btn-submit" :disabled="loading">
                <span v-if="loading" class="btn-spinner" aria-hidden="true" />
                {{ loading ? 'Entrando...' : 'Entrar no painel' }}
              </button>
            </form>

            <!-- Modo código: pede e-mail -->
            <form v-else-if="!codeSent" @submit.prevent="sendCode">
              <p class="muted" style="margin: 0 0 12px; font-size: 0.9rem">
                Enviamos um código pro seu e-mail. Útil se você não tem senha ainda (ex: já agendou nessa plataforma antes).
              </p>
              <div class="float-field" :class="{ filled: email }">
                <input id="email-otp" v-model="email" type="email" autocomplete="email" required placeholder=" " />
                <label for="email-otp"><Icon name="mail" />E-mail</label>
              </div>
              <button class="btn block btn-submit" :disabled="loading">
                <span v-if="loading" class="btn-spinner" aria-hidden="true" />
                {{ loading ? 'Enviando...' : 'Enviar código' }}
              </button>
            </form>

            <!-- Modo código: pede o código -->
            <div v-else class="otp-block">
              <div class="otp-sent">
                <div class="otp-sent-icon"><Icon name="check" /></div>
                <div class="otp-sent-text">
                  <strong>Código enviado!</strong>
                  <small>Confira sua caixa de entrada <strong>e o spam</strong>. Enviado pra <strong>{{ email }}</strong>.</small>
                </div>
                <button type="button" class="link-btn otp-change" @click="changeEmail">Trocar</button>
              </div>
              <form @submit.prevent="verifyCode" class="otp-form">
                <label class="otp-label" for="otp-input">Cole aqui o código do e-mail</label>
                <input id="otp-input" v-model="code" inputmode="numeric" autocomplete="one-time-code"
                       maxlength="8" required class="otp-input" placeholder="________" />
                <button class="btn block btn-submit" :disabled="loading || code.length < 6">
                  <span v-if="loading" class="btn-spinner" aria-hidden="true" />
                  {{ loading ? 'Verificando...' : 'Entrar' }}
                </button>
                <p class="otp-resend">
                  Não recebeu?
                  <button type="button" class="link-btn" :disabled="resendIn > 0 || loading" @click="resendCode">
                    {{ resendIn > 0 ? `Reenviar em ${resendIn}s` : 'Reenviar código' }}
                  </button>
                </p>
              </form>
            </div>

            <div class="form-foot">
              <span class="muted">Ainda não tem conta?</span>
              <RouterLink to="/cadastro" class="form-foot-link">Cadastrar estabelecimento</RouterLink>
            </div>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>

<style scoped>
/* =====================================================================
   Shell geral da página
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
  mask-image: radial-gradient(ellipse 70% 60% at 30% 30%, #000 40%, transparent 85%);
  -webkit-mask-image: radial-gradient(ellipse 70% 60% at 30% 30%, #000 40%, transparent 85%);
}
.auth-orb {
  position: absolute; border-radius: 50%; filter: blur(70px); opacity: 0.5;
  animation: orbFloat 14s ease-in-out infinite;
}
.orb-a {
  width: 540px; height: 540px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.45), transparent 65%);
  top: -160px; left: -120px;
}
.orb-b {
  width: 440px; height: 440px;
  background: radial-gradient(circle, rgba(29, 78, 216, 0.35), transparent 65%);
  bottom: -180px; right: -80px;
  animation-delay: -7s;
}
@keyframes orbFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(20px, -20px) scale(1.05); }
}

.auth-shell {
  display: grid;
  grid-template-columns: 1.05fr 1fr;
  min-height: 100vh;
  width: min(1200px, 100%);
  margin: 0 auto;
  padding: 0 24px;
  gap: 48px;
}

/* =====================================================================
   Lado esquerdo (pitch)
   ===================================================================== */
.auth-pitch {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 32px 0 48px;
  min-width: 0;
}
.auth-top { padding-bottom: 12px; }
.pitch-body { max-width: 460px; margin-top: auto; margin-bottom: auto; padding: 24px 0; }

.hero-pill {
  display: inline-flex; align-items: center; gap: 10px;
  padding: 7px 14px 7px 10px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: var(--silver);
  font-size: 0.82rem;
  font-weight: 500;
  margin-bottom: 24px;
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

.pitch-title {
  font-size: clamp(2rem, 4.4vw, 3.1rem);
  font-weight: 800;
  line-height: 1.03;
  letter-spacing: -0.035em;
  margin: 0 0 20px;
}
.pitch-sub {
  color: var(--silver);
  font-size: 1.05rem;
  line-height: 1.55;
  margin: 0 0 32px;
}
.pitch-list { list-style: none; padding: 0; margin: 0; display: grid; gap: 12px; }
.pitch-list li {
  display: flex; align-items: center; gap: 12px;
  color: var(--silver); font-size: 0.95rem;
}
.pitch-list strong { color: #fff; font-weight: 600; }
.pitch-check {
  width: 24px; height: 24px; border-radius: 999px;
  display: grid; place-items: center; flex-shrink: 0;
  background: var(--brand-soft);
  color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
}
.pitch-check :deep(svg) { width: 13px; height: 13px; stroke-width: 3; }

.pitch-foot { font-size: 0.8rem; letter-spacing: 0.04em; }

/* =====================================================================
   Lado direito (form)
   ===================================================================== */
.auth-form-side {
  display: flex;
  flex-direction: column;
  padding: 32px 0 48px;
  min-width: 0;
}
.auth-form-top {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
}
.auth-logo-sm { display: none; }

.auth-form-wrap {
  flex: 1;
  display: grid;
  place-items: center;
  padding: 32px 0;
}

.auth-card {
  width: 100%;
  max-width: 440px;
  background:
    radial-gradient(ellipse 400px 220px at 100% 0%, rgba(59, 130, 246, 0.14), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 36px 32px;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.1);
  position: relative;
}

.form-head { margin-bottom: 20px; }
.form-head .eyebrow { display: inline-block; margin-bottom: 10px; }
.form-title {
  font-size: 1.65rem; font-weight: 800;
  letter-spacing: -0.025em;
  margin: 0 0 6px;
}
.form-sub { font-size: 0.92rem; margin: 0; }

/* Tabs de modo (senha / código) */
.mode-tabs {
  display: grid; grid-template-columns: 1fr 1fr; gap: 6px;
  padding: 4px;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  margin-bottom: 22px;
}
.mode-tab {
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  padding: 10px 10px;
  border-radius: 8px;
  background: transparent;
  color: var(--muted);
  font: inherit; font-weight: 600; font-size: 0.85rem;
  border: none; cursor: pointer;
  transition: background 0.18s ease, color 0.18s ease;
}
.mode-tab :deep(svg) { width: 14px; height: 14px; }
.mode-tab:hover { color: var(--text); }
.mode-tab.on {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 14px var(--brand-glow);
}

/* OTP block (igual ao do AgendaBooking, só local) */
.otp-block { display: flex; flex-direction: column; gap: 12px; }
.otp-sent {
  display: flex; align-items: center; gap: 12px;
  padding: 10px 12px;
  background: var(--success-soft);
  border: 1px solid rgba(74, 222, 128, 0.3);
  border-radius: var(--radius-sm);
}
.otp-sent-icon {
  width: 30px; height: 30px; border-radius: 50%; flex-shrink: 0;
  display: grid; place-items: center;
  background: var(--success); color: #0b1220;
}
.otp-sent-icon :deep(svg) { width: 15px; height: 15px; stroke-width: 3; }
.otp-sent-text { flex: 1; min-width: 0; display: flex; flex-direction: column; line-height: 1.3; font-size: 0.85rem; }
.otp-sent-text > strong { color: var(--success); }
.otp-sent-text small { color: var(--muted); font-size: 0.78rem; margin-top: 2px; }
.otp-sent-text small strong { color: var(--text); font-weight: 600; }
.otp-change { font-size: 0.82rem; flex-shrink: 0; }

.otp-form { display: flex; flex-direction: column; gap: 10px; }
.otp-label { color: var(--text); font-weight: 600; font-size: 0.9rem; margin: 0; }
.otp-input {
  width: 100%; min-width: 0; box-sizing: border-box;
  font-size: 1.4rem; font-weight: 800;
  letter-spacing: 0.2em; text-align: center;
  font-family: 'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  padding: 14px;
  background: var(--input); color: var(--text);
  border: 1px solid var(--border); border-radius: var(--radius-sm);
}
.otp-input:focus { outline: none; border-color: var(--brand); box-shadow: 0 0 0 3px var(--brand-soft); }
.otp-input::placeholder { letter-spacing: 0.2em; color: var(--border-strong); font-weight: 500; }
.otp-resend { margin: 2px 0 0; font-size: 0.85rem; color: var(--muted); text-align: center; }

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
  margin-bottom: 16px;
}
.auth-alert.error {
  color: #fecaca;
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.35);
}
.auth-alert.success {
  color: #bbf7d0;
  background: var(--success-soft);
  border-color: rgba(74, 222, 128, 0.35);
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

/* =====================================================================
   Helper row (link "esqueci")
   ===================================================================== */
.form-row-helper {
  display: flex; justify-content: flex-end;
  margin: -2px 0 20px;
}
.form-row-helper .link-btn {
  font-size: 0.85rem;
  font-weight: 600;
}

/* =====================================================================
   Botão submit com spinner
   ===================================================================== */
.btn-submit {
  padding: 14px 22px;
  font-size: 1rem;
  position: relative;
}
.btn-spinner {
  width: 16px; height: 16px;
  border-radius: 50%;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: #fff;
  animation: spin 0.7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* =====================================================================
   Foot
   ===================================================================== */
.form-foot {
  display: flex; justify-content: center; align-items: center; gap: 6px;
  flex-wrap: wrap;
  margin-top: 22px;
  font-size: 0.9rem;
}
.form-foot-link { font-weight: 600; }

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 960px) {
  .auth-shell {
    grid-template-columns: 1fr;
    gap: 0;
    min-height: 100vh;
  }
  .auth-pitch { display: none; }
  .auth-form-side { padding: 20px 0 36px; }
  .auth-logo-sm { display: block; }
  .auth-form-wrap { padding: 20px 0; }
  .orb-a { top: -220px; left: -200px; }
  .orb-b { bottom: -220px; right: -200px; }
}

@media (max-width: 520px) {
  .auth-shell { padding: 0 16px; }
  .auth-card { padding: 28px 22px; border-radius: 16px; }
  .form-title { font-size: 1.4rem; }
  .auth-form-side { padding-top: 16px; }
}
</style>
