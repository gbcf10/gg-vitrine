<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { money } from '@/lib/format'
import { CATEGORIES_BY_KIND, FEATURE_LABELS, APP_DOMAIN, APP_SLOGAN, KINDS } from '@/config/brand'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'

const allPlans = ref([])
const plans = computed(() => allPlans.value.filter((p) => p.kind === 'agenda'))
const kindCards = computed(() => Object.entries(KINDS).map(([kind, k]) => {
  const prices = allPlans.value.filter((p) => p.kind === kind).map((p) => Number(p.base_price))
  return { kind, ...k, examples: CATEGORIES_BY_KIND[kind].slice(0, 5).join(' · '), from: prices.length ? Math.min(...prices) : null }
}))

onMounted(async () => {
  const { data } = await supabase.from('plans').select('*').order('sort_order')
  allPlans.value = data ?? []
})

// Mostra só o que cada plano acrescenta em relação ao anterior.
function newFeatures(index) {
  const prev = new Set(plans.value[index - 1]?.features ?? [])
  return plans.value[index].features.filter((f) => !prev.has(f))
}

function limits(plan) {
  return [
    plan.max_professionals ? `Até ${plan.max_professionals} profissional${plan.max_professionals > 1 ? 'is' : ''}` : 'Profissionais ilimitados',
    plan.max_customers ? `Até ${plan.max_customers} clientes` : 'Clientes ilimitados',
  ]
}

const notifications = [
  { icon: 'calendar', title: 'Novo agendamento', when: 'agora', text: 'Corte + barba · hoje às 10:00' },
  { icon: 'bag', title: 'Novo pedido', when: '2 min', text: '2 itens · entrega · R$ 69,00' },
  { icon: 'sparkles', title: 'Novo agendamento', when: '5 min', text: 'Manicure · amanhã às 14:30' },
  { icon: 'bag', title: 'Novo pedido', when: '8 min', text: '1 item · retirada · R$ 32,00' },
]

const steps = [
  { icon: 'store', title: 'Cadastre seu negócio', text: 'Envie seus dados. Analisamos e aprovamos rapidinho.' },
  { icon: 'scissors', title: 'Monte sua vitrine', text: 'Serviços ou cardápio, preços, fotos e horários em poucos minutos.' },
  { icon: 'link', title: 'Compartilhe seu link', text: 'Seus clientes agendam ou pedem sozinhos, a qualquer hora.' },
]

const features = [
  { icon: 'link', title: 'Link próprio', text: `${APP_DOMAIN}/seu-negocio com sua logo e sua cor.` },
  { icon: 'whatsapp', title: 'Tudo no WhatsApp', text: 'Pedidos, reservas e orçamentos chegam prontos no seu WhatsApp.' },
  { icon: 'star', title: 'Avaliações', text: 'Clientes avaliam e você aprova o que aparece na vitrine.' },
  { icon: 'gift', title: 'Cartão fidelidade', text: 'Carimbos automáticos: no 10º atendimento, o cliente ganha um prêmio.' },
  { icon: 'tag', title: 'Cupons de desconto', text: 'Crie códigos promocionais para divulgar nas redes.' },
  { icon: 'qr', title: 'QR Code e cartaz', text: 'Imprima e deixe no balcão, na mesa ou na vitrine da loja.' },
]
</script>

