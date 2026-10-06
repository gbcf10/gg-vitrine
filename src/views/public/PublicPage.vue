<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { brandVars } from '@/lib/colors'
import { plural } from '@/lib/format'
import { APP_NAME } from '@/config/brand'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'
import LinkButtons from '@/components/public/LinkButtons.vue'
import GallerySection from '@/components/public/GallerySection.vue'
import ReviewsSection from '@/components/public/ReviewsSection.vue'
import LoyaltySection from '@/components/public/LoyaltySection.vue'
import Stars from '@/components/public/Stars.vue'
import AgendaBooking from '@/components/public/AgendaBooking.vue'

// preset: dados prontos (usado pela pré-visualização de desenvolvimento).
const props = defineProps({ preset: { type: Object, default: null } })
const route = useRoute()
const business = ref(props.preset)
const notFound = ref(false)

const brandStyle = computed(() => brandVars(business.value?.primary_color))

// Scroll suave pro bloco de agendamento (sticky CTA do mobile).
function scrollToBooking() {
  const el = document.getElementById('agendar')
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

let io
onMounted(async () => {
  if (!props.preset) {
    const { data } = await supabase.rpc('get_public_business', { p_slug: route.params.slug })
    if (!data) { notFound.value = true; return }
    business.value = data
    document.title = `${data.name} · ${APP_NAME}`
  }
  if (typeof IntersectionObserver === 'undefined') return
  io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) { e.target.classList.add('is-visible'); io.unobserve(e.target) }
      }
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
  )
  requestAnimationFrame(() => {
    document.querySelectorAll('[data-pub-reveal]').forEach((el) => io.observe(el))
  })
})
onBeforeUnmount(() => io?.disconnect())
</script>

<template>
  <div v-if="notFound" class="narrow">
    <div class="auth-logo"><AppLogo /></div>
    <div class="card" style="text-align: center">
      <h3>Página não encontrada</h3>
      <p class="muted">Confira se o link está correto.</p>
    </div>
  </div>

  <div v-else-if="business" :style="brandStyle" style="min-height: 100vh">
    <header class="biz-hero rich">
      <div class="biz-cover">
        <div v-if="business.live" class="biz-live-pill">
          <span class="dot" />
          <span>Agendando online</span>
        </div>
        <div class="container biz-cover-inner">
          <!-- espaço reservado — a logo "flutua" sobre a capa -->
        </div>
      </div>

      <div class="container">
        <div class="biz-rich-head">
          <img v-if="business.logo_url" :src="business.logo_url" :alt="business.name" class="biz-rich-logo" />
          <div v-else class="biz-rich-logo initial">{{ business.name.charAt(0).toUpperCase() }}</div>

          <div class="biz-rich-info">
            <span class="biz-rich-pill">{{ business.category }}</span>
            <h1>{{ business.name }}</h1>
            <div class="biz-rich-meta">
              <span v-if="business.reviews?.count" class="biz-rich-rating">
                <Stars :value="Number(business.reviews.average)" />
                <strong>{{ String(business.reviews.average).replace('.', ',') }}</strong>
                <small class="muted">· {{ plural(business.reviews.count, 'avaliação', 'avaliações') }}</small>
              </span>
              <span v-if="business.address"><Icon name="map" />{{ business.address }}</span>
              <span v-if="business.phone"><Icon name="phone" />{{ business.phone }}</span>
            </div>
            <p v-if="business.description" class="biz-rich-desc">{{ business.description }}</p>
          </div>
        </div>
      </div>
    </header>

    <main class="container pub-main" :class="{ 'has-sticky': business.live }">
      <div data-pub-reveal class="pub-reveal">
        <LinkButtons :business="business" />
      </div>

      <section id="agendar" class="pub-section space" data-pub-reveal>
        <div class="pub-section-head">
          <span class="eyebrow">Agendamento</span>
          <h2>Escolha o melhor horário</h2>
        </div>
        <div class="pub-reveal is-visible">
          <AgendaBooking :business="business" />
        </div>
      </section>

      <template v-if="business.live">
        <section class="pub-section space" data-pub-reveal>
          <LoyaltySection :business="business" />
        </section>
        <section v-if="business.gallery?.length" class="pub-section space" data-pub-reveal>
          <div class="pub-section-head">
            <span class="eyebrow">Galeria</span>
            <h2>Veja nosso trabalho</h2>
          </div>
          <GallerySection :photos="business.gallery" />
        </section>
        <section v-if="business.reviews" class="pub-section space" data-pub-reveal>
          <ReviewsSection :business="business" />
        </section>
      </template>

      <div class="powered">
        <span class="muted">Feito com</span> <AppLogo />
      </div>
      <p class="privacy-note">
        Seus dados são usados só para este atendimento. <RouterLink to="/privacidade">Política de privacidade</RouterLink>
      </p>
    </main>

    <div v-if="business.live" class="biz-sticky-cta">
      <button class="btn large" @click="scrollToBooking">
        <Icon name="calendar" /> Agendar horário
      </button>
    </div>
  </div>

  <div v-else class="narrow muted" style="text-align: center">Carregando...</div>
</template>

<style scoped>
.privacy-note { text-align: center; font-size: 0.75rem; color: var(--muted); margin-top: 8px; }
.privacy-note a { color: var(--muted); text-decoration: underline; }
.biz-rich-info .biz-rich-rating small { font-weight: 500; }
</style>
