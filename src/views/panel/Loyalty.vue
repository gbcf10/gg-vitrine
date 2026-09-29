<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDate } from '@/lib/format'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const program = ref({ active: true, stamps_required: 10, reward: biz.business.kind === 'cardapio' ? '1 pedido grátis' : '1 serviço grátis' })
const exists = ref(false)
const cards = ref([])
const search = ref('')
const newCard = ref({ phone: '', name: '' })
const error = ref('')
const msg = ref('')

const digits = (v) => (v ?? '').replace(/\D/g, '')
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return q ? cards.value.filter((c) => c.phone.includes(digits(q) || '§') || (c.name ?? '').toLowerCase().includes(q)) : cards.value
})

async function load() {
  const bid = biz.business.id
  const p = unwrap(await supabase.from('loyalty_programs').select('*').eq('business_id', bid).maybeSingle())
  if (p) { program.value = p; exists.value = true }
  cards.value = unwrap(await supabase.from('loyalty_cards').select('*').eq('business_id', bid).order('updated_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('fidelidade')) load() })

async function saveProgram() {
  error.value = msg.value = ''
  const { active, stamps_required, reward } = program.value
  const { error: err } = await supabase.from('loyalty_programs')
    .upsert({ business_id: biz.business.id, active, stamps_required: Number(stamps_required), reward })
  if (err) { error.value = err.message; return }
  exists.value = true
  msg.value = 'Programa de fidelidade salvo.'
}

async function stamp(c, delta) {
  const stamps = Math.max(c.stamps + delta, 0)
  await supabase.from('loyalty_cards').update({ stamps, updated_at: new Date().toISOString() }).eq('id', c.id)
  load()
}

async function redeem(c) {
  if (!confirm(`Resgatar "${program.value.reward}" para ${c.name || c.phone}?`)) return
  await supabase.from('loyalty_cards').update({
    stamps: c.stamps - program.value.stamps_required, rewards_redeemed: c.rewards_redeemed + 1, updated_at: new Date().toISOString(),
  }).eq('id', c.id)
  load()
}

async function addCard() {
  error.value = ''
  const phone = digits(newCard.value.phone)
  const existing = cards.value.find((c) => c.phone === phone)
  if (existing) { await stamp(existing, 1); newCard.value = { phone: '', name: '' }; return }
  const { error: err } = await supabase.from('loyalty_cards')
    .insert({ business_id: biz.business.id, phone, name: newCard.value.name || null, stamps: 1 })
  if (err) { error.value = err.message.includes('phone') ? 'Telefone inválido.' : err.message; return }
  newCard.value = { phone: '', name: '' }
  load()
}
</script>

<template>
  <div class="page-header"><p class="eyebrow">Extras</p><h1>Cartão fidelidade</h1></div>
  <Upsell v-if="!biz.hasFeature('fidelidade')" feature="fidelidade" />

  <template v-else>
    <div v-if="error" class="error">{{ error }}</div>
    <div v-if="msg" class="success">{{ msg }}</div>

    <form class="card" @submit.prevent="saveProgram">
      <h3>Como funciona</h3>
      <p class="muted" style="font-size: 0.9rem">
        {{ biz.business.kind === 'cardapio' ? 'Cada pedido marcado como "entregue"' : 'Cada atendimento marcado como "concluído"' }}
        dá 1 carimbo automaticamente para o telefone do cliente. Você também pode carimbar na mão.
      </p>
      <div class="row">
        <div class="field" style="max-width: 200px"><label>Carimbos para ganhar</label><input v-model="program.stamps_required" type="number" min="2" max="50" required /></div>
        <div class="field"><label>Prêmio</label><input v-model="program.reward" required maxlength="100" /></div>
      </div>
      <div class="spread">
        <label><input v-model="program.active" type="checkbox" /> Programa ativo (aparece na sua vitrine)</label>
        <button class="btn">{{ exists ? 'Salvar' : 'Ativar fidelidade' }}</button>
      </div>
    </form>

    <template v-if="exists">
      <form class="card" @submit.prevent="addCard">
        <h3>Carimbar</h3>
        <div class="row">
          <div class="field"><label>WhatsApp do cliente</label><input v-model="newCard.phone" type="tel" required /></div>
          <div class="field"><label>Nome <small>(opcional)</small></label><input v-model="newCard.name" /></div>
          <div class="field shrink"><button class="btn">+1 carimbo</button></div>
        </div>
      </form>

      <div class="card table-wrap">
        <input v-model="search" placeholder="Buscar por nome ou telefone" style="margin-bottom: 12px" />
        <p v-if="!filtered.length" class="muted">Nenhum cartão ainda.</p>
        <table v-else>
          <thead><tr><th>Cliente</th><th>Carimbos</th><th>Prêmios</th><th></th></tr></thead>
          <tbody>
            <tr v-for="c in filtered" :key="c.id">
              <td>{{ c.name || '—' }}<br /><small>{{ c.phone }} · {{ formatDate(c.updated_at, biz.business.timezone) }}</small></td>
              <td>
                <strong :style="{ color: c.stamps >= program.stamps_required ? 'var(--success)' : '' }">{{ c.stamps }}</strong> / {{ program.stamps_required }}
              </td>
              <td>{{ c.rewards_redeemed }}</td>
              <td style="text-align: right; white-space: nowrap">
                <button class="btn small secondary" @click="stamp(c, -1)">−1</button>
                <button class="btn small secondary" @click="stamp(c, 1)">+1</button>
                <button class="btn small" :disabled="c.stamps < program.stamps_required" @click="redeem(c)">Resgatar</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </template>
</template>
