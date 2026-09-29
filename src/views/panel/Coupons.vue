<script setup>
import { ref, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, formatDate, zonedToUtc } from '@/lib/format'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const coupons = ref([])
const error = ref('')
const empty = () => ({ code: '', kind: 'percent', value: 10, min_order: 0, valid_until: '', max_uses: '' })
const form = ref(empty())

async function load() {
  coupons.value = unwrap(await supabase.from('coupons').select('*')
    .eq('business_id', biz.business.id).order('created_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('cupons')) load() })

async function add() {
  error.value = ''
  const f = form.value
  const { error: err } = await supabase.from('coupons').insert({
    business_id: biz.business.id, code: f.code.trim().toUpperCase(), kind: f.kind, value: Number(f.value),
    min_order: Number(f.min_order || 0), valid_until: f.valid_until || null, max_uses: f.max_uses ? Number(f.max_uses) : null,
  })
  if (err) {
    error.value = err.message.includes('coupons_code_unique') ? 'Já existe um cupom com esse código.'
      : err.message.includes('code_check') ? 'Use de 3 a 20 letras, números, - ou _.' : err.message
    return
  }
  form.value = empty()
  load()
}

async function toggle(c) {
  await supabase.from('coupons').update({ active: !c.active }).eq('id', c.id)
  load()
}
async function remove(c) {
  if (!confirm(`Excluir o cupom ${c.code}?`)) return
  await supabase.from('coupons').delete().eq('id', c.id)
  load()
}

const describe = (c) => (c.kind === 'percent' ? `${Number(c.value)}% de desconto` : `${money(c.value)} de desconto`)
const expired = (c) => c.valid_until && c.valid_until < new Date().toISOString().slice(0, 10)
</script>

<template>
  <div class="page-header"><p class="eyebrow">Extras</p><h1>Cupons de desconto</h1></div>
  <Upsell v-if="!biz.hasFeature('cupons')" feature="cupons" />

  <template v-else>
    <p class="muted">Crie códigos para divulgar (ex.: no Instagram). O cliente digita o cupom ao finalizar na sua vitrine.</p>
    <div v-if="error" class="error">{{ error }}</div>

    <form class="card" @submit.prevent="add">
      <div class="row">
        <div class="field"><label>Código</label><input v-model="form.code" required placeholder="Ex.: PROMO10" style="text-transform: uppercase" maxlength="20" /></div>
        <div class="field">
          <label>Tipo</label>
          <select v-model="form.kind"><option value="percent">Porcentagem (%)</option><option value="fixed">Valor fixo (R$)</option></select>
        </div>
        <div class="field"><label>{{ form.kind === 'percent' ? 'Desconto (%)' : 'Desconto (R$)' }}</label><input v-model="form.value" type="number" min="0.01" :max="form.kind === 'percent' ? 100 : undefined" step="0.01" required /></div>
      </div>
      <div class="row">
        <div class="field"><label>Valor mínimo (R$)</label><input v-model="form.min_order" type="number" min="0" step="0.01" /></div>
        <div class="field"><label>Válido até <small>(opcional)</small></label><input v-model="form.valid_until" type="date" /></div>
        <div class="field"><label>Limite de usos <small>(opcional)</small></label><input v-model="form.max_uses" type="number" min="1" /></div>
        <div class="field shrink"><button class="btn">Criar cupom</button></div>
      </div>
    </form>

    <div class="card table-wrap">
      <p v-if="!coupons.length" class="muted" style="margin: 0">Nenhum cupom ainda.</p>
      <table v-else>
        <thead><tr><th>Código</th><th>Desconto</th><th>Regras</th><th>Usos</th><th></th></tr></thead>
        <tbody>
          <tr v-for="c in coupons" :key="c.id" :style="{ opacity: c.active && !expired(c) ? 1 : 0.5 }">
            <td><strong>{{ c.code }}</strong> <span v-if="expired(c)" class="badge red">Expirado</span><span v-else-if="!c.active" class="badge">Pausado</span></td>
            <td>{{ describe(c) }}</td>
            <td><small>
              <template v-if="Number(c.min_order)">A partir de {{ money(c.min_order) }}<br /></template>
              <template v-if="c.valid_until">Até {{ formatDate(zonedToUtc(c.valid_until, '12:00', biz.business.timezone), biz.business.timezone) }}</template>
              <template v-if="!Number(c.min_order) && !c.valid_until">Sem restrições</template>
            </small></td>
            <td>{{ c.uses }}{{ c.max_uses ? ` / ${c.max_uses}` : '' }}</td>
            <td style="text-align: right; white-space: nowrap">
              <button class="btn small secondary" @click="toggle(c)">{{ c.active ? 'Pausar' : 'Ativar' }}</button>
              <button class="btn small danger" @click="remove(c)">Excluir</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </template>
</template>
