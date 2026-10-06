<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { supabase } from '@/lib/supabase'
import { money } from '@/lib/format'
import { CATEGORIES, APP_NAME, APP_DOMAIN, APP_SLOGAN, SUPPORT_WHATSAPP } from '@/config/brand'
import { waLink } from '@/lib/whatsapp'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'

const contactLink = waLink(SUPPORT_WHATSAPP, `Olá! Quero saber mais sobre o ${APP_NAME}.`)
const plans = ref([])

const sampleCategories = CATEGORIES.filter((c) => c !== 'Outro').slice(0, 8)

// Copy específico por plano: tagline (quem é o alvo) + bullets.
// As features em si são as mesmas em todos os planos; o que muda é o número
// de estabelecimentos — e é isso que os bullets reforçam.
const planCopy = {
  solo: {
    tagline: 'Pra quem está começando ou toca o negócio sozinho.',
    bullets: [
      '1 estabelecimento',
      'Profissionais e clientes ilimitados',
      'Agendamento online com seu link próprio',
      'Lembretes automáticos no WhatsApp',
      'Galeria, avaliações e fidelidade',
    ],
  },
  equipe: {
    tagline: 'Ideal pra quem gerencia poucas unidades ou está crescendo.',
    bullets: [
      'Até 3 estabelecimentos no mesmo login',
      'Agendas separadas pra cada unidade',
      'Tudo que o Solo tem, pra cada vitrine',
      'Troca entre vitrines num clique',
      'Pague 1 vez, use nos 3',
    ],
  },
  rede: {
    tagline: 'Pra redes consolidadas com várias unidades no ar.',
    bullets: [
      'Até 5 estabelecimentos no mesmo login',
      'Agendas separadas pra cada unidade',
      'Preço por unidade menor que no Solo',
      'Links e QR Codes individuais',
      'Suporte prioritário no WhatsApp',
    ],
  },
}

// Mockup do app: tela de agendamento (dias / horários)
const mockDays = [
  { d: 'Qui', n: 10 },
  { d: 'Sex', n: 11, on: true },
  { d: 'Sáb', n: 12 },
  { d: 'Dom', n: 13 },
]
const mockSlots = [
  { h: '09:00', taken: false },
  { h: '10:00', taken: true },
  { h: '11:30', taken: false, on: true },
  { h: '14:00', taken: false },
  { h: '15:30', taken: false },
  { h: '17:00', taken: true },
]

const steps = [
  {
    icon: 'user',
    kicker: 'Passo 1',
    title: 'Cadastre em 2 minutos',
    text: 'Nome, segmento e WhatsApp. Pronto, sua conta já abre.',
  },
  {
    icon: 'sparkles',
    kicker: 'Passo 2',
    title: 'Monte sua vitrine com templates',
    text: 'Serviços e horários típicos do seu segmento já vêm prontos. Ajusta o que quiser e tá no ar.',
  },
  {
    icon: 'calendar',
    kicker: 'Passo 3',
    title: 'Compartilhe seu link',
    text: 'Cliente abre, escolhe serviço, dia e hora. Agendamento confirmado — direto na sua agenda.',
  },
]

// Mocks por passo (visuais pequenos dentro de cada card)
const mockForm = {
  nome: 'Studio Aurora',
  segmento: 'Salão de beleza',
  telefone: '(11) 98765-4321',
}
const mockServices = [
  { name: 'Corte feminino', dur: '45 min', price: 'R$ 80' },
  { name: 'Escova', dur: '30 min', price: 'R$ 60' },
  { name: 'Coloração', dur: '90 min', price: 'R$ 180' },
]
const mockVitrineSlots = ['09:00', '10:00', '11:30', '14:00']

// Grid bento: a primeira feature é a "principal" (destaque grande).
const features = [
  { icon: 'link', title: 'Link próprio', text: `${APP_DOMAIN}/seu-negocio com sua logo e sua cor.`, size: 'xl' },
  { icon: 'calendar', title: 'Agendamento 24h', text: 'Clientes agendam de qualquer lugar, mesmo fora do horário.' },
  { icon: 'bell', title: 'Lembrete automático', text: 'Reduz o não comparecimento com aviso no WhatsApp.' },
  { icon: 'star', title: 'Avaliações', text: 'Clientes avaliam e você aprova o que aparece na vitrine.' },
  { icon: 'gift', title: 'Cartão fidelidade', text: 'Carimbos automáticos: no 10º atendimento, o cliente ganha um prêmio.' },
  { icon: 'qr', title: 'QR Code e cartaz', text: 'Imprima e deixe no balcão ou na vitrine da loja.' },
]

// Scroll reveal com IntersectionObserver (sem lib).
let io
onMounted(async () => {
  // Carrega os planos da Supabase
  const { data } = await supabase.from('plans').select('*').order('sort_order')
  plans.value = data ?? []

  if (typeof IntersectionObserver === 'undefined') return
  io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          e.target.classList.add('is-visible')
          io.unobserve(e.target)
        }
      }
    },
    { rootMargin: '0px 0px -10% 0px', threshold: 0.1 },
  )
  requestAnimationFrame(() => {
    document.querySelectorAll('[data-reveal]').forEach((el) => io.observe(el))
  })
})
onBeforeUnmount(() => io?.disconnect())
</script>

