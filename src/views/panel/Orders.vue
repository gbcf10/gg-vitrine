<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatTime, formatDate, todayISO, zonedToUtc } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'
import { catalogWord } from '@/config/brand'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const orders = ref([])
const filter = ref('abertos')
const error = ref('')
const lastCount = ref(null)
const hasNew = ref(false)

const STATUS = {
  novo: { label: 'Novo', badge: 'yellow', next: 'preparando', action: 'Começar a preparar' },
  preparando: { label: 'Preparando', badge: 'blue', next: 'pronto', action: 'Marcar como pronto' },
  pronto: { label: 'Pronto', badge: 'green', next: 'entregue', action: 'Marcar como entregue' },
  entregue: { label: 'Entregue', badge: '' },
  cancelado: { label: 'Cancelado', badge: 'red' },
}
const FILTERS = { abertos: 'Em aberto', hoje: 'Hoje', todos: 'Todos' }

const visible = computed(() => orders.value.filter((o) => {
  if (filter.value === 'abertos') return ['novo', 'preparando', 'pronto'].includes(o.status)
  if (filter.value === 'hoje') return new Date(o.created_at) >= zonedToUtc(todayISO(tz.value), '00:00', tz.value)
  return true
}))
const todayTotal = computed(() => orders.value
  .filter((o) => o.status !== 'cancelado' && new Date(o.created_at) >= zonedToUtc(todayISO(tz.value), '00:00', tz.value))
  .reduce((s, o) => s + Number(o.total), 0))

async function load() {
  try {
    orders.value = unwrap(await supabase.from('orders').select('*, order_items(name, qty, total)')
      .eq('business_id', biz.business.id).order('created_at', { ascending: false }).limit(200))
    const openCount = orders.value.filter((o) => o.status === 'novo').length
    if (lastCount.value !== null && openCount > lastCount.value) hasNew.value = true
    lastCount.value = openCount
  } catch (e) {
    error.value = e.message
  }
}

// Atualiza sozinho para quem deixa o painel aberto no balcão.
let timer
onMounted(() => { load(); timer = setInterval(load, 20000) })
onUnmounted(() => clearInterval(timer))

async function setStatus(o, status) {
  const { error: err } = await supabase.from('orders').update({ status }).eq('id', o.id)
  if (err) error.value = err.message
  load()
}

function customerLink(o) {
  const msg = {
    novo: `Olá ${o.customer_name}! Recebemos seu pedido #${o.number}. Já já começamos a preparar.`,
    preparando: `Olá ${o.customer_name}! Seu pedido #${o.number} está sendo preparado.`,
    pronto: o.mode === 'entrega'
      ? `Olá ${o.customer_name}! Seu pedido #${o.number} saiu para entrega.`
      : `Olá ${o.customer_name}! Seu pedido #${o.number} está pronto para retirada.`,
  }[o.status] ?? `Olá ${o.customer_name}!`
  return waLink(o.phone, msg)
}
</script>

<template>
  <div class="page-header spread">
    <div>
      <p class="eyebrow">{{ catalogWord(biz.business.category) }}</p>
      <h1>Pedidos</h1>
    </div>
    <div class="card stat" style="padding: 12px 18px">
      <div class="label">Vendido hoje</div>
      <div class="value" style="font-size: 1.4rem">{{ money(todayTotal) }}</div>
    </div>
  </div>

  <div v-if="hasNew" class="success spread" @click="hasNew = false">
    <strong>🔔 Chegou pedido novo!</strong><button class="btn small secondary">Ok</button>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <div class="chips" style="margin-bottom: 16px">
    <button v-for="(label, key) in FILTERS" :key="key" class="chip" :class="{ selected: filter === key }" @click="filter = key">{{ label }}</button>
  </div>

  <p v-if="!visible.length" class="card muted" style="text-align: center">Nenhum pedido aqui. Os pedidos feitos pelo seu link aparecem nesta tela.</p>

  <div class="orders">
    <div v-for="o in visible" :key="o.id" class="card order" :class="{ fresh: o.status === 'novo' }">
      <div class="spread">
        <h3 style="margin: 0">#{{ o.number }} · {{ o.customer_name }}</h3>
        <span :class="['badge', STATUS[o.status].badge]">{{ STATUS[o.status].label }}</span>
      </div>
      <small>{{ formatDate(o.created_at, tz, { day: '2-digit', month: '2-digit' }) }} às {{ formatTime(o.created_at, tz) }}</small>

      <ul class="items">
        <li v-for="(i, n) in o.order_items" :key="n"><strong>{{ i.qty }}x</strong> {{ i.name }} <span class="muted">{{ money(i.total) }}</span></li>
      </ul>

      <div class="meta">
        <span><Icon :name="o.mode === 'entrega' ? 'truck' : 'bag'" />{{ o.mode === 'entrega' ? o.address : 'Retirada no local' }}</span>
        <span><Icon name="card" />{{ o.payment }}<template v-if="o.change_for"> · troco p/ {{ money(o.change_for) }}</template></span>
        <span v-if="o.notes"><Icon name="clipboard" />{{ o.notes }}</span>
      </div>

      <div class="spread" style="margin-top: 12px">
        <div>
          <strong style="font-size: 1.15rem">{{ money(o.total) }}</strong>
          <small v-if="Number(o.discount)"> (desconto {{ money(o.discount) }} · {{ o.coupon_code }})</small>
        </div>
        <div class="chips">
          <a v-if="customerLink(o)" class="btn small secondary" :href="customerLink(o)" target="_blank" rel="noopener">
            <Icon name="whatsapp" style="width: 15px; height: 15px" />Avisar cliente
          </a>
          <button v-if="STATUS[o.status].next" class="btn small" @click="setStatus(o, STATUS[o.status].next)">{{ STATUS[o.status].action }}</button>
          <button v-if="['novo', 'preparando'].includes(o.status)" class="btn small danger" @click="setStatus(o, 'cancelado')">Cancelar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.orders { display: grid; gap: 12px; }
.card + .card { margin-top: 0; }
.order.fresh { border-color: rgba(251, 191, 36, 0.5); box-shadow: 0 0 20px rgba(251, 191, 36, 0.12); }
.items { list-style: none; padding: 0; margin: 12px 0; display: grid; gap: 4px; }
.meta { display: grid; gap: 6px; font-size: 0.88rem; color: var(--silver); }
.meta span { display: flex; gap: 8px; align-items: flex-start; }
.meta svg { width: 16px; height: 16px; flex-shrink: 0; margin-top: 2px; color: var(--brand-ink); }
</style>
