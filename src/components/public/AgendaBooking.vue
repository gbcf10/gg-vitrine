<script setup>
import { ref, computed, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { session, signOut } from '@/lib/session'
import { money, formatTime, formatDate, formatDateTime, todayISO, addDaysISO, zonedToUtc, APPOINTMENT_STATUS } from '@/lib/format'

const props = defineProps({ business: { type: Object, required: true } })
const business = computed(() => props.business)
const tab = ref('agendar')
const error = ref('')
const tz = computed(() => business.value.timezone)
const staffLabel = computed(() => business.value.staff_label || 'Profissional')
const hasCoupons = computed(() => business.value.features.includes('cupons'))

// ---------------- Agendamento ----------------
const service = ref(null)
const professionalId = ref('any')
const date = ref(todayISO(props.business.timezone))
const slots = ref([])
const loadingSlots = ref(false)
const slot = ref(null)      // { starts_at, professional_id }
const booked = ref(null)

const professionalsForService = computed(() =>
  business.value?.professionals.filter((p) => p.service_ids.includes(service.value?.id)) ?? [])

const nextDays = computed(() => {
  if (!date.value) return []
  const today = todayISO(tz.value)
  return Array.from({ length: 21 }, (_, i) => addDaysISO(today, i))
})

// Com "qualquer profissional", mostra cada horário uma vez só.
const visibleSlots = computed(() => {
  const seen = new Set()
  return slots.value.filter((s) => (seen.has(s.starts_at) ? false : seen.add(s.starts_at)))
})

function professionalName(id) {
  return business.value.professionals.find((p) => p.id === id)?.name
}

function dayLabel(d) {
  const noon = zonedToUtc(d, '12:00', tz.value)
  return {
    weekday: formatDate(noon, tz.value, { weekday: 'short' }).replace('.', ''),
    day: formatDate(noon, tz.value, { day: '2-digit', month: '2-digit' }),
  }
}

async function loadSlots(forService = service.value, forProfessional = professionalId.value) {
  slot.value = null
  slots.value = []
  if (!forService || !date.value) return
  loadingSlots.value = true
  const { data, error: err } = await supabase.rpc('get_available_slots', {
    p_business: business.value.id, p_service: forService.id, p_date: date.value,
    p_professional: forProfessional === 'any' ? null : forProfessional,
  })
  loadingSlots.value = false
  if (err) error.value = err.message
  slots.value = data ?? []
}

function pickService(s) {
  service.value = s
  const pros = professionalsForService.value
  professionalId.value = pros.length === 1 ? pros[0].id : 'any'
}

// ---------------- Login do cliente (código por e-mail) ----------------
const email = ref('')
const code = ref('')
const codeSent = ref(false)
const customer = ref({ name: '', phone: '' })
const busy = ref(false)

async function sendCode() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.auth.signInWithOtp({
    email: email.value,
    options: { shouldCreateUser: true, emailRedirectTo: location.href },
  })
  busy.value = false
  if (err) error.value = err.message
  else codeSent.value = true
}

async function verifyCode() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.auth.verifyOtp({ email: email.value, token: code.value.trim(), type: 'email' })
  busy.value = false
  if (err) error.value = 'Código inválido ou expirado.'
}

// Preenche nome e telefone de quem já agendou aqui antes.
watch(() => [session.user?.id, business.value?.id], async ([uid, bid]) => {
  if (!uid || !bid) return
  const { data } = await supabase.from('customers').select('name, phone')
    .eq('business_id', bid).eq('auth_user_id', uid).maybeSingle()
  if (data) customer.value = { name: data.name, phone: data.phone ?? '' }
}, { immediate: true })

// ---------------- Cupom ----------------
const couponCode = ref('')
const coupon = ref(null)   // { code, discount, message }
const couponError = ref('')
watch(service, () => { coupon.value = null; couponError.value = '' })

async function applyCoupon() {
  couponError.value = ''
  const { data, error: err } = await supabase.rpc('check_coupon', {
    p_business: business.value.id, p_code: couponCode.value, p_subtotal: service.value.price,
  })
  if (err) { couponError.value = err.message; return }
  if (!data.valid) { coupon.value = null; couponError.value = data.message; return }
  coupon.value = data
}
const finalPrice = computed(() => Math.max(Number(service.value?.price ?? 0) - Number(coupon.value?.discount ?? 0), 0))

async function confirm() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.rpc('book_appointment', {
    p_business: business.value.id, p_service: service.value.id,
    p_professional: slot.value.professional_id, p_starts_at: slot.value.starts_at,
    p_name: customer.value.name, p_phone: customer.value.phone,
    p_coupon: coupon.value?.code ?? null,
  })
  busy.value = false
  if (err) { error.value = err.message; loadSlots(); return }
  booked.value = { ...slot.value, service: service.value, price: finalPrice.value }
}

function restart() {
  booked.value = null
  coupon.value = null
  couponCode.value = ''
  service.value = null
  slot.value = null
}

// ---------------- Meus agendamentos ----------------
const mine = ref([])
const rescheduling = ref(null)

