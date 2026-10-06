<script setup>
import { ref, computed, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { session, signOut } from '@/lib/session'
import { money, formatTime, formatDate, formatDateTime, todayISO, addDaysISO, zonedToUtc, APPOINTMENT_STATUS } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })
const business = computed(() => props.business)
const tab = ref('agendar')
const error = ref('')
const tz = computed(() => business.value.timezone)
const staffLabel = computed(() => business.value.staff_label || 'Profissional')
const hasCoupons = computed(() => business.value.features.includes('cupons'))

// Ícone-padrão por categoria pra ilustrar os cards de serviço.
const CATEGORY_ICON = {
  Barbearia: 'scissors', 'Salão de beleza': 'sparkles', Estética: 'sparkles',
  Manicure: 'sparkles', Tatuagem: 'sparkles', 'Clínica': 'shield',
  Odontologia: 'shield', 'Estúdio fotográfico': 'image',
}
function iconFor() {
  return CATEGORY_ICON[business.value?.category] || 'calendar'
}

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
  const today = todayISO(tz.value)
  const tomorrow = addDaysISO(today, 1)
  let weekday
  if (d === today) weekday = 'Hoje'
  else if (d === tomorrow) weekday = 'Amanhã'
  else weekday = formatDate(noon, tz.value, { weekday: 'short' }).replace('.', '')
  return {
    weekday,
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

function clearService() {
  service.value = null
  slot.value = null
  slots.value = []
}

// ---------------- Login do cliente (código por e-mail) ----------------
const email = ref('')
const code = ref('')
const codeSent = ref(false)
const customer = ref({ name: '', phone: '' })
const busy = ref(false)
const resendIn = ref(0)

function startResendTimer() {
  resendIn.value = 60
  const t = setInterval(() => {
    resendIn.value--
    if (resendIn.value <= 0) clearInterval(t)
  }, 1000)
}

async function sendCode() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.auth.signInWithOtp({
    email: email.value,
    options: { shouldCreateUser: true, emailRedirectTo: location.href },
  })
  busy.value = false
  if (err) { error.value = err.message; return }
  codeSent.value = true
  startResendTimer()
}

async function resendCode() {
  if (resendIn.value > 0 || busy.value) return
  await sendCode()
}

