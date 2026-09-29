<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime, formatDate, zonedToUtc } from '@/lib/format'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const quotes = ref([])
const filter = ref('abertos')
const error = ref('')

const STATUS = {
  novo: { label: 'Novo', badge: 'yellow' },
  respondido: { label: 'Respondido', badge: 'blue' },
  fechado: { label: 'Fechado (virou serviço)', badge: 'green' },
  perdido: { label: 'Não fechou', badge: 'red' },
}

const visible = computed(() => quotes.value.filter((q) =>
  filter.value === 'todos' || (filter.value === 'abertos' ? ['novo', 'respondido'].includes(q.status) : q.status === filter.value)))
const stats = computed(() => {
  const total = quotes.value.length
  const closed = quotes.value.filter((q) => q.status === 'fechado').length
  return { total, closed, rate: total ? Math.round((closed / total) * 100) : 0 }
})

async function load() {
  try {
    quotes.value = unwrap(await supabase.from('quote_requests').select('*')
      .eq('business_id', biz.business.id).order('created_at', { ascending: false }).limit(300))
  } catch (e) {
    error.value = e.message
  }
}
onMounted(load)

async function update(q, patch) {
  const { error: err } = await supabase.from('quote_requests').update(patch).eq('id', q.id)
  if (err) error.value = err.message
  load()
}

function reply(q) {
  return waLink(q.phone, `Olá ${q.name}! Aqui é ${biz.business.name}, sobre o seu pedido de orçamento:\n\n"${q.description}"\n\n`)
}
</script>

<template>
  <div class="page-header spread">
    <div>
      <p class="eyebrow">Orçamentos</p>
      <h1>Pedidos de orçamento</h1>
    </div>
    <div class="card stat" style="padding: 12px 18px">
      <div class="label">Taxa de fechamento</div>
      <div class="value" style="font-size: 1.4rem">{{ stats.rate }}% <small>({{ stats.closed }}/{{ stats.total }})</small></div>
    </div>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <div class="chips" style="margin-bottom: 16px">
    <button class="chip" :class="{ selected: filter === 'abertos' }" @click="filter = 'abertos'">Em aberto</button>
    <button v-for="(s, key) in STATUS" :key="key" class="chip" :class="{ selected: filter === key }" @click="filter = key">{{ s.label }}</button>
    <button class="chip" :class="{ selected: filter === 'todos' }" @click="filter = 'todos'">Todos</button>
  </div>

  <p v-if="!visible.length" class="card muted" style="text-align: center">Nenhum pedido aqui. Os pedidos feitos pelo seu link aparecem nesta tela.</p>

  <div v-for="q in visible" :key="q.id" class="card">
    <div class="spread">
      <h3 style="margin: 0">{{ q.name }}</h3>
      <select :value="q.status" style="max-width: 230px" @change="update(q, { status: $event.target.value })">
        <option v-for="(s, key) in STATUS" :key="key" :value="key">{{ s.label }}</option>
      </select>
    </div>
    <small>
      {{ formatDateTime(q.created_at, tz) }} · {{ q.phone }}
      <template v-if="q.district"> · {{ q.district }}</template>
      <template v-if="q.preferred_date"> · para {{ formatDate(zonedToUtc(q.preferred_date, '12:00', tz), tz) }}</template>
    </small>
    <p style="white-space: pre-line; margin: 12px 0">{{ q.description }}</p>
    <div class="row">
      <input :value="q.internal_notes" placeholder="Anotações internas (valor passado, visita marcada...)"
             @change="update(q, { internal_notes: $event.target.value })" />
      <a class="btn shrink" :href="reply(q)" target="_blank" rel="noopener" @click="q.status === 'novo' && update(q, { status: 'respondido' })">
        <Icon name="whatsapp" style="width: 16px; height: 16px" />Responder
      </a>
    </div>
  </div>
</template>
