<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, SUBSCRIPTION_STATUS } from '@/lib/format'
import { SUPPORT_WHATSAPP } from '@/config/brand'
import Icon from '@/components/Icon.vue'

const PLAN_PITCH = {
  solo: 'Pra quem está começando ou toca o negócio sozinho.',
  equipe: 'Pra quem gerencia poucas unidades ou está crescendo.',
  rede: 'Pra redes com várias unidades no ar.',
}
const PLAN_BULLETS = {
  solo: ['1 estabelecimento', 'Profissionais ilimitados', 'Lembretes no WhatsApp', 'Galeria, avaliações e fidelidade'],
  equipe: ['Até 3 estabelecimentos', 'Agendas separadas por unidade', 'Troca entre vitrines em 1 clique', 'Pague 1 vez, use nos 3'],
  rede: ['Até 5 estabelecimentos', 'Agendas separadas por unidade', 'Preço por unidade menor', 'Suporte prioritário'],
}

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
  const { data } = await supabase.rpc('billing_quote')
  quote.value = data
  if (data?.method) payForm.value.method = data.method
}

// Quantos estabelecimentos o dono tem (bate com max_businesses do plano).
const businessesCount = ref(1)

onMounted(async () => {
  plans.value = unwrap(await supabase.from('plans').select('*').order('sort_order'))
  const owned = unwrap(await supabase.from('businesses').select('id', { count: 'exact', head: true })
    .eq('created_by', biz.business.created_by))
  businessesCount.value = owned ?? 1
  if (sub.value) {
    payments.value = unwrap(await supabase.from('payments').select('*')
      .eq('subscription_id', sub.value.id).order('created_at', { ascending: false }).limit(12))
    loadQuote()
  }
})

async function choose(plan) {
  error.value = ''
  const { error: err } = await supabase.rpc('choose_plan', { p_plan: plan.id })
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
      action: 'checkout', method: payForm.value.method,
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
  const { error: err } = await supabase.functions.invoke('asaas-checkout', { body: { action: 'cancel' } })
  if (err) { error.value = await functionError(err); return }
  info.value = `Assinatura cancelada.${until}`
  biz.reload()
}
</script>

