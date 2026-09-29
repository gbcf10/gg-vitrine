<script setup>
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/lib/format'
import Stars from './Stars.vue'

const props = defineProps({ business: { type: Object, required: true } })

const showForm = ref(false)
const form = ref({ name: '', rating: 5, comment: '' })
const sent = ref(false)
const error = ref('')
const busy = ref(false)

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
  <section v-if="business.reviews" class="pub-section">
    <div class="spread" style="margin-bottom: 12px">
      <h2 style="margin: 0">Avaliações</h2>
      <div v-if="business.reviews.count" class="avg">
        <strong>{{ String(business.reviews.average).replace('.', ',') }}</strong>
        <Stars :value="Number(business.reviews.average)" />
        <small>({{ business.reviews.count }})</small>
      </div>
    </div>

    <div v-for="r in business.reviews.latest" :key="r.created_at + r.author_name" class="card review">
      <div class="spread">
        <strong>{{ r.author_name }}</strong>
        <Stars :value="r.rating" />
      </div>
      <p v-if="r.comment" style="margin: 8px 0 0">{{ r.comment }}</p>
      <small>{{ formatDate(r.created_at, business.timezone) }}</small>
      <div v-if="r.reply" class="reply"><strong>Resposta de {{ business.name }}:</strong> {{ r.reply }}</div>
    </div>
    <p v-if="!business.reviews.count" class="muted">Ainda não há avaliações. Seja o primeiro!</p>

    <div v-if="sent" class="success" style="margin-top: 12px">Obrigado! Sua avaliação aparece aqui assim que for aprovada.</div>
    <button v-else-if="!showForm" class="btn secondary" style="margin-top: 12px" @click="showForm = true">Deixar minha avaliação</button>
    <form v-else class="card" style="margin-top: 12px" @submit.prevent="submit">
      <div class="field">
        <label>Sua nota</label>
        <div class="rate">
          <button v-for="n in 5" :key="n" type="button" :class="{ on: n <= form.rating }" :aria-label="`${n} estrelas`" @click="form.rating = n">★</button>
        </div>
      </div>
      <div class="field"><label>Seu nome</label><input v-model="form.name" required maxlength="60" /></div>
      <div class="field"><label>Comentário <small>(opcional)</small></label><textarea v-model="form.comment" rows="3" maxlength="500" /></div>
      <div v-if="error" class="error">{{ error }}</div>
      <button class="btn" :disabled="busy">Enviar avaliação</button>
    </form>
  </section>
</template>

<style scoped>
.avg { display: flex; align-items: center; gap: 8px; }
.avg strong { font-size: 1.3rem; }
.review { margin-top: 10px; }
.card + .card { margin-top: 10px; }
.reply { margin-top: 10px; padding: 10px 12px; border-radius: 10px; background: var(--brand-soft); font-size: 0.9rem; }
.rate { display: flex; gap: 4px; }
.rate button { background: none; border: none; font-size: 2rem; line-height: 1; cursor: pointer; color: var(--border-strong); padding: 0 2px; }
.rate button.on { color: #fbbf24; }
</style>
