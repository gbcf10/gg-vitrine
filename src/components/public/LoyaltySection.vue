<script setup>
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const phone = ref('')
const card = ref(null)
const error = ref('')

async function check() {
  error.value = ''
  const { data, error: err } = await supabase.rpc('check_loyalty', { p_business: props.business.id, p_phone: phone.value })
  if (err) error.value = err.message
  else card.value = data
}
</script>

<template>
  <section v-if="business.loyalty" class="pub-section">
    <div class="card loyalty">
      <div class="spread">
        <div>
          <h2 style="margin: 0 0 4px; display: flex; gap: 8px; align-items: center"><Icon name="gift" style="width: 22px; height: 22px" />Cartão fidelidade</h2>
          <p class="muted" style="margin: 0">
            Junte <strong>{{ business.loyalty.required }}</strong> carimbos e ganhe <strong>{{ business.loyalty.reward }}</strong>.
          </p>
        </div>
      </div>
      <form class="row" style="margin-top: 14px" @submit.prevent="check">
        <input v-model="phone" type="tel" placeholder="Seu WhatsApp" required />
        <button class="btn secondary shrink">Ver meus carimbos</button>
      </form>
      <div v-if="error" class="error" style="margin-top: 10px">{{ error }}</div>
      <div v-if="card" style="margin-top: 14px">
        <div class="stamps">
          <span v-for="n in card.required" :key="n" :class="{ on: n <= Math.min(card.stamps, card.required) }">
            <Icon name="check" />
          </span>
        </div>
        <p style="margin: 10px 0 0">
          <template v-if="card.stamps >= card.required"><strong>Parabéns! Você já pode resgatar: {{ card.reward }}.</strong> Avise na próxima visita.</template>
          <template v-else>Você tem <strong>{{ card.stamps }}</strong> de {{ card.required }}. Faltam {{ card.required - card.stamps }}.</template>
        </p>
      </div>
    </div>
  </section>
</template>

<style scoped>
.loyalty { background: linear-gradient(160deg, var(--brand-soft), rgba(11, 23, 48, 0.5)); border-color: var(--border-strong); }
.stamps { display: flex; flex-wrap: wrap; gap: 8px; }
.stamps span { width: 36px; height: 36px; border-radius: 50%; display: grid; place-items: center; border: 2px dashed var(--border-strong); color: transparent; }
.stamps span.on { border: none; background: linear-gradient(140deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); box-shadow: 0 0 12px var(--brand-glow); }
.stamps svg { width: 18px; height: 18px; }
</style>