<template>
  <div class="page-header">
    <p class="eyebrow sub-eyebrow">Conta</p>
    <h1>Assinatura</h1>
    <p v-if="!sub" class="muted sub-lede">
      Escolha um plano pra liberar o painel completo e colocar sua vitrine no ar.
    </p>
    <p v-else-if="sub.status === 'active'" class="muted sub-lede">
      Sua assinatura está em dia. Veja detalhes, troque a forma de pagamento ou mude de plano quando quiser.
    </p>
    <p v-else class="muted sub-lede">
      Pague a fatura em aberto pra liberar o painel.
    </p>
  </div>

  <div v-if="biz.business.billing_blocked" class="alert alert-danger">
    <span class="alert-icon"><Icon name="ban" /></span>
    <div>
      <strong>Sua vitrine está bloqueada por falta de pagamento.</strong>
      <span>Pague a fatura em aberto e ela volta ao ar sozinha em alguns minutos.</span>
    </div>
  </div>
  <div v-if="error" class="alert alert-danger">
    <span class="alert-icon"><Icon name="ban" /></span>
    <span>{{ error }}</span>
  </div>

  <!-- Resumo do plano atual -->
  <div v-if="sub" class="sub-card">
    <div class="sub-card-head">
      <div class="sub-head-left">
        <span class="sub-plan-badge"><Icon name="sparkles" /></span>
        <div>
          <small class="muted sub-eyebrow-sm">Seu plano</small>
          <h2 class="sub-plan-name">{{ sub.plan.name }}</h2>
          <span class="sub-plan-status" :class="`tone-${sub.status === 'active' ? 'green' : sub.status === 'past_due' ? 'yellow' : 'red'}`">
            <span class="dot" />
            {{ SUBSCRIPTION_STATUS[sub.status] }}
          </span>
        </div>
      </div>
      <div class="sub-head-right">
        <div v-if="hasDiscount" class="sub-price-old">{{ money(sub.plan.base_price) }}</div>
        <div class="sub-price">
          <span class="sub-price-amount gradient-text">{{ money(sub.effective_price) }}</span>
          <small class="muted">/mês</small>
        </div>
        <small v-if="sub.discount_amount > 0 && sub.discount_until" class="sub-disc">
          Desconto até {{ formatDate(sub.discount_until + 'T12:00:00') }}
        </small>
        <small v-if="sub.current_period_end" class="muted sub-until">
          Válida até {{ formatDate(sub.current_period_end) }}
        </small>
      </div>
    </div>

    <!-- Bloco de pagamento pendente / em atraso -->
    <div v-if="needsPayment" class="pay-block" :class="sub.status === 'past_due' ? 'danger' : 'warn'">
      <div class="pay-block-head">
        <span class="pay-block-icon">
          <Icon :name="sub.status === 'past_due' ? 'ban' : 'bell'" />
        </span>
        <div>
          <strong v-if="sub.status === 'past_due'">Pagamento em atraso</strong>
          <strong v-else>Falta pouco!</strong>
          <small v-if="sub.status === 'past_due'">Pague a fatura em aberto pra sua vitrine não ser bloqueada.</small>
          <small v-else>Assim que o pagamento for confirmado, seu painel é liberado.</small>
        </div>
      </div>

      <div v-if="quote" class="methods">
        <button v-for="(m, key) in METHODS" :key="key" type="button" class="method" :class="{ on: payForm.method === key }"
                @click="payForm.method = key">
          <span class="method-check">
            <Icon v-if="payForm.method === key" name="check" />
          </span>
          <strong>{{ m.label }}</strong>
          <span class="total">{{ money(quote.options[key].total) }}<small>/mês</small></span>
          <small class="method-hint">{{ money(quote.base) }} + {{ money(quote.options[key].fee) }} de taxa · {{ m.hint }}</small>
        </button>
      </div>

      <form v-if="showPayForm" class="pay-form" @submit.prevent="payOnline">
        <div class="row">
          <div class="field"><label>CPF ou CNPJ de quem paga</label><input v-model="payForm.document" inputmode="numeric" required placeholder="Só números" /></div>
          <div class="field"><label>Nome ou razão social</label><input v-model="payForm.name" required /></div>
        </div>
        <small class="muted">Usamos só para emitir a cobrança, como exige o banco.</small>
      </form>

      <div class="pay-actions">
        <button class="btn" :disabled="paying" @click="payOnline">
          <Icon name="card" style="width: 17px; height: 17px" />
          {{ paying ? 'Abrindo...' : `Pagar ${quote ? money(quote.options[payForm.method].total) : 'agora'}` }}
        </button>
        <a v-if="whatsappLink && (onlineUnavailable || !showPayForm)" :href="whatsappLink" target="_blank" class="btn secondary">
          <Icon name="whatsapp" style="width: 16px; height: 16px" />
          Pagar pelo WhatsApp
        </a>
      </div>
      <p v-if="!onlineUnavailable" class="pay-note muted">
        A taxa é cobrada pela instituição de pagamento e varia conforme a forma escolhida. Pode cancelar quando quiser.
      </p>
    </div>

    <div v-if="info" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span>
      <span>{{ info }}</span>
    </div>

    <!-- Forma de pagamento atual -->
    <div v-if="sub.status === 'active' && quote && sub.gateway" class="pay-method-card">
      <div class="pmc-row">
        <div class="pmc-info">
          <span class="pmc-icon"><Icon name="card" /></span>
          <div>
            <small class="muted sub-eyebrow-sm">Forma de pagamento</small>
            <strong>{{ METHODS[quote.method ?? 'pix'].label }} · {{ money(quote.options[quote.method ?? 'pix'].total) }}/mês</strong>
            <small class="muted">{{ money(quote.base) }} + {{ money(quote.options[quote.method ?? 'pix'].fee) }} de taxa</small>
          </div>
        </div>
        <button v-if="!changingMethod" class="btn small secondary" @click="changingMethod = true">Trocar</button>
      </div>
      <template v-if="changingMethod">
        <div v-if="quote" class="methods">
          <button v-for="(m, key) in METHODS" :key="key" type="button" class="method" :class="{ on: payForm.method === key }"
                  @click="payForm.method = key">
            <span class="method-check">
              <Icon v-if="payForm.method === key" name="check" />
            </span>
            <strong>{{ m.label }}</strong>
            <span class="total">{{ money(quote.options[key].total) }}<small>/mês</small></span>
            <small class="method-hint">{{ money(quote.base) }} + {{ money(quote.options[key].fee) }} de taxa · {{ m.hint }}</small>
          </button>
        </div>
        <div class="pay-actions compact">
          <button class="btn small" :disabled="paying" @click="payOnline">Salvar forma de pagamento</button>
          <button class="btn small secondary" @click="changingMethod = false">Voltar</button>
        </div>
      </template>
    </div>

    <p v-if="sub.status === 'active' || sub.status === 'past_due'" class="sub-cancel">
      <button class="link-btn muted" @click="cancelSubscription">Cancelar assinatura</button>
    </p>
    <div v-if="sub.status === 'canceled' && sub.current_period_end" class="alert alert-info">
      <span class="alert-icon"><Icon name="clock" /></span>
      <span>Assinatura cancelada. Sua vitrine fica no ar até <strong>{{ formatDate(sub.current_period_end) }}</strong>. Pra continuar, escolha um plano abaixo.</span>
    </div>
  </div>

  <!-- Faturas em aberto -->
  <div v-if="openInvoices.length" class="invoices-card">
    <div class="invoices-head">
      <span class="pay-block-icon warn"><Icon name="ticket" /></span>
      <div>
        <strong>Faturas em aberto</strong>
        <small>Pague agora pra não ter sua vitrine bloqueada.</small>
      </div>
    </div>
    <div class="invoices-list">
      <div v-for="p in openInvoices" :key="p.id" class="invoice-row">
        <div class="invoice-info">
          <strong>{{ money(p.amount) }}</strong>
          <small class="muted">Vence {{ formatDate(p.due_date + 'T12:00:00') }}</small>
        </div>
        <span v-if="p.status === 'overdue'" class="badge red">Vencida</span>
        <a class="btn small" :href="p.invoice_url" target="_blank" rel="noopener">Pagar fatura</a>
      </div>
    </div>
  </div>

  <!-- Planos (destaque: Equipe) -->
  <template v-if="canChoose">
    <div class="plans-head">
      <h2 class="plans-title">
        {{ sub ? 'Trocar plano' : 'Escolha seu plano' }}
      </h2>
      <p class="muted plans-sub">
        Todos os planos têm as mesmas funcionalidades. Mudam só os <strong>estabelecimentos</strong> que você pode cadastrar na sua conta.
      </p>
    </div>
    <div class="plans-grid">
      <div v-for="plan in plans" :key="plan.id"
           class="plan-card"
           :class="{ featured: plan.id === 'equipe', cant: plan.max_businesses < businessesCount, selected: sub?.plan_id === plan.id }">
        <div v-if="plan.id === 'equipe'" class="plan-ribbon">
          <Icon name="sparkles" />
          Mais escolhido
        </div>
        <div v-if="sub?.plan_id === plan.id" class="plan-current">
          <Icon name="check" />
          Plano atual
        </div>

        <div class="plan-head">
          <h3 class="plan-name">{{ plan.name }}</h3>
          <p class="plan-tagline">{{ PLAN_PITCH[plan.id] }}</p>
        </div>

        <div class="plan-price">
          <span class="plan-price-amount gradient-text">{{ money(plan.base_price) }}</span>
          <small>/mês</small>
        </div>
        <p class="muted plan-fee">+ taxa do meio de pagamento (a partir de R$ 1,99)</p>

        <div class="plan-sep" />

        <ul class="plan-list">
          <li v-for="b in (PLAN_BULLETS[plan.id] ?? [])" :key="b">
            <span class="plan-check"><Icon name="check" /></span>
            {{ b }}
          </li>
        </ul>

        <button class="btn block"
                :class="plan.id === 'equipe' ? '' : 'secondary'"
                :disabled="sub?.plan_id === plan.id || plan.max_businesses < businessesCount"
                @click="choose(plan)">
          {{ sub?.plan_id === plan.id ? 'Selecionado' : (plan.max_businesses < businessesCount ? 'Insuficiente' : (sub ? 'Trocar pra este' : `Começar com o ${plan.name}`)) }}
        </button>
        <small v-if="plan.max_businesses < businessesCount" class="muted plan-insuf">
          Você já tem {{ businessesCount }} vitrines. Precisa remover alguma pra escolher esse plano.
        </small>
      </div>
    </div>
  </template>

  <!-- Histórico de pagamentos -->
  <div v-if="payments.length" class="history-card">
    <div class="history-head">
      <span class="pay-block-icon"><Icon name="clock" /></span>
      <div>
        <strong>Histórico de pagamentos</strong>
        <small>Últimas {{ payments.length }} cobranças da sua assinatura.</small>
      </div>
    </div>
    <div class="history-list">
      <div v-for="p in payments" :key="p.id" class="history-row">
        <div class="history-date">
          <strong>{{ formatDate(p.paid_at ?? (p.due_date ? p.due_date + 'T12:00:00' : p.created_at)) }}</strong>
          <small v-if="p.method" class="muted">{{ METHODS[p.method]?.label ?? p.method }}</small>
        </div>
        <div class="history-amount">{{ money(p.amount) }}</div>
        <span class="badge" :class="{ green: p.status === 'paid', yellow: p.status === 'pending', red: p.status === 'overdue' }">
          {{ { paid: 'Pago', pending: 'Em aberto', overdue: 'Vencido', refunded: 'Estornado', canceled: 'Cancelado' }[p.status] }}
        </span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* =====================================================================
   Header da página
   ===================================================================== */
