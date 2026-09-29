<script setup>
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { money, todayISO } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const categories = computed(() => (props.business.menu ?? []).filter((c) => c.items.length))

const form = ref({ name: '', phone: '', description: '', district: '', preferred_date: '' })
const sent = ref(false)
const error = ref('')
const busy = ref(false)

// Clicar em um serviço da lista já preenche a descrição.
function pick(item) {
  const line = `• ${item.name}`
  if (!form.value.description.includes(line)) {
    form.value.description = (form.value.description ? form.value.description + '\n' : '') + line
  }
  document.getElementById('quote-form')?.scrollIntoView({ behavior: 'smooth' })
}

function message() {
  const f = form.value
  return [
    `*Pedido de orçamento: ${props.business.name}*`, '',
    f.description, '',
    `*Nome:* ${f.name}`, `*WhatsApp:* ${f.phone}`,
    f.district ? `*Bairro:* ${f.district}` : null,
    f.preferred_date ? `*Data desejada:* ${f.preferred_date.split('-').reverse().join('/')}` : null,
  ].filter((l) => l !== null).join('\n')
}

async function submit() {
  error.value = ''
  busy.value = true
  const f = form.value
  const { error: err } = await supabase.rpc('submit_quote', {
    p_business: props.business.id, p_name: f.name, p_phone: f.phone, p_description: f.description,
    p_district: f.district || null, p_preferred_date: f.preferred_date || null,
  })
  busy.value = false
  if (err) { error.value = err.message; return }
  sent.value = true
}

const whatsappUrl = computed(() => waLink(props.business.phone, message()))
</script>

<template>
  <div v-if="!business.live" class="card">
    <p>Este profissional não está recebendo pedidos de orçamento online no momento.</p>
  </div>

  <template v-else>
    <section v-if="categories.length" class="pub-section" style="margin-top: 0">
      <h2>Serviços</h2>
      <div v-for="c in categories" :key="c.id" style="margin-bottom: 18px">
        <h3 v-if="categories.length > 1" class="muted" style="font-size: 0.95rem">{{ c.name }}</h3>
        <button v-for="i in c.items" :key="i.id" class="chip option-item" @click="pick(i)">
          <div class="spread">
            <strong>{{ i.name }}</strong>
            <span>{{ Number(i.price) ? `a partir de ${money(i.price)}` : 'sob consulta' }}</span>
          </div>
          <small v-if="i.description">{{ i.description }}</small>
        </button>
      </div>
    </section>

    <section id="quote-form" class="pub-section">
      <div v-if="sent" class="card glow done">
        <div class="done-icon"><Icon name="check" /></div>
        <h2 class="gradient-text">Pedido enviado!</h2>
        <p class="muted">{{ business.name }} recebeu seu pedido e vai responder pelo WhatsApp.</p>
        <a v-if="whatsappUrl" class="btn" :href="whatsappUrl" target="_blank" rel="noopener">
          <Icon name="whatsapp" style="width: 18px; height: 18px" />Enviar também pelo WhatsApp
        </a>
      </div>

      <form v-else class="card glow" @submit.prevent="submit">
        <h2 class="step-title" style="font-size: 1.3rem"><Icon name="clipboard" style="width: 22px; height: 22px" />Pedir orçamento</h2>
        <p class="muted">Conte o que você precisa. Quanto mais detalhes, mais certeiro o orçamento.</p>
        <div class="field">
          <label>O que você precisa?</label>
          <textarea v-model="form.description" rows="4" required minlength="5" maxlength="2000"
                    placeholder="Ex.: trocar 3 tomadas e instalar um chuveiro novo" />
        </div>
        <div class="row">
          <div class="field"><label>Seu nome</label><input v-model="form.name" required autocomplete="name" /></div>
          <div class="field"><label>WhatsApp</label><input v-model="form.phone" type="tel" required autocomplete="tel" /></div>
        </div>
        <div class="row">
          <div class="field"><label>Bairro <small>(opcional)</small></label><input v-model="form.district" /></div>
          <div class="field"><label>Data desejada <small>(opcional)</small></label><input v-model="form.preferred_date" type="date" :min="todayISO(business.timezone)" /></div>
        </div>
        <div v-if="error" class="error">{{ error }}</div>
        <button class="btn large block" :disabled="busy">{{ busy ? 'Enviando...' : 'Pedir orçamento' }}</button>
      </form>
    </section>
  </template>
</template>
