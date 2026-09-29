<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { brandVars } from '@/lib/colors'
import { plural } from '@/lib/format'
import { KINDS, APP_NAME } from '@/config/brand'
import AppLogo from '@/components/AppLogo.vue'
import LinkButtons from '@/components/public/LinkButtons.vue'
import GallerySection from '@/components/public/GallerySection.vue'
import ReviewsSection from '@/components/public/ReviewsSection.vue'
import LoyaltySection from '@/components/public/LoyaltySection.vue'
import Stars from '@/components/public/Stars.vue'
import AgendaBooking from '@/components/public/AgendaBooking.vue'
import CatalogOrder from '@/components/public/CatalogOrder.vue'
import QuoteRequest from '@/components/public/QuoteRequest.vue'
import ReservationRequest from '@/components/public/ReservationRequest.vue'
import EventsList from '@/components/public/EventsList.vue'

// preset: dados prontos (usado pela pré-visualização de desenvolvimento).
const props = defineProps({ preset: { type: Object, default: null } })
const route = useRoute()
const business = ref(props.preset)
const notFound = ref(false)

const BODY = {
  agenda: AgendaBooking,
  cardapio: CatalogOrder,
  orcamento: QuoteRequest,
  reserva: ReservationRequest,
  evento: EventsList,
}
const body = computed(() => BODY[business.value?.kind])
const isCard = computed(() => business.value?.kind === 'cartao')
const brandStyle = computed(() => brandVars(business.value?.primary_color))

onMounted(async () => {
  if (props.preset) return
  const { data } = await supabase.rpc('get_public_business', { p_slug: route.params.slug })
  if (!data) { notFound.value = true; return }
  business.value = data
  document.title = `${data.name} · ${KINDS[data.kind]?.label ?? APP_NAME}`
})
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
    <!-- Cartão digital: layout centralizado -->
    <header v-if="isCard" class="biz-hero">
      <div class="biz-glow" />
      <div class="container card-head">
        <img v-if="business.logo_url" :src="business.logo_url" alt="" class="biz-logo big" />
        <div v-else class="biz-logo big initial">{{ business.name.charAt(0).toUpperCase() }}</div>
        <p class="eyebrow" style="margin: 16px 0 4px">{{ business.category }}</p>
        <h1 class="gradient-text" style="margin: 0">{{ business.name }}</h1>
        <div v-if="business.reviews?.count" class="rating"><Stars :value="Number(business.reviews.average)" /> <small>{{ plural(business.reviews.count, 'avaliação', 'avaliações') }}</small></div>
        <p v-if="business.description" class="muted" style="margin: 12px auto 0; max-width: 520px">{{ business.description }}</p>
      </div>
    </header>

    <header v-else class="biz-hero">
      <div class="biz-glow" />
      <div class="container biz-head">
        <img v-if="business.logo_url" :src="business.logo_url" alt="" class="biz-logo" />
        <div v-else class="biz-logo initial">{{ business.name.charAt(0).toUpperCase() }}</div>
        <div style="min-width: 0">
          <p class="eyebrow" style="margin-bottom: 4px">{{ business.category }}</p>
          <h1 class="gradient-text" style="margin: 0">{{ business.name }}</h1>
          <div v-if="business.reviews?.count" class="rating"><Stars :value="Number(business.reviews.average)" /> <small>{{ String(business.reviews.average).replace('.', ',') }} · {{ plural(business.reviews.count, 'avaliação', 'avaliações') }}</small></div>
          <div v-else-if="business.address" class="muted" style="margin-top: 4px; font-size: 0.9rem">{{ business.address }}</div>
        </div>
      </div>
    </header>

    <main class="container pub-main" :class="{ narrowed: isCard }">
      <template v-if="isCard">
        <div v-if="!business.live" class="card"><p>Esta página está temporariamente indisponível.</p></div>
        <LinkButtons v-else :business="business" big />
      </template>
      <template v-else>
        <p v-if="business.description" class="muted">{{ business.description }}</p>
        <LinkButtons :business="business" />
        <component :is="body" v-if="body" :business="business" />
      </template>

      <template v-if="business.live">
        <LoyaltySection :business="business" />
        <GallerySection :photos="business.gallery" />
        <ReviewsSection :business="business" />
      </template>

      <div class="powered">
        <span class="muted">Feito com</span> <AppLogo />
      </div>
      <p class="privacy-note">
        Seus dados são usados só para este atendimento. <RouterLink to="/privacidade">Política de privacidade</RouterLink>
      </p>
    </main>
  </div>

  <div v-else class="narrow muted" style="text-align: center">Carregando...</div>
</template>

<style scoped>
.card-head { position: relative; max-width: 560px; text-align: center; padding: 40px 0 28px; }
.biz-logo.big { width: 110px; height: 110px; border-radius: 28px; margin: 0 auto; font-size: 2.6rem; }
.rating { display: flex; align-items: center; gap: 8px; margin-top: 6px; font-size: 0.85rem; }
.card-head .rating { justify-content: center; }
.narrowed { max-width: 560px; }
.privacy-note { text-align: center; font-size: 0.75rem; color: var(--muted); margin-top: 8px; }
.privacy-note a { color: var(--muted); text-decoration: underline; }
</style>
