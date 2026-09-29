<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { money, formatDate, todayISO, BUSINESS_STATUS, SUBSCRIPTION_STATUS } from '@/lib/format'
import { KINDS } from '@/config/brand'

const rows = ref([])
const plans = ref([])
const filter = ref('')
const kindFilter = ref('')
const search = ref('')
const error = ref('')
const editing = ref(null)   // empresa aberta no formulário de assinatura
const payment = ref(null)   // empresa aberta no formulário de pagamento

const KIND_LABEL = Object.fromEntries(Object.entries(KINDS).map(([k, v]) => [k, v.label]))
const ACTIVITY = { agenda: 'agendamentos', cardapio: 'pedidos', orcamento: 'orçamentos', reserva: 'reservas', evento: 'inscrições', cartao: 'links' }
const STATUS_BADGE = { pending: 'yellow', approved: 'green', rejected: 'red', blocked: 'red' }

const visible = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value.filter((r) =>
    (!filter.value || r.status === filter.value) &&
    (!kindFilter.value || r.kind === kindFilter.value) &&
    (!q || `${r.name} ${r.slug} ${r.owner_email}`.toLowerCase().includes(q)))
})

async function load() {
  try {
    rows.value = unwrap(await supabase.rpc('admin_list_businesses'))
    plans.value = unwrap(await supabase.from('plans').select('*').order('sort_order'))
  } catch (e) {
    error.value = e.message
  }
}
onMounted(load)

async function call(fn, args) {
  error.value = ''
  const { error: err } = await supabase.rpc(fn, args)
  if (err) error.value = err.message
  await load()
  return !err
}

function setStatus(b, status) {
  let reason = null
  if (status === 'rejected' || status === 'blocked') {
    reason = prompt(status === 'rejected' ? 'Motivo da recusa (aparece para a empresa):' : 'Mensagem de bloqueio (aparece para a empresa):')
    if (reason === null) return
  }
  call('admin_set_business_status', { p_business: b.id, p_status: status, p_reason: reason })
}

// ---- Plano e preço negociado ----
function openEdit(b) {
  const plan = b.plan_id ?? (b.kind === 'cardapio' ? 'cardapio' : 'basico')
  editing.value = {
    business: b, plan_id: plan,
    custom_price: b.custom_price, discount_amount: b.discount_amount ?? 0,
    discount_mode: b.discount_until ? 'months' : 'forever',
    discount_months: 3, discount_until: b.discount_until, discount_note: b.discount_note ?? '',
  }
}

const preview = computed(() => {
  const e = editing.value
  if (!e) return null
  const base = plans.value.find((p) => p.id === e.plan_id)?.base_price ?? 0
  const price = e.custom_price === '' || e.custom_price == null ? Number(base) : Number(e.custom_price)
  return { base, final: Math.max(0, price - Number(e.discount_amount || 0)) }
})

function discountUntil(e) {
  if (!Number(e.discount_amount) || e.discount_mode === 'forever') return null
  if (e.discount_mode === 'date') return e.discount_until
  const d = new Date(todayISO() + 'T12:00:00')
  d.setMonth(d.getMonth() + Number(e.discount_months))
  return d.toISOString().slice(0, 10)
}

async function saveEdit() {
  const e = editing.value
  const ok = await call('admin_update_subscription', {
    p_business: e.business.id, p_plan: e.plan_id,
    p_custom_price: e.custom_price === '' || e.custom_price == null ? null : Number(e.custom_price),
    p_discount_amount: Number(e.discount_amount || 0),
    p_discount_until: discountUntil(e),
    p_discount_note: e.discount_note || null,
  })
  if (ok) {
    // Se a empresa paga pelo Asaas, atualiza o valor lá também (sem efeito para quem paga por fora).
    supabase.functions.invoke('asaas-checkout', { body: { action: 'sync-price', business_id: e.business.id } }).catch(() => {})
    editing.value = null
  }
}

// ---- Pagamento manual ----
function openPayment(b) {
  payment.value = { business: b, amount: b.monthly_price ?? 0, months: 1, method: 'pix', note: '' }
}

async function savePayment() {
  const p = payment.value
  const ok = await call('admin_register_payment', {
    p_business: p.business.id, p_amount: Number(p.amount), p_months: Number(p.months),
    p_method: p.method, p_note: p.note || null,
  })
  if (ok) payment.value = null
}
</script>

