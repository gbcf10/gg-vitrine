import { createClient } from '@supabase/supabase-js'
import { toast } from './toast'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !key) {
  console.error('Configure VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY no arquivo .env')
}

// Funções do banco que gravam algo (as demais funções só consultam).
const SAVING_RPCS = ['choose_plan', 'request_business', 'admin_set_business_status', 'admin_update_subscription', 'admin_register_payment']

// Junta gravações seguidas (ex.: apagar e gravar de novo os horários) num aviso só.
let pending = null
function notifySaved(isDelete) {
  if (!pending) {
    pending = { onlyDeletes: true }
    setTimeout(() => {
      toast(pending.onlyDeletes ? 'Removido com sucesso' : 'Salvo com sucesso')
      pending = null
    }, 300)
  }
  if (!isDelete) pending.onlyDeletes = false
}

// Mostra "Salvo com sucesso" sempre que o painel ou o admin grava algo no banco.
async function fetchWithSavedToast(input, init = {}) {
  const res = await fetch(input, init)
  try {
    const method = (init.method ?? 'GET').toUpperCase()
    const path = new URL(typeof input === 'string' ? input : input.url).pathname
    const inPanel = /^\/(painel|admin)(\/|$)/.test(location.pathname)
    const isRest = path.startsWith('/rest/v1/')
    const isRpc = path.startsWith('/rest/v1/rpc/')
    const saves = isRpc ? SAVING_RPCS.includes(path.split('/').pop()) : isRest && method !== 'GET' && method !== 'HEAD'
    if (res.ok && inPanel && saves) notifySaved(method === 'DELETE')
  } catch { /* aviso é só conveniência */ }
  return res
}

export const supabase = createClient(url ?? 'http://localhost', key ?? 'missing', {
  global: { fetch: fetchWithSavedToast },
})

// Converte o retorno do Supabase em exceção com mensagem legível.
export function unwrap({ data, error }) {
  if (error) throw new Error(error.message)
  return data
}
