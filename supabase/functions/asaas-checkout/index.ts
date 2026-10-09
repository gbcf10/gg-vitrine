// @ts-nocheck -- roda em Deno (Supabase Edge Function), não no TS do VSCode
// GG Vitrine — Edge Function "asaas-checkout"
//
// Chamada pelo painel (usuário logado). Ações:
//   checkout   → cria cliente + assinatura no Asaas e devolve o link da fatura em aberto.
//                Com a assinatura ativa, só troca a forma de pagamento.
//   cancel     → cancela a assinatura (a vitrine fica no ar até o fim do período pago)
//   sync-price → (admin) atualiza no Asaas o valor da mensalidade depois de mudar plano/desconto
//
// Segredos (Supabase > Edge Functions > Secrets):
//   ASAAS_API_KEY   chave da API do Asaas (sandbox ou produção)
//   ASAAS_ENV       "sandbox" (padrão) ou "production"
import { createClient } from 'jsr:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

// .trim(): ignora espaço ou quebra de linha colados junto com o segredo.
const ASAAS_KEY = Deno.env.get('ASAAS_API_KEY')?.trim()
const ASAAS_URL = Deno.env.get('ASAAS_ENV')?.trim().toLowerCase() === 'production'
  ? 'https://api.asaas.com/v3'
  : 'https://api-sandbox.asaas.com/v3'

async function asaas(path: string, method = 'GET', body?: unknown) {
  const res = await fetch(ASAAS_URL + path, {
    method,
    headers: { access_token: ASAAS_KEY!, 'Content-Type': 'application/json', 'User-Agent': 'GGVitrine' },
    body: body ? JSON.stringify(body) : undefined,
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data?.errors?.[0]?.description ?? `O Asaas respondeu com erro ${res.status}.`)
  return data
}

const todayBR = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
const digits = (v: unknown) => String(v ?? '').replace(/\D/g, '')
const BILLING_TYPE: Record<string, string> = { cartao: 'CREDIT_CARD', pix: 'PIX', boleto: 'BOLETO' }

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Sua sessão expirou. Entre novamente.' }, 401)

    const { action = 'checkout', document, name, method, owner_id: argOwner } = await req.json()
    const { data: isAdmin } = await userClient.rpc('is_platform_admin')
    // Admin pode sincronizar preço de qualquer dono; o próprio usuário mexe só na dele.
    const ownerId = action === 'sync-price' && isAdmin ? argOwner : user.id
    if (!ownerId) return json({ error: 'Sem permissão.' }, 403)

    // Forma de pagamento escolhida (define a taxa repassada na mensalidade).
    if (action === 'checkout') {
      if (!BILLING_TYPE[method]) return json({ error: 'Escolha cartão, PIX ou boleto.' }, 400)
      await admin.from('subscriptions').update({ billing_method: method }).eq('owner_id', ownerId)
    }

    // Carrega assinatura do dono + primeira vitrine (pra montar o nome na descrição).
    const { data: sub } = await admin.from('subscriptions')
      .select('*, effective_price, charge_value, plan:plans(name)')
      .eq('owner_id', ownerId).maybeSingle()
    if (!sub) return json({ error: 'Escolha um plano primeiro.' }, 400)
    const { data: biz } = await admin.from('businesses')
      .select('name, phone').eq('created_by', ownerId).order('created_at').limit(1).maybeSingle()
    const value = Number(sub.charge_value)                    // plano + taxa do meio de pagamento
    const billingType = BILLING_TYPE[sub.billing_method ?? 'pix']

    // ---- Cancelar ----
    if (action === 'cancel') {
      if (sub.gateway_subscription_id && ASAAS_KEY) {
        await asaas(`/subscriptions/${sub.gateway_subscription_id}`, 'DELETE')
      }
      await admin.from('subscriptions').update({ status: 'canceled' }).eq('id', sub.id)
      return json({ ok: true, until: sub.current_period_end })
    }

    if (!ASAAS_KEY) return json({ error: 'O pagamento online ainda não está disponível. Fale com o suporte.' }, 503)

    // ---- Atualizar valor (admin) ----
    if (action === 'sync-price') {
      if (!sub.gateway_subscription_id || sub.status === 'canceled') return json({ ok: true, skipped: true })
      await asaas(`/subscriptions/${sub.gateway_subscription_id}`, 'POST', {
        value, updatePendingPayments: true,
      })
      return json({ ok: true })
    }

    // ---- Checkout ----
    // Assinatura em dia: só troca a forma de pagamento (vale a partir da próxima fatura).
    if (sub.status === 'active') {
      if (sub.gateway_subscription_id) {
        await asaas(`/subscriptions/${sub.gateway_subscription_id}`, 'POST', { billingType, value, updatePendingPayments: true })
      }
      return json({ ok: true, updated: true })
    }

    let customerId = sub.gateway_customer_id
    const doc = digits(document) || sub.billing_document || ''
    if (!customerId) {
      if (doc.length !== 11 && doc.length !== 14) return json({ error: 'Informe um CPF (11 dígitos) ou CNPJ (14 dígitos) válido.' }, 400)
      const customer = await asaas('/customers', 'POST', {
        name: String(name || biz?.name || 'Cliente').slice(0, 100),
        cpfCnpj: doc,
        email: user.email,
        mobilePhone: digits(biz?.phone) || undefined,
        externalReference: ownerId,
      })
      customerId = customer.id
    }

    let subId = sub.status === 'canceled' ? null : sub.gateway_subscription_id
    if (subId) {
      await asaas(`/subscriptions/${subId}`, 'POST', { billingType, value, updatePendingPayments: true })
    } else {
      const created = await asaas('/subscriptions', 'POST', {
        customer: customerId,
        billingType,
        value,
        nextDueDate: todayBR(),
        cycle: 'MONTHLY',
        description: `GG Vitrine: plano ${sub.plan.name}`,
        externalReference: sub.id,
      })
      subId = created.id
    }

    await admin.from('subscriptions').update({
      gateway: 'asaas', gateway_customer_id: customerId, gateway_subscription_id: subId,
      billing_document: doc || sub.billing_document,
      status: sub.status === 'canceled' ? 'pending_payment' : sub.status,
    }).eq('id', sub.id)

    const list = await asaas(`/subscriptions/${subId}/payments`)
    const open = (list.data ?? [])
      .filter((p: { status: string }) => ['PENDING', 'OVERDUE'].includes(p.status))
      .sort((a: { dueDate: string }, b: { dueDate: string }) => a.dueDate.localeCompare(b.dueDate))[0]
    if (!open) return json({ error: 'Não há fatura em aberto. Tente de novo em alguns segundos.' }, 409)

    // Registra a fatura no painel mesmo antes do aviso do Asaas chegar.
    await admin.rpc('billing_webhook', { p_event: 'PAYMENT_CREATED', p: open })
    return json({ invoiceUrl: open.invoiceUrl })
  } catch (e) {
    console.error(e)
    return json({ error: e instanceof Error ? e.message : 'Erro inesperado.' }, 500)
  }
})