<template>
  <div class="page-header"><h1>Empresas</h1></div>
  <div v-if="error" class="error">{{ error }}</div>

  <!-- Formulário: plano e preço -->
  <div v-if="editing" class="card">
    <div class="spread"><h3>Plano e preço · {{ editing.business.name }}</h3>
      <button class="btn small secondary" @click="editing = null">Fechar</button></div>
    <div class="row">
      <div class="field">
        <label>Plano</label>
        <select v-model="editing.plan_id">
          <option v-for="p in plans.filter((x) => x.kind === editing.business.kind)" :key="p.id" :value="p.id">{{ p.name }} ({{ money(p.base_price) }})</option>
        </select>
      </div>
      <div class="field">
        <label>Preço personalizado <small>(vazio = tabela)</small></label>
        <input v-model="editing.custom_price" type="number" min="0" step="0.01" :placeholder="String(preview.base)" />
      </div>
      <div class="field">
        <label>Desconto (R$)</label>
        <input v-model="editing.discount_amount" type="number" min="0" step="0.01" />
      </div>
    </div>
    <div v-if="Number(editing.discount_amount) > 0" class="row">
      <div class="field">
        <label>Duração do desconto</label>
        <select v-model="editing.discount_mode">
          <option value="forever">Permanente</option>
          <option value="months">Por alguns meses</option>
          <option value="date">Até uma data</option>
        </select>
      </div>
      <div v-if="editing.discount_mode === 'months'" class="field">
        <label>Meses</label><input v-model="editing.discount_months" type="number" min="1" />
      </div>
      <div v-if="editing.discount_mode === 'date'" class="field">
        <label>Até</label><input v-model="editing.discount_until" type="date" />
      </div>
      <div class="field"><label>Observação</label><input v-model="editing.discount_note" placeholder="Ex.: migração da concorrência" /></div>
    </div>
    <p class="notice">
      Tabela: {{ money(preview.base) }} → <strong>valor contratado: {{ money(preview.final) }}/mês</strong>
      <span v-if="discountUntil(editing)"> até {{ formatDate(discountUntil(editing) + 'T12:00:00') }}, depois {{ money(editing.custom_price || preview.base) }}</span>
    </p>
    <button class="btn" @click="saveEdit">Salvar</button>
  </div>

  <!-- Formulário: pagamento manual -->
  <div v-if="payment" class="card">
    <div class="spread"><h3>Registrar pagamento · {{ payment.business.name }}</h3>
      <button class="btn small secondary" @click="payment = null">Fechar</button></div>
    <div class="row">
      <div class="field"><label>Valor (R$)</label><input v-model="payment.amount" type="number" min="0" step="0.01" /></div>
      <div class="field"><label>Meses pagos</label><input v-model="payment.months" type="number" min="1" /></div>
      <div class="field">
        <label>Forma</label>
        <select v-model="payment.method">
          <option value="pix">PIX</option><option value="boleto">Boleto</option>
          <option value="cartao">Cartão</option><option value="dinheiro">Dinheiro</option>
        </select>
      </div>
      <div class="field"><label>Observação</label><input v-model="payment.note" /></div>
    </div>
    <p class="muted">A assinatura fica ativa e o vencimento avança os meses informados.</p>
    <button class="btn" @click="savePayment">Registrar</button>
  </div>

  <div class="card">
    <div class="row" style="margin-bottom: 12px">
      <input v-model="search" placeholder="Buscar por nome, link ou e-mail" />
      <select v-model="filter" style="max-width: 200px">
        <option value="">Todos os status</option>
        <option v-for="(label, key) in BUSINESS_STATUS" :key="key" :value="key">{{ label }}</option>
      </select>
      <select v-model="kindFilter" style="max-width: 200px">
        <option value="">Todos os tipos</option>
        <option v-for="(label, key) in KIND_LABEL" :key="key" :value="key">{{ label }}</option>
      </select>
    </div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Empresa</th><th>Status</th><th>Plano</th><th>Mensalidade</th><th>Uso</th><th>Ações</th></tr>
        </thead>
        <tbody>
          <tr v-for="b in visible" :key="b.id">
            <td>
              <strong>{{ b.name }}</strong><br />
              <span class="badge blue" style="margin-left: 6px">{{ KIND_LABEL[b.kind] }}</span><br />
              <small class="muted">/{{ b.slug }} · {{ b.category }}<br />{{ b.owner_email }} · {{ b.phone }}</small>
            </td>
            <td>
              <span :class="['badge', STATUS_BADGE[b.status]]">{{ BUSINESS_STATUS[b.status] }}</span>
              <br /><small class="muted">desde {{ formatDate(b.created_at) }}</small>
            </td>
            <td>
              <template v-if="b.plan_id">
                {{ b.plan_name }}<br />
                <small class="muted">{{ SUBSCRIPTION_STATUS[b.subscription_status] }}</small>
                <br v-if="b.current_period_end" /><small v-if="b.current_period_end" class="muted">até {{ formatDate(b.current_period_end) }}</small>
              </template>
              <span v-else class="muted">—</span>
            </td>
            <td>
              <template v-if="b.plan_id">
                <strong>{{ money(b.monthly_price) }}</strong>
                <br v-if="Number(b.monthly_price) !== Number(b.base_price)" />
                <small v-if="Number(b.monthly_price) !== Number(b.base_price)" class="muted" style="text-decoration: line-through">{{ money(b.base_price) }}</small>
                <br v-if="b.discount_note" /><small v-if="b.discount_note" class="muted">{{ b.discount_note }}</small>
              </template>
            </td>
            <td>
              <small v-if="b.kind === 'agenda'">{{ b.professionals_count }} prof.<br />{{ b.customers_count }} clientes<br /></small>
              <small v-else-if="b.kind === 'cardapio'">{{ b.menu_items_count }} produtos<br /></small>
              <small>{{ b.activity_count }} {{ ACTIVITY[b.kind] }}</small>
            </td>
            <td>
              <div class="chips">
                <template v-if="b.status === 'pending'">
                  <button class="btn small" @click="setStatus(b, 'approved')">Aprovar</button>
                  <button class="btn small secondary" @click="setStatus(b, 'rejected')">Recusar</button>
                </template>
                <button v-if="b.status === 'approved'" class="btn small secondary" @click="setStatus(b, 'blocked')">Bloquear</button>
                <button v-if="b.status === 'blocked' || b.status === 'rejected'" class="btn small secondary" @click="setStatus(b, 'approved')">Reativar</button>
                <button v-if="b.status === 'approved'" class="btn small secondary" @click="openEdit(b)">Plano/preço</button>
                <button v-if="b.plan_id" class="btn small secondary" @click="openPayment(b)">Pagamento</button>
                <a class="btn small secondary" :href="`/${b.slug}`" target="_blank">Ver página</a>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!visible.length" class="muted">Nenhuma empresa encontrada.</p>
    </div>
  </div>
</template>
