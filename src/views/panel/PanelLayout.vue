<script setup>
import { ref, computed, provide, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { signOut, isPlatformAdmin } from '@/lib/session'
import { createBusinessContext, provideKey } from '@/lib/business'
import { slugify } from '@/lib/format'
import { APP_NAME, APP_DOMAIN, CATEGORIES, SUPPORT_WHATSAPP } from '@/config/brand'
import { waLink } from '@/lib/whatsapp'
import { brandVars } from '@/lib/colors'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'
import BackButton from '@/components/BackButton.vue'
import { PANEL_NAV, PANEL_HOME, routeAllowed } from '@/lib/panel-nav'

const route = useRoute()
const router = useRouter()
const biz = createBusinessContext()
provide(provideKey(), biz)

const isAdmin = ref(false)
const brandStyle = computed(() => brandVars(biz.business?.primary_color))
const publicLink = computed(() => biz.business && `${location.origin}/${biz.business.slug}`)
const publicLinkShort = computed(() => biz.business && `${APP_DOMAIN}/${biz.business.slug}`)
const copied = ref(false)
const supportLink = computed(() => SUPPORT_WHATSAPP &&
  waLink(SUPPORT_WHATSAPP, `Olá! Preciso de ajuda com o ${biz.business?.name ?? 'meu cadastro'} no ${APP_NAME}.`))
const mobileNavOpen = ref(false)

async function copyLink() {
  await navigator.clipboard.writeText(publicLink.value)
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

const whatsappShareLink = computed(() => biz.business && publicLink.value &&
  `https://wa.me/?text=${encodeURIComponent(`Agende um horário com ${biz.business.name}: ${publicLink.value}`)}`)

// Esconde a faixa de divulgação em telas onde ela não faz sentido.
const HIDE_SHARE_BAR = ['/painel/comecar', '/painel/divulgar', '/painel/assinatura']
const showShareBar = computed(() =>
  biz.live && biz.business && !HIDE_SHARE_BAR.includes(route.path))

// Agrupamento visual do menu — mantém os mesmos itens/labels do PANEL_NAV,
// só distribui em "seções" pra dar hierarquia na sidebar. A ordem dentro
// de cada grupo segue o PANEL_NAV original.
const NAV_GROUPS = [
  { title: 'Agenda', match: ['/painel', '/painel/servicos', '/painel/profissionais', '/painel/horarios', '/painel/clientes', '/painel/bloqueios'] },
  { title: 'Divulgar', match: ['/painel/lembretes', '/painel/galeria', '/painel/avaliacoes', '/painel/fidelidade', '/painel/cupons', '/painel/divulgar'] },
  { title: 'Conta', match: ['/painel/perfil', '/painel/assinatura'] },
]

const nav = computed(() => PANEL_NAV.map((item) => ({
  ...item,
  label: item.staffLabel && biz.business?.staff_label && biz.business.staff_label !== 'Profissional'
    ? `${biz.business.staff_label}s` : item.label,
  locked: item.feature && !biz.hasFeature(item.feature),
})))

const groupedNav = computed(() => NAV_GROUPS
  .map((g) => ({ ...g, items: nav.value.filter((i) => g.match.includes(i.to)) }))
  .filter((g) => g.items.length))

// Pill de status do estabelecimento na sidebar (plano ativo, aprovado, atrasado etc).
const statusPill = computed(() => {
  if (!biz.business) return null
  if (biz.business.billing_blocked) return { label: 'Bloqueado', tone: 'red' }
  if (biz.business.status === 'pending') return { label: 'Em análise', tone: 'yellow' }
  if (biz.business.status === 'rejected') return { label: 'Não aprovado', tone: 'red' }
  if (biz.subscription?.status === 'past_due') return { label: 'Atrasado', tone: 'yellow' }
  if (biz.subscription?.status === 'active') return { label: `Plano ${biz.plan?.name ?? ''}`.trim(), tone: 'green' }
  if (biz.plan) return { label: `Plano ${biz.plan.name}`, tone: 'blue' }
  return { label: 'Sem plano', tone: 'yellow' }
})

// Pedaços do caminho atual pra montar um breadcrumb discreto no topo da main.
const currentPage = computed(() => nav.value.find((i) => i.to === route.path))

// Fecha o menu mobile quando trocar de rota.
watch(() => route.path, () => { mobileNavOpen.value = false })

const FREE_WHEN_INACTIVE = ['/painel/assinatura', '/painel/perfil']

function enforceAccess() {
  // Bloqueado por atraso também entra no painel, mas só na tela de Assinatura (para pagar).
  const billingBlocked = biz.business?.status === 'blocked' && biz.business?.billing_blocked
  if (biz.loading || !biz.business || (biz.business.status !== 'approved' && !billingBlocked)) return
  // Aprovado mas sem assinatura ativa: só a tela de assinatura e o perfil ficam liberados.
  if (!biz.live && !FREE_WHEN_INACTIVE.includes(route.path)) {
    router.replace('/painel/assinatura')
    return
  }
  // Primeira vez após assinar: manda pro onboarding escolher template.
  if (biz.live && !biz.business.onboarding_done && route.path !== '/painel/comecar') {
    router.replace('/painel/comecar')
    return
  }
  if (!routeAllowed(route.path) && route.path !== '/painel/comecar') router.replace(PANEL_HOME)
}
watch(() => [route.path, biz.loading], enforceAccess)

onMounted(async () => {
  await biz.reload()
  enforceAccess()
  isAdmin.value = await isPlatformAdmin()
})

async function logout() {
  await signOut()
  router.push('/entrar')
}

// Cadastro pelo painel, para quem criou a conta sem os dados do estabelecimento.
const form = ref({ name: '', slug: '', category: CATEGORIES[0], phone: '' })
const formError = ref('')
watch(() => form.value.name, (n) => { form.value.slug = slugify(n) })
async function requestBusiness() {
  formError.value = ''
  const { error } = await supabase.rpc('request_business', {
    p_name: form.value.name, p_slug: slugify(form.value.slug),
    p_category: form.value.category, p_phone: form.value.phone,
  })
  if (error) formError.value = error.message
  else await biz.reload()
}
</script>

<template>
  <div v-if="biz.loading && !biz.business" class="panel-loading">
    <div class="loading-orb" aria-hidden="true" />
    <p class="muted">Carregando seu painel...</p>
  </div>

  <!-- Sem estabelecimento: form com linguagem do signup -->
  <div v-else-if="!biz.business" class="status-shell">
    <div class="status-bg" aria-hidden="true">
      <div class="status-grid-lines" />
      <div class="status-orb orb-a" />
      <div class="status-orb orb-b" />
    </div>

    <div class="status-wrap">
      <header class="status-top">
        <AppLogo />
        <button type="button" class="link-btn" @click="logout">Sair</button>
      </header>

      <div class="status-head">
        <div class="status-pill">
          <span class="dot-live" />
          Falta pouco pra sua vitrine entrar no ar
        </div>
        <h1 class="status-title">
          Cadastre seu <span class="gradient-text">estabelecimento</span>
        </h1>
        <p class="muted status-sub">
          Preencha os dados abaixo pra nossa equipe analisar e liberar seu painel.
        </p>
      </div>

      <form class="status-card" @submit.prevent="requestBusiness">
        <div v-if="formError" class="error">{{ formError }}</div>
        <div class="field">
          <label><Icon name="store" />Nome do estabelecimento</label>
          <input v-model="form.name" required />
        </div>
        <div class="field">
          <label><Icon name="link" />Seu link</label>
          <input v-model="form.slug" required />
          <small>{{ APP_DOMAIN }}/<strong>{{ form.slug || 'seu-negocio' }}</strong></small>
        </div>
        <div class="row">
          <div class="field">
            <label><Icon name="tag" />Segmento</label>
            <select v-model="form.category"><option v-for="c in CATEGORIES" :key="c">{{ c }}</option></select>
          </div>
          <div class="field">
            <label><Icon name="whatsapp" />WhatsApp</label>
            <input v-model="form.phone" type="tel" required />
          </div>
        </div>
        <button class="btn block">Cadastrar estabelecimento</button>
      </form>
    </div>
  </div>

  <!-- Em análise / recusado / bloqueado -->
  <div v-else-if="biz.business.status !== 'approved' && !biz.business.billing_blocked" class="status-shell">
    <div class="status-bg" aria-hidden="true">
      <div class="status-grid-lines" />
      <div class="status-orb orb-a" />
      <div class="status-orb orb-b" />
    </div>

    <div class="status-wrap">
      <header class="status-top">
        <AppLogo />
        <button type="button" class="link-btn" @click="logout">Sair</button>
      </header>

      <div class="status-card center">
        <div class="status-icon-wrap">
          <div class="status-icon-ring" :class="biz.business.status === 'pending' ? 'ring-warn' : 'ring-danger'" />
          <div class="status-icon-core" :class="biz.business.status === 'pending' ? 'core-warn' : 'core-danger'">
            <Icon v-if="biz.business.status === 'pending'" name="clock" />
            <Icon v-else name="ban" />
          </div>
        </div>

        <div class="status-pill" :class="biz.business.status === 'pending' ? 'pill-warn' : 'pill-danger'">
          <template v-if="biz.business.status === 'pending'">
            <Icon name="clock" />
            Em análise
          </template>
          <template v-else-if="biz.business.status === 'rejected'">
            <Icon name="ban" />
            Cadastro não aprovado
          </template>
          <template v-else>
            <Icon name="ban" />
            Acesso bloqueado
          </template>
        </div>

        <h2 class="status-title lg">{{ biz.business.name }}</h2>

        <p class="muted status-sub" v-if="biz.business.status === 'pending'">
          Recebemos seu cadastro e nossa equipe está analisando. Você receberá um aviso assim que for aprovado.
        </p>
        <template v-else-if="biz.business.status === 'rejected'">
          <p v-if="biz.business.status_reason" class="status-sub">
            <strong>Motivo:</strong> {{ biz.business.status_reason }}
          </p>
          <p class="muted status-sub">Se acha que houve um engano, fale com o nosso suporte.</p>
        </template>
        <p v-else class="status-sub">
          {{ biz.business.status_reason || 'Seu acesso está bloqueado. Regularize a assinatura ou fale com o suporte.' }}
        </p>

        <!-- Próximo passo claro -->
        <div v-if="biz.business.status === 'pending'" class="status-next">
          <div class="status-next-icon"><Icon name="bell" /></div>
          <div>
            <strong>Próximo passo</strong>
            <small>Assim que aprovarmos, você escolhe um plano e libera o painel.</small>
          </div>
        </div>

        <div class="status-actions">
          <button class="btn secondary" @click="biz.reload()">
            <Icon name="clock" style="width: 16px; height: 16px" />
            Atualizar
          </button>
          <a v-if="supportLink" class="btn" :href="supportLink" target="_blank" rel="noopener">
            <Icon name="whatsapp" style="width: 16px; height: 16px" />
            Falar com o suporte
          </a>
          <RouterLink v-if="isAdmin" class="btn secondary" to="/admin">Painel admin</RouterLink>
        </div>
      </div>
    </div>
  </div>

  <!-- Painel -->
  <div v-else class="app-shell" :style="brandStyle" :class="{ 'nav-open': mobileNavOpen }">
    <!-- Barra mobile -->
    <header class="mobile-topbar">
      <button type="button" class="mobile-toggle" :aria-expanded="mobileNavOpen"
              aria-label="Abrir menu" @click="mobileNavOpen = !mobileNavOpen">
        <span /><span /><span />
      </button>
      <div class="mobile-brand">
        <img v-if="biz.business.logo_url" :src="biz.business.logo_url" alt="" />
        <span v-else class="initial-sm">{{ biz.business.name.charAt(0).toUpperCase() }}</span>
        <span class="mobile-brand-name">{{ biz.business.name }}</span>
      </div>
      <RouterLink to="/painel/perfil" class="mobile-avatar" aria-label="Perfil">
        <Icon name="store" />
      </RouterLink>
    </header>

    <div v-if="mobileNavOpen" class="mobile-backdrop" @click="mobileNavOpen = false" />

    <aside class="sidebar panel-sidebar">
      <!-- Brand + plano -->
      <div class="side-brand">
        <div class="side-brand-row">
          <img v-if="biz.business.logo_url" :src="biz.business.logo_url" alt="" class="side-logo" />
          <span v-else class="side-initial">{{ biz.business.name.charAt(0).toUpperCase() }}</span>
          <div class="side-brand-text">
            <strong class="side-brand-name">{{ biz.business.name }}</strong>
            <small class="side-brand-cat">{{ biz.business.category }}</small>
          </div>
        </div>
        <span v-if="statusPill" class="side-plan-pill" :class="`tone-${statusPill.tone}`">
          <span class="plan-dot" />
          {{ statusPill.label }}
        </span>
      </div>

      <!-- Navegação agrupada -->
      <nav class="side-nav">
        <div v-for="group in groupedNav" :key="group.title" class="nav-group">
          <div class="nav-group-title">{{ group.title }}</div>
          <RouterLink v-for="item in group.items" :key="item.to" :to="item.to"
                      :class="{ disabled: !biz.live && !FREE_WHEN_INACTIVE.includes(item.to), locked: item.locked }">
            <Icon :name="item.icon" />
            <span class="nav-label">{{ item.label }}</span>
            <span v-if="item.locked" class="lock-tag">PRO</span>
          </RouterLink>
        </div>
        <div v-if="isAdmin" class="nav-group">
          <div class="nav-group-title">Plataforma</div>
          <RouterLink to="/admin"><Icon name="shield" /><span class="nav-label">Admin</span></RouterLink>
        </div>
      </nav>

      <!-- Rodapé: suporte + logout -->
      <div class="side-foot">
        <a v-if="supportLink" class="side-support" :href="supportLink" target="_blank" rel="noopener">
          <Icon name="whatsapp" />
          <span>Suporte no WhatsApp</span>
        </a>
        <a href="#" class="side-logout" @click.prevent="logout">
          <Icon name="logout" />
          <span>Sair</span>
        </a>
        <div class="side-copyright">{{ APP_NAME }} · G&amp;G Soluções</div>
      </div>
    </aside>

    <main class="main panel-main">
      <!-- Faixa de divulgação do link: fica sticky no topo em todas as telas do painel -->
      <div v-if="showShareBar" class="share-bar">
        <div class="share-bar-info">
          <span class="share-bar-badge"><Icon name="link" /></span>
          <div class="share-bar-text">
            <small>Seu link público</small>
            <a :href="publicLink" target="_blank" rel="noopener">{{ publicLinkShort }}</a>
          </div>
        </div>
        <div class="share-bar-actions">
          <button type="button" class="btn small" :class="{ 'is-ok': copied }" @click="copyLink">
            <Icon :name="copied ? 'check' : 'copy'" />
            <span>{{ copied ? 'Copiado' : 'Copiar' }}</span>
          </button>
          <a class="btn small secondary" :href="whatsappShareLink" target="_blank" rel="noopener">
            <Icon name="whatsapp" />
            <span>Enviar</span>
          </a>
          <a class="btn small secondary share-bar-open" :href="publicLink" target="_blank" rel="noopener" aria-label="Abrir vitrine">
            <Icon name="globe" />
          </a>
        </div>
      </div>

      <div class="main-topbar">
        <BackButton v-if="route.path !== PANEL_HOME" :fallback="PANEL_HOME" />
        <nav v-else class="main-crumbs" aria-hidden="true">
          <span>{{ APP_NAME }}</span>
          <span class="crumbs-sep">/</span>
          <strong>{{ currentPage?.label ?? 'Painel' }}</strong>
        </nav>
      </div>
      <div class="main-content">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<style scoped>
/* =====================================================================
   Loading inicial
   ===================================================================== */
.panel-loading {
  min-height: 100vh;
  display: grid; place-items: center;
  gap: 16px;
  text-align: center;
}
.loading-orb {
  width: 48px; height: 48px; border-radius: 50%;
  background: radial-gradient(circle, var(--brand), var(--brand-strong));
  box-shadow: 0 0 40px var(--brand-glow);
  animation: loadPulse 1.4s ease-in-out infinite;
}
@keyframes loadPulse {
  0%, 100% { transform: scale(0.85); opacity: 0.7; }
  50% { transform: scale(1); opacity: 1; }
}

/* =====================================================================
   Shell "sem estabelecimento" / "em análise" / "bloqueado"
   Mesma linguagem visual do Login/Signup (orbs, grid, pill).
   ===================================================================== */
.status-shell {
  position: relative;
  min-height: 100vh;
  isolation: isolate;
  overflow: hidden;
}
.status-bg { position: absolute; inset: 0; z-index: -1; pointer-events: none; }
.status-grid-lines {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(148, 180, 220, 0.05) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 180, 220, 0.05) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 80% 50% at 50% 10%, #000 30%, transparent 85%);
  -webkit-mask-image: radial-gradient(ellipse 80% 50% at 50% 10%, #000 30%, transparent 85%);
}
.status-orb {
  position: absolute; border-radius: 50%; filter: blur(70px); opacity: 0.45;
  animation: orbFloat 14s ease-in-out infinite;
}
.status-orb.orb-a {
  width: 520px; height: 520px;
  background: radial-gradient(circle, var(--brand-glow), transparent 65%);
  top: -160px; right: -120px;
}
.status-orb.orb-b {
  width: 420px; height: 420px;
  background: radial-gradient(circle, rgba(29, 78, 216, 0.35), transparent 65%);
  bottom: -200px; left: -100px;
  animation-delay: -7s;
}
@keyframes orbFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(20px, -20px) scale(1.05); }
}