<template>
  <nav class="topnav">
    <div class="container">
      <AppLogo />
      <div class="links">
        <a href="#como-funciona" class="hide-sm">Como funciona</a>
        <a href="#recursos" class="hide-sm">Recursos</a>
        <a href="#planos" class="hide-sm">Planos</a>
        <RouterLink class="btn secondary small" to="/entrar">Entrar</RouterLink>
        <RouterLink class="btn small" to="/cadastro">Começar</RouterLink>
      </div>
    </div>
  </nav>

  <!-- Hero -->
  <header class="hero">
    <div class="hero-bg" aria-hidden="true">
      <div class="hero-grid-lines" />
      <div class="hero-orb orb-a" />
      <div class="hero-orb orb-b" />
    </div>

    <div class="container hero-grid">
      <div class="hero-copy">
        <div class="hero-pill">
          <span class="dot-live" />
          Agendamento online pra negócios de serviço
        </div>
        <h1 class="hero-title">
          <span class="line-1">Mostre seus serviços.</span>
          <span class="line-2 gradient-text">Receba clientes.</span>
        </h1>
        <p class="hero-sub">
          Crie a vitrine do seu negócio com link próprio. Seu cliente marca o horário sozinho,
          direto pelo celular, a qualquer hora. Você só aparece pra atender.
        </p>
        <div class="hero-cta">
          <RouterLink class="btn large shrink" to="/cadastro">
            Cadastrar meu negócio
            <Icon name="plus" />
          </RouterLink>
          <a class="btn secondary large shrink" href="#planos">Ver planos</a>
        </div>
        <div class="hero-proof">
          <div class="proof-item">
            <strong>24h</strong>
            <span>agenda sempre aberta</span>
          </div>
          <div class="proof-divider" />
          <div class="proof-item">
            <strong>-70%</strong>
            <span>em não comparecimento</span>
          </div>
          <div class="proof-divider" />
          <div class="proof-item">
            <strong>5 min</strong>
            <span>pra colocar no ar</span>
          </div>
        </div>
      </div>

      <div class="hero-visual" aria-hidden="true">
        <!-- Chip do link flutuante -->
        <div class="link-pill float-a">
          <Icon name="link" />
          <span>{{ APP_DOMAIN }}/<strong>seu-negocio</strong></span>
        </div>

        <!-- Mockup celular -->
        <div class="phone">
          <div class="phone-notch" />
          <div class="phone-screen">
            <div class="screen-head">
              <div class="screen-avatar">S</div>
              <div class="screen-head-text">
                <strong>Studio Aurora</strong>
                <small>Corte feminino · 45 min</small>
              </div>
            </div>

            <div class="screen-label">Escolha o dia</div>
            <div class="screen-days">
              <button
                v-for="d in mockDays"
                :key="d.d"
                type="button"
                class="day"
                :class="{ on: d.on }"
                tabindex="-1"
              >
                <small>{{ d.d }}</small>
                <strong>{{ d.n }}</strong>
              </button>
            </div>

            <div class="screen-label">Horários</div>
            <div class="screen-slots">
              <button
                v-for="s in mockSlots"
                :key="s.h"
                type="button"
                class="slot"
                :class="{ on: s.on, taken: s.taken }"
                tabindex="-1"
              >
                {{ s.h }}
              </button>
            </div>

            <button type="button" class="screen-cta" tabindex="-1">
              Confirmar agendamento
            </button>
          </div>
        </div>

        <!-- Card flutuante: stat -->
        <div class="float-card float-b">
          <div class="float-icon"><Icon name="sparkles" /></div>
          <div>
            <div class="float-label">Esta semana</div>
            <div class="float-value gradient-text">+38 clientes</div>
          </div>
        </div>

        <!-- Card flutuante: notificação -->
        <div class="float-card float-c compact">
          <div class="float-icon success"><Icon name="check" /></div>
          <div>
            <strong>Agendamento confirmado</strong>
            <small>Corte + barba · 10:00</small>
          </div>
        </div>
      </div>
    </div>
  </header>

  <div class="tagline container" data-reveal>
    <template v-for="(c, i) in sampleCategories" :key="c">
      <span v-if="i" class="dot">•</span><span>{{ c }}</span>
    </template>
  </div>

  <!-- Como funciona -->
  <section id="como-funciona" class="container section">
    <div class="section-head" data-reveal>
      <p class="eyebrow">Como funciona</p>
      <h2 class="section-title">Do cadastro ao primeiro cliente em <span class="gradient-text">3 passos</span></h2>
      <p class="section-sub">Uma jornada curta: você cadastra, o template monta sua vitrine e seu cliente agenda sozinho.</p>
    </div>

    <ol class="journey" aria-label="Como funciona em 3 passos">
      <!-- Linha conectora (desktop) -->
      <div class="journey-track" aria-hidden="true">
        <div class="journey-track-fill" />
      </div>

      <li
        v-for="(s, i) in steps"
        :key="s.title"
        class="journey-step"
        data-reveal
        :style="{ '--delay': i * 180 + 'ms', '--i': i }"
      >
        <!-- Conector mobile (vertical) -->
        <span class="journey-connector" aria-hidden="true" />

        <!-- Visual (mockup pequeno) -->
        <div class="journey-visual" aria-hidden="true">
          <div class="journey-badge">0{{ i + 1 }}</div>

          <!-- Passo 1: mini-form de cadastro -->
          <div v-if="i === 0" class="mock-form">
            <div class="mock-form-head">
              <div class="mock-logo-dot" />
              <span>Criar conta</span>
            </div>
            <div class="mock-field" style="--d:0.1s">
              <small>Nome do negócio</small>
              <div class="mock-input">
                <span class="type-text">{{ mockForm.nome }}</span>
                <span class="caret" />
              </div>
            </div>
            <div class="mock-field" style="--d:0.9s">
              <small>Segmento</small>
              <div class="mock-input select">
                <span>{{ mockForm.segmento }}</span>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6" /></svg>
              </div>
            </div>
            <div class="mock-field" style="--d:1.5s">
              <small>WhatsApp</small>
              <div class="mock-input">{{ mockForm.telefone }}</div>
            </div>
            <div class="mock-submit" style="--d:2.1s">
              <Icon name="check" />
              <span>Conta criada</span>
            </div>
          </div>

          <!-- Passo 2: template sendo aplicado -->
          <div v-else-if="i === 1" class="mock-panel">
            <div class="mock-panel-head">
              <div class="mock-chip">
                <Icon name="sparkles" />
                <span>Template aplicado</span>
              </div>
              <small>Salão de beleza</small>
            </div>
            <ul class="mock-services">
              <li
                v-for="(svc, k) in mockServices"
                :key="svc.name"
                class="mock-service"
                :style="{ '--d': 0.3 + k * 0.35 + 's' }"
              >
                <div class="mock-service-dot"><Icon name="scissors" /></div>
                <div class="mock-service-body">
                  <strong>{{ svc.name }}</strong>
                  <small>{{ svc.dur }}</small>
                </div>
                <span class="mock-service-price">{{ svc.price }}</span>
              </li>
            </ul>
            <div class="mock-panel-foot" style="--d:1.6s">
              <span class="live-dot" />
              <span>Vitrine no ar</span>
            </div>
          </div>

          <!-- Passo 3: cliente agenda + confirmação popping -->
          <div v-else class="mock-vitrine">
            <div class="mock-url">
              <Icon name="link" />
              <span>{{ APP_DOMAIN }}/<strong>studio-aurora</strong></span>
            </div>
            <div class="mock-vitrine-head">
              <div class="mock-vit-avatar">S</div>
              <div>
                <strong>Studio Aurora</strong>
                <small>Escolha um horário</small>
              </div>
            </div>
            <div class="mock-slots">
              <button
                v-for="(h, k) in mockVitrineSlots"
                :key="h"
                type="button"
                class="mock-slot"
                :class="{ picked: k === 2 }"
                :style="{ '--d': 0.3 + k * 0.15 + 's' }"
                tabindex="-1"
              >
                {{ h }}
              </button>
            </div>
            <div class="mock-toast" style="--d:1.3s">
              <div class="mock-toast-icon"><Icon name="check" /></div>
              <div>
                <strong>Agendado!</strong>
                <small>Sex 12 · 11:30</small>
              </div>
            </div>
          </div>
        </div>

        <!-- Texto -->
        <div class="journey-copy">
          <span class="journey-kicker">
            <span class="journey-kicker-num">0{{ i + 1 }}</span>
            <span>{{ s.kicker }}</span>
          </span>
          <h3 class="journey-title">{{ s.title }}</h3>
          <p class="journey-text">{{ s.text }}</p>
        </div>
      </li>
    </ol>
  </section>

  <!-- Recursos (bento) -->
  <section id="recursos" class="container section">
    <div class="section-head" data-reveal>
      <p class="eyebrow">Recursos</p>
      <h2 class="section-title">Tudo o que faz o cliente <span class="gradient-text">voltar</span></h2>
    </div>

    <div class="bento">
      <!-- Feature grande (destaque) -->
      <div class="card hoverable bento-xl" data-reveal>
        <div class="bento-xl-head">
          <div class="icon-box"><Icon :name="features[0].icon" /></div>
          <span class="badge blue">Principal</span>
        </div>
        <h3 class="bento-xl-title">{{ features[0].title }}</h3>
        <p class="muted bento-xl-text">{{ features[0].text }}</p>
        <div class="url-preview">
          <span class="url-dot" /><span class="url-dot" /><span class="url-dot" />
          <code>{{ APP_DOMAIN }}/<strong>seu-negocio</strong></code>
        </div>
      </div>

      <!-- Features menores -->
      <div
        v-for="(f, i) in features.slice(1)"
        :key="f.title"
        class="card hoverable bento-item"
        data-reveal
        :style="{ '--delay': (i + 1) * 60 + 'ms' }"
      >
        <div class="icon-box small"><Icon :name="f.icon" /></div>
        <div>
          <h3 class="bento-item-title">{{ f.title }}</h3>
          <p class="muted bento-item-text">{{ f.text }}</p>
        </div>
      </div>
    </div>
  </section>

  <!-- Planos -->
  <section id="planos" class="container section">
    <div class="section-head" data-reveal>
      <p class="eyebrow">Planos</p>
      <h2 class="section-title">
        Pague uma vez por mês.<br />
        <span class="gradient-text">Gerencie quantos negócios quiser.</span>
      </h2>
      <p class="section-sub">Todos os planos têm as mesmas funcionalidades — mudam só o número de estabelecimentos que você pode cadastrar na sua conta.</p>
    </div>

    <div class="plans">
      <div
        v-for="(plan, i) in plans"
        :key="plan.id"
        class="card plan"
        :class="{ featured: plan.id === 'equipe' }"
        data-reveal
        :style="{ '--delay': i * 90 + 'ms' }"
      >
        <div v-if="plan.id === 'equipe'" class="ribbon">
          <Icon name="sparkles" />
          Mais escolhido
        </div>
        <div class="plan-head">
          <h3 class="plan-name">{{ plan.name }}</h3>
          <p class="plan-tagline">{{ planCopy[plan.id]?.tagline }}</p>
        </div>

        <div class="price">
          <span class="price-amount gradient-text">{{ money(plan.base_price) }}</span>
          <small class="price-period">/mês</small>
        </div>
        <p class="muted fee-note">+ taxa do meio de pagamento (a partir de R$ 1,99)</p>

        <div class="plan-sep" />

        <ul class="plan-list">
          <li v-for="f in (planCopy[plan.id]?.bullets ?? [])" :key="f">
            <span class="plan-check"><Icon name="check" /></span>
            {{ f }}
          </li>
        </ul>
        <RouterLink :class="['btn', 'block', plan.id === 'equipe' ? '' : 'secondary']" to="/cadastro">
          Começar com o {{ plan.name }}
        </RouterLink>
      </div>
    </div>
  </section>

  <!-- CTA -->
  <section class="container section">
    <div class="card cta glow" data-reveal>
      <div class="cta-glow" aria-hidden="true" />
      <p class="eyebrow">Começar agora</p>
      <h2 class="gradient-text">{{ APP_SLOGAN }}</h2>
      <p class="muted">Cadastre seu negócio e coloque sua vitrine no ar ainda hoje.</p>
      <RouterLink class="btn large" to="/cadastro">
        Criar minha vitrine
        <Icon name="plus" />
      </RouterLink>
    </div>
  </section>

  <footer class="container footer">
    <div>
      <AppLogo />
      <div class="muted" style="font-size: 0.85rem; margin-top: 6px">{{ APP_SLOGAN }}</div>
    </div>
    <div class="footer-links">
      <a v-if="contactLink" :href="contactLink" target="_blank" rel="noopener">Fale conosco</a>
      <RouterLink to="/termos">Termos de uso</RouterLink>
      <RouterLink to="/privacidade">Privacidade</RouterLink>
      <span class="muted">Um produto <a href="https://portfoliogegsolucoes.netlify.app/" target="_blank" rel="noopener">G&amp;G Soluções</a></span>
    </div>
  </footer>
