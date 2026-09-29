<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { money } from '@/lib/format'
import { isOpenNow, nextOpening, hoursSummary } from '@/lib/store-hours'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const props = defineProps({ business: { type: Object, required: true } })

const store = computed(() => props.business.store)
const tz = computed(() => props.business.timezone)
const categories = computed(() => (props.business.menu ?? []).filter((c) => c.items.length))
const allItems = computed(() => categories.value.flatMap((c) => c.items))
const hasCoupons = computed(() => props.business.features.includes('cupons'))

// Reavalia aberto/fechado a cada minuto, para quem deixa a página aberta.
const tick = ref(0)
const timer = setInterval(() => { tick.value++ }, 60000)
onUnmounted(() => clearInterval(timer))
const openNow = computed(() => tick.value >= 0 && isOpenNow(store.value.hours, tz.value))
const canOrder = computed(() => props.business.live && store.value.accepting_orders && openNow.value)
const closedReason = computed(() => {
  if (!props.business.live) return 'Esta loja não está recebendo pedidos online no momento.'
  if (!store.value.accepting_orders) return 'A loja pausou os pedidos por enquanto.'
  if (!openNow.value) {
    const next = nextOpening(store.value.hours, tz.value)
    return next ? `Fechado agora · abre ${next}` : 'Fechado agora'
  }
  return ''
})
const schedule = computed(() => hoursSummary(store.value.hours))
const showHours = ref(false)

// ---------------- Sacola ----------------
const cart = ref({})   // { itemId: quantidade }
const cartLines = computed(() => allItems.value
  .filter((i) => cart.value[i.id])
  .map((i) => ({ ...i, qty: cart.value[i.id], total: cart.value[i.id] * Number(i.price) })))
const cartCount = computed(() => cartLines.value.reduce((n, l) => n + l.qty, 0))
const subtotal = computed(() => cartLines.value.reduce((s, l) => s + l.total, 0))

function add(item) {
  if (!item.available || !canOrder.value) return
  cart.value = { ...cart.value, [item.id]: (cart.value[item.id] ?? 0) + 1 }
}
function remove(item) {
  const qty = (cart.value[item.id] ?? 0) - 1
  const next = { ...cart.value }
  if (qty > 0) next[item.id] = qty
  else delete next[item.id]
  cart.value = next
}

// ---------------- Finalizar ----------------
const checkoutOpen = ref(false)
const placed = ref(null)   // resposta do place_order
const error = ref('')
const busy = ref(false)

const STORAGE_KEY = 'gg-vitrine-cliente'
function loadSaved() {
  try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) ?? {} } catch { return {} }
}
const saved = loadSaved()
const form = ref({
  name: saved.name ?? '', phone: saved.phone ?? '',
  mode: store.value.pickup_enabled ? 'retirada' : 'entrega',
  street: saved.street ?? '', number: saved.number ?? '', district: saved.district ?? '', reference: saved.reference ?? '',
  payment: 'pix', change: '', notes: '',
})
watch(() => [form.value.name, form.value.phone, form.value.street, form.value.number, form.value.district, form.value.reference], () => {
  const { name, phone, street, number, district, reference } = form.value
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ name, phone, street, number, district, reference })) } catch { /* sem armazenamento local */ }
})

// ---------------- Cupom ----------------
const couponCode = ref('')
const coupon = ref(null)
const couponError = ref('')
watch(subtotal, () => { if (coupon.value) applyCoupon() })

async function applyCoupon() {
  couponError.value = ''
  const { data, error: err } = await supabase.rpc('check_coupon', {
    p_business: props.business.id, p_code: couponCode.value, p_subtotal: subtotal.value,
  })
  if (err) { couponError.value = err.message; return }
  if (!data.valid) { coupon.value = null; couponError.value = data.message; return }
  coupon.value = data
}

const deliveryFee = computed(() => (form.value.mode === 'entrega' ? Number(store.value.delivery_fee) : 0))
const discount = computed(() => Number(coupon.value?.discount ?? 0))
const total = computed(() => Math.max(subtotal.value + deliveryFee.value - discount.value, 0))
const belowMinimum = computed(() => Number(store.value.min_order) > 0 && subtotal.value < Number(store.value.min_order))

const PAYMENTS = { pix: 'PIX', dinheiro: 'Dinheiro', cartao: 'Cartão na entrega/retirada' }

function address() {
  const f = form.value
  return [`${f.street}, ${f.number} - ${f.district}`, f.reference && `Ref.: ${f.reference}`].filter(Boolean).join(' · ')
}

