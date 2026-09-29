<script setup>
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { money, formatDate, formatTime, plural } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const tz = computed(() => props.business.timezone)
const hasCoupons = computed(() => props.business.features.includes('cupons'))

const selected = ref(null)
const form = ref({ name: '', phone: '', email: '', quantity: 1 })
const couponCode = ref('')
const coupon = ref(null)
const couponError = ref('')
const result = ref(null)
const error = ref('')
const busy = ref(false)

function open(e) {
  selected.value = e
  result.value = null
  error.value = ''
  coupon.value = null
  couponCode.value = ''
  form.value.quantity = 1
}

const subtotal = computed(() => Number(selected.value?.price ?? 0) * form.value.quantity)
const total = computed(() => Math.max(subtotal.value - Number(coupon.value?.discount ?? 0), 0))
const maxQty = computed(() => Math.min(20, selected.value?.spots_left ?? 20))

async function applyCoupon() {
  couponError.value = ''
  const { data, error: err } = await supabase.rpc('check_coupon', {
    p_business: props.business.id, p_code: couponCode.value, p_subtotal: subtotal.value,
  })
  if (err) { couponError.value = err.message; return }
  if (!data.valid) { coupon.value = null; couponError.value = data.message; return }
  coupon.value = data
}

async function submit() {
  error.value = ''
  busy.value = true
  const f = form.value
  const { data, error: err } = await supabase.rpc('register_event', {
    p_event: selected.value.id, p_name: f.name, p_phone: f.phone, p_quantity: f.quantity,
    p_email: f.email || null, p_coupon: coupon.value?.code ?? null,
  })
  busy.value = false
  if (err) { error.value = err.message; return }
  result.value = data
  if (selected.value.spots_left != null) selected.value.spots_left -= f.quantity
}

const whatsappUrl = computed(() => selected.value && waLink(props.business.phone,
  `*Inscrição: ${selected.value.title}*\n${formatDate(selected.value.starts_at, tz.value)} às ${formatTime(selected.value.starts_at, tz.value)}\n\n` +
  `*Nome:* ${form.value.name}\n*Vagas:* ${form.value.quantity}\n*Total:* ${money(result.value?.total ?? total.value)}`))
</script>

<template>
  <div v-if="!business.live" class="card">
    <p>As inscrições online estão indisponíveis no momento.</p>
  </div>

  <template v-else>
    <p v-if="!business.events.length" class="card muted" style="text-align: center">Nenhum evento agendado no momento. Volte em breve!</p>

    <div class="events">
      <article v-for="e in business.events" :key="e.id" class="card event" :class="{ selected: selected?.id === e.id }">
        <img v-if="e.photo_url" :src="e.photo_url" alt="" class="cover" />
        <div class="when">
          <strong>{{ formatDate(e.starts_at, tz, { day: '2-digit' }) }}</strong>
          <small>{{ formatDate(e.starts_at, tz, { month: 'short' }).replace('.', '') }}</small>
        </div>
        <h3>{{ e.title }}</h3>
        <p class="muted meta">
          <Icon name="clock" />{{ formatDate(e.starts_at, tz, { weekday: 'long' }) }}, {{ formatTime(e.starts_at, tz) }}<span v-if="e.ends_at"> às {{ formatTime(e.ends_at, tz) }}</span>
        </p>
        <p v-if="e.location" class="muted meta"><Icon name="map" />{{ e.location }}</p>
        <p v-if="e.description" style="white-space: pre-line">{{ e.description }}</p>
        <div class="spread">
          <div>
            <strong style="font-size: 1.2rem">{{ Number(e.price) ? money(e.price) : 'Gratuito' }}</strong>
            <small v-if="e.spots_left != null" style="display: block">
              {{ e.spots_left > 0 ? `${plural(e.spots_left, 'vaga restante', 'vagas restantes')}` : 'Esgotado' }}
            </small>
          </div>
          <button class="btn" :disabled="e.spots_left === 0" @click="open(e)">
            {{ e.spots_left === 0 ? 'Esgotado' : 'Quero participar' }}
          </button>
        </div>
      </article>
    </div>

    <div v-if="selected" class="sheet-backdrop" @click.self="selected = null">
      <div class="sheet">
        <div v-if="result" class="done">
          <div class="done-icon"><Icon name="check" /></div>
          <h2 class="gradient-text">Inscrição confirmada!</h2>
          <p>{{ selected.title }} · {{ formatDate(selected.starts_at, tz) }} às {{ formatTime(selected.starts_at, tz) }}</p>
          <p v-if="Number(result.total)"><strong>Total: {{ money(result.total) }}</strong>. Combine o pagamento com {{ business.name }}.</p>
          <div class="row" style="justify-content: center">
            <a v-if="whatsappUrl" class="btn secondary shrink" :href="whatsappUrl" target="_blank" rel="noopener">Avisar pelo WhatsApp</a>
            <button class="btn shrink" @click="selected = null">Fechar</button>
          </div>
        </div>

        <form v-else @submit.prevent="submit">
          <div class="spread" style="margin-bottom: 12px">
            <h2 style="margin: 0">{{ selected.title }}</h2>
            <button type="button" class="btn small secondary" @click="selected = null">Fechar</button>
          </div>
          <div class="row">
            <div class="field"><label>Seu nome</label><input v-model="form.name" required autocomplete="name" /></div>
            <div class="field"><label>WhatsApp</label><input v-model="form.phone" type="tel" required autocomplete="tel" /></div>
          </div>
          <div class="row">
            <div class="field"><label>E-mail <small>(opcional)</small></label><input v-model="form.email" type="email" /></div>
            <div class="field" style="max-width: 120px"><label>Vagas</label><input v-model.number="form.quantity" type="number" min="1" :max="maxQty" required /></div>
          </div>
          <div v-if="hasCoupons && Number(selected.price)" class="field">
            <label>Cupom <small>(opcional)</small></label>
            <div class="row">
              <input v-model="couponCode" placeholder="Ex.: AMIGA" style="text-transform: uppercase" />
              <button type="button" class="btn secondary shrink" :disabled="!couponCode" @click="applyCoupon">Aplicar</button>
            </div>
            <small v-if="coupon" style="color: var(--success)">{{ coupon.message }}</small>
            <small v-if="couponError" style="color: var(--danger)">{{ couponError }}</small>
          </div>
          <div v-if="Number(selected.price)" class="notice"><strong>Total: {{ money(total) }}</strong></div>
          <div v-if="error" class="error">{{ error }}</div>
          <button class="btn large block" :disabled="busy">{{ busy ? 'Enviando...' : 'Confirmar inscrição' }}</button>
        </form>
      </div>
    </div>
  </template>
</template>

<style scoped>
.events { display: grid; gap: 14px; }
.card + .card { margin-top: 0; }
.event { position: relative; }
.event.selected { border-color: var(--brand); }
.cover { max-width: none; display: block; width: calc(100% + 44px); margin: -22px -22px 16px; height: 180px; object-fit: cover; border-radius: var(--radius) var(--radius) 0 0; }
.when { position: absolute; top: 16px; right: 16px; text-align: center; padding: 6px 12px; border-radius: 12px; background: linear-gradient(140deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); box-shadow: 0 0 16px var(--brand-glow); }
.when strong { display: block; font-size: 1.3rem; line-height: 1; }
.when small { color: inherit; text-transform: uppercase; font-size: 0.7rem; }
.event h3 { padding-right: 70px; font-size: 1.2rem; }
.meta { display: flex; align-items: center; gap: 6px; margin-bottom: 6px; font-size: 0.9rem; }
.meta svg { width: 15px; height: 15px; }
</style>