</template>

<style scoped>
/* =====================================================================
   HERO
   ===================================================================== */
.hero {
  position: relative;
  border-bottom: 1px solid var(--border);
  overflow: hidden;
  isolation: isolate;
}
.hero-bg {
  position: absolute; inset: 0; z-index: -1; pointer-events: none;
}
.hero-grid-lines {
  position: absolute; inset: 0;
  background-image:
    linear-gradient(rgba(148, 180, 220, 0.055) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 180, 220, 0.055) 1px, transparent 1px);
  background-size: 56px 56px;
  mask-image: radial-gradient(ellipse 70% 60% at 50% 30%, #000 40%, transparent 85%);
  -webkit-mask-image: radial-gradient(ellipse 70% 60% at 50% 30%, #000 40%, transparent 85%);
}
.hero-orb {
  position: absolute; border-radius: 50%; filter: blur(60px); opacity: 0.55;
  animation: orbFloat 14s ease-in-out infinite;
}
.orb-a {
  width: 520px; height: 520px;
  background: radial-gradient(circle, rgba(59, 130, 246, 0.45), transparent 65%);
  top: -140px; right: -80px;
}
.orb-b {
  width: 420px; height: 420px;
  background: radial-gradient(circle, rgba(29, 78, 216, 0.35), transparent 65%);
  bottom: -160px; left: -60px;
  animation-delay: -7s;
}
@keyframes orbFloat {
  0%, 100% { transform: translate(0, 0) scale(1); }
  50% { transform: translate(20px, -20px) scale(1.05); }
}

.hero-grid {
  display: grid;
  grid-template-columns: 1.05fr 1fr;
  gap: 64px;
  align-items: center;
  padding: 72px 0 96px;
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

.hero-title {
  font-size: clamp(2.4rem, 5.6vw, 4rem);
  font-weight: 800;
  line-height: 1.02;
  letter-spacing: -0.035em;
  margin: 0 0 22px;
  font-feature-settings: 'ss01', 'cv11';
}
.hero-title .line-1 { display: block; color: var(--text); }
.hero-title .line-2 { display: block; }

.hero-sub {
  color: var(--silver);
  font-size: 1.12rem;
  line-height: 1.55;
  max-width: 540px;
  margin: 0 0 32px;
}

.hero-cta { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 36px; }
.hero-cta .btn.large svg { width: 18px; height: 18px; }

.hero-proof {
  display: flex; align-items: center; gap: 20px;
  padding-top: 24px; border-top: 1px solid var(--border);
  flex-wrap: wrap;
}
.proof-item { display: flex; flex-direction: column; gap: 2px; }
.proof-item strong {
  font-size: 1.3rem; font-weight: 800; color: var(--text);
  letter-spacing: -0.02em;
}
.proof-item span { font-size: 0.78rem; color: var(--muted); }
.proof-divider { width: 1px; height: 32px; background: var(--border); }

/* ---------- Visual: mockup celular ---------- */
.hero-visual {
  position: relative;
  display: grid;
  place-items: center;
  min-height: 520px;
}

.link-pill {
  position: absolute;
  display: inline-flex; align-items: center; gap: 10px;
  padding: 10px 16px; border-radius: 999px;
  background: rgba(11, 23, 48, 0.92);
  border: 1px solid rgba(59, 130, 246, 0.5);
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4), 0 0 24px rgba(59, 130, 246, 0.25);
  font-size: 0.88rem; color: var(--silver);
  backdrop-filter: blur(12px);
  z-index: 3;
}
.link-pill svg { width: 16px; height: 16px; color: var(--brand-ink); }
.link-pill strong { color: #fff; }
.float-a { top: 8px; left: -16px; animation: float 6s ease-in-out infinite; }

.phone {
  position: relative;
  width: 290px;
  aspect-ratio: 9 / 18;
  border-radius: 42px;
  padding: 10px;
  background: linear-gradient(160deg, rgba(255, 255, 255, 0.14), rgba(11, 23, 48, 0.5));
  border: 1px solid rgba(148, 180, 220, 0.22);
  box-shadow:
    0 40px 80px rgba(0, 0, 0, 0.55),
    0 0 60px rgba(59, 130, 246, 0.18),
    inset 0 0 0 1px rgba(255, 255, 255, 0.04);
  z-index: 2;
  animation: phoneFloat 7s ease-in-out infinite;
}
@keyframes phoneFloat {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-8px); }
}
.phone-notch {
  position: absolute; top: 18px; left: 50%; transform: translateX(-50%);
  width: 76px; height: 20px;
  border-radius: 999px;
  background: #050b16;
  border: 1px solid rgba(255, 255, 255, 0.06);
  z-index: 4;
}
.phone-screen {
  width: 100%; height: 100%;
  border-radius: 34px;
  background: linear-gradient(180deg, #0a1526 0%, #050b16 100%);
  padding: 44px 18px 18px;
  display: flex; flex-direction: column;
  overflow: hidden;
}
.screen-head { display: flex; align-items: center; gap: 10px; margin-bottom: 18px; }
.screen-avatar {
  width: 38px; height: 38px; border-radius: 12px;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff; font-weight: 800;
  box-shadow: 0 0 20px rgba(59, 130, 246, 0.35);
  flex-shrink: 0;
}
.screen-head-text { display: flex; flex-direction: column; min-width: 0; }
.screen-head-text strong { color: #fff; font-size: 0.9rem; }
.screen-head-text small { color: var(--muted); font-size: 0.72rem; }

.screen-label {
  color: var(--muted); font-size: 0.65rem;
  text-transform: uppercase; letter-spacing: 0.14em; font-weight: 700;
  margin: 4px 0 8px;
}
.screen-days { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-bottom: 14px; }
.day {
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  padding: 8px 0;
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
  color: var(--silver);
  cursor: default; font: inherit;
}
.day small { font-size: 0.6rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; }
.day strong { font-size: 1rem; color: #fff; }
.day.on {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent; color: #fff;
  box-shadow: 0 6px 18px rgba(59, 130, 246, 0.4);
}
.day.on small { color: rgba(255, 255, 255, 0.75); }

.screen-slots { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-bottom: auto; }
.slot {
  padding: 8px 0;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
  color: var(--silver);
  font-size: 0.76rem; font-weight: 600;
  cursor: default; font-family: inherit;
}
.slot.on {
  background: var(--brand-soft);
  border-color: var(--brand);
  color: #fff;
  box-shadow: 0 0 0 1px var(--brand) inset;
}
.slot.taken {
  opacity: 0.35; text-decoration: line-through;
}

.screen-cta {
  margin-top: 14px;
  padding: 11px;
  border-radius: 14px;
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff; font-weight: 700; font-size: 0.82rem;
  border: none; cursor: default; font-family: inherit;
  box-shadow: 0 10px 24px rgba(59, 130, 246, 0.35);
}

/* Cards flutuantes auxiliares */
.float-card {
  position: absolute;
  display: flex; align-items: center; gap: 12px;
  padding: 14px 16px; border-radius: 16px;
  background: rgba(11, 23, 48, 0.92);
  border: 1px solid var(--border);
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(14px);
  z-index: 3;
}
.float-card.compact { padding: 10px 14px; }
.float-icon {
  width: 36px; height: 36px; border-radius: 10px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px rgba(59, 130, 246, 0.45);
}
.float-icon.success {
  background: linear-gradient(140deg, #22c55e, #15803d);
  box-shadow: 0 0 16px rgba(74, 222, 128, 0.4);
}
.float-icon svg { width: 18px; height: 18px; }
.float-label { font-size: 0.68rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.1em; font-weight: 700; }
.float-value { font-size: 1.05rem; font-weight: 800; }
.float-card.compact strong { display: block; font-size: 0.82rem; color: #fff; }
.float-card.compact small { font-size: 0.72rem; color: var(--muted); }

.float-b { right: -22px; top: 22%; animation: float 7s ease-in-out infinite; animation-delay: -2s; }
.float-c { right: -8px; bottom: 14%; animation: float 6s ease-in-out infinite; animation-delay: -4s; }

@keyframes float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-10px); }
}

/* =====================================================================
   Tagline (categorias)
   ===================================================================== */
.tagline {
  display: flex; flex-wrap: wrap; justify-content: center; gap: 10px;
  padding: 26px 0;
  color: var(--silver);
  text-transform: uppercase; letter-spacing: 0.2em;
  font-size: 0.72rem; font-weight: 700;
}
.tagline .dot { color: var(--brand); }

/* =====================================================================
   Sections (comum)
   ===================================================================== */
.section { padding: 80px 0; border-top: 1px solid var(--border); }
.section-head { text-align: center; max-width: 720px; margin: 0 auto 48px; }
.section-head .eyebrow { display: inline-block; margin-bottom: 14px; }
.section-title {
  font-size: clamp(1.7rem, 3.4vw, 2.5rem);
  font-weight: 800;
  letter-spacing: -0.025em;
  line-height: 1.1;
  margin: 0 0 14px;
}
.section-sub {
  color: var(--muted);
  font-size: 1rem;
  max-width: 540px;
  margin: 0 auto;
}

/* =====================================================================
   Como funciona — Jornada visual
   ===================================================================== */
.journey {
  position: relative;
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 28px;
  counter-reset: journey;
}

/* Trilho conector no desktop (atrás dos cards, horizontal) */
.journey-track {
  position: absolute;
  top: 108px;
  left: 10%;
  right: 10%;
  height: 2px;
  pointer-events: none;
  z-index: 0;
}
.journey-track::before {
  content: '';
  position: absolute; inset: 0;
  background: linear-gradient(90deg, transparent 0%, var(--border-strong) 15%, var(--border-strong) 85%, transparent 100%);
  border-radius: 2px;
}
.journey-track-fill {
  position: absolute; inset: 0;
  background: linear-gradient(90deg, var(--brand) 0%, var(--brand-strong) 100%);
  border-radius: 2px;
  transform-origin: left center;
  transform: scaleX(0);
  box-shadow: 0 0 18px rgba(59, 130, 246, 0.5);
  transition: transform 1.6s cubic-bezier(0.65, 0, 0.35, 1) 0.3s;
}
.journey:has(.journey-step.is-visible:last-child) .journey-track-fill {
  transform: scaleX(1);
}

.journey-step {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 20px;
  z-index: 1;
}

/* Visual (mockup) */
.journey-visual {
  position: relative;
  width: 100%;
  max-width: 300px;
  aspect-ratio: 1 / 1;
  padding: 20px;
  border-radius: 24px;
  background:
    radial-gradient(ellipse 300px 200px at 50% 0%, rgba(59, 130, 246, 0.12), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.04);
  overflow: hidden;
  isolation: isolate;
  transition: transform 0.3s ease, border-color 0.3s ease, box-shadow 0.3s ease;
}
.journey-step:hover .journey-visual {
  transform: translateY(-4px);
  border-color: rgba(59, 130, 246, 0.4);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45), 0 0 36px rgba(59, 130, 246, 0.18);
}

/* Badge numerado */
.journey-badge {
  position: absolute;
  top: -1px; left: 50%; transform: translateX(-50%);
  min-width: 44px;
  padding: 6px 14px;
  border-radius: 0 0 14px 14px;
  background: linear-gradient(135deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-size: 0.78rem;
  font-weight: 800;
  letter-spacing: 0.08em;
  box-shadow: 0 6px 18px rgba(59, 130, 246, 0.45);
  z-index: 2;
}

/* Copy */
.journey-copy {
  max-width: 300px;
}
.journey-kicker {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 4px 12px 4px 4px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.08);
  border: 1px solid rgba(59, 130, 246, 0.25);
  color: var(--silver);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  margin-bottom: 14px;
}
.journey-kicker-num {
  display: grid; place-items: center;
  width: 20px; height: 20px;
  border-radius: 999px;
  background: linear-gradient(135deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-size: 0.68rem;
  letter-spacing: 0;
  box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
}
.journey-title {
  font-size: 1.15rem;
  letter-spacing: -0.015em;
  margin: 0 0 10px;
  line-height: 1.25;
}
.journey-text {
  color: var(--muted);
  font-size: 0.95rem;
  line-height: 1.55;
  margin: 0;
}

/* Conector mobile (vertical) — oculto no desktop */
.journey-connector { display: none; }

/* ---------- Passo 1: Mini form ---------- */
.mock-form {
  display: flex; flex-direction: column; gap: 10px;
  padding-top: 18px;
  height: 100%;
}
.mock-form-head {
  display: flex; align-items: center; gap: 8px;
  padding-bottom: 8px;
  border-bottom: 1px dashed var(--border);
  color: var(--silver);
  font-size: 0.75rem;
  font-weight: 700;
}
.mock-logo-dot {
  width: 18px; height: 18px; border-radius: 6px;
  background: linear-gradient(135deg, var(--brand), var(--brand-strong));
  box-shadow: 0 0 10px rgba(59, 130, 246, 0.5);
}
.mock-field {
  display: flex; flex-direction: column; gap: 4px;
  opacity: 0;
  transform: translateY(6px);
}
.journey-step.is-visible .mock-field {
  animation: fieldIn 0.4s cubic-bezier(0.2, 0.8, 0.2, 1) var(--d, 0s) forwards;
}
@keyframes fieldIn {
  to { opacity: 1; transform: translateY(0); }
}
.mock-field small {
  font-size: 0.6rem;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  font-weight: 700;
}
.mock-input {
  display: flex; align-items: center; gap: 6px;
  padding: 7px 10px;
  border-radius: 9px;
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
  color: #fff;
  font-size: 0.78rem;
  font-weight: 500;
  min-height: 30px;
}
.mock-input.select {
  justify-content: space-between;
  color: var(--silver);
}
.mock-input.select svg { width: 12px; height: 12px; color: var(--muted); }
.type-text {
  overflow: hidden;
  white-space: nowrap;
  width: 0;
}
.journey-step.is-visible .type-text {
  animation: typing 0.9s steps(14, end) 0.2s forwards;
}
@keyframes typing {
  to { width: 100%; }
}
.caret {
  width: 1px; height: 12px;
  background: var(--brand-ink);
  animation: blink 0.9s steps(2, end) infinite;
}
@keyframes blink {
  50% { opacity: 0; }
}
.mock-submit {
  margin-top: auto;
  display: flex; align-items: center; justify-content: center; gap: 6px;
  padding: 8px;
  border-radius: 9px;
  background: linear-gradient(135deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-size: 0.78rem;
  font-weight: 700;
  box-shadow: 0 6px 16px rgba(59, 130, 246, 0.4);
  opacity: 0;
  transform: translateY(6px);
}
.journey-step.is-visible .mock-submit {
  animation: fieldIn 0.4s cubic-bezier(0.2, 0.8, 0.2, 1) var(--d, 0s) forwards;
}
.mock-submit svg { width: 14px; height: 14px; stroke-width: 3; }

/* ---------- Passo 2: Painel com template ---------- */
.mock-panel {
  display: flex; flex-direction: column; gap: 10px;
  padding-top: 18px;
  height: 100%;
}
.mock-panel-head {
  display: flex; align-items: center; justify-content: space-between; gap: 8px;
  padding-bottom: 8px;
  border-bottom: 1px dashed var(--border);
}
.mock-panel-head small {
  font-size: 0.65rem;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 700;
}
.mock-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.14);
  border: 1px solid rgba(59, 130, 246, 0.35);
  color: var(--brand-ink);
  font-size: 0.68rem;
  font-weight: 700;
}
.mock-chip svg { width: 11px; height: 11px; }
.mock-services {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex; flex-direction: column; gap: 6px;
  flex: 1;
}
.mock-service {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 10px;
  border-radius: 10px;
  background: rgba(5, 11, 22, 0.45);
  border: 1px solid var(--border);
  opacity: 0;
  transform: translateX(-10px);
}
.journey-step.is-visible .mock-service {
  animation: serviceIn 0.5s cubic-bezier(0.2, 0.8, 0.2, 1) var(--d, 0s) forwards;
}
@keyframes serviceIn {
  to { opacity: 1; transform: translateX(0); }
}
.mock-service-dot {
  width: 24px; height: 24px; border-radius: 7px;
  display: grid; place-items: center;
  background: var(--brand-soft);
  color: var(--brand-ink);
  flex-shrink: 0;
}
.mock-service-dot svg { width: 12px; height: 12px; }
.mock-service-body {
  flex: 1; min-width: 0;
  display: flex; flex-direction: column;
  text-align: left;
  line-height: 1.15;
}
.mock-service-body strong {
  font-size: 0.74rem;
  color: #fff;
  font-weight: 600;
}
.mock-service-body small {
  font-size: 0.62rem;
  color: var(--muted);
}
.mock-service-price {
  font-size: 0.72rem;
  color: var(--brand-ink);
  font-weight: 700;
}
.mock-panel-foot {
  display: inline-flex; align-items: center; gap: 8px;
  align-self: flex-start;
  padding: 5px 10px;
  border-radius: 999px;
  background: var(--success-soft);
  border: 1px solid rgba(74, 222, 128, 0.3);
  color: #bbf7d0;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  opacity: 0;
}
.journey-step.is-visible .mock-panel-foot {
  animation: fieldIn 0.4s ease-out var(--d, 0s) forwards;
}
.live-dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: var(--success);
  box-shadow: 0 0 0 0 rgba(74, 222, 128, 0.6);
  animation: pulse 2s ease-in-out infinite;
}

