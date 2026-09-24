<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { money } from '@/lib/format'
import { CATEGORIES, FEATURE_LABELS, APP_DOMAIN } from '@/config/brand'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'

const plans = ref([])

onMounted(async () => {
  const { data } = await supabase.from('plans').select('*').order('sort_order')
  plans.value = data ?? []
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

const steps = [
  { icon: 'store', title: 'Cadastre seu negócio', text: 'Envie seus dados. Analisamos e aprovamos rapidinho.' },
  { icon: 'scissors', title: 'Monte sua agenda', text: 'Serviços, preços, profissionais e horários em poucos minutos.' },
  { icon: 'link', title: 'Compartilhe seu link', text: 'Seus clientes agendam sozinhos, 24 horas por dia.' },
]

const features = [
  { icon: 'link', title: 'Link próprio', text: `${APP_DOMAIN}/seu-negocio com sua logo e sua cor.` },
  { icon: 'calendar', title: 'Agenda inteligente', text: 'Sem horário duplicado: o sistema bloqueia conflitos sozinho.' },
  { icon: 'users', title: 'Vários profissionais', text: 'Agenda individual para cada profissional da equipe.' },
  { icon: 'smartphone', title: 'Cliente no controle', text: 'O cliente vê, cancela e remarca pelo celular, sem te ligar.' },
  { icon: 'ban', title: 'Folgas e bloqueios', text: 'Feche um horário, um dia ou as férias com um clique.' },
  { icon: 'chart', title: 'Relatórios', text: 'Acompanhe atendimentos, clientes e faturamento.' },
]
</script>

<template>
  <nav class="topnav">
    <div class="container">
      <AppLogo />
      <div class="links">
        <a href="#como-funciona" class="hide-sm">Como funciona</a>
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
        <p class="eyebrow">Agendamento online</p>
        <h1 class="hero-title gradient-text">Sua agenda cheia, sem precisar parar para responder mensagem.</h1>
        <p class="hero-sub">
          Seu cliente escolhe o serviço, o profissional e o horário direto pelo seu link. Você só aparece para atender.
        </p>
        <div class="row" style="gap: 12px">
          <RouterLink class="btn large shrink" to="/cadastro">Cadastrar meu negócio</RouterLink>
          <a class="btn secondary large shrink" href="#planos">Ver planos</a>
        </div>
      </div>

      <div class="hero-visual" aria-hidden="true">
        <div class="hero-glow" />
        <div class="card mock">
          <div class="mock-head">
            <div class="mock-avatar">BZ</div>
            <div>
              <strong>Barbearia do Zé</strong>
              <div class="muted" style="font-size: 0.8rem">Barbearia</div>
            </div>
          </div>
          <div class="mock-service">
            <span>Corte + barba</span><strong>R$ 60</strong>
          </div>
          <div class="mock-days">
            <span>Seg<b>14</b></span><span class="on">Ter<b>15</b></span><span>Qua<b>16</b></span><span>Qui<b>17</b></span>
          </div>
          <div class="chips">
            <span class="chip">09:00</span><span class="chip">09:30</span><span class="chip selected">10:00</span>
            <span class="chip">11:30</span><span class="chip">14:00</span><span class="chip">15:30</span>
          </div>
          <div class="btn block" style="margin-top: 16px">Confirmar agendamento</div>
        </div>
        <div class="card floating">
          <div class="stat">
            <div class="label">Hoje</div>
            <div class="value gradient-text">12 agendamentos</div>
          </div>
        </div>
      </div>
    </div>
  </header>

  <div class="tagline container">
    <template v-for="(c, i) in CATEGORIES.slice(0, 7)" :key="c">
      <span v-if="i" class="dot">•</span><span>{{ c }}</span>
    </template>
  </div>

  <!-- Como funciona -->
  <section id="como-funciona" class="container section">
    <p class="eyebrow center">Como funciona</p>
    <h2 class="section-title">Pronto para receber agendamentos em 3 passos</h2>
    <div class="grid three">
      <div v-for="(s, i) in steps" :key="s.title" class="card hoverable step">
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
    <h2 class="section-title">Tudo o que seu negócio precisa para organizar a agenda</h2>
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

  <!-- Planos -->
  <section id="planos" class="container section">
    <p class="eyebrow center">Planos</p>
    <h2 class="section-title">Escolha o plano ideal para o tamanho do seu negócio</h2>
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
      <h2 class="gradient-text">Seu próximo cliente pode agendar hoje.</h2>
      <p class="muted">Cadastre seu estabelecimento e comece a receber agendamentos pelo seu link.</p>
      <RouterLink class="btn large" to="/cadastro">Cadastrar meu negócio</RouterLink>
    </div>
  </section>

  <footer class="container footer">
    <AppLogo />
    <span class="muted">
      Um produto <a href="https://portfoliogegsolucoes.netlify.app/" target="_blank" rel="noopener">G&amp;G Soluções</a>
    </span>
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
.floating { position: absolute; right: -18px; top: 8px; padding: 14px 18px; animation: float 5s ease-in-out infinite; background: rgba(11, 23, 48, 0.85); }
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
.step { position: relative; }
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
.footer { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px; padding: 28px 0 40px; border-top: 1px solid var(--border); }

@media (max-width: 900px) {
  .hero-grid { grid-template-columns: 1fr; padding: 40px 0 48px; }
  .hero-visual { display: none; }
  .grid.three { grid-template-columns: 1fr; }
  .hide-sm { display: none; }
}
</style>
