<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, SUBSCRIPTION_STATUS, plural } from '@/lib/format'
import { FEATURE_LABELS, SUPPORT_WHATSAPP } from '@/config/brand'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const plans = ref([])
const payments = ref([])
const error = ref('')
const sub = computed(() => biz.subscription)
const canChoose = computed(() => !sub.value || ['pending_payment', 'canceled'].includes(sub.value.status))
const hasDiscount = computed(() => sub.value && Number(sub.value.effective_price) !== Number(sub.value.plan.base_price))

// Quanto fica em cada forma de pagamento (plano + taxa do meio de pagamento).
const quote = ref(null)
async function loadQuote() {
  const { data } = await supabase.rpc('billing_quote', { p_business: biz.business.id })
  quote.value = data
  if (data?.method) payForm.value.method = data.method
}

onMounted(async () => {
  plans.value = unwrap(await supabase.from('plans').select('*').eq('kind', biz.business.kind).order('sort_order'))
  if (sub.value) {
    payments.value = unwrap(await supabase.from('payments').select('*')
      .eq('business_id', biz.business.id).order('created_at', { ascending: false }).limit(12))
    loadQuote()
  }
})

async function choose(plan) {
  error.value = ''
  const { error: err } = await supabase.rpc('choose_plan', { p_business: biz.business.id, p_plan: plan.id })
  if (err) error.value = err.message
  else { await biz.reload(); loadQuote() }
}

const whatsappLink = computed(() => SUPPORT_WHATSAPP &&
  `https://wa.me/${SUPPORT_WHATSAPP}?text=${encodeURIComponent(`Olá! Quero pagar a assinatura do ${biz.business.name} (${biz.business.slug}).`)}`)

// ---------------- Pagamento online (Asaas) ----------------
const needsPayment = computed(() => sub.value && ['pending_payment', 'past_due'].includes(sub.value.status))
const openInvoices = computed(() => payments.value.filter((p) => ['pending', 'overdue'].includes(p.status) && p.invoice_url))
const payForm = ref({ document: '', name: biz.business.name, method: 'cartao' })
const METHODS = {
  cartao: { label: 'Cartão de crédito', hint: 'Cobrado sozinho todo mês' },
  pix: { label: 'PIX', hint: 'Fatura todo mês' },
  boleto: { label: 'Boleto', hint: 'Fatura todo mês' },
}
const changingMethod = ref(false)
const showPayForm = ref(false)
const paying = ref(false)
const onlineUnavailable = ref(false)
const info = ref('')

async function functionError(err) {
  try { return (await err.context.json()).error } catch { return err.message }
}

async function payOnline() {
  error.value = ''
  // Primeira vez: precisa do CPF/CNPJ para emitir a cobrança.
  if (!sub.value.gateway_customer_id && !showPayForm.value) { showPayForm.value = true; return }
  paying.value = true
  const { data, error: err } = await supabase.functions.invoke('asaas-checkout', {
    body: {
      action: 'checkout', business_id: biz.business.id, method: payForm.value.method,
      document: payForm.value.document, name: payForm.value.name,
    },
  })
  paying.value = false
  if (err) {
    const msg = await functionError(err)
    if (err.context?.status === 503 || /Failed to send|not found/i.test(err.message)) onlineUnavailable.value = true
    error.value = msg
    return
  }
  showPayForm.value = false
  if (data.updated) {
    changingMethod.value = false
    info.value = `Forma de pagamento alterada para ${METHODS[payForm.value.method].label}. Vale a partir da próxima fatura.`
  } else {
    window.open(data.invoiceUrl, '_blank', 'noopener')
    info.value = 'Abrimos a página de pagamento em outra aba. Assim que o pagamento for confirmado, seu painel é liberado.'
  }
  await biz.reload()
  loadQuote()
}

async function cancelSubscription() {
  const until = sub.value.current_period_end ? ` Sua vitrine continua no ar até ${formatDate(sub.value.current_period_end)}.` : ''
  if (!confirm(`Cancelar a assinatura?${until}`)) return
  error.value = ''
  const { error: err } = await supabase.functions.invoke('asaas-checkout', { body: { action: 'cancel', business_id: biz.business.id } })
  if (err) { error.value = await functionError(err); return }
  info.value = `Assinatura cancelada.${until}`
  biz.reload()
}
</script>