function changeEmail() {
  codeSent.value = false
  code.value = ''
  resendIn.value = 0
  error.value = ''
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

// WhatsApp pós-agendamento (opcional).
const bookedWaLink = computed(() => {
  if (!booked.value || !business.value.phone) return null
  const msg = `Oi! Confirmei meu agendamento de ${booked.value.service.name} para ${formatDateTime(booked.value.starts_at, tz.value)}.`
  return waLink(business.value.phone, msg)
})

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
    <h3 style="margin: 0 0 8px">Temporariamente indisponível</h3>
    <p class="muted" style="margin: 0 0 6px">Este estabelecimento não está recebendo agendamentos online no momento.</p>
    <p v-if="business.phone" class="muted" style="margin: 0">Para falar diretamente: <strong>{{ business.phone }}</strong></p>
  </div>

  <template v-else>
    <div class="booking-tabs">
      <button :class="{ on: tab === 'agendar' }" @click="tab = 'agendar'; rescheduling = null">Agendar</button>
      <button :class="{ on: tab === 'meus' }" @click="tab = 'meus'">Meus agendamentos</button>
    </div>

    <div v-if="error" class="error">{{ error }}</div>

    <!-- ============ AGENDAR ============ -->
    <template v-if="tab === 'agendar'">
      <!-- Sucesso -->
      <div v-if="booked" class="card glow booking-done">
        <div class="done-ico"><Icon name="check" /></div>
        <h2 class="gradient-text">Agendamento confirmado!</h2>
        <p class="muted" style="margin: 0">Tá tudo certo. Guardamos aqui embaixo e você pode conferir em "Meus agendamentos".</p>
        <div class="summary">
          <div class="summary-row">
            <span class="label"><Icon name="scissors" />Serviço</span>
            <span class="value">{{ booked.service.name }}</span>
          </div>
          <div class="summary-row">
            <span class="label"><Icon name="contact" />{{ staffLabel }}</span>
            <span class="value">{{ professionalName(booked.professional_id) }}</span>
          </div>
          <div class="summary-row">
            <span class="label"><Icon name="calendar" />Quando</span>
            <span class="value">{{ formatDateTime(booked.starts_at, tz) }}</span>
          </div>
          <div class="summary-row total">
            <span class="label">Total</span>
            <span class="value">{{ money(booked.price) }}</span>
          </div>
        </div>
        <div class="done-actions">
          <a v-if="bookedWaLink" :href="bookedWaLink" target="_blank" rel="noopener" class="btn">
            <Icon name="whatsapp" />Falar no WhatsApp
          </a>
          <button class="btn secondary" @click="restart">Fazer outro agendamento</button>
        </div>
        <p class="muted" style="font-size: 0.82rem; margin: 16px 0 0">Ver, cancelar ou remarcar em "Meus agendamentos".</p>
      </div>

      <template v-else>
        <!-- 1. Serviço -->
        <div class="card">
          <div class="step-head">
            <span class="step-chip"><span class="n">1</span>Serviço</span>
            <h3>O que você quer agendar?</h3>
            <p v-if="!service">Escolha abaixo pra ver os horários disponíveis.</p>
            <p v-else>Toque pra trocar a qualquer momento.</p>
          </div>
          <p v-if="!business.services.length" class="muted">Nenhum serviço disponível no momento.</p>
          <div v-else class="svc-grid">
            <button
              v-for="s in business.services"
              :key="s.id"
              type="button"
              class="svc-card"
              :class="{ on: service?.id === s.id }"
              @click="service?.id === s.id ? clearService() : pickService(s)"
            >
              <div class="svc-icon"><Icon :name="iconFor()" /></div>
              <div class="svc-body">
                <span class="name">{{ s.name }}</span>
                <span v-if="s.description" class="desc">{{ s.description }}</span>
              </div>
              <div class="svc-meta">
                <span class="svc-price">{{ money(s.price) }}</span>
                <span class="svc-duration"><Icon name="clock" />{{ s.duration_min }} min</span>
              </div>
            </button>
          </div>
        </div>

        <!-- 2. Profissional -->
        <div v-if="service && professionalsForService.length > 1" class="card">
          <div class="step-head">
            <span class="step-chip"><span class="n">2</span>{{ staffLabel }}</span>
            <h3>Com quem você quer ser atendido?</h3>
            <p>Escolha "qualquer um" pra ver mais horários.</p>
          </div>
          <div class="pro-chips">
            <button
              type="button" class="pro-chip"
              :class="{ on: professionalId === 'any' }"
              @click="professionalId = 'any'"
            >
              <span class="pro-avatar"><Icon name="users" style="width:14px;height:14px" /></span>
              Qualquer um
            </button>
            <button
              v-for="p in professionalsForService" :key="p.id"
              type="button" class="pro-chip"
              :class="{ on: professionalId === p.id }"
              @click="professionalId = p.id"
            >
              <span class="pro-avatar">{{ p.name.charAt(0).toUpperCase() }}</span>
              {{ p.name }}
            </button>
          </div>
        </div>

        <!-- 3. Data e horário -->
        <div v-if="service" class="card">
          <div class="step-head">
            <span class="step-chip"><span class="n">{{ professionalsForService.length > 1 ? 3 : 2 }}</span>Data e horário</span>
            <h3>Quando fica bom pra você?</h3>
          </div>
          <div class="day-strip">
            <button
              v-for="d in nextDays" :key="d"
              type="button" class="day-pill"
              :class="{ on: date === d }"
              @click="date = d"
            >
              <small>{{ dayLabel(d).weekday }}</small>
              <strong>{{ dayLabel(d).day }}</strong>
            </button>
          </div>

          <p v-if="loadingSlots" class="muted" style="margin: 10px 0 0">Buscando horários...</p>
          <div v-else-if="!visibleSlots.length" class="slot-empty">
            <Icon name="ban" />
            <p style="margin: 0">Nenhum horário livre neste dia.</p>
            <small>Tente outra data acima.</small>
          </div>
          <div v-else class="slot-grid">
            <button
              v-for="s in visibleSlots" :key="s.starts_at"
              type="button" class="slot-btn"
              :class="{ on: slot?.starts_at === s.starts_at }"
              @click="slot = s"
            >
              {{ formatTime(s.starts_at, tz) }}
            </button>
          </div>
        </div>

        <!-- 4. Confirmação -->
        <div v-if="slot" class="card glow">
          <div class="step-head">
            <span class="step-chip"><span class="n"><Icon name="check" style="width:12px;height:12px" /></span>Confirmar</span>
            <h3>Tudo pronto, confere aí</h3>
          </div>

          <div class="summary">
            <div class="summary-row">
              <span class="label"><Icon name="scissors" />Serviço</span>
              <span class="value">{{ service.name }}</span>
            </div>
            <div class="summary-row">
              <span class="label"><Icon name="contact" />{{ staffLabel }}</span>
              <span class="value">{{ professionalName(slot.professional_id) }}</span>
            </div>
            <div class="summary-row">
              <span class="label"><Icon name="calendar" />Quando</span>
              <span class="value">{{ formatDateTime(slot.starts_at, tz) }}</span>
            </div>
            <div class="summary-row total">
              <span class="label">Total</span>
              <span class="value">
                <s v-if="coupon">{{ money(service.price) }}</s>{{ money(finalPrice) }}
              </span>
            </div>
          </div>

          <template v-if="!session.user">
            <!-- Passo 1: pede e-mail -->
            <form v-if="!codeSent" @submit.prevent="sendCode">
              <p class="muted" style="margin: 0 0 10px">Pra finalizar, informe seu e-mail. Vamos mandar um código de 6 dígitos.</p>
              <div class="row" style="gap: 10px">
                <div class="ff" style="flex: 1 1 180px; margin-bottom: 0">
                  <input v-model="email" type="email" required placeholder=" " />
                  <label>E-mail</label>
                </div>
                <button class="btn shrink" :disabled="busy">
                  <Icon name="mail" />
                  {{ busy ? 'Enviando...' : 'Enviar código' }}
                </button>
              </div>
            </form>

            <!-- Passo 2: pede código -->
            <div v-else class="otp-block">
              <div class="otp-sent">
                <div class="otp-sent-icon"><Icon name="check" /></div>
                <div class="otp-sent-text">
                  <strong>Código enviado!</strong>
                  <small>Confira sua caixa de entrada <strong>e o spam</strong>. Enviado pra <strong>{{ email }}</strong>.</small>
                </div>
                <button type="button" class="link-btn otp-change" @click="changeEmail">Trocar</button>
              </div>

              <form @submit.prevent="verifyCode" class="otp-form">
                <label class="otp-label" for="otp-input">Cole aqui o código do e-mail</label>
                <div class="otp-row">
                  <input
                    id="otp-input"
                    v-model="code"
                    inputmode="numeric"
                    autocomplete="one-time-code"
                    maxlength="8"
                    required
                    class="otp-input"
                    placeholder="________"
                  />
                  <button class="btn" :disabled="busy || code.length < 6">
                    {{ busy ? 'Verificando...' : 'Entrar' }}
                  </button>
                </div>
                <p class="otp-resend">
                  Não recebeu?
                  <button type="button" class="link-btn" :disabled="resendIn > 0 || busy" @click="resendCode">
                    {{ resendIn > 0 ? `Reenviar em ${resendIn}s` : 'Reenviar código' }}
                  </button>
                </p>
              </form>
            </div>
          </template>

          <form v-else @submit.prevent="confirm">
            <div class="row" style="gap: 10px">
              <div class="ff" style="flex: 1 1 180px; margin-bottom: 0">
                <input v-model="customer.name" required placeholder=" " />
                <label>Seu nome</label>
              </div>
              <div class="ff" style="flex: 1 1 180px; margin-bottom: 0">
                <input v-model="customer.phone" type="tel" required placeholder=" " />
                <label>WhatsApp</label>
              </div>
            </div>
            <div v-if="hasCoupons" class="field" style="margin-top: 12px">
              <label>Cupom de desconto <small>(opcional)</small></label>
              <div class="row">
                <input v-model="couponCode" placeholder="Ex.: PROMO10" style="text-transform: uppercase" />
                <button type="button" class="btn secondary shrink" :disabled="!couponCode" @click="applyCoupon">Aplicar</button>
              </div>
              <small v-if="coupon" style="color: var(--success)">{{ coupon.message }}</small>
              <small v-if="couponError" style="color: var(--danger)">{{ couponError }}</small>
            </div>
            <button class="btn block" style="margin-top: 16px" :disabled="busy">
              <Icon v-if="!busy" name="check" style="width:18px;height:18px" />
              {{ busy ? 'Confirmando...' : 'Confirmar agendamento' }}
            </button>
            <p class="muted" style="font-size: 0.8rem; margin-top: 10px; text-align: center">
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
        <h3 style="margin: 0 0 6px">Seus agendamentos</h3>
        <p class="muted" style="margin: 0 0 14px">Entre com seu e-mail pra ver, remarcar ou cancelar.</p>
        <form v-if="!codeSent" class="row" @submit.prevent="sendCode">
          <div class="ff" style="flex: 1 1 180px; margin-bottom: 0">
            <input v-model="email" type="email" required placeholder=" " />
            <label>E-mail</label>
          </div>
          <button class="btn shrink" :disabled="busy">{{ busy ? 'Enviando...' : 'Enviar código' }}</button>
        </form>
        <form v-else class="row" @submit.prevent="verifyCode">
          <div class="ff" style="flex: 1 1 180px; margin-bottom: 0">
            <input v-model="code" inputmode="numeric" required placeholder=" " />
            <label>Código recebido</label>
          </div>
          <button class="btn shrink" :disabled="busy">{{ busy ? 'Verificando...' : 'Entrar' }}</button>
        </form>
      </div>

      <div v-else-if="rescheduling" class="card">
        <h3 style="margin: 0 0 10px">Remarcar {{ rescheduling.service_name }}</h3>
        <div class="day-strip">
          <button
            v-for="d in nextDays" :key="d"
            type="button" class="day-pill"
            :class="{ on: date === d }"
            @click="date = d"
          >
            <small>{{ dayLabel(d).weekday }}</small>
            <strong>{{ dayLabel(d).day }}</strong>
          </button>
        </div>
        <div v-if="!visibleSlots.length && !loadingSlots" class="slot-empty" style="margin-top: 12px">
          <Icon name="ban" />
          <p style="margin: 0">Nenhum horário livre neste dia.</p>
        </div>
        <div v-else class="slot-grid" style="margin-top: 12px">
          <button
            v-for="s in visibleSlots" :key="s.starts_at"
            type="button" class="slot-btn"
            :class="{ on: slot?.starts_at === s.starts_at }"
            @click="slot = s"
          >
            {{ formatTime(s.starts_at, tz) }}
          </button>
        </div>
        <div class="row" style="margin-top: 16px">
          <button class="btn secondary shrink" @click="rescheduling = null; slot = null">Voltar</button>
          <button class="btn shrink" :disabled="!slot" @click="confirmReschedule">Confirmar novo horário</button>
        </div>
      </div>

      <div v-else class="card">
        <p v-if="!mine.length" class="muted" style="margin: 0">Você ainda não tem agendamentos aqui.</p>
        <div v-for="a in mine" :key="a.id" class="spread" style="padding: 14px 0; border-bottom: 1px solid var(--border); gap: 14px">
          <div style="min-width: 0">
            <strong>{{ a.service_name }}</strong>
            <span class="muted"> com {{ a.professional_name }}</span><br />
            <span class="muted" style="font-size: 0.88rem">{{ formatDateTime(a.starts_at, tz) }} · {{ APPOINTMENT_STATUS[a.status] }}</span>
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
