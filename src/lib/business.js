import { inject, reactive } from 'vue'
import { supabase, unwrap } from './supabase'
import { session } from './session'

const KEY = Symbol('business')

// Contexto do estabelecimento do usuário logado, compartilhado pelas
// páginas do painel via provide/inject.
export function createBusinessContext() {
  const ctx = reactive({
    loading: true,
    business: null,
    subscription: null,
    plan: null,
    get live() {
      return this.business?.status === 'approved' && ['active', 'past_due'].includes(this.subscription?.status)
    },
    hasFeature(feature) {
      return this.plan?.features?.includes(feature) ?? false
    },
    async reload() {
      this.loading = true
      try {
        const members = unwrap(await supabase.from('business_members')
          .select('business_id, role').eq('user_id', session.user.id).limit(1))
        if (!members.length) {
          this.business = this.subscription = this.plan = null
          return
        }
        const id = members[0].business_id
        this.business = unwrap(await supabase.from('businesses').select('*').eq('id', id).single())
        this.subscription = unwrap(await supabase.from('subscriptions')
          .select('*, effective_price, plan:plans(*)').eq('business_id', id).maybeSingle())
        this.plan = this.subscription?.plan ?? null
      } finally {
        this.loading = false
      }
    },
  })
  return ctx
}

export function provideKey() {
  return KEY
}

export function useBusiness() {
  return inject(KEY)
}