.sub-eyebrow { display: inline-block; margin-bottom: 6px; }
.sub-lede { font-size: 0.95rem; max-width: 540px; margin: 4px 0 0; }

/* =====================================================================
   Alertas
   ===================================================================== */
.alert {
  display: flex; align-items: flex-start; gap: 12px;
  padding: 14px 16px;
  border-radius: var(--radius-sm);
  border: 1px solid;
  margin-bottom: 16px;
  line-height: 1.5;
}
.alert strong { display: block; }
.alert span { font-size: 0.92rem; }
.alert-danger { color: #fecaca; background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.35); }
.alert-success { color: #bbf7d0; background: var(--success-soft); border-color: rgba(74, 222, 128, 0.35); }
.alert-info { color: var(--silver); background: var(--brand-soft); border-color: rgba(59, 130, 246, 0.3); }
.alert-icon {
  flex-shrink: 0;
  width: 32px; height: 32px; border-radius: 10px;
  display: grid; place-items: center;
}
.alert-danger .alert-icon { background: rgba(248, 113, 113, 0.2); color: var(--danger); }
.alert-success .alert-icon { background: rgba(74, 222, 128, 0.2); color: var(--success); }
.alert-info .alert-icon { background: var(--brand-soft); color: var(--brand-ink); }
.alert-icon :deep(svg) { width: 16px; height: 16px; stroke-width: 2.4; }

/* =====================================================================
   Card principal: resumo do plano atual
   ===================================================================== */
.sub-card {
  position: relative;
  background:
    radial-gradient(ellipse 500px 240px at 100% 0%, rgba(59, 130, 246, 0.14), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 24px;
  margin-bottom: 20px;
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
  box-shadow: var(--shadow), 0 0 40px rgba(59, 130, 246, 0.08);
  overflow: hidden;
}

.sub-card-head {
  display: flex; align-items: flex-start; justify-content: space-between;
  gap: 20px;
  flex-wrap: wrap;
}
.sub-head-left { display: flex; align-items: center; gap: 14px; min-width: 0; }
.sub-plan-badge {
  width: 48px; height: 48px; border-radius: 14px;
  display: grid; place-items: center; flex-shrink: 0;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 22px var(--brand-glow);
}
.sub-plan-badge :deep(svg) { width: 22px; height: 22px; }
.sub-eyebrow-sm {
  font-size: 0.68rem;
  text-transform: uppercase; letter-spacing: 0.14em;
  font-weight: 700; color: var(--muted);
  display: block;
}
.sub-plan-name {
  font-size: 1.5rem; font-weight: 800;
  letter-spacing: -0.02em;
  margin: 2px 0 8px;
}
.sub-plan-status {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px 4px 8px;
  border-radius: 999px;
  font-size: 0.72rem; font-weight: 700;
  letter-spacing: 0.03em;
  border: 1px solid;
}
.sub-plan-status .dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: currentColor;
  box-shadow: 0 0 8px currentColor;
}
.sub-plan-status.tone-green { color: var(--success); background: var(--success-soft); border-color: rgba(74, 222, 128, 0.3); }
.sub-plan-status.tone-yellow { color: var(--warning); background: var(--warning-soft); border-color: rgba(251, 191, 36, 0.3); }
.sub-plan-status.tone-red { color: var(--danger); background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.3); }

.sub-head-right { text-align: right; }
.sub-price-old {
  font-size: 0.9rem;
  color: var(--muted);
  text-decoration: line-through;
}
.sub-price {
  display: flex; align-items: baseline; gap: 4px;
  justify-content: flex-end;
}
.sub-price-amount {
  font-size: 1.9rem; font-weight: 800;
  letter-spacing: -0.03em; line-height: 1;
}
.sub-price small { font-size: 0.9rem; }
.sub-disc, .sub-until {
  display: block;
  font-size: 0.78rem;
  margin-top: 4px;
}
.sub-disc { color: var(--brand-ink); font-weight: 600; }

/* ---------- Bloco "precisa pagar" ---------- */
.pay-block {
  margin-top: 20px;
  padding: 18px;
  border-radius: var(--radius-sm);
  border: 1px solid;
}
.pay-block.warn {
  background: linear-gradient(160deg, rgba(251, 191, 36, 0.08), rgba(5, 11, 22, 0.3));
  border-color: rgba(251, 191, 36, 0.3);
}
.pay-block.danger {
  background: linear-gradient(160deg, rgba(248, 113, 113, 0.1), rgba(5, 11, 22, 0.3));
  border-color: rgba(248, 113, 113, 0.3);
}
.pay-block-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 14px;
}
.pay-block-icon {
  width: 40px; height: 40px; border-radius: 12px;
  display: grid; place-items: center; flex-shrink: 0;
  background: var(--brand-soft);
  color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
}
.pay-block.warn .pay-block-icon {
  background: var(--warning-soft);
  color: var(--warning);
  border-color: rgba(251, 191, 36, 0.3);
}
.pay-block.danger .pay-block-icon {
  background: var(--danger-soft);
  color: var(--danger);
  border-color: rgba(248, 113, 113, 0.3);
}
.pay-block-icon.warn { background: var(--warning-soft); color: var(--warning); border-color: rgba(251, 191, 36, 0.3); }
.pay-block-icon :deep(svg) { width: 18px; height: 18px; }
.pay-block-head strong { display: block; font-size: 1rem; color: var(--text); margin-bottom: 2px; }
.pay-block-head small { color: var(--muted); font-size: 0.85rem; display: block; }