<template>
  <div class="page-header"><h1>Assinatura</h1></div>
  <div v-if="biz.business.billing_blocked" class="error">
    <strong>Sua vitrine está bloqueada por falta de pagamento.</strong> Pague a fatura em aberto e ela volta ao ar sozinha
    em alguns minutos.
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <div v-if="sub" class="card">
    <div class="spread">
      <div>
        <h3 style="margin-bottom: 4px">Plano {{ sub.plan.name }}</h3>
        <span :class="['badge', sub.status === 'active' ? 'green' : sub.status === 'past_due' ? 'yellow' : 'red']">
          {{ SUBSCRIPTION_STATUS[sub.status] }}
        </span>
      </div>
      <div style="text-align: right">
        <div v-if="hasDiscount" class="muted" style="text-decoration: line-through">{{ money(sub.plan.base_price) }}</div>
        <div style="font-size: 1.6rem; font-weight: 700">{{ money(sub.effective_price) }}<span class="muted" style="font-size: 1rem">/mês</span></div>
        <small v-if="sub.discount_amount > 0 && sub.discount_until" class="muted">
          Desconto válido até {{ formatDate(sub.discount_until + 'T12:00:00') }}
        </small>
      </div>
    </div>
    <p v-if="sub.current_period_end" class="muted" style="margin-top: 12px">
      Válida até {{ formatDate(sub.current_period_end) }}
    </p>

    <div v-if="needsPayment" :class="sub.status === 'past_due' ? 'error' : 'notice'" style="margin-top: 16px">
      <template v-if="sub.status === 'past_due'">
        <strong>Pagamento em atraso.</strong> Pague a fatura em aberto para sua vitrine não ser bloqueada.
      </template>
      <template v-else>
        <strong>Falta pouco!</strong> Assim que o pagamento for confirmado, seu painel é liberado.
      </template>


      <div v-if="quote" class="methods">
        <button v-for="(m, key) in METHODS" :key="key" type="button" class="method" :class="{ on: payForm.method === key }"
                @click="payForm.method = key">
          <strong>{{ m.label }}</strong>
          <span class="total">{{ money(quote.options[key].total) }}<small>/mês</small></span>
          <small>{{ money(quote.base) }} + {{ money(quote.options[key].fee) }} de taxa · {{ m.hint }}</small>
        </button>
      </div>

      <form v-if="showPayForm" style="margin-top: 14px" @submit.prevent="payOnline">
        <div class="row">
          <div class="field"><label>CPF ou CNPJ de quem paga</label><input v-model="payForm.document" inputmode="numeric" required placeholder="Só números" /></div>
          <div class="field"><label>Nome ou razão social</label><input v-model="payForm.name" required /></div>
        </div>
        <small>Usamos só para emitir a cobrança, como exige o banco.</small>
      </form>

      <div class="chips" style="margin-top: 12px">
        <button class="btn" :disabled="paying" @click="payOnline">
          <Icon name="card" style="width: 17px; height: 17px" />{{ paying ? 'Abrindo...' : `Pagar ${quote ? money(quote.options[payForm.method].total) : 'agora'}` }}
        </button>
        <a v-if="whatsappLink && (onlineUnavailable || !showPayForm)" :href="whatsappLink" target="_blank" class="btn secondary">Pagar pelo WhatsApp</a>
      </div>
      <p v-if="!onlineUnavailable" style="margin: 10px 0 0; font-size: 0.85rem">
        A taxa é cobrada pela instituição de pagamento e varia conforme a forma escolhida. Pode cancelar quando quiser.
      </p>
    </div>

    <div v-if="info" class="success" style="margin-top: 16px">{{ info }}</div>

    <div v-if="sub.status === 'active' && quote && sub.gateway" class="notice" style="margin-top: 16px">
      <div class="spread">
        <span>
          Forma de pagamento: <strong>{{ METHODS[quote.method ?? 'pix'].label }}</strong> ·
          {{ money(quote.options[quote.method ?? 'pix'].total) }}/mês
          <small>({{ money(quote.base) }} + {{ money(quote.options[quote.method ?? 'pix'].fee) }} de taxa)</small>
        </span>
        <button v-if="!changingMethod" class="btn small secondary" @click="changingMethod = true">Trocar</button>
      </div>
      <template v-if="changingMethod">

      <div v-if="quote" class="methods">
        <button v-for="(m, key) in METHODS" :key="key" type="button" class="method" :class="{ on: payForm.method === key }"
                @click="payForm.method = key">
          <strong>{{ m.label }}</strong>
          <span class="total">{{ money(quote.options[key].total) }}<small>/mês</small></span>
          <small>{{ money(quote.base) }} + {{ money(quote.options[key].fee) }} de taxa · {{ m.hint }}</small>
        </button>
      </div>

        <div class="chips" style="margin-top: 10px">
          <button class="btn small" :disabled="paying" @click="payOnline">Salvar forma de pagamento</button>
          <button class="btn small secondary" @click="changingMethod = false">Voltar</button>
        </div>
      </template>
    </div>

    <p v-if="sub.status === 'active' || sub.status === 'past_due'" style="margin: 16px 0 0; font-size: 0.85rem">
      <button class="link-btn" style="color: var(--muted)" @click="cancelSubscription">Cancelar assinatura</button>
    </p>
    <p v-if="sub.status === 'canceled' && sub.current_period_end" class="notice" style="margin-top: 16px">
      Assinatura cancelada. Sua vitrine fica no ar até {{ formatDate(sub.current_period_end) }}. Para continuar, escolha um plano abaixo.
    </p>
  </div>

  <div v-if="openInvoices.length" class="card">
    <h3>Faturas em aberto</h3>
    <div v-for="p in openInvoices" :key="p.id" class="spread" style="padding: 8px 0; border-top: 1px solid var(--border)">
      <span>{{ money(p.amount) }} · vence {{ formatDate(p.due_date + 'T12:00:00') }}
        <span v-if="p.status === 'overdue'" class="badge red" style="margin-left: 6px">Vencida</span></span>
      <a class="btn small" :href="p.invoice_url" target="_blank" rel="noopener">Pagar fatura</a>
    </div>
  </div>

  <template v-if="canChoose">
    <h3 style="margin-top: 24px">{{ sub ? 'Trocar plano' : 'Escolha seu plano' }}</h3>
    <div class="grid">
      <div v-for="plan in plans" :key="plan.id" class="card" style="margin: 0">
        <h3>{{ plan.name }}</h3>
        <p style="font-size: 1.5rem; font-weight: 700; margin-bottom: 2px">{{ money(plan.base_price) }}<span class="muted" style="font-size: 1rem">/mês</span></p>
        <p class="muted" style="font-size: 0.8rem">+ taxa do meio de pagamento (a partir de R$ 1,99)</p>
        <ul style="padding-left: 18px; font-size: 0.9rem">
          <template v-if="plan.kind === 'agenda'">
            <li>{{ plan.max_professionals ? `Até ${plural(plan.max_professionals, 'profissional', 'profissionais')}` : 'Profissionais ilimitados' }}</li>
            <li>{{ plan.max_customers ? `Até ${plan.max_customers} clientes` : 'Clientes ilimitados' }}</li>
          </template>
          <li v-else-if="plan.kind === 'cardapio'">Sem comissão por pedido</li>
          <li v-for="f in plan.features" :key="f">{{ FEATURE_LABELS[f] ?? f }}</li>
        </ul>
        <button class="btn block" :disabled="sub?.plan_id === plan.id" @click="choose(plan)">
          {{ sub?.plan_id === plan.id ? 'Selecionado' : 'Escolher' }}
        </button>
      </div>
    </div>
  </template>
  <p v-else class="muted" style="margin-top: 16px">Para mudar de plano, fale com o suporte.</p>

  <div v-if="payments.length" class="card table-wrap" style="margin-top: 24px">
    <h3>Pagamentos</h3>
    <table>
      <tbody>
        <tr v-for="p in payments" :key="p.id">
          <td>{{ formatDate(p.paid_at ?? (p.due_date ? p.due_date + 'T12:00:00' : p.created_at)) }}</td>
          <td>{{ money(p.amount) }}</td>
          <td>{{ { paid: 'Pago', pending: 'Em aberto', overdue: 'Vencido', refunded: 'Estornado', canceled: 'Cancelado' }[p.status] }}<small v-if="p.method"> · {{ METHODS[p.method]?.label ?? p.method }}</small></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.methods { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; margin-top: 14px; }
.method {
  display: flex; flex-direction: column; gap: 2px; text-align: left; padding: 12px 14px; cursor: pointer;
  border-radius: var(--radius-sm); border: 1px solid var(--border); background: var(--surface); color: var(--text); font: inherit;
}
.method:hover { border-color: var(--brand); }
.method.on { border-color: var(--brand); background: var(--brand-soft); box-shadow: 0 0 16px var(--brand-soft); }
.method .total { font-size: 1.25rem; font-weight: 800; }
.method .total small { font-size: 0.8rem; font-weight: 400; }
.method > small { font-size: 0.75rem; }
</style>