<template>
  <nav class="topnav">
    <div class="container">
      <AppLogo />
      <div class="links">
        <a href="#como-funciona" class="hide-sm">Como funciona</a>
        <a href="#vitrines" class="hide-sm">Vitrines</a>
        <a href="#planos" class="hide-sm">Planos</a>
        <RouterLink class="btn secondary small" to="/entrar">Entrar</RouterLink>
        <RouterLink class="btn small" to="/cadastro">Começar</RouterLink>
      </div>
    </div>
  </nav>

  <!-- Hero -->
  <header class="hero">
    <div class="container hero-grid">
      <div>
        <p class="eyebrow">Sua vitrine online</p>
        <h1 class="hero-title gradient-text">{{ APP_SLOGAN }}</h1>
        <p class="hero-sub">
          Crie a vitrine do seu negócio com link próprio. Seu cliente agenda um horário ou faz um pedido
          sozinho, direto pelo celular. Você só aparece para atender.
        </p>
        <div class="row" style="gap: 12px">
          <RouterLink class="btn large shrink" to="/cadastro">Cadastrar meu negócio</RouterLink>
          <a class="btn secondary large shrink" href="#planos">Ver planos</a>
        </div>
      </div>

      <div class="hero-visual" aria-hidden="true">
        <div class="hero-glow" />
        <div class="feed">
          <div class="link-pill">
            <Icon name="link" />
            <span>{{ APP_DOMAIN }}/<strong>seu-negocio</strong></span>
          </div>
          <div v-for="(n, i) in notifications" :key="n.title" class="card notif" :style="{ '--i': i }">
            <div class="notif-icon"><Icon :name="n.icon" /></div>
            <div style="flex: 1; min-width: 0">
              <div class="notif-top"><strong>{{ n.title }}</strong><small>{{ n.when }}</small></div>
              <div class="muted notif-text">{{ n.text }}</div>
            </div>
          </div>
          <div class="card floating">
            <div class="stat">
              <div class="label">Esta semana</div>
              <div class="value gradient-text">+38 clientes</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>

  <div class="tagline container">
    <template v-for="(c, i) in [...CATEGORIES_BY_KIND.agenda.slice(0, 4), ...CATEGORIES_BY_KIND.cardapio.slice(0, 3)]" :key="c">
      <span v-if="i" class="dot">•</span><span>{{ c }}</span>
    </template>
  </div>

  <!-- Como funciona -->
  <section id="como-funciona" class="container section">
    <p class="eyebrow center">Como funciona</p>
    <h2 class="section-title">Sua vitrine no ar em 3 passos</h2>
    <div class="grid three">
      <div v-for="(s, i) in steps" :key="s.title" class="card hoverable how-step">
        <div class="icon-box"><Icon :name="s.icon" /></div>
        <span class="step-n">0{{ i + 1 }}</span>
        <h3>{{ s.title }}</h3>
        <p class="muted" style="margin: 0">{{ s.text }}</p>
      </div>
    </div>
  </section>

  <!-- Recursos -->
  <section class="container section">
    <p class="eyebrow center">Recursos</p>
    <h2 class="section-title">Recursos que fazem o cliente voltar</h2>
    <div class="grid three">
      <div v-for="f in features" :key="f.title" class="card hoverable feature">
        <div class="icon-box small"><Icon :name="f.icon" /></div>
        <div>
          <h3 style="margin-bottom: 4px">{{ f.title }}</h3>
          <p class="muted" style="margin: 0; font-size: 0.92rem">{{ f.text }}</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Tipos de vitrine -->
  <section id="vitrines" class="container section">
    <p class="eyebrow center">Para cada tipo de negócio</p>
    <h2 class="section-title">Escolha como seus clientes vão te encontrar</h2>
    <div class="grid three">
      <RouterLink v-for="k in kindCards" :key="k.kind" to="/cadastro" class="card hoverable kind-card">
        <div class="icon-box small"><Icon :name="k.icon" /></div>
        <h3 style="margin: 14px 0 6px">{{ k.label }}</h3>
        <p class="muted" style="margin: 0 0 10px; font-size: 0.92rem">{{ k.description }}</p>
        <small class="examples">{{ k.examples }}</small>
        <div v-if="k.from" class="kind-price">a partir de <strong class="gradient-text">{{ money(k.from) }}</strong>/mês</div>
      </RouterLink>
    </div>
  </section>

  <!-- Planos -->
  <section id="planos" class="container section">
    <p class="eyebrow center">Planos</p>
    <h2 class="section-title">Planos de agendamento para o tamanho do seu negócio</h2>
    <p class="muted" style="text-align: center; margin: -20px 0 28px">As outras vitrines têm plano único, com os valores mostrados acima.</p>
    <div class="grid three">
      <div v-for="(plan, i) in plans" :key="plan.id" class="card plan" :class="{ featured: plan.id === 'profissional' }">
        <span v-if="plan.id === 'profissional'" class="badge blue plan-tag">Mais escolhido</span>
        <h3>{{ plan.name }}</h3>
        <div class="price">
          <span class="gradient-text">{{ money(plan.base_price) }}</span><small>/mês</small>
        </div>
        <ul class="plan-list">
          <li v-for="l in limits(plan)" :key="l"><Icon name="check" />{{ l }}</li>
          <li v-if="i > 0" class="plus">Tudo do {{ plans[i - 1].name }}, mais:</li>
          <li v-for="f in newFeatures(i)" :key="f"><Icon name="check" />{{ FEATURE_LABELS[f] ?? f }}</li>
        </ul>
        <RouterLink :class="['btn', 'block', plan.id === 'profissional' ? '' : 'secondary']" to="/cadastro">
          Começar com o {{ plan.name }}
        </RouterLink>
      </div>
    </div>
  </section>

  <!-- CTA -->
  <section class="container section">
    <div class="card cta glow">
      <h2 class="gradient-text">{{ APP_SLOGAN }}</h2>
      <p class="muted">Cadastre seu negócio e coloque sua vitrine no ar ainda hoje.</p>
      <RouterLink class="btn large" to="/cadastro">Criar minha vitrine</RouterLink>
    </div>
  </section>

  <footer class="container footer">
    <div>
      <AppLogo />
      <div class="muted" style="font-size: 0.85rem; margin-top: 6px">{{ APP_SLOGAN }}</div>
    </div>
    <div class="footer-links">
      <RouterLink to="/termos">Termos de uso</RouterLink>
      <RouterLink to="/privacidade">Privacidade</RouterLink>
      <span class="muted">Um produto <a href="https://portfoliogegsolucoes.netlify.app/" target="_blank" rel="noopener">G&amp;G Soluções</a></span>
    </div>
  </footer>