/* ---------- Métodos de pagamento ---------- */
.methods {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 10px;
  margin: 14px 0;
}
.method {
  position: relative;
  display: flex; flex-direction: column;
  gap: 4px;
  text-align: left;
  padding: 14px 16px 14px 44px;
  cursor: pointer;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  font: inherit;
  transition: border-color 0.15s ease, background 0.15s ease, box-shadow 0.15s ease, transform 0.15s ease;
}
.method:hover {
  border-color: var(--brand);
  transform: translateY(-1px);
}
.method.on {
  border-color: var(--brand);
  background: linear-gradient(160deg, var(--brand-soft), rgba(5, 11, 22, 0.3));
  box-shadow: 0 0 20px rgba(59, 130, 246, 0.18);
}
.method-check {
  position: absolute;
  left: 14px; top: 50%; transform: translateY(-50%);
  width: 20px; height: 20px; border-radius: 999px;
  display: grid; place-items: center;
  background: var(--surface);
  border: 1.5px solid var(--border);
  color: #fff;
  transition: background 0.15s ease, border-color 0.15s ease;
}
.method.on .method-check {
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  border-color: transparent;
  box-shadow: 0 0 10px var(--brand-glow);
}
.method-check :deep(svg) { width: 12px; height: 12px; stroke-width: 3; }
.method strong { font-size: 0.9rem; font-weight: 700; }
.method .total { font-size: 1.3rem; font-weight: 800; letter-spacing: -0.02em; }
.method .total small { font-size: 0.8rem; font-weight: 500; color: var(--muted); }
.method-hint { font-size: 0.74rem; color: var(--muted); line-height: 1.4; }

