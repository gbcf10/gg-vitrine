<script setup>
import { ref, computed, provide, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { signOut, isPlatformAdmin } from '@/lib/session'
import { createBusinessContext, provideKey } from '@/lib/business'
import { slugify } from '@/lib/format'
import { APP_NAME, APP_DOMAIN, KINDS, CATEGORIES_BY_KIND } from '@/config/brand'
import { brandVars } from '@/lib/colors'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'
import { navFor, homeFor, routeAllowed } from '@/lib/panel-nav'

const route = useRoute()
const router = useRouter()
const biz = createBusinessContext()
provide(provideKey(), biz)

const isAdmin = ref(false)
const brandStyle = computed(() => brandVars(biz.business?.primary_color))
const publicLink = computed(() => biz.business && `${location.origin}/${biz.business.slug}`)
const copied = ref(false)

async function copyLink() {
  await navigator.clipboard.writeText(publicLink.value)
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

const nav = computed(() => navFor(biz.business?.kind ?? 'agenda').map((item) => ({
  ...item,
  label: item.staffLabel && biz.business?.staff_label && biz.business.staff_label !== 'Profissional'
    ? `${biz.business.staff_label}s` : item.label,
  locked: item.feature && !biz.hasFeature(item.feature),
})))

const FREE_WHEN_INACTIVE = ['/painel/assinatura', '/painel/perfil']

function enforceAccess() {
  if (biz.loading || !biz.business || biz.business.status !== 'approved') return
  const kind = biz.business.kind
  // Aprovado mas sem assinatura ativa: só a tela de assinatura e o perfil ficam liberados.
  if (!biz.live && !FREE_WHEN_INACTIVE.includes(route.path)) {
    router.replace('/painel/assinatura')
    return
  }
  if (!routeAllowed(route.path, kind)) router.replace(homeFor(kind))
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
const form = ref({ kind: 'agenda', name: '', slug: '', category: CATEGORIES_BY_KIND.agenda[0], phone: '' })
watch(() => form.value.kind, (k) => { form.value.category = CATEGORIES_BY_KIND[k][0] })
const formError = ref('')
watch(() => form.value.name, (n) => { form.value.slug = slugify(n) })
async function requestBusiness() {
  formError.value = ''
  const { error } = await supabase.rpc('request_business', {
    p_name: form.value.name, p_slug: slugify(form.value.slug),
    p_category: form.value.category, p_phone: form.value.phone, p_kind: form.value.kind,
  })
  if (error) formError.value = error.message
  else await biz.reload()
}
</script>

<template>
  <div v-if="biz.loading && !biz.business" class="narrow muted" style="text-align: center">Carregando...</div>

  <!-- Sem estabelecimento -->
  <div v-else-if="!biz.business" class="narrow" style="max-width: 520px">
    <div class="auth-logo"><AppLogo /></div>
    <form class="card glow" @submit.prevent="requestBusiness">
      <h3>Cadastre seu estabelecimento</h3>
      <div v-if="formError" class="error">{{ formError }}</div>
      <div class="field">
        <label>Tipo</label>
        <select v-model="form.kind">
          <option v-for="(k, key) in KINDS" :key="key" :value="key">{{ k.label }}</option>
        </select>
      </div>
      <div class="field">
        <label>Nome do estabelecimento</label>
        <input v-model="form.name" required />
      </div>
      <div class="field">
        <label>Seu link</label>
        <input v-model="form.slug" required />
        <small>{{ APP_DOMAIN }}/<strong>{{ form.slug || 'seu-negocio' }}</strong></small>
      </div>
      <div class="row">
        <div class="field">
          <label>Segmento</label>
          <select v-model="form.category"><option v-for="c in CATEGORIES_BY_KIND[form.kind]" :key="c">{{ c }}</option></select>
        </div>
        <div class="field">
          <label>WhatsApp</label>
          <input v-model="form.phone" type="tel" required />
        </div>
      </div>
      <button class="btn block">Solicitar cadastro</button>
      <p style="margin-top: 12px"><button type="button" class="link-btn" @click="logout">Sair</button></p>
    </form>
  </div>

  <!-- Em análise / recusado / bloqueado -->
  <div v-else-if="biz.business.status !== 'approved'" class="narrow" style="max-width: 520px">
    <div class="auth-logo"><AppLogo /></div>
    <div class="card glow">
      <h3>{{ biz.business.name }}</h3>
      <template v-if="biz.business.status === 'pending'">
        <p><span class="badge yellow">Em análise</span></p>
        <p>Recebemos seu cadastro e nossa equipe está analisando. Você receberá um aviso assim que for aprovado.</p>
      </template>
      <template v-else-if="biz.business.status === 'rejected'">
        <p><span class="badge red">Cadastro não aprovado</span></p>
        <p v-if="biz.business.status_reason">Motivo: {{ biz.business.status_reason }}</p>
        <p>Se acha que houve um engano, fale com o nosso suporte.</p>
      </template>
      <template v-else>
        <p><span class="badge red">Acesso bloqueado</span></p>
        <p>{{ biz.business.status_reason || 'Seu acesso está bloqueado. Regularize a assinatura ou fale com o suporte.' }}</p>
      </template>
      <div class="row">
        <button class="btn secondary shrink" @click="biz.reload()">Atualizar</button>
        <RouterLink v-if="isAdmin" class="btn secondary shrink" to="/admin">Painel admin</RouterLink>
        <button class="btn secondary shrink" @click="logout">Sair</button>
      </div>
    </div>
  </div>

  <!-- Painel -->
  <div v-else class="app-shell" :style="brandStyle">
    <aside class="sidebar">
      <div class="brand">
        <img v-if="biz.business.logo_url" :src="biz.business.logo_url" alt="" />
        <span v-else class="initial">{{ biz.business.name.charAt(0).toUpperCase() }}</span>
        <div style="min-width: 0">
          <div style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap">{{ biz.business.name }}</div>
          <small>{{ biz.plan ? `Plano ${biz.plan.name}` : biz.business.category }}</small>
        </div>
      </div>
      <nav>
        <RouterLink v-for="item in nav" :key="item.to" :to="item.to"
                    :class="{ disabled: !biz.live && !FREE_WHEN_INACTIVE.includes(item.to), locked: item.locked }">
          <Icon :name="item.icon" />{{ item.label }}
          <span v-if="item.locked" class="lock-tag">PRO</span>
        </RouterLink>
        <RouterLink v-if="isAdmin" to="/admin"><Icon name="shield" />Admin da plataforma</RouterLink>
        <a href="#" @click.prevent="logout"><Icon name="logout" />Sair</a>
      </nav>
      <div v-if="biz.live" class="share">
        <div style="font-weight: 600; margin-bottom: 4px">Link da sua vitrine</div>
        <a :href="publicLink" target="_blank">{{ publicLink }}</a>
        <button class="btn small block" style="margin-top: 10px" @click="copyLink">
          <Icon name="link" style="width: 15px; height: 15px" />{{ copied ? 'Copiado!' : 'Copiar link' }}
        </button>
      </div>
      <div class="footer">{{ APP_NAME }} · G&amp;G Soluções</div>
    </aside>
    <main class="main">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.sidebar nav a.locked { opacity: 0.6; }
.lock-tag { margin-left: auto; font-size: 0.6rem; font-weight: 800; letter-spacing: 0.06em; padding: 2px 6px; border-radius: 6px; background: var(--brand-soft); color: var(--brand-ink); border: 1px solid var(--border); }
</style>
