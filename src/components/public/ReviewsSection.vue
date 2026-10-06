<script setup>
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/lib/format'
import Stars from './Stars.vue'

const props = defineProps({ business: { type: Object, required: true } })

const showForm = ref(false)
const form = ref({ name: '', rating: 5, comment: '' })
const sent = ref(false)
const error = ref('')
const busy = ref(false)

const initial = (name) => (name || '?').trim().charAt(0).toUpperCase()
const avg = computed(() => String(props.business.reviews?.average ?? '0').replace('.', ','))

async function submit() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.rpc('submit_review', {
    p_business: props.business.id, p_name: form.value.name, p_rating: form.value.rating, p_comment: form.value.comment,
  })
  busy.value = false
  if (err) error.value = err.message
  else sent.value = true
}
</script>

<template>
  <div v-if="business.reviews">
    <div class="pub-section-head spread">
      <div>
        <span class="eyebrow">Avaliações</span>
        <h2>O que dizem por aí</h2>
      </div>
    </div>

    <div v-if="business.reviews.count" class="rev-avg">
      <span class="big">{{ avg }}</span>
      <div class="mt">
        <Stars :value="Number(business.reviews.average)" />
        <small>{{ business.reviews.count }} avaliações</small>
      </div>
    </div>

    <div v-for="r in business.reviews.latest" :key="r.created_at + r.author_name" class="rev-card">
      <div class="top">
        <div class="rev-avatar">{{ initial(r.author_name) }}</div>
        <div class="rev-head">
          <span class="name">{{ r.author_name }}</span>
          <Stars :value="r.rating" />
        </div>
        <small class="when">{{ formatDate(r.created_at, business.timezone) }}</small>
      </div>
      <p v-if="r.comment" class="rev-text">{{ r.comment }}</p>
      <div v-if="r.reply" class="rev-reply">
        <strong>Resposta de {{ business.name }}</strong>
        {{ r.reply }}
      </div>
    </div>
    <p v-if="!business.reviews.count" class="muted">Ainda não há avaliações. Seja o primeiro!</p>

    <div v-if="sent" class="success" style="margin-top: 12px">Obrigado! Sua avaliação foi enviada.</div>
    <button v-else-if="!showForm" class="btn secondary" style="margin-top: 14px" @click="showForm = true">Deixar minha avaliação</button>
    <form v-else class="card" style="margin-top: 14px" @submit.prevent="submit">
      <div class="field">
        <label>Sua nota</label>
        <div class="rate-input">
          <button
            v-for="n in 5" :key="n"
            type="button"
            :class="{ on: n <= form.rating }"
            :aria-label="`${n} estrelas`"
            @click="form.rating = n"
          >★</button>
        </div>
      </div>
      <div class="field"><label>Seu nome</label><input v-model="form.name" required maxlength="60" /></div>
      <div class="field"><label>Comentário <small>(opcional)</small></label><textarea v-model="form.comment" rows="3" maxlength="500" /></div>
      <div v-if="error" class="error">{{ error }}</div>
      <button class="btn" :disabled="busy">{{ busy ? 'Enviando...' : 'Enviar avaliação' }}</button>
    </form>
  </div>
</template>

<style scoped>
.spread { align-items: center; }
.rev-head .name { font-weight: 700; }
</style>
