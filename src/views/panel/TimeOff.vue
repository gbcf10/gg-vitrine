<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime, todayISO, addDaysISO, zonedToUtc } from '@/lib/format'

const biz = useBusiness()
const tz = computed(() => biz.business.timezone)
const allowed = computed(() => biz.hasFeature('bloqueios') || biz.hasFeature('folgas'))
const items = ref([])
const professionals = ref([])
const error = ref('')
const emptyForm = () => ({
  kind: 'bloqueio', professional_id: '', reason: '',
  start_date: todayISO(tz.value), start_time: '12:00',
  end_date: todayISO(tz.value), end_time: '13:00', whole_day: false,
})
const form = ref(emptyForm())

async function load() {
  const bid = biz.business.id
  professionals.value = unwrap(await supabase.from('professionals').select('id, name').eq('business_id', bid).eq('active', true).order('name'))
  items.value = unwrap(await supabase.from('time_off').select('*, professional:professionals(name)')
    .eq('business_id', bid).gte('ends_at', new Date().toISOString()).order('starts_at'))
}
onMounted(() => { if (allowed.value) load() })

async function add() {
  error.value = ''
  const f = form.value
  const starts = zonedToUtc(f.start_date, f.whole_day ? '00:00' : f.start_time, tz.value)
  const ends = f.whole_day
    ? zonedToUtc(addDaysISO(f.end_date, 1), '00:00', tz.value)
    : zonedToUtc(f.end_date, f.end_time, tz.value)
  const { error: err } = await supabase.from('time_off').insert({
    business_id: biz.business.id, kind: f.kind, reason: f.reason || null,
    professional_id: f.professional_id || null,
    starts_at: starts.toISOString(), ends_at: ends.toISOString(),
  })
  if (err) { error.value = err.message; return }
  form.value = emptyForm()
  load()
}

async function remove(item) {
  await supabase.from('time_off').delete().eq('id', item.id)
  load()
}
</script>

<template>
  <div class="page-header"><h1>Folgas e bloqueios</h1></div>

  <div v-if="!allowed" class="card">
    <p>Folgas e bloqueios de horário estão disponíveis a partir do plano <strong>Profissional</strong>.</p>
    <RouterLink class="btn" to="/painel/assinatura">Ver planos</RouterLink>
  </div>

  <template v-else>
    <div v-if="error" class="error">{{ error }}</div>
    <form class="card" @submit.prevent="add">
      <div class="row">
        <div class="field">
          <label>Tipo</label>
          <select v-model="form.kind">
            <option value="bloqueio">Bloqueio de horário</option>
            <option value="folga">Folga</option>
          </select>
        </div>
        <div class="field">
          <label>Quem</label>
          <select v-model="form.professional_id">
            <option value="">Todo o estabelecimento</option>
            <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <div class="field"><label>Motivo <small>(opcional)</small></label><input v-model="form.reason" /></div>
      </div>
      <label style="margin-bottom: 12px"><input v-model="form.whole_day" type="checkbox" /> Dia inteiro</label>
      <div class="row">
        <div class="field"><label>De</label><input v-model="form.start_date" type="date" required /></div>
        <div v-if="!form.whole_day" class="field"><label>&nbsp;</label><input v-model="form.start_time" type="time" required /></div>
        <div class="field"><label>Até</label><input v-model="form.end_date" type="date" required /></div>
        <div v-if="!form.whole_day" class="field"><label>&nbsp;</label><input v-model="form.end_time" type="time" required /></div>
        <div class="field shrink"><button class="btn">Adicionar</button></div>
      </div>
    </form>

    <div class="card table-wrap">
      <p v-if="!items.length" class="muted">Nenhuma folga ou bloqueio futuro.</p>
      <table v-else>
        <thead><tr><th>Tipo</th><th>Quem</th><th>De</th><th>Até</th><th>Motivo</th><th></th></tr></thead>
        <tbody>
          <tr v-for="t in items" :key="t.id">
            <td>{{ t.kind === 'folga' ? 'Folga' : 'Bloqueio' }}</td>
            <td>{{ t.professional?.name ?? 'Todos' }}</td>
            <td>{{ formatDateTime(t.starts_at, tz) }}</td>
            <td>{{ formatDateTime(t.ends_at, tz) }}</td>
            <td>{{ t.reason }}</td>
            <td style="text-align: right"><button class="btn small secondary" @click="remove(t)">Remover</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  </template>
</template>
