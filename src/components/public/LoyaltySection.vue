<script setup>
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const phone = ref('')
const card = ref(null)
const error = ref('')
const busy = ref(false)

const required = computed(() => props.business.loyalty?.required ?? 10)
const reward = computed(() => props.business.loyalty?.reward ?? '')
const stamps = computed(() => Math.min(card.value?.stamps ?? 0, required.value))
const progress = computed(() => Math.round((stamps.value / required.value) * 100))

async function check() {
  error.value = ''
  busy.value = true
  const { data, error: err } = await supabase.rpc('check_loyalty', { p_business: props.business.id, p_phone: phone.value })
  busy.value = false
  if (err) error.value = err.message
  else card.value = data
}
</script>

<template>
  <div v-if="business.loyalty" class="loyalty-card">
    <div class="loyalty-head">
      <div class="ico"><Icon name="gift" /></div>
      <div>
        <h2>Cartão fidelidade</h2>
        <p>Junte <strong>{{ required }}</strong> carimbos e ganhe <strong>{{ reward }}</strong>.</p>
      </div>
    </div>

    <form class="row" @submit.prevent="check">
      <input v-model="phone" type="tel" placeholder="Seu WhatsApp" required />
      <button class="btn secondary shrink" :disabled="busy">{{ busy ? 'Buscando...' : 'Ver meus carimbos' }}</button>
    </form>
    <div v-if="error" class="error" style="margin-top: 10px">{{ error }}</div>

    <template v-if="card">
      <div class="loyalty-progress">
        <div class="track"><div class="fill" :style="{ width: progress + '%' }" /></div>
        <span class="count">{{ stamps }}/{{ required }}</span>
      </div>
      <div class="loyalty-stamps">
        <span v-for="n in required" :key="n" class="loyalty-stamp" :class="{ on: n <= stamps }">
          <Icon name="check" />
        </span>
      </div>
      <p style="margin: 12px 0 0">
        <template v-if="stamps >= required">
          <strong>Parabéns! Você já pode resgatar: {{ reward }}.</strong> Avise na próxima visita.
        </template>
        <template v-else>
          Faltam <strong>{{ required - stamps }}</strong> carimbos pro seu prêmio.
        </template>
      </p>
    </template>
  </div>
</template>
