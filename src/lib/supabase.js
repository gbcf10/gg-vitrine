import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !key) {
  console.error('Configure VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY no arquivo .env')
}

export const supabase = createClient(url ?? 'http://localhost', key ?? 'missing')

// Converte o retorno do Supabase em exceção com mensagem legível.
export function unwrap({ data, error }) {
  if (error) throw new Error(error.message)
  return data
}
