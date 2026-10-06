// MarqueAí — Edge Function "asaas-webhook"
//
// Recebe os avisos do Asaas (pagamento criado, confirmado, recebido, vencido...)
// e atualiza assinatura, faturas e bloqueio no banco.
//
// Publicar com "Verify JWT" DESLIGADO (o Asaas não envia login do Supabase).
// A segurança vem do token abaixo, configurado igual no Asaas e aqui.
//
// Segredos (Supabase > Edge Functions > Secrets):
//   ASAAS_WEBHOOK_TOKEN   o mesmo "Token de autenticação" cadastrado no webhook do Asaas
//   ASAAS_API_KEY         para corrigir o valor de faturas (ex.: fim de desconto)
//   ASAAS_ENV             "sandbox" (padrão) ou "production"
import { createClient } from 'jsr:@supabase/supabase-js@2'

// .trim(): ignora espaço ou quebra de linha colados junto com o segredo.
const ASAAS_KEY = Deno.env.get('ASAAS_API_KEY')?.trim()
const ASAAS_URL = Deno.env.get('ASAAS_ENV')?.trim().toLowerCase() === 'production'
  ? 'https://api.asaas.com/v3'
  : 'https://api-sandbox.asaas.com/v3'

async function asaas(path: string, method: string, body: unknown) {
  const res = await fetch(ASAAS_URL + path, {
    method,
    headers: { access_token: ASAAS_KEY!, 'Content-Type': 'application/json', 'User-Agent': 'MarqueAi' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Asaas ${res.status}: ${await res.text()}`)
}

Deno.serve(async (req) => {
  const token = Deno.env.get('ASAAS_WEBHOOK_TOKEN')?.trim()
  if (!token || req.headers.get('asaas-access-token')?.trim() !== token) {
    return new Response('não autorizado', { status: 401 })
  }

  const evt = await req.json().catch(() => null)
  // Eventos que não são de pagamento: só confirma o recebimento.
  if (!evt?.payment) return new Response('ok')

  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { data, error } = await admin.rpc('billing_webhook', { p_event: evt.event, p: evt.payment })
  if (error) {
    console.error('billing_webhook', error)
    return new Response('erro', { status: 500 })   // o Asaas tenta de novo depois
  }

  // Fatura nova com valor diferente do contratado: corrige a fatura e a assinatura.
  if (data?.adjust_value && ASAAS_KEY && evt.payment.status === 'PENDING') {
    try {
      await asaas(`/payments/${evt.payment.id}`, 'POST', {
        value: data.adjust_value, dueDate: evt.payment.dueDate, billingType: evt.payment.billingType,
      })
      if (evt.payment.subscription) {
        await asaas(`/subscriptions/${evt.payment.subscription}`, 'POST', { value: data.adjust_value })
      }
    } catch (e) {
      console.error('ajuste de valor', e)
    }
  }
  return new Response('ok')
})