/* ---------- Passo 3: Vitrine pública + confirmação ---------- */
.mock-vitrine {
  display: flex; flex-direction: column; gap: 10px;
  padding-top: 18px;
  height: 100%;
  position: relative;
}
.mock-url {
  display: inline-flex; align-items: center; gap: 6px;
  align-self: flex-start;
  padding: 5px 10px;
  border-radius: 999px;
  background: rgba(5, 11, 22, 0.6);
  border: 1px solid var(--border);
  color: var(--silver);
  font-size: 0.68rem;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
}
.mock-url svg { width: 11px; height: 11px; color: var(--brand-ink); }
.mock-url strong { color: #fff; font-weight: 600; }
.mock-vitrine-head {
  display: flex; align-items: center; gap: 10px;
  padding: 8px 0;
  border-bottom: 1px dashed var(--border);
}
.mock-vit-avatar {
  width: 32px; height: 32px; border-radius: 10px;
  display: grid; place-items: center;
  background: linear-gradient(135deg, var(--brand), var(--brand-strong));
  color: #fff; font-weight: 800; font-size: 0.85rem;
  box-shadow: 0 0 14px rgba(59, 130, 246, 0.4);
  flex-shrink: 0;
}
.mock-vitrine-head strong {
  display: block;
  font-size: 0.8rem;
  color: #fff;
  line-height: 1.1;
}
.mock-vitrine-head small {
  font-size: 0.65rem;
  color: var(--muted);
}
.mock-slots {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 6px;
}
.mock-slot {
  padding: 9px 0;
  border-radius: 9px;
  background: rgba(5, 11, 22, 0.45);
  border: 1px solid var(--border);
  color: var(--silver);
  font-size: 0.78rem;
  font-weight: 600;
  font-family: inherit;
  cursor: default;
  opacity: 0;
  transform: translateY(6px);
}
.journey-step.is-visible .mock-slot {
  animation: fieldIn 0.35s ease-out var(--d, 0s) forwards;
}
.mock-slot.picked {
  background: var(--brand-soft);
  border-color: var(--brand);
  color: #fff;
  box-shadow: 0 0 0 1px var(--brand) inset, 0 0 16px rgba(59, 130, 246, 0.3);
}
.mock-toast {
  position: absolute;
  left: 50%; bottom: 8px;
  transform: translate(-50%, 10px);
  display: flex; align-items: center; gap: 10px;
  padding: 8px 12px;
  border-radius: 12px;
  background: rgba(11, 23, 48, 0.96);
  border: 1px solid rgba(74, 222, 128, 0.4);
  box-shadow: 0 14px 30px rgba(0, 0, 0, 0.5), 0 0 20px rgba(74, 222, 128, 0.25);
  backdrop-filter: blur(8px);
  text-align: left;
  opacity: 0;
  z-index: 3;
}
.journey-step.is-visible .mock-toast {
  animation: toastPop 0.5s cubic-bezier(0.2, 1.4, 0.4, 1) var(--d, 0s) forwards;
}
@keyframes toastPop {
  to { opacity: 1; transform: translate(-50%, 0); }
}
.mock-toast-icon {
  width: 26px; height: 26px; border-radius: 8px;
  display: grid; place-items: center;
  background: linear-gradient(135deg, #22c55e, #15803d);
  color: #fff;
  box-shadow: 0 0 12px rgba(74, 222, 128, 0.5);
  flex-shrink: 0;
}
.mock-toast-icon svg { width: 14px; height: 14px; stroke-width: 3; }
.mock-toast strong {
  display: block;
  font-size: 0.78rem;
  color: #fff;
  line-height: 1.1;
}
.mock-toast small {
  font-size: 0.66rem;
  color: var(--muted);
}

/* =====================================================================
   Recursos — Bento grid
   ===================================================================== */
.bento {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-auto-rows: minmax(170px, auto);
  gap: 16px;
}
.bento-xl {
  grid-column: span 2; grid-row: span 2;
  display: flex; flex-direction: column;
  padding: 32px;
  background:
    radial-gradient(ellipse 400px 300px at 85% 15%, rgba(59, 130, 246, 0.18), transparent 60%),
    var(--surface);
  overflow: hidden;
  position: relative;
}
.bento-xl::before {
  content: '';
  position: absolute; inset: 0;
  background: radial-gradient(circle at 100% 0%, rgba(59, 130, 246, 0.15), transparent 50%);
  pointer-events: none;
}
.bento-xl-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: auto; position: relative; }
.bento-xl-title {
  font-size: clamp(1.3rem, 2.4vw, 1.7rem);
  letter-spacing: -0.02em;
  margin: 24px 0 8px;
  position: relative;
}
.bento-xl-text {
  font-size: 1rem;
  max-width: 420px;
  margin: 0 0 24px;
  position: relative;
}
.url-preview {
  display: flex; align-items: center; gap: 8px;
  padding: 10px 14px;
  border-radius: 12px;
  background: rgba(5, 11, 22, 0.65);
  border: 1px solid var(--border);
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.82rem;
  color: var(--silver);
  position: relative;
}
.url-preview code { color: var(--muted); background: none; padding: 0; }
.url-preview code strong { color: var(--brand-ink); font-weight: 600; }
.url-dot {
  width: 9px; height: 9px; border-radius: 50%;
  background: rgba(148, 180, 220, 0.3);
}
.url-dot:nth-child(1) { background: rgba(248, 113, 113, 0.6); }
.url-dot:nth-child(2) { background: rgba(251, 191, 36, 0.6); }
.url-dot:nth-child(3) { background: rgba(74, 222, 128, 0.6); margin-right: 6px; }

.bento-item {
  display: flex; gap: 16px; align-items: flex-start;
  padding: 22px;
}
.bento-item-title { font-size: 1.02rem; margin: 0 0 4px; letter-spacing: -0.01em; }
.bento-item-text { font-size: 0.88rem; margin: 0; }

/* =====================================================================
   Planos
   ===================================================================== */
.plans {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  align-items: stretch;
  padding-top: 20px; /* espaço pro ribbon */
}
.plan {
  position: relative;
  display: flex; flex-direction: column;
  padding: 30px 26px;
  transition: transform 0.25s ease, border-color 0.25s ease, box-shadow 0.25s ease;
}
.plan.featured {
  background:
    radial-gradient(ellipse 300px 200px at 50% 0%, rgba(59, 130, 246, 0.22), transparent 70%),
    linear-gradient(165deg, rgba(59, 130, 246, 0.14), rgba(29, 78, 216, 0.16));
  border-color: rgba(59, 130, 246, 0.5);
  box-shadow: var(--shadow), 0 0 60px rgba(59, 130, 246, 0.22);
  transform: translateY(-14px);
}
.plan.featured::before {
  content: '';
  position: absolute; inset: -1px;
  border-radius: var(--radius);
  padding: 1px;
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.6), transparent 50%, rgba(59, 130, 246, 0.3));
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
.plan:hover { transform: translateY(-6px); }
.plan.featured:hover { transform: translateY(-18px); }

