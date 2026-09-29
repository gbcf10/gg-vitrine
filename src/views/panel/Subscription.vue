<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, SUBSCRIPTION_STATUS } from '@/lib/format'
import { FEATURE_LABELS, SUPPORT_WHATSAPP } from '@/config/brand'

const biz = useBusiness()
const plans = ref([])
const payments = ref([])
const error = ref('')
const sub = computed(() => biz.subscription)
const canChoose = computed(() => !sub.value || ['pending_payment', 'canceled'].includes(sub.value.status))
const hasDiscount = computed(() => sub.value && Number(sub.value.effective_price) !== Number(sub.value.plan.base_price))

onMounted(async () => {
  plans.value = unwrap(await supabase.from('plans').select('*').eq('kind', biz.business.kind).order('sort_order'))
  if (sub.value) {
    payments.value = unwrap(await supabase.from('payments').select('*')
      .eq('business_id', biz.business.id).order('created_at', { ascending: false }).limit(12))
  }
})

async function choose(plan) {
  error.value = ''
  const { error: err } = await supabase.rpc('choose_plan', { p_business: biz.business.id, p_plan: plan.id })
  if (err) error.value = err.message
  else biz.reload()
}

const whatsappLink = computed(() => SUPPORT_WHATSAPP &&
  `https://wa.me/${SUPPORT_WHATSAPP}?text=${encodeURIComponent(`Olá! Quero pagar a assinatura do ${biz.business.name} (${biz.business.slug}).`)}`)
</script>

<template>
  <div class="page-header"><h1>Assinatura</h1></div>
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

    <div v-if="sub.status === 'pending_payment'" class="notice" style="margin-top: 16px">
      <strong>Falta pouco!</strong> Assim que o pagamento for confirmado, seu painel é liberado.
      <p style="margin: 8px 0 0">
        O pagamento online (PIX, boleto e cartão) chega em breve. Por enquanto, fale com a gente para pagar via PIX.
      </p>
      <a v-if="whatsappLink" :href="whatsappLink" target="_blank" class="btn" style="margin-top: 10px">Pagar pelo WhatsApp</a>
    </div>
  </div>

  <template v-if="canChoose">
    <h3 style="margin-top: 24px">{{ sub ? 'Trocar plano' : 'Escolha seu plano' }}</h3>
    <div class="grid">
      <div v-for="plan in plans" :key="plan.id" class="card" style="margin: 0">
        <h3>{{ plan.name }}</h3>
        <p style="font-size: 1.5rem; font-weight: 700">{{ money(plan.base_price) }}<span class="muted" style="font-size: 1rem">/mês</span></p>
        <ul style="padding-left: 18px; font-size: 0.9rem">
          <template v-if="plan.kind === 'agenda'">
            <li>{{ plan.max_professionals ? `Até ${plan.max_professionals} profissional(is)` : 'Profissionais ilimitados' }}</li>
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
          <td>{{ formatDate(p.paid_at ?? p.created_at) }}</td>
          <td>{{ money(p.amount) }}</td>
          <td>{{ p.status === 'paid' ? 'Pago' : p.status }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