function buildMessage(order) {
  const f = form.value
  const lines = [`*Pedido #${order.number}: ${props.business.name}*`, '']
  for (const l of order.items) lines.push(`${l.qty}x ${l.name}: ${money(l.total)}`)
  lines.push('', `Subtotal: ${money(order.subtotal)}`)
  if (Number(order.delivery_fee)) lines.push(`Entrega: ${money(order.delivery_fee)}`)
  if (Number(order.discount)) lines.push(`Desconto (${order.coupon}): -${money(order.discount)}`)
  lines.push(`*Total: ${money(order.total)}*`, '')
  lines.push(`*Cliente:* ${f.name}`, `*Telefone:* ${f.phone}`)
  lines.push(f.mode === 'entrega' ? `*Entregar em:* ${address()}` : '*Retirada no local*')
  let payment = PAYMENTS[f.payment]
  if (f.payment === 'dinheiro' && f.change) payment += ` (troco para ${money(f.change)})`
  lines.push(`*Pagamento:* ${payment}`)
  if (f.notes) lines.push(`*Observações:* ${f.notes}`)
  return lines.join('\n')
}

function openWhatsApp() {
  const url = waLink(props.business.phone, buildMessage(placed.value))
  if (url) window.open(url, '_blank', 'noopener')
}

async function send() {
  error.value = ''
  if (belowMinimum.value) { error.value = `O pedido mínimo é ${money(store.value.min_order)}.`; return }
  const f = form.value
  busy.value = true
  const { data, error: err } = await supabase.rpc('place_order', {
    p_business: props.business.id,
    p_items: cartLines.value.map((l) => ({ id: l.id, qty: l.qty })),
    p_name: f.name, p_phone: f.phone, p_mode: f.mode,
    p_address: f.mode === 'entrega' ? address() : null,
    p_payment: PAYMENTS[f.payment], p_change: f.payment === 'dinheiro' && f.change ? Number(f.change) : null,
    p_notes: f.notes || null, p_coupon: coupon.value?.code ?? null,
  })
  busy.value = false
  if (err) { error.value = err.message; return }
  placed.value = data
  openWhatsApp()
}

function finish() {
  cart.value = {}
  placed.value = null
  checkoutOpen.value = false
  coupon.value = null
  couponCode.value = ''
  form.value.notes = ''
  form.value.change = ''
}