</template>

<style scoped>
.hero { border-bottom: 1px solid var(--border); background: linear-gradient(180deg, rgba(11, 23, 48, 0.6), transparent 70%); overflow: hidden; }
.hero-grid { display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 40px; align-items: center; padding: 64px 0 72px; }
.hero-title { font-size: clamp(2.1rem, 4.4vw, 3.4rem); font-weight: 800; margin-bottom: 18px; }
.hero-sub { color: var(--muted); font-size: 1.1rem; max-width: 540px; margin-bottom: 28px; }

.hero-visual { position: relative; display: grid; place-items: center; min-height: 380px; }
.hero-glow {
  position: absolute; inset: -20%;
  background: radial-gradient(circle at 60% 40%, rgba(59, 130, 246, 0.35), transparent 60%),
              radial-gradient(circle at 30% 70%, rgba(207, 216, 227, 0.12), transparent 55%);
  filter: blur(20px);
}
.mock {
  position: relative; width: 100%; max-width: 340px;
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.07), rgba(11, 23, 48, 0.6));
  box-shadow: var(--shadow), 0 0 40px rgba(59, 130, 246, 0.12);
}
.mock-head { display: flex; gap: 12px; align-items: center; margin-bottom: 16px; }
.mock-avatar {
  width: 42px; height: 42px; border-radius: 12px; display: grid; place-items: center; font-weight: 800;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
}
.mock-service { display: flex; justify-content: space-between; padding: 12px 14px; border-radius: 12px; border: 1px solid var(--brand); background: var(--brand-soft); margin-bottom: 14px; font-size: 0.92rem; }
.mock-days { display: flex; gap: 8px; margin-bottom: 14px; }
.mock-days span { flex: 1; text-align: center; padding: 8px 0; border-radius: 12px; border: 1px solid var(--border); font-size: 0.72rem; color: var(--muted); }
.mock-days span b { display: block; color: var(--text); font-size: 1rem; }
.mock-days span.on { background: linear-gradient(120deg, var(--brand), var(--brand-strong)); border-color: transparent; color: #dbeafe; }
.mock .chip { font-size: 0.82rem; padding: 7px 11px; }
.feed { position: relative; width: 100%; max-width: 360px; display: grid; gap: 12px; }
.link-pill {
  display: flex; align-items: center; gap: 10px; justify-self: start; padding: 10px 16px; border-radius: 999px;
  background: rgba(11, 23, 48, 0.85); border: 1px solid rgba(59, 130, 246, 0.45); box-shadow: 0 0 24px rgba(59, 130, 246, 0.25);
  font-size: 0.9rem; color: var(--silver);
}
.link-pill svg { width: 18px; height: 18px; color: var(--brand-ink); }
.link-pill strong { color: #fff; }
.notif {
  display: flex; gap: 12px; align-items: center; padding: 14px 16px;
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.07), rgba(11, 23, 48, 0.65));
  box-shadow: var(--shadow); margin-left: calc(var(--i) * 14px);
  opacity: calc(1 - var(--i) * 0.17);
  animation: rise 0.6s ease both; animation-delay: calc(var(--i) * 0.15s);
}
.notif-icon {
  width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong)); color: #fff; box-shadow: 0 0 16px var(--brand-glow);
}
.notif-icon svg { width: 20px; height: 20px; }
.notif-top { display: flex; justify-content: space-between; gap: 10px; }
.notif-top small { white-space: nowrap; }
.notif-text { font-size: 0.86rem; }
@keyframes rise { from { opacity: 0; transform: translateY(12px); } }
.floating { position: absolute; right: -28px; bottom: -34px; padding: 14px 18px; animation: float 5s ease-in-out infinite; background: rgba(11, 23, 48, 0.85); }
.floating .value { font-size: 1.2rem; }
@keyframes float { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-10px); } }