.status-wrap {
  width: min(560px, calc(100% - 32px));
  margin: 0 auto;
  padding: 24px 0 56px;
}
.status-top {
  display: flex; align-items: center; justify-content: space-between;
  gap: 12px;
  margin-bottom: 32px;
}

.status-head { text-align: center; max-width: 480px; margin: 0 auto 24px; }
.status-pill {
  display: inline-flex; align-items: center; gap: 10px;
  padding: 7px 14px 7px 12px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.1);
  border: 1px solid rgba(59, 130, 246, 0.3);
  color: var(--silver);
  font-size: 0.82rem; font-weight: 600;
  margin-bottom: 18px;
}
.status-pill :deep(svg) { width: 14px; height: 14px; }
.status-pill.pill-warn {
  background: var(--warning-soft);
  border-color: rgba(251, 191, 36, 0.3);
  color: var(--warning);
}
.status-pill.pill-danger {
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.3);
  color: var(--danger);
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
.status-title {
  font-size: clamp(1.6rem, 3.2vw, 2.2rem);
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
  margin: 0 0 14px;
}
.status-title.lg { margin: 10px 0 10px; }
.status-sub { font-size: 1rem; line-height: 1.55; margin: 0 auto 14px; max-width: 420px; }

.status-card {
  background:
    radial-gradient(ellipse 500px 220px at 50% 0%, rgba(59, 130, 246, 0.14), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 32px;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.1);
}
.status-card.center { text-align: center; }
.status-card .field label { display: inline-flex; align-items: center; gap: 6px; }
.status-card .field label :deep(svg) { width: 14px; height: 14px; color: var(--brand-ink); }

