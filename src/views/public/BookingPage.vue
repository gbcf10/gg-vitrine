<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { supabase, unwrap } from '@/lib/supabase'
import { session, signOut } from '@/lib/session'
import { money, formatTime, formatDate, formatDateTime, todayISO, addDaysISO, zonedToUtc, APPOINTMENT_STATUS } from '@/lib/format'
import { APP_NAME } from '@/config/brand'
import { brandVars } from '@/lib/colors'
import AppLogo from '@/components/AppLogo.vue'

const route = useRoute()
const business = ref(null)
const notFound = ref(false)
const tab = ref('agendar')
const error = ref('')

const tz = computed(() => business.value?.timezone)
const brandStyle = computed(() => brandVars(business.value?.primary_color))

onMounted(async () => {
  const { data } = await supabase.rpc('get_public_business', { p_slug: route.params.slug })
  if (!data) { notFound.value = true; return }
  business.value = data
  document.title = `${data.name} · Agendamento online`
  date.value = todayISO(data.timezone)
})

// ---------------- Agendamento ----------------
const service = ref(null)
const professionalId = ref('any')
const date = ref('')
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

async function confirm() {
  error.value = ''
  busy.value = true
  const { error: err } = await supabase.rpc('book_appointment', {
    p_business: business.value.id, p_service: service.value.id,
    p_professional: slot.value.professional_id, p_starts_at: slot.value.starts_at,
    p_name: customer.value.name, p_phone: customer.value.phone,
  })
  busy.value = false
  if (err) { error.value = err.message; loadSlots(); return }
  booked.value = { ...slot.value, service: service.value }
}

function restart() {
  booked.value = null
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
  <div v-if="notFound" class="narrow">
    <div class="auth-logo"><AppLogo /></div>
    <div class="card" style="text-align: center">
      <h3>Página não encontrada</h3>
      <p class="muted">Confira se o link está correto.</p>
    </div>
  </div>

  <div v-else-if="business" :style="brandStyle" style="min-height: 100vh">
    <header class="biz-hero">
      <div class="biz-glow" />
      <div class="container biz-head">
        <img v-if="business.logo_url" :src="business.logo_url" alt="" class="biz-logo" />
        <div v-else class="biz-logo initial">{{ business.name.charAt(0).toUpperCase() }}</div>
        <div>
          <p class="eyebrow" style="margin-bottom: 4px">{{ business.category }}</p>
          <h1 class="gradient-text" style="margin: 0">{{ business.name }}</h1>
          <div v-if="business.address" class="muted" style="margin-top: 4px">{{ business.address }}</div>
        </div>
      </div>
    </header>

    <main class="container biz-main">
      <p v-if="business.description" class="muted">{{ business.description }}</p>

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
            <h2 class="gradient-text">Agendamento confirmado!</h2>
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
              <h3><span class="step">1</span>Escolha o serviço</h3>
              <p v-if="!business.services.length" class="muted">Nenhum serviço disponível.</p>
              <div v-for="s in business.services" :key="s.id" class="chip service-item"
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
              <h3><span class="step">2</span>Profissional</h3>
              <div class="chips">
                <button class="chip" :class="{ selected: professionalId === 'any' }" @click="professionalId = 'any'">Qualquer um</button>
                <button v-for="p in professionalsForService" :key="p.id" class="chip"
                        :class="{ selected: professionalId === p.id }" @click="professionalId = p.id">{{ p.name }}</button>
              </div>
            </div>

            <!-- 3. Data e horário -->
            <div v-if="service" class="card">
              <h3><span class="step">{{ professionalsForService.length > 1 ? 3 : 2 }}</span>Data e horário</h3>
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
              <h3><span class="step"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6 9 17l-5-5"/></svg></span>Confirmar</h3>
              <p>
                <strong>{{ service.name }}</strong> · {{ money(service.price) }}<br />
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

      <div class="powered">
        <span class="muted">Agendamento por</span> <AppLogo />
      </div>
    </main>
  </div>
</template>

<style scoped>
.biz-hero { position: relative; overflow: hidden; border-bottom: 1px solid var(--border); background: linear-gradient(180deg, rgba(11, 23, 48, 0.7), transparent); }
.biz-glow { position: absolute; inset: -60% -10% auto; height: 420px; background: radial-gradient(circle at 30% 50%, var(--brand-glow), transparent 60%); opacity: 0.55; filter: blur(30px); pointer-events: none; }
.biz-head { position: relative; max-width: 720px; display: flex; gap: 18px; align-items: center; padding: 36px 0 30px; }
.biz-logo { width: 78px; height: 78px; border-radius: 20px; object-fit: cover; background: #fff; flex-shrink: 0; box-shadow: 0 0 30px var(--brand-glow); border: 1px solid var(--border); }
.biz-logo.initial { display: grid; place-items: center; font-size: 2rem; font-weight: 800; background: linear-gradient(140deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); }
.biz-main { max-width: 720px; padding-top: 24px; padding-bottom: 48px; }

.tabs { display: flex; gap: 4px; padding: 4px; border-radius: 999px; background: var(--surface); border: 1px solid var(--border); margin-bottom: 18px; }
.tabs button { flex: 1; padding: 10px; border-radius: 999px; border: none; background: none; color: var(--muted); font: inherit; font-weight: 600; cursor: pointer; }
.tabs button.on { background: linear-gradient(120deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); box-shadow: 0 0 18px var(--brand-glow); }

h3 { display: flex; align-items: center; gap: 10px; }
.step { width: 26px; height: 26px; border-radius: 50%; display: inline-grid; place-items: center; font-size: 0.8rem; font-weight: 800; background: var(--brand-soft); color: var(--brand-ink); border: 1px solid var(--border); }
.service-item { display: block; width: 100%; margin-bottom: 10px; padding: 14px 16px; }
.service-item:last-child { margin-bottom: 0; }

.done { text-align: center; padding: 36px 22px; }
.done-icon { width: 64px; height: 64px; margin: 0 auto 16px; border-radius: 50%; display: grid; place-items: center; background: linear-gradient(140deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); box-shadow: 0 0 30px var(--brand-glow); }
.done-icon svg { width: 30px; height: 30px; }
.done h2 { justify-content: center; }

.powered { display: flex; justify-content: center; align-items: center; gap: 8px; margin-top: 36px; font-size: 0.85rem; }
.powered :deep(.logo) { font-size: 0.95rem; }
.powered :deep(.logo-mark) { width: 26px; height: 26px; border-radius: 8px; }
.powered :deep(.logo-mark svg) { width: 15px; height: 15px; }
</style>
