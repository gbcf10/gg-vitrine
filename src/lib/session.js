import { reactive } from 'vue'
import { supabase } from './supabase'

// Estado de login compartilhado por todo o app.
export const session = reactive({
  user: null,
  ready: false,
})

let readyPromise
export function initSession() {
  readyPromise ??= supabase.auth.getSession().then(({ data }) => {
    session.user = data.session?.user ?? null
    session.ready = true
    supabase.auth.onAuthStateChange((_event, s) => {
      session.user = s?.user ?? null
    })
  })
  return readyPromise
}

export async function isPlatformAdmin() {
  if (!session.user) return false
  const { data } = await supabase.rpc('is_platform_admin')
  return data === true
}

export async function signOut() {
  await supabase.auth.signOut()
}