/* ---------- Form inline (CPF / nome) ---------- */
.pay-form {
  margin-top: 8px;
  padding: 14px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
}
.pay-form .field { margin-bottom: 10px; }
.pay-form .row > .field:last-child { margin-bottom: 10px; }

.pay-actions { display: flex; gap: 10px; flex-wrap: wrap; margin-top: 14px; }
.pay-actions.compact { margin-top: 10px; }
.pay-note { font-size: 0.82rem; margin: 12px 0 0; line-height: 1.5; }

/* ---------- Forma de pagamento atual (ativo) ---------- */
.pay-method-card {
  margin-top: 16px;
  padding: 16px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
}
.pmc-row {
  display: flex; align-items: center; justify-content: space-between;
  gap: 16px; flex-wrap: wrap;
}
.pmc-info {
  display: flex; align-items: center; gap: 12px;
  min-width: 0;
}
.pmc-icon {
  width: 40px; height: 40px; border-radius: 12px;
  display: grid; place-items: center; flex-shrink: 0;
  background: var(--brand-soft);
  color: var(--brand-ink);
  border: 1px solid rgba(59, 130, 246, 0.3);
}
.pmc-icon :deep(svg) { width: 18px; height: 18px; }
.pmc-info strong { display: block; font-size: 0.95rem; margin: 2px 0; }
.pmc-info small { display: block; }