.status-icon-wrap {
  position: relative;
  width: 88px; height: 88px;
  margin: 0 auto 20px;
}
.status-icon-ring {
  position: absolute; inset: 0;
  border-radius: 50%;
  animation: ringPulse 2.4s ease-in-out infinite;
}
.status-icon-ring.ring-warn {
  background: radial-gradient(circle, rgba(251, 191, 36, 0.4), transparent 70%);
}
.status-icon-ring.ring-danger {
  background: radial-gradient(circle, rgba(248, 113, 113, 0.4), transparent 70%);
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.75; }
  50% { transform: scale(1.15); opacity: 0.35; }
}
.status-icon-core {
  position: absolute; inset: 10px;
  border-radius: 50%;
  display: grid; place-items: center;
  color: #fff;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35);
}
.status-icon-core.core-warn {
  background: linear-gradient(140deg, #fbbf24, #d97706);
}
.status-icon-core.core-danger {
  background: linear-gradient(140deg, #f87171, #b91c1c);
}
.status-icon-core :deep(svg) { width: 30px; height: 30px; }

.status-next {
  display: flex; align-items: center; gap: 14px;
  text-align: left;
  padding: 14px 16px;
  margin: 20px auto 0;
  max-width: 420px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
}
.status-next-icon {
  width: 36px; height: 36px; border-radius: 10px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 16px var(--brand-glow);
}
.status-next-icon :deep(svg) { width: 18px; height: 18px; }
.status-next strong { display: block; font-size: 0.95rem; }
.status-next small { color: var(--muted); font-size: 0.82rem; }

.status-actions {
  display: flex; justify-content: center; gap: 10px;
  flex-wrap: wrap;
  margin-top: 24px;
}

/* =====================================================================
   Painel: shell com sidebar + main
   ===================================================================== */
.app-shell {
  display: grid;
  grid-template-columns: 272px 1fr;
  min-height: 100vh;
}

/* ---------- Sidebar ---------- */
.panel-sidebar {
  position: sticky; top: 0;
  height: 100vh;
  overflow-y: auto;
  background:
    radial-gradient(ellipse 300px 240px at 0% 0%, rgba(59, 130, 246, 0.08), transparent 70%),
    rgba(5, 11, 22, 0.72);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-right: 1px solid var(--border);
  padding: 20px 14px 16px;
  display: flex; flex-direction: column;
  gap: 20px;
}

/* Scrollbar discreta */
.panel-sidebar::-webkit-scrollbar { width: 6px; }
.panel-sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 6px; }
.panel-sidebar::-webkit-scrollbar-thumb:hover { background: var(--border-strong); }

/* ---------- Brand card ---------- */
.side-brand {
  padding: 14px 12px 14px;
  border-radius: var(--radius-sm);
  background:
    radial-gradient(ellipse 220px 120px at 100% 0%, var(--brand-soft), transparent 70%),
    rgba(255, 255, 255, 0.03);
  border: 1px solid var(--border);
}
.side-brand-row { display: flex; align-items: center; gap: 10px; min-width: 0; }
.side-logo,
.side-initial {
  width: 42px; height: 42px; border-radius: 12px;
  flex-shrink: 0;
  object-fit: cover;
  background: #fff;
}
.side-initial {
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: var(--brand-contrast);
  font-weight: 800; font-size: 1.1rem;
  box-shadow: 0 0 20px var(--brand-glow);
}
.side-brand-text { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.side-brand-name {
  font-size: 0.92rem; font-weight: 700; color: var(--text);
  letter-spacing: -0.01em;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.side-brand-cat {
  font-size: 0.72rem; color: var(--muted);
  text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600;
}

.side-plan-pill {
  display: inline-flex; align-items: center; gap: 6px;
  margin-top: 10px;
  padding: 4px 10px 4px 8px;
  border-radius: 999px;
  font-size: 0.72rem; font-weight: 700;
  letter-spacing: 0.02em;
  border: 1px solid;
}
.side-plan-pill .plan-dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 8px currentColor;
}
.side-plan-pill.tone-green {
  color: var(--success);
  background: var(--success-soft);
  border-color: rgba(74, 222, 128, 0.3);
}
.side-plan-pill.tone-yellow {
  color: var(--warning);
  background: var(--warning-soft);
  border-color: rgba(251, 191, 36, 0.3);
}
.side-plan-pill.tone-red {
  color: var(--danger);
  background: var(--danger-soft);
  border-color: rgba(248, 113, 113, 0.3);
}
.side-plan-pill.tone-blue {
  color: var(--brand-ink);
  background: var(--brand-soft);
  border-color: rgba(59, 130, 246, 0.3);
}

/* ---------- Navegação agrupada ---------- */
.side-nav { display: flex; flex-direction: column; gap: 16px; }
.nav-group { display: flex; flex-direction: column; gap: 2px; }
.nav-group-title {
  padding: 4px 12px 6px;
  font-size: 0.68rem;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--muted);
  font-weight: 700;
}
.side-nav a {
  position: relative;
  display: flex; align-items: center; gap: 10px;
  padding: 9px 12px;
  border-radius: 10px;
  color: var(--silver);
  font-weight: 500;
  font-size: 0.92rem;
  transition: background 0.15s ease, color 0.15s ease;
}
.side-nav a :deep(svg) {
  width: 17px; height: 17px;
  flex-shrink: 0;
  color: var(--muted);
  transition: color 0.15s ease;
}
.side-nav a:hover {
  background: var(--surface);
  color: var(--text);
}
.side-nav a:hover :deep(svg) { color: var(--brand-ink); }
.side-nav a.router-link-exact-active {
  background: linear-gradient(100deg, var(--brand-soft), transparent 80%);
  color: #fff;
}
.side-nav a.router-link-exact-active :deep(svg) { color: var(--brand-ink); }
.side-nav a.router-link-exact-active::before {
  content: '';
  position: absolute;
  left: 0; top: 50%; transform: translateY(-50%);
  width: 3px; height: 60%;
  border-radius: 0 3px 3px 0;
  background: linear-gradient(180deg, var(--brand), var(--brand-strong));
  box-shadow: 0 0 10px var(--brand-glow);
}
.side-nav a.disabled { opacity: 0.35; pointer-events: none; }
.side-nav a.locked { opacity: 0.65; }
.lock-tag {
  margin-left: auto;
  font-size: 0.58rem; font-weight: 800;
  letter-spacing: 0.08em;
  padding: 2px 6px; border-radius: 6px;
  background: var(--brand-soft);
  color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
}
.nav-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
  flex: 1;
}

