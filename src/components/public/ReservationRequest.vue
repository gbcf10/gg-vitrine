<script setup>
import { ref, computed, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { money, todayISO, addDaysISO, zonedToUtc, formatDate, plural } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const cfg = computed(() => props.business.reservation)
const byDay = computed(() => cfg.value.mode === 'diaria')
const today = computed(() => todayISO(props.business.timezone))

const unit = ref(null)
const busy = ref([])   // períodos já confirmados da unidade escolhida
const form = ref({ name: '', phone: '', email: '', start: today.value, end: addDaysISO(today.value, 1), time: '20:00', party: 2, notes: '' })
const result = ref(null)
const error = ref('')
const sending = ref(false)

watch(unit, async (u) => {
  busy.value = []
  if (!u) return
  form.value.party = Math.min(form.value.party, u.capacity)
  const { data } = await supabase.rpc('get_unit_busy_dates', { p_unit: u.id })
  busy.value = data ?? []
})
watch(() => form.value.start, (s) => { if (form.value.end <= s) form.value.end = addDaysISO(s, 1) })

const nights = computed(() => {
  const ms = new Date(form.value.end + 'T12:00:00') - new Date(form.value.start + 'T12:00:00')
  return Math.max(Math.round(ms / 86400000), 0)
})
const total = computed(() => (unit.value ? nights.value * Number(unit.value.price) : 0))
const conflict = computed(() => byDay.value && busy.value.some((b) => form.value.start < b.end_date && form.value.end > b.start_date))

const fmt = (d) => formatDate(zonedToUtc(d, '12:00', props.business.timezone), props.business.timezone)

async function submit() {
  error.value = ''
  sending.value = true
  const f = form.value
  const { data, error: err } = await supabase.rpc('request_reservation', {
    p_business: props.business.id, p_name: f.name, p_phone: f.phone, p_start: f.start,
    p_end: byDay.value ? f.end : null, p_time: byDay.value ? null : f.time,
    p_party: Number(f.party), p_unit: byDay.value ? unit.value?.id : null,
    p_email: f.email || null, p_notes: f.notes || null,
  })
  sending.value = false
  if (err) { error.value = err.message; return }
  result.value = data
}

const summary = computed(() => {
  const f = form.value
  return byDay.value
    ? `${unit.value?.name}: ${fmt(f.start)} a ${fmt(f.end)} (${plural(nights.value, 'diária', 'diárias')}), ${plural(f.party, 'pessoa', 'pessoas')}`
    : `${fmt(f.start)} às ${f.time}, ${plural(f.party, 'pessoa', 'pessoas')}`
})
const whatsappUrl = computed(() => waLink(props.business.phone,
  `*Pedido de reserva: ${props.business.name}*\n\n${summary.value}\n\n*Nome:* ${form.value.name}\n*WhatsApp:* ${form.value.phone}` +
  (form.value.notes ? `\n*Obs.:* ${form.value.notes}` : '')))
</script>

<template>
  <div v-if="!business.live" class="card">
    <p>Este estabelecimento não está recebendo reservas online no momento.</p>
  </div>

  <div v-else-if="result" class="card glow done">
    <div class="done-icon"><Icon name="check" /></div>
    <h2 class="gradient-text">Pedido de reserva enviado!</h2>
    <p>{{ summary }}</p>
    <p v-if="Number(result.total)"><strong>Total previsto: {{ money(result.total) }}</strong></p>
    <p class="muted">Sua reserva fica <strong>pendente</strong> até {{ business.name }} confirmar. A resposta vem pelo WhatsApp.</p>
    <a v-if="whatsappUrl" class="btn" :href="whatsappUrl" target="_blank" rel="noopener">
      <Icon name="whatsapp" style="width: 18px; height: 18px" />Avisar pelo WhatsApp
    </a>
  </div>

  <template v-else>
    <!-- Diárias: escolha da unidade -->
    <div v-if="byDay" class="card">
      <h3 class="step-title"><span class="step">1</span>Escolha a opção</h3>
      <p v-if="!cfg.units.length" class="muted">Nenhuma opção disponível no momento.</p>
      <button v-for="u in cfg.units" :key="u.id" class="chip option-item unit" :class="{ selected: unit?.id === u.id }" @click="unit = u">
        <img v-if="u.photo_url" :src="u.photo_url" alt="" />
        <div style="flex: 1; min-width: 0">
          <div class="spread"><strong>{{ u.name }}</strong><span>{{ money(u.price) }}/diária</span></div>
          <small>Até {{ u.capacity }} pessoas<span v-if="u.description"> · {{ u.description }}</span></small>
        </div>
      </button>
    </div>

    <form v-if="!byDay || unit" class="card glow" @submit.prevent="submit">
      <h3 class="step-title"><span class="step">{{ byDay ? 2 : 1 }}</span>{{ byDay ? 'Datas e dados' : 'Faça sua reserva' }}</h3>

      <div class="row">
        <div class="field">
          <label>{{ byDay ? 'Entrada' : 'Data' }}</label>
          <input v-model="form.start" type="date" :min="today" required />
        </div>
        <div v-if="byDay" class="field">
          <label>Saída</label>
          <input v-model="form.end" type="date" :min="addDaysISO(form.start, 1)" required />
        </div>
        <div v-else class="field"><label>Horário</label><input v-model="form.time" type="time" required /></div>
        <div class="field" style="max-width: 130px">
          <label>Pessoas</label>
          <input v-model.number="form.party" type="number" min="1" :max="byDay ? unit.capacity : cfg.max_party" required />
        </div>
      </div>

      <div v-if="byDay && busy.length" class="muted" style="font-size: 0.85rem; margin-bottom: 12px">
        Já reservado: <span v-for="(b, i) in busy" :key="i">{{ fmt(b.start_date) }}–{{ fmt(b.end_date) }}{{ i < busy.length - 1 ? ', ' : '' }}</span>
      </div>
      <div v-if="conflict" class="error">Essas datas já estão reservadas. Escolha outras.</div>
      <div v-if="byDay && nights" class="notice">{{ nights }} diária{{ nights > 1 ? 's' : '' }} · <strong>{{ money(total) }}</strong></div>

      <div class="row">
        <div class="field"><label>Seu nome</label><input v-model="form.name" required autocomplete="name" /></div>
        <div class="field"><label>WhatsApp</label><input v-model="form.phone" type="tel" required autocomplete="tel" /></div>
      </div>
      <div class="field"><label>Observações <small>(opcional)</small></label><input v-model="form.notes" maxlength="500" placeholder="Ex.: aniversário, cadeirão para criança" /></div>
      <p v-if="cfg.notice" class="muted" style="font-size: 0.85rem">{{ cfg.notice }}</p>

      <div v-if="error" class="error">{{ error }}</div>
      <button class="btn large block" :disabled="sending || conflict">{{ sending ? 'Enviando...' : 'Pedir reserva' }}</button>
    </form>
  </template>
</template>

<style scoped>
.unit { display: flex; gap: 12px; align-items: center; }
.unit img { width: 64px; height: 64px; border-radius: 12px; object-fit: cover; flex-shrink: 0; }
</style>