.sub-cancel { margin: 18px 0 0; font-size: 0.85rem; }

/* =====================================================================
   Faturas em aberto
   ===================================================================== */
.invoices-card {
  padding: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 180px at 0% 0%, rgba(251, 191, 36, 0.08), transparent 65%),
    var(--surface);
  border: 1px solid rgba(251, 191, 36, 0.25);
  margin-bottom: 20px;
}
.invoices-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 14px;
}
.invoices-head strong { display: block; font-size: 1rem; }
.invoices-head small { color: var(--muted); font-size: 0.84rem; }
.invoices-list { display: flex; flex-direction: column; gap: 10px; }
.invoice-row {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 14px;
  border-radius: var(--radius-sm);
  background: rgba(5, 11, 22, 0.5);
  border: 1px solid var(--border);
}
.invoice-info { flex: 1; min-width: 0; }
.invoice-info strong { display: block; font-size: 1.05rem; }
.invoice-info small { display: block; font-size: 0.78rem; }

/* =====================================================================
   Planos
   ===================================================================== */
.plans-head { margin: 28px 0 20px; }
.plans-title {
  font-size: 1.4rem; font-weight: 800;
  letter-spacing: -0.02em; margin: 0 0 6px;
}
.plans-sub { font-size: 0.92rem; margin: 0; max-width: 560px; }

