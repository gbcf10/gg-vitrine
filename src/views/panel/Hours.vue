<script setup>
import { ref, onMounted, watch } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { WEEKDAYS } from '@/lib/format'

const biz = useBusiness()
const professionals = ref([])
const selected = ref(null)
const days = ref([])   // [{ weekday, open, intervals: [{ start, end }] }]
const error = ref('')
const saved = ref(false)

function blankWeek() {
  return WEEKDAYS.map((_, weekday) => ({ weekday, open: false, intervals: [{ start: '09:00', end: '18:00' }] }))
}

async function loadProfessionals() {
  professionals.value = unwrap(await supabase.from('professionals').select('id, name')
    .eq('business_id', biz.business.id).eq('active', true).order('name'))
  selected.value = professionals.value[0]?.id ?? null
}

async function loadHours() {
  saved.value = false
  if (!selected.value) return
  const rows = unwrap(await supabase.from('working_hours').select('*')
    .eq('professional_id', selected.value).order('start_time'))
  const week = blankWeek()
  for (const day of week) {
    const mine = rows.filter((r) => r.weekday === day.weekday)
    if (mine.length) {
      day.open = true
      day.intervals = mine.map((r) => ({ start: r.start_time.slice(0, 5), end: r.end_time.slice(0, 5) }))
    }
  }
  days.value = week
}

onMounted(loadProfessionals)
watch(selected, loadHours)

async function save() {
  error.value = ''
  const rows = days.value.filter((d) => d.open).flatMap((d) =>
    d.intervals.map((i) => ({
      business_id: biz.business.id, professional_id: selected.value,
      weekday: d.weekday, start_time: i.start, end_time: i.end,
    })))
  if (rows.some((r) => r.end_time <= r.start_time)) {
    error.value = 'O horário final precisa ser depois do inicial.'
    return
  }
  try {
    unwrap(await supabase.from('working_hours').delete().eq('professional_id', selected.value))
    if (rows.length) unwrap(await supabase.from('working_hours').insert(rows))
    saved.value = true
  } catch (e) {
    error.value = e.message
  }
}

function copyToAll(day) {
  for (const d of days.value) {
    if (d !== day && d.open) d.intervals = day.intervals.map((i) => ({ ...i }))
  }
}
</script>

<template>
  <div class="page-header"><h1>Horários de atendimento</h1></div>
  <p v-if="!professionals.length" class="notice">Cadastre um profissional para configurar os horários.</p>

  <template v-else>
    <div class="field" style="max-width: 320px">
      <label>Profissional</label>
      <select v-model="selected">
        <option v-for="p in professionals" :key="p.id" :value="p.id">{{ p.name }}</option>
      </select>
    </div>

    <div v-if="error" class="error">{{ error }}</div>
    <div v-if="saved" class="success">Horários salvos.</div>

    <div class="card">
      <div v-for="day in days" :key="day.weekday" class="row" style="padding: 10px 0; border-bottom: 1px solid var(--border)">
        <label class="shrink" style="width: 120px"><input v-model="day.open" type="checkbox" /> {{ WEEKDAYS[day.weekday] }}</label>
        <div v-if="day.open" style="flex: 1 1 300px">
          <div v-for="(interval, i) in day.intervals" :key="i" class="row" style="margin-bottom: 6px">
            <input v-model="interval.start" type="time" />
            <span class="shrink">até</span>
            <input v-model="interval.end" type="time" />
            <button v-if="day.intervals.length > 1" type="button" class="btn small secondary shrink"
                    @click="day.intervals.splice(i, 1)">Remover</button>
          </div>
          <button type="button" class="link-btn" @click="day.intervals.push({ start: '14:00', end: '18:00' })">
            + intervalo (ex.: depois do almoço)
          </button>
          &nbsp;·&nbsp;
          <button type="button" class="link-btn" @click="copyToAll(day)">copiar para os outros dias abertos</button>
        </div>
        <span v-else class="muted">Fechado</span>
      </div>
      <button class="btn" style="margin-top: 16px" @click="save">Salvar horários</button>
    </div>
  </template>
</template>