async function loadMine() {
  if (!session.user || !business.value) return
  mine.value = unwrap(await supabase.rpc('my_appointments', { p_business: business.value.id }))
}
watch([tab, () => session.user?.id], () => { if (tab.value === 'meus') loadMine() })

const canChange = (a) => ['scheduled', 'confirmed'].includes(a.status) && new Date(a.starts_at) > new Date()

async function cancel(a) {
  if (!window.confirm('Cancelar este agendamento?')) return
  const { error: err } = await supabase.rpc('cancel_my_appointment', { p_id: a.id })
  if (err) error.value = err.message
  loadMine()
}

function startReschedule(a) {
  rescheduling.value = a
  date.value = todayISO(tz.value)
}

// Os mesmos horários servem para agendar e para remarcar.
watch([service, professionalId, date, rescheduling], () => {
  const a = rescheduling.value
  if (a) loadSlots({ id: a.service_id }, a.professional_id)
  else loadSlots()
})

async function confirmReschedule() {
  error.value = ''
  const { error: err } = await supabase.rpc('reschedule_my_appointment', {
    p_id: rescheduling.value.id, p_starts_at: slot.value.starts_at,
  })
  if (err) { error.value = err.message; return }
  rescheduling.value = null
  slot.value = null
  loadMine()
}
</script>