.plans-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  padding-top: 16px; /* espaço pro ribbon */
}
.plan-card {
  position: relative;
  display: flex; flex-direction: column;
  padding: 26px 22px;
  border-radius: var(--radius);
  background: var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  transition: transform 0.25s ease, border-color 0.25s ease, box-shadow 0.25s ease;
}
.plan-card:hover { transform: translateY(-4px); border-color: var(--brand); }
.plan-card.featured {
  background:
    radial-gradient(ellipse 300px 200px at 50% 0%, rgba(59, 130, 246, 0.22), transparent 70%),
    linear-gradient(165deg, rgba(59, 130, 246, 0.14), rgba(29, 78, 216, 0.14));
  border-color: rgba(59, 130, 246, 0.5);
  box-shadow: var(--shadow), 0 0 50px rgba(59, 130, 246, 0.2);
  transform: translateY(-10px);
}
.plan-card.featured::before {
  content: '';
  position: absolute; inset: -1px;
  border-radius: var(--radius);
  padding: 1px;
  background: linear-gradient(135deg, rgba(59, 130, 246, 0.6), transparent 50%, rgba(59, 130, 246, 0.3));
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
.plan-card.featured:hover { transform: translateY(-14px); }
.plan-card.selected { border-color: var(--brand); box-shadow: 0 0 24px var(--brand-soft); }
.plan-card.cant { opacity: 0.6; }

.plan-ribbon {
  position: absolute; top: -14px; left: 50%; transform: translateX(-50%);
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 14px;
  border-radius: 999px;
  background: linear-gradient(120deg, var(--brand), var(--brand-strong));
  color: #fff;
  font-size: 0.74rem; font-weight: 700;
  letter-spacing: 0.04em;
  box-shadow: 0 10px 24px var(--brand-glow);
  white-space: nowrap;
}
.plan-ribbon :deep(svg) { width: 13px; height: 13px; }

.plan-current {
  position: absolute; top: 14px; right: 14px;
  display: inline-flex; align-items: center; gap: 4px;
  padding: 4px 10px 4px 8px;
  border-radius: 999px;
  background: var(--success-soft);
  color: var(--success);
  font-size: 0.68rem; font-weight: 700;
  letter-spacing: 0.04em;
  border: 1px solid rgba(74, 222, 128, 0.3);
}
.plan-current :deep(svg) { width: 11px; height: 11px; stroke-width: 3; }

.plan-head { margin-bottom: 16px; }
.plan-name { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 6px; }
.plan-tagline { font-size: 0.84rem; color: var(--muted); line-height: 1.45; margin: 0; min-height: 2.4em; }

.plan-price { display: flex; align-items: baseline; gap: 4px; margin: 2px 0; }
.plan-price-amount { font-size: 2.1rem; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
.plan-price small { font-size: 0.9rem; color: var(--muted); }
.plan-fee { font-size: 0.76rem; margin: 6px 0 0; }

.plan-sep { height: 1px; background: var(--border); margin: 18px 0; }

.plan-list {
  list-style: none; padding: 0; margin: 0 0 20px;
  flex: 1; display: grid; gap: 8px;
  font-size: 0.88rem;
}
.plan-list li { display: flex; gap: 10px; align-items: flex-start; }
.plan-check {
  flex-shrink: 0;
  width: 18px; height: 18px; border-radius: 999px;
  display: grid; place-items: center;
  background: var(--brand-soft);
  color: var(--brand-ink);
  margin-top: 1px;
}
.plan-check :deep(svg) { width: 11px; height: 11px; stroke-width: 3; }

.plan-insuf { display: block; margin-top: 8px; font-size: 0.78rem; }

/* =====================================================================
   Histórico de pagamentos
   ===================================================================== */
.history-card {
  margin-top: 24px;
  padding: 20px;
  border-radius: var(--radius);
  background: var(--surface);
  border: 1px solid var(--border);
}
.history-head {
  display: flex; align-items: center; gap: 12px;
  margin-bottom: 14px;
}
.history-head strong { display: block; font-size: 1rem; }
.history-head small { display: block; color: var(--muted); font-size: 0.84rem; }

.history-list { display: flex; flex-direction: column; }
.history-row {
  display: grid;
  grid-template-columns: 1.4fr 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 12px 2px;
  border-top: 1px solid var(--border);
}
.history-row:first-child { border-top: none; }
.history-date strong { display: block; font-size: 0.9rem; font-weight: 600; }
.history-date small { display: block; font-size: 0.76rem; }
.history-amount { font-size: 1rem; font-weight: 700; letter-spacing: -0.01em; }

/* =====================================================================
   Responsive
   ===================================================================== */
@media (max-width: 900px) {
  .plans-grid { grid-template-columns: 1fr; gap: 20px; }
  .plan-card.featured { transform: none; }
  .plan-card.featured:hover { transform: translateY(-4px); }
}

@media (max-width: 640px) {
  .sub-card { padding: 20px; }
  .sub-card-head { flex-direction: column; }
  .sub-head-right { text-align: left; }
  .sub-price { justify-content: flex-start; }
  .pmc-row { flex-direction: column; align-items: stretch; }
  .pmc-row .btn { align-self: flex-start; }
  .history-row {
    grid-template-columns: 1fr auto;
    gap: 8px 12px;
  }
  .history-amount { grid-column: 1 / 2; grid-row: 2; font-size: 0.9rem; color: var(--muted); font-weight: 500; }
  .history-row .badge { grid-column: 2; grid-row: 1 / 3; align-self: center; }
  .invoice-row { flex-wrap: wrap; }
  .invoice-row .btn { width: 100%; }
}
</style>