.ribbon {
  position: absolute; top: -14px; left: 50%; transform: translateX(-50%);
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 14px;
  border-radius: 999px;
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-size: 0.74rem; font-weight: 700;
  letter-spacing: 0.04em;
  box-shadow: 0 10px 24px rgba(59, 130, 246, 0.45);
  white-space: nowrap;
}
.ribbon svg { width: 14px; height: 14px; }

.plan-head { margin-bottom: 20px; }
.plan-name { font-size: 1.3rem; font-weight: 700; letter-spacing: -0.02em; margin: 0 0 6px; }
.plan-tagline { font-size: 0.85rem; color: var(--muted); line-height: 1.45; margin: 0; min-height: 2.5em; }

.price { display: flex; align-items: baseline; gap: 4px; margin: 4px 0 2px; }
.price-amount { font-size: 2.6rem; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
.price-period { font-size: 0.95rem; color: var(--muted); font-weight: 500; }
.fee-note { font-size: 0.78rem; margin: 8px 0 0; }

.plan-sep { height: 1px; background: var(--border); margin: 22px 0; }

.plan-list { list-style: none; padding: 0; margin: 0 0 24px; flex: 1; display: grid; gap: 10px; font-size: 0.92rem; }
.plan-list li { display: flex; gap: 10px; align-items: flex-start; }
.plan-check {
  flex-shrink: 0;
  width: 20px; height: 20px; border-radius: 999px;
  display: grid; place-items: center;
  background: var(--brand-soft);
  color: var(--brand-ink);
  margin-top: 1px;
}
.plan-check svg { width: 12px; height: 12px; stroke-width: 3; }

/* =====================================================================
   CTA final
   ===================================================================== */
.cta { text-align: center; padding: 56px 24px; position: relative; overflow: hidden; }
.cta-glow {
  position: absolute; inset: 0;
  background:
    radial-gradient(ellipse 500px 200px at 50% 100%, rgba(59, 130, 246, 0.25), transparent 70%),
    radial-gradient(ellipse 400px 180px at 50% 0%, rgba(59, 130, 246, 0.15), transparent 70%);
  pointer-events: none;
}
.cta > * { position: relative; }
.cta .eyebrow { margin-bottom: 10px; }
.cta h2 { font-size: clamp(1.6rem, 3.2vw, 2.4rem); margin-bottom: 12px; letter-spacing: -0.02em; }
.cta .btn.large svg { width: 18px; height: 18px; }

/* =====================================================================
   Footer
   ===================================================================== */
.footer-links { display: flex; gap: 18px; align-items: center; flex-wrap: wrap; font-size: 0.9rem; }
.footer-links a:not([target]) { color: var(--silver); }
.footer { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; padding: 36px 0 48px; border-top: 1px solid var(--border); }

/* =====================================================================
   Scroll reveal
   ===================================================================== */
[data-reveal] {
  opacity: 0;
  transform: translateY(16px);
  transition: opacity 0.6s ease, transform 0.6s ease;
  transition-delay: var(--delay, 0ms);
}
[data-reveal].is-visible {
  opacity: 1;
  transform: translateY(0);
}
@media (prefers-reduced-motion: reduce) {
  [data-reveal] { opacity: 1; transform: none; transition: none; }
  .phone, .float-b, .float-c, .float-a, .hero-orb, .dot-live, .live-dot { animation: none; }
  .journey-track-fill { transition: none; transform: scaleX(1); }
  .mock-field, .mock-submit, .mock-service, .mock-slot, .mock-toast, .mock-panel-foot {
    opacity: 1 !important; transform: none !important; animation: none !important;
  }
  .type-text { width: 100% !important; animation: none !important; }
  .caret { display: none; }
}

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 1040px) {
  .hero-grid { gap: 40px; }
  .bento { grid-template-columns: repeat(2, 1fr); }
  .bento-xl { grid-column: span 2; grid-row: auto; }
  .journey { gap: 18px; }
  .journey-visual { max-width: 260px; padding: 16px; }
  .journey-track { top: 94px; left: 15%; right: 15%; }
}