/* ---------- Footer da sidebar ---------- */
.side-foot {
  margin-top: auto;
  display: flex; flex-direction: column;
  gap: 10px;
  padding-top: 16px;
  border-top: 1px solid var(--border);
}

.share-card {
  position: relative;
  padding: 14px;
  border-radius: var(--radius-sm);
  background:
    radial-gradient(ellipse 220px 120px at 100% 0%, var(--brand-soft), transparent 70%),
    linear-gradient(160deg, rgba(59, 130, 246, 0.08), rgba(29, 78, 216, 0.06));
  border: 1px solid rgba(59, 130, 246, 0.25);
  box-shadow: 0 0 24px rgba(59, 130, 246, 0.12);
  overflow: hidden;
}
.share-head {
  display: flex; align-items: center; gap: 10px;
  margin-bottom: 10px;
}
.share-badge {
  width: 32px; height: 32px; border-radius: 10px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 16px var(--brand-glow);
}
.share-badge :deep(svg) { width: 15px; height: 15px; }
.share-head strong {
  display: block;
  font-size: 0.85rem; color: var(--text);
}
.share-head small {
  display: block;
  color: var(--muted); font-size: 0.72rem;
}
.share-url {
  display: block;
  padding: 8px 10px;
  border-radius: 8px;
  background: rgba(5, 11, 22, 0.6);
  border: 1px solid var(--border);
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.76rem;
  color: var(--silver);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  transition: border-color 0.15s ease;
}
.share-url:hover { border-color: var(--brand); color: #fff; }

.share-actions { display: flex; gap: 6px; margin-top: 8px; }
.share-copy {
  flex: 1;
  display: inline-flex; align-items: center; justify-content: center; gap: 6px;
  padding: 8px 10px;
  border-radius: 8px;
  border: 1px solid transparent;
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff;
  font: inherit; font-size: 0.8rem; font-weight: 700;
  cursor: pointer;
  box-shadow: 0 0 18px var(--brand-glow);
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
.share-copy:hover { transform: translateY(-1px); box-shadow: 0 0 24px var(--brand-glow); }
.share-copy.ok {
  background: linear-gradient(120deg, #22c55e, #15803d);
  box-shadow: 0 0 18px rgba(74, 222, 128, 0.5);
}
.share-copy :deep(svg) { width: 14px; height: 14px; }
.share-open {
  display: inline-grid; place-items: center;
  width: 36px; height: 36px;
  border-radius: 8px;
  background: var(--surface);
  border: 1px solid var(--border);
  color: var(--silver);
  transition: border-color 0.15s ease, color 0.15s ease;
}
.share-open:hover { border-color: var(--brand); color: #fff; }
.share-open :deep(svg) { width: 15px; height: 15px; }

.side-support,
.side-logout {
  display: flex; align-items: center; gap: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  color: var(--muted);
  font-size: 0.88rem; font-weight: 500;
  transition: background 0.15s ease, color 0.15s ease;
}
.side-support :deep(svg),
.side-logout :deep(svg) { width: 16px; height: 16px; }
.side-support:hover { background: var(--success-soft); color: var(--success); }
.side-logout:hover { background: var(--danger-soft); color: var(--danger); }

.side-copyright {
  margin-top: 6px;
  padding: 0 12px;
  font-size: 0.72rem;
  color: var(--muted);
  letter-spacing: 0.04em;
}

/* =====================================================================
   Main (área de conteúdo)
   ===================================================================== */
.panel-main {
  padding: 0 36px 48px;
  min-width: 0;
  position: relative;
}
.share-bar {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 12px 18px;
  margin: 0 -36px 20px;
  padding-left: 54px; padding-right: 54px;
  background:
    radial-gradient(ellipse 320px 100px at 10% 50%, var(--brand-soft), transparent 70%),
    linear-gradient(180deg, rgba(5, 11, 22, 0.92), rgba(5, 11, 22, 0.86));
  border-bottom: 1px solid var(--border);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
.share-bar-info { display: flex; align-items: center; gap: 12px; min-width: 0; flex: 1; }
.share-bar-badge {
  width: 36px; height: 36px; border-radius: 10px; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.share-bar-badge :deep(svg) { width: 16px; height: 16px; }
.share-bar-text { display: flex; flex-direction: column; min-width: 0; line-height: 1.25; }
.share-bar-text small {
  color: var(--muted);
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 700;
}
.share-bar-text a {
  color: var(--text);
  font-weight: 600;
  font-size: 0.95rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}
.share-bar-text a:hover { color: var(--brand-ink); }
.share-bar-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.share-bar-actions .btn { padding: 7px 14px; }
.share-bar-actions .btn.is-ok { background: linear-gradient(120deg, var(--success), #16a34a); box-shadow: 0 0 18px rgba(74, 222, 128, 0.35); }
.share-bar-open { padding: 7px 10px !important; }
.share-bar-open :deep(svg) { margin: 0; }

@media (max-width: 760px) {
  .share-bar {
    padding: 10px 14px;
    padding-left: 14px; padding-right: 14px;
    margin: 0 -16px 14px;
    flex-wrap: wrap;
  }
  .share-bar-info { flex: 1 1 100%; }
  .share-bar-actions { flex: 1 1 100%; justify-content: stretch; }
  .share-bar-actions .btn { flex: 1; }
  .share-bar-actions .btn span { display: inline; }
  .share-bar-open { flex: 0 0 auto !important; }
}

.main-topbar {
  display: flex; align-items: center;
  min-height: 32px;
  margin-top: 24px;
  margin-bottom: 18px;
}
.main-topbar :deep(.back-btn) { margin-bottom: 0; }
.main-crumbs {
  display: inline-flex; align-items: center; gap: 8px;
  font-size: 0.82rem;
  color: var(--muted);
}
.main-crumbs strong {
  color: var(--text);
  font-weight: 700;
}
.main-crumbs .crumbs-sep { opacity: 0.5; }

.main-content { min-width: 0; }
.main-content :deep(.page-header) { margin-bottom: 22px; }
.main-content :deep(.page-header h1) {
  font-size: clamp(1.5rem, 2.6vw, 1.9rem);
  letter-spacing: -0.02em;
}

/* =====================================================================
   Topbar e sidebar mobile
   ===================================================================== */
.mobile-topbar {
  display: none;
}
.mobile-backdrop {
  display: none;
}

@media (max-width: 960px) {
  .app-shell {
    grid-template-columns: 1fr;
  }

  .mobile-topbar {
    position: sticky; top: 0; z-index: 40;
    display: flex; align-items: center; gap: 12px;
    padding: 12px 16px;
    background: rgba(5, 11, 22, 0.9);
    backdrop-filter: blur(14px);
    -webkit-backdrop-filter: blur(14px);
    border-bottom: 1px solid var(--border);
  }
  .mobile-toggle {
    display: flex; flex-direction: column; gap: 4px;
    width: 38px; height: 38px;
    padding: 0;
    border-radius: 10px;
    background: var(--surface);
    border: 1px solid var(--border);
    color: var(--text);
    align-items: center; justify-content: center;
    cursor: pointer;
    transition: border-color 0.15s ease;
  }
  .mobile-toggle:hover { border-color: var(--brand); }
  .mobile-toggle span {
    width: 16px; height: 2px;
    background: currentColor;
    border-radius: 2px;
    transition: transform 0.2s ease, opacity 0.2s ease;
  }
  .nav-open .mobile-toggle span:nth-child(1) { transform: translateY(6px) rotate(45deg); }
  .nav-open .mobile-toggle span:nth-child(2) { opacity: 0; }
  .nav-open .mobile-toggle span:nth-child(3) { transform: translateY(-6px) rotate(-45deg); }

  .mobile-brand {
    display: flex; align-items: center; gap: 10px;
    flex: 1; min-width: 0;
  }
  .mobile-brand img,
  .mobile-brand .initial-sm {
    width: 32px; height: 32px; border-radius: 8px;
    object-fit: cover;
    flex-shrink: 0;
  }
  .mobile-brand .initial-sm {
    display: grid; place-items: center;
    background: linear-gradient(140deg, var(--brand), var(--brand-strong));
    color: #fff;
    font-weight: 800; font-size: 0.95rem;
    box-shadow: 0 0 14px var(--brand-glow);
  }
  .mobile-brand-name {
    font-weight: 700;
    font-size: 0.95rem;
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    min-width: 0;
  }
  .mobile-avatar {
    width: 38px; height: 38px; border-radius: 10px;
    display: grid; place-items: center;
    background: var(--brand-soft);
    border: 1px solid rgba(59, 130, 246, 0.3);
    color: var(--brand-ink);
    flex-shrink: 0;
    transition: transform 0.15s ease;
  }
  .mobile-avatar:hover { transform: translateY(-1px); }
  .mobile-avatar :deep(svg) { width: 17px; height: 17px; }

  .mobile-backdrop {
    position: fixed; inset: 0; z-index: 44;
    background: rgba(2, 6, 14, 0.65);
    backdrop-filter: blur(4px);
    display: block;
  }

  .panel-sidebar {
    position: fixed;
    top: 0; left: 0;
    z-index: 45;
    width: min(300px, 88vw);
    height: 100vh;
    transform: translateX(-100%);
    transition: transform 0.25s ease;
    border-right: 1px solid var(--border);
    padding: 20px 14px 20px;
  }
  .nav-open .panel-sidebar { transform: translateX(0); }

  .panel-main {
    padding: 20px 16px 48px;
  }
  .main-topbar { margin-bottom: 14px; }
}

@media (prefers-reduced-motion: reduce) {
  .status-orb, .loading-orb, .status-icon-ring, .dot-live { animation: none; }
}
</style>