<template>
  <div v-if="!business.live" class="card">
    <p>Este estabelecimento não está recebendo agendamentos online no momento.</p>
    <p v-if="business.phone" class="muted">Contato: {{ business.phone }}</p>
  </div>

  <template v-else>
    <div class="tabs">
      <button :class="{ on: tab === 'agendar' }" @click="tab = 'agendar'; rescheduling = null">Agendar</button>
      <button :class="{ on: tab === 'meus' }" @click="tab = 'meus'">Meus agendamentos</button>
    </div>

    <div v-if="error" class="error">{{ error }}</div>

    <!-- ============ AGENDAR ============ -->
    <template v-if="tab === 'agendar'">
      <div v-if="booked" class="card glow done">
        <div class="done-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6 9 17l-5-5"/></svg></div>
        <h2 class="gradient-text" style="justify-content: center">Agendamento confirmado!</h2>
        <p>
          <strong>{{ booked.service.name }}</strong> com {{ professionalName(booked.professional_id) }}<br />
          {{ formatDateTime(booked.starts_at, tz) }}
        </p>
        <p class="muted">Você pode ver, cancelar ou remarcar em "Meus agendamentos".</p>
        <button class="btn" @click="restart">Fazer outro agendamento</button>
      </div>

      <template v-else>
        <!-- 1. Serviço -->
        <div class="card">
          <h3 class="step-title"><span class="step">1</span>Escolha o serviço</h3>
          <p v-if="!business.services.length" class="muted">Nenhum serviço disponível.</p>
          <div v-for="s in business.services" :key="s.id" class="chip option-item"
               :class="{ selected: service?.id === s.id }" @click="pickService(s)">
            <div class="spread">
              <strong>{{ s.name }}</strong>
              <span>{{ money(s.price) }}</span>
            </div>
            <small :style="{ opacity: 0.8 }">{{ s.duration_min }} min<span v-if="s.description"> · {{ s.description }}</span></small>
          </div>
        </div>

        <!-- 2. Profissional -->
        <div v-if="service && professionalsForService.length > 1" class="card">
          <h3 class="step-title"><span class="step">2</span>{{ staffLabel }}</h3>
          <div class="chips">
            <button class="chip" :class="{ selected: professionalId === 'any' }" @click="professionalId = 'any'">Qualquer um</button>
            <button v-for="p in professionalsForService" :key="p.id" class="chip"
                    :class="{ selected: professionalId === p.id }" @click="professionalId = p.id">{{ p.name }}</button>
          </div>
        </div>

        <!-- 3. Data e horário -->
        <div v-if="service" class="card">
          <h3 class="step-title"><span class="step">{{ professionalsForService.length > 1 ? 3 : 2 }}</span>Data e horário</h3>
          <div class="chips" style="flex-wrap: nowrap; overflow-x: auto; padding-bottom: 8px; margin-bottom: 12px">
            <button v-for="d in nextDays" :key="d" class="chip" :class="{ selected: date === d }"
                    style="text-align: center; min-width: 64px" @click="date = d">
              <small>{{ dayLabel(d).weekday }}</small><br /><strong>{{ dayLabel(d).day }}</strong>
            </button>
          </div>
          <p v-if="loadingSlots" class="muted">Buscando horários...</p>
          <p v-else-if="!visibleSlots.length" class="muted">Nenhum horário livre neste dia. Tente outra data.</p>
          <div v-else class="chips">
            <button v-for="s in visibleSlots" :key="s.starts_at" class="chip"
                    :class="{ selected: slot?.starts_at === s.starts_at }" @click="slot = s">
              {{ formatTime(s.starts_at, tz) }}
            </button>
          </div>
        </div>

        <!-- 4. Confirmação -->
        <div v-if="slot" class="card glow">
          <h3 class="step-title"><span class="step"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6 9 17l-5-5"/></svg></span>Confirmar</h3>
          <p>
            <strong>{{ service.name }}</strong> ·
            <span v-if="coupon"><s class="muted">{{ money(service.price) }}</s> {{ money(finalPrice) }}</span>
            <span v-else>{{ money(service.price) }}</span><br />
            {{ formatDateTime(slot.starts_at, tz) }} com {{ professionalName(slot.professional_id) }}
          </p>

          <template v-if="!session.user">
            <p class="muted">Para confirmar, informe seu e-mail. Enviaremos um código de acesso.</p>
            <form v-if="!codeSent" class="row" @submit.prevent="sendCode">
              <input v-model="email" type="email" placeholder="seu@email.com" required />
              <button class="btn shrink" :disabled="busy">Enviar código</button>
            </form>
            <form v-else class="row" @submit.prevent="verifyCode">
              <input v-model="code" inputmode="numeric" placeholder="Código recebido no e-mail" required />
              <button class="btn shrink" :disabled="busy">Entrar</button>
            </form>
          </template>

          <form v-else @submit.prevent="confirm">
            <div class="row">
              <div class="field"><label>Seu nome</label><input v-model="customer.name" required /></div>
              <div class="field"><label>WhatsApp</label><input v-model="customer.phone" type="tel" required /></div>
            </div>
            <div v-if="hasCoupons" class="field">
              <label>Cupom de desconto <small>(opcional)</small></label>
              <div class="row">
                <input v-model="couponCode" placeholder="Ex.: PROMO10" style="text-transform: uppercase" />
                <button type="button" class="btn secondary shrink" :disabled="!couponCode" @click="applyCoupon">Aplicar</button>
              </div>
              <small v-if="coupon" style="color: var(--success)">{{ coupon.message }}</small>
              <small v-if="couponError" style="color: var(--danger)">{{ couponError }}</small>
            </div>
            <button class="btn block" :disabled="busy">{{ busy ? 'Confirmando...' : 'Confirmar agendamento' }}</button>
            <p class="muted" style="font-size: 0.8rem; margin-top: 8px">
              Conectado como {{ session.user.email }} ·
              <button type="button" class="link-btn" @click="signOut">trocar</button>
            </p>
          </form>
        </div>
      </template>
    </template>

    <!-- ============ MEUS AGENDAMENTOS ============ -->
    <template v-else>
      <div v-if="!session.user" class="card">
        <p>Entre com seu e-mail para ver seus agendamentos.</p>
        <form v-if="!codeSent" class="row" @submit.prevent="sendCode">
          <input v-model="email" type="email" placeholder="seu@email.com" required />
          <button class="btn shrink" :disabled="busy">Enviar código</button>
        </form>
        <form v-else class="row" @submit.prevent="verifyCode">
          <input v-model="code" inputmode="numeric" placeholder="Código recebido no e-mail" required />
          <button class="btn shrink" :disabled="busy">Entrar</button>
        </form>
      </div>

      <div v-else-if="rescheduling" class="card">
        <h3>Remarcar {{ rescheduling.service_name }}</h3>
        <div class="chips" style="flex-wrap: nowrap; overflow-x: auto; padding-bottom: 8px; margin-bottom: 12px">
          <button v-for="d in nextDays" :key="d" class="chip" :class="{ selected: date === d }"
                  style="text-align: center; min-width: 64px" @click="date = d">
            <small>{{ dayLabel(d).weekday }}</small><br /><strong>{{ dayLabel(d).day }}</strong>
          </button>
        </div>
        <p v-if="!visibleSlots.length && !loadingSlots" class="muted">Nenhum horário livre neste dia.</p>
        <div class="chips">
          <button v-for="s in visibleSlots" :key="s.starts_at" class="chip"
                  :class="{ selected: slot?.starts_at === s.starts_at }" @click="slot = s">
            {{ formatTime(s.starts_at, tz) }}
          </button>
        </div>
        <div class="row" style="margin-top: 16px">
          <button class="btn secondary shrink" @click="rescheduling = null; slot = null">Voltar</button>
          <button class="btn shrink" :disabled="!slot" @click="confirmReschedule">Confirmar novo horário</button>
        </div>
      </div>

      <div v-else class="card">
        <p v-if="!mine.length" class="muted">Você ainda não tem agendamentos aqui.</p>
        <div v-for="a in mine" :key="a.id" class="spread" style="padding: 12px 0; border-bottom: 1px solid var(--border)">
          <div>
            <strong>{{ a.service_name }}</strong> com {{ a.professional_name }}<br />
            <span class="muted">{{ formatDateTime(a.starts_at, tz) }} · {{ APPOINTMENT_STATUS[a.status] }}</span>
          </div>
          <div v-if="canChange(a)" class="row" style="flex: 0 0 auto">
            <button class="btn small secondary" @click="startReschedule(a)">Remarcar</button>
            <button class="btn small danger" @click="cancel(a)">Cancelar</button>
          </div>
        </div>
        <p class="muted" style="font-size: 0.8rem; margin-top: 12px">
          {{ session.user.email }} · <button class="link-btn" @click="signOut">sair</button>
        </p>
      </div>
    </template>
  </template>
</template>