@media (max-width: 900px) {
  .hero-grid { grid-template-columns: 1fr; padding: 48px 0 64px; gap: 48px; }
  .hero-visual { min-height: 480px; }
  .phone { width: 260px; }
  .float-a { top: -8px; left: 0; }
  .float-b { right: -8px; top: 18%; }
  .float-c { right: 0; bottom: 10%; }
  .plans { grid-template-columns: 1fr; }
  .journey {
    grid-template-columns: 1fr;
    gap: 0;
    max-width: 440px;
    margin: 0 auto;
  }
  .journey-track { display: none; }
  .journey-step {
    flex-direction: row;
    align-items: flex-start;
    text-align: left;
    gap: 20px;
    padding-bottom: 36px;
  }
  .journey-visual {
    flex-shrink: 0;
    width: 180px;
    max-width: 180px;
    aspect-ratio: 1 / 1.1;
    padding: 14px;
  }
  .journey-copy { padding-top: 8px; max-width: none; }
  .journey-connector {
    display: block;
    position: absolute;
    left: 90px;
    top: 180px;
    bottom: -6px;
    width: 2px;
    background: linear-gradient(180deg, var(--border-strong) 0%, transparent 100%);
    transform-origin: top center;
    transform: scaleY(0);
    transition: transform 0.8s cubic-bezier(0.65, 0, 0.35, 1) 0.2s;
  }
  .journey-step.is-visible .journey-connector { transform: scaleY(1); }
  .journey-step:last-child .journey-connector { display: none; }
  .journey-step:last-child { padding-bottom: 0; }
  .journey-badge {
    font-size: 0.7rem;
    min-width: 36px;
    padding: 4px 10px;
  }
  .mock-form, .mock-panel, .mock-vitrine { gap: 7px; padding-top: 14px; }
  .mock-service { padding: 6px 8px; }
  .mock-service-body strong { font-size: 0.68rem; }
  .mock-service-body small { font-size: 0.56rem; }
  .mock-service-price { font-size: 0.66rem; }
  .mock-service-dot { width: 20px; height: 20px; }
  .mock-service-dot svg { width: 10px; height: 10px; }
  .plan.featured { transform: none; }
  .plan.featured:hover { transform: translateY(-6px); }
  .hide-sm { display: none; }
  .section { padding: 56px 0; }
}

@media (max-width: 560px) {
  .hero-grid { padding: 32px 0 48px; }
  .hero-proof { gap: 14px; }
  .proof-item strong { font-size: 1.1rem; }
  .proof-divider { height: 24px; }
  .hero-visual { min-height: 440px; }
  .phone { width: 240px; }
  .float-b, .float-c { padding: 10px 12px; }
  .float-b { right: -6px; }
  .float-c { right: 0; bottom: 8%; }
  .bento { grid-template-columns: 1fr; }
  .bento-xl { grid-column: auto; padding: 24px; }
  .section-head { margin-bottom: 32px; }
  .journey-step { gap: 14px; padding-bottom: 28px; }
  .journey-visual { width: 150px; max-width: 150px; padding: 12px; }
  .journey-connector { left: 75px; top: 150px; }
  .journey-title { font-size: 1.05rem; }
  .journey-text { font-size: 0.9rem; }
  .mock-input, .mock-submit { font-size: 0.72rem; padding: 6px 8px; min-height: 26px; }
  .mock-field small, .mock-panel-head small { font-size: 0.56rem; }
}
</style>