function scrollTo(id) {
  document.getElementById(`cat-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<template>
  <div :style="{ paddingBottom: cartCount ? '90px' : '0' }">
    <div class="status-row">
      <span :class="['badge', canOrder ? 'green' : 'red']">{{ canOrder ? 'Aberto agora' : 'Fechado' }}</span>
      <button v-if="schedule.length" class="link-btn" @click="showHours = !showHours">{{ showHours ? 'ocultar horários' : 'ver horários' }}</button>
    </div>
    <div v-if="showHours" class="card hours">
      <div v-for="d in schedule" :key="d.name" class="spread"><span>{{ d.name }}</span><span class="muted">{{ d.ranges.join(' e ') }}</span></div>
    </div>

    <div v-if="closedReason" class="notice closed">{{ closedReason }}</div>

    <div class="info">
      <span v-if="store.pickup_enabled"><Icon name="bag" />Retirada no local</span>
      <span v-if="store.delivery_enabled"><Icon name="truck" />Entrega {{ Number(store.delivery_fee) ? money(store.delivery_fee) : 'grátis' }}</span>
      <span v-if="Number(store.min_order)">Pedido mínimo {{ money(store.min_order) }}</span>
    </div>
    <p v-if="store.delivery_enabled && store.delivery_area" class="muted" style="font-size: 0.88rem">
      Entregamos em: {{ store.delivery_area }}
    </p>

    <nav v-if="categories.length > 1" class="cat-nav">
      <button v-for="c in categories" :key="c.id" class="chip" @click="scrollTo(c.id)">{{ c.name }}</button>
    </nav>

    <p v-if="!categories.length" class="card muted" style="text-align: center">Os produtos ainda estão sendo cadastrados.</p>

    <section v-for="c in categories" :id="`cat-${c.id}`" :key="c.id" class="category">
      <h2>{{ c.name }}</h2>
      <div class="items">
        <div v-for="i in c.items" :key="i.id" class="card item" :class="{ off: !i.available }">
          <div class="item-text">
            <strong>{{ i.name }}</strong>
            <p v-if="i.description" class="muted">{{ i.description }}</p>
            <div class="item-foot">
              <span class="price">{{ money(i.price) }}</span>
              <span v-if="!i.available" class="badge red">Esgotado</span>
              <div v-else-if="cart[i.id]" class="stepper">
                <button aria-label="Diminuir" @click="remove(i)"><Icon name="minus" /></button>
                <span>{{ cart[i.id] }}</span>
                <button aria-label="Aumentar" @click="add(i)"><Icon name="plus" /></button>
              </div>
              <button v-else class="btn small" :disabled="!canOrder" @click="add(i)">
                <Icon name="plus" style="width: 15px; height: 15px" />Adicionar
              </button>
            </div>
          </div>
          <img v-if="i.photo_url" :src="i.photo_url" :alt="i.name" class="item-photo" loading="lazy" />
        </div>
      </div>
    </section>

    <!-- Barra da sacola -->
    <div v-if="cartCount && !checkoutOpen" class="cart-bar">
      <button class="btn large block" @click="checkoutOpen = true">
        <Icon name="bag" style="width: 20px; height: 20px" />
        Ver sacola · {{ cartCount }} {{ cartCount === 1 ? 'item' : 'itens' }} · {{ money(subtotal) }}
      </button>
    </div>

    <!-- Finalização -->
    <div v-if="checkoutOpen" class="sheet-backdrop" @click.self="checkoutOpen = false">
      <div class="sheet">
        <div v-if="placed" class="done">
          <div class="done-icon"><Icon name="check" /></div>
          <h2 class="gradient-text">Pedido #{{ placed.number }} enviado!</h2>
          <p class="muted">Confirme o envio da mensagem no WhatsApp. A loja responde por lá.</p>
          <p><strong>Total: {{ money(placed.total) }}</strong></p>
          <div class="row" style="justify-content: center">
            <button class="btn secondary shrink" @click="openWhatsApp">Abrir WhatsApp de novo</button>
            <button class="btn shrink" @click="finish">Fazer outro pedido</button>
          </div>
        </div>

        <form v-else @submit.prevent="send">
          <div class="spread" style="margin-bottom: 12px">
            <h2 style="margin: 0">Sua sacola</h2>
            <button type="button" class="btn small secondary" @click="checkoutOpen = false">Continuar comprando</button>
          </div>
          <div v-for="l in cartLines" :key="l.id" class="line">
            <div class="stepper small">
              <button type="button" @click="remove(l)"><Icon name="minus" /></button>
              <span>{{ l.qty }}</span>
              <button type="button" @click="add(l)"><Icon name="plus" /></button>
            </div>
            <span style="flex: 1">{{ l.name }}</span>
            <strong>{{ money(l.total) }}</strong>
          </div>

          <div v-if="store.pickup_enabled && store.delivery_enabled" class="tabs" style="margin-top: 18px">
            <button type="button" :class="{ on: form.mode === 'retirada' }" @click="form.mode = 'retirada'">Retirar no local</button>
            <button type="button" :class="{ on: form.mode === 'entrega' }" @click="form.mode = 'entrega'">Entrega</button>
          </div>
          <p v-if="form.mode === 'retirada' && business.address" class="muted" style="font-size: 0.88rem; margin-top: 10px">
            Retirada em: {{ business.address }}
          </p>

          <div class="row" style="margin-top: 16px">
            <div class="field"><label>Seu nome</label><input v-model="form.name" required autocomplete="name" /></div>
            <div class="field"><label>WhatsApp</label><input v-model="form.phone" type="tel" required autocomplete="tel" /></div>
          </div>

          <template v-if="form.mode === 'entrega'">
            <div class="row">
              <div class="field" style="flex-basis: 240px"><label>Rua</label><input v-model="form.street" required autocomplete="address-line1" /></div>
              <div class="field" style="max-width: 110px"><label>Número</label><input v-model="form.number" required /></div>
            </div>
            <div class="row">
              <div class="field"><label>Bairro</label><input v-model="form.district" required /></div>
              <div class="field"><label>Referência <small>(opcional)</small></label><input v-model="form.reference" /></div>
            </div>
          </template>

          <div class="field">
            <label>Pagamento</label>
            <div class="chips">
              <button v-for="(label, key) in PAYMENTS" :key="key" type="button" class="chip"
                      :class="{ selected: form.payment === key }" @click="form.payment = key">{{ label }}</button>
            </div>
          </div>
          <div v-if="form.payment === 'dinheiro'" class="field" style="max-width: 220px">
            <label>Troco para <small>(opcional)</small></label>
            <input v-model="form.change" type="number" min="0" step="0.01" placeholder="Ex.: 100" />
          </div>
          <div class="field">
            <label>Observações <small>(opcional)</small></label>
            <input v-model="form.notes" placeholder="Ex.: sem cebola, bem passado" />
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

          <div class="totals">
            <div class="spread"><span class="muted">Subtotal</span><span>{{ money(subtotal) }}</span></div>
            <div v-if="form.mode === 'entrega'" class="spread"><span class="muted">Entrega</span><span>{{ money(deliveryFee) }}</span></div>
            <div v-if="discount" class="spread"><span class="muted">Desconto</span><span style="color: var(--success)">-{{ money(discount) }}</span></div>
            <div class="spread total"><span>Total</span><span class="gradient-text">{{ money(total) }}</span></div>
          </div>

          <div v-if="belowMinimum" class="notice">Faltam {{ money(store.min_order - subtotal) }} para o pedido mínimo de {{ money(store.min_order) }}.</div>
          <div v-if="error" class="error">{{ error }}</div>

          <button class="btn large block" :disabled="!canOrder || belowMinimum || busy">
            <Icon name="whatsapp" style="width: 20px; height: 20px" />{{ busy ? 'Enviando...' : 'Enviar pedido pelo WhatsApp' }}
          </button>
          <p v-if="!canOrder" class="muted" style="text-align: center; margin-top: 8px">{{ closedReason }}</p>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.status-row { display: flex; gap: 12px; align-items: center; margin-bottom: 12px; font-size: 0.88rem; }
.hours { display: grid; gap: 6px; font-size: 0.9rem; margin-bottom: 14px; }
.closed { text-align: center; font-weight: 600; }
.info { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 10px; }
.info span { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 999px; background: var(--surface); border: 1px solid var(--border); font-size: 0.85rem; color: var(--silver); }
.info svg { width: 16px; height: 16px; color: var(--brand-ink); }

.cat-nav { position: sticky; top: 0; z-index: 10; display: flex; gap: 8px; overflow-x: auto; padding: 12px 0; margin: 8px 0; background: linear-gradient(180deg, rgba(5, 11, 22, 0.95) 70%, transparent); backdrop-filter: blur(8px); }
.cat-nav .chip { white-space: nowrap; }

.category { padding-top: 16px; scroll-margin-top: 70px; }
.category h2 { font-size: 1.3rem; margin-bottom: 12px; }
.items { display: grid; gap: 12px; }
.card + .card { margin-top: 0; }
.item { display: flex; gap: 14px; padding: 16px; align-items: stretch; transition: border-color 0.15s ease; }
.item:hover { border-color: var(--border-strong); }
.item.off { opacity: 0.55; }
.item-text { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.item-text p { font-size: 0.87rem; margin: 4px 0 0; }
.item-foot { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: auto; padding-top: 12px; }
.price { font-weight: 700; font-size: 1.05rem; }
.item-photo { width: 110px; height: 110px; border-radius: 14px; object-fit: cover; flex-shrink: 0; border: 1px solid var(--border); }

.stepper { display: inline-flex; align-items: center; gap: 4px; border-radius: 999px; border: 1px solid var(--brand); background: var(--brand-soft); padding: 3px; }
.stepper button { width: 30px; height: 30px; border-radius: 50%; border: none; display: grid; place-items: center; background: linear-gradient(120deg, var(--brand), var(--brand-strong)); color: var(--brand-contrast); cursor: pointer; }
.stepper button svg { width: 15px; height: 15px; }
.stepper span { min-width: 26px; text-align: center; font-weight: 700; }
.stepper.small button { width: 26px; height: 26px; }

.cart-bar { position: fixed; left: 0; right: 0; bottom: 0; z-index: 40; padding: 14px 16px calc(14px + env(safe-area-inset-bottom)); background: linear-gradient(0deg, rgba(5, 11, 22, 0.98) 60%, transparent); }
.cart-bar .btn { max-width: 728px; margin: 0 auto; display: flex; }
.line { display: flex; align-items: center; gap: 12px; padding: 10px 0; border-bottom: 1px solid var(--border); }
.totals { display: grid; gap: 6px; padding: 14px 0; margin: 6px 0 14px; border-top: 1px solid var(--border); }
.totals .total { font-size: 1.25rem; font-weight: 800; }

@media (max-width: 520px) { .item-photo { width: 88px; height: 88px; } }
</style>