.tagline { display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; padding: 22px 0; color: var(--silver); text-transform: uppercase; letter-spacing: 0.18em; font-size: 0.74rem; font-weight: 700; }
.tagline .dot { color: var(--brand); }

.section { padding: 56px 0; border-top: 1px solid var(--border); }
.section-title { text-align: center; font-size: clamp(1.5rem, 2.6vw, 2.1rem); max-width: 720px; margin: 0 auto 36px; }
.eyebrow.center { text-align: center; }
.grid.three { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.card + .card { margin-top: 0; }

.icon-box {
  width: 58px; height: 58px; border-radius: 16px; display: grid; place-items: center; color: var(--silver);
  background: linear-gradient(160deg, rgba(59, 130, 246, 0.16), rgba(11, 23, 48, 0.4));
  border: 1px solid var(--border); box-shadow: 0 0 18px rgba(59, 130, 246, 0.12); margin-bottom: 18px;
}
.icon-box svg { width: 28px; height: 28px; }
.icon-box.small { width: 46px; height: 46px; border-radius: 13px; margin: 0; flex-shrink: 0; }
.icon-box.small svg { width: 22px; height: 22px; }
.card:hover .icon-box { color: #fff; border-color: var(--brand); }
.how-step { position: relative; }
.step-n { position: absolute; top: 20px; right: 22px; font-size: 2rem; font-weight: 800; color: rgba(148, 180, 220, 0.14); }
.feature { display: flex; gap: 16px; align-items: flex-start; }

.plan { position: relative; display: flex; flex-direction: column; }
.plan.featured {
  background: linear-gradient(165deg, rgba(59, 130, 246, 0.2), rgba(29, 78, 216, 0.24));
  border-color: rgba(59, 130, 246, 0.5); box-shadow: var(--shadow), 0 0 40px rgba(59, 130, 246, 0.22);
}
.plan-tag { position: absolute; top: 20px; right: 20px; }
.price { margin: 4px 0 18px; }
.price span { font-size: 2.4rem; font-weight: 800; }
.price small { font-size: 1rem; }
.plan-list { list-style: none; padding: 0; margin: 0 0 24px; flex: 1; display: grid; gap: 9px; font-size: 0.93rem; }
.plan-list li { display: flex; gap: 10px; align-items: flex-start; }
.plan-list svg { width: 18px; height: 18px; color: var(--brand); flex-shrink: 0; margin-top: 2px; }
.plan-list .plus { color: var(--silver); font-weight: 700; margin-top: 6px; }

.cta { text-align: center; padding: 48px 24px; background: linear-gradient(160deg, rgba(59, 130, 246, 0.12), rgba(11, 23, 48, 0.5)); }
.cta h2 { font-size: clamp(1.5rem, 3vw, 2.2rem); }
.footer-links { display: flex; gap: 18px; align-items: center; flex-wrap: wrap; font-size: 0.9rem; }
.footer-links a:not([target]) { color: var(--silver); }
.footer { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; padding: 28px 0 40px; border-top: 1px solid var(--border); }

.kind-card { display: flex; flex-direction: column; color: var(--text); }
.kind-card:hover { color: var(--text); }
.examples { color: var(--silver); font-size: 0.8rem; line-height: 1.5; }
.kind-price { margin-top: auto; padding-top: 14px; color: var(--muted); font-size: 0.9rem; }
.kind-price strong { font-size: 1.3rem; }

@media (max-width: 900px) {
  .hero-grid { grid-template-columns: 1fr; padding: 40px 0 48px; }
  .hero-visual { display: none; }
  .grid.three { grid-template-columns: 1fr; }
  .hide-sm { display: none; }
}
</style>
