<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { formatDateTime } from '@/lib/format'
import Stars from '@/components/public/Stars.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const reviews = ref([])
const filter = ref('pending')
const error = ref('')

const STATUS = { pending: 'Aguardando', approved: 'Publicadas', hidden: 'Ocultas' }
const visible = computed(() => reviews.value.filter((r) => r.status === filter.value))
const avg = computed(() => {
  const ok = reviews.value.filter((r) => r.status === 'approved')
  return ok.length ? (ok.reduce((s, r) => s + r.rating, 0) / ok.length).toFixed(1).replace('.', ',') : '–'
})

async function load() {
  reviews.value = unwrap(await supabase.from('reviews').select('*')
    .eq('business_id', biz.business.id).order('created_at', { ascending: false }))
  if (!reviews.value.some((r) => r.status === 'pending') && filter.value === 'pending') filter.value = 'approved'
}
onMounted(() => { if (biz.hasFeature('avaliacoes')) load() })

async function update(r, patch) {
  const { error: err } = await supabase.from('reviews').update(patch).eq('id', r.id)
  if (err) error.value = err.message
  load()
}
async function remove(r) {
  if (!confirm('Excluir esta avaliação?')) return
  await supabase.from('reviews').delete().eq('id', r.id)
  load()
}
</script>

<template>
  <div class="page-header spread">
    <div><p class="eyebrow">Extras</p><h1>Avaliações</h1></div>
    <div v-if="biz.hasFeature('avaliacoes')" class="card stat" style="padding: 12px 18px">
      <div class="label">Nota média</div>
      <div class="value" style="font-size: 1.4rem">{{ avg }} ★</div>
    </div>
  </div>
  <Upsell v-if="!biz.hasFeature('avaliacoes')" feature="avaliacoes" />

  <template v-else>
    <p class="muted">Seus clientes avaliam pela sua vitrine. Nada aparece para o público antes de você aprovar.</p>
    <div v-if="error" class="error">{{ error }}</div>
    <div class="chips" style="margin-bottom: 16px">
      <button v-for="(label, key) in STATUS" :key="key" class="chip" :class="{ selected: filter === key }" @click="filter = key">
        {{ label }} ({{ reviews.filter((r) => r.status === key).length }})
      </button>
    </div>

    <p v-if="!visible.length" class="card muted" style="text-align: center">Nenhuma avaliação aqui.</p>
    <div v-for="r in visible" :key="r.id" class="card">
      <div class="spread">
        <strong>{{ r.author_name }}</strong>
        <Stars :value="r.rating" />
      </div>
      <small>{{ formatDateTime(r.created_at, biz.business.timezone) }}</small>
      <p v-if="r.comment" style="margin: 10px 0">{{ r.comment }}</p>
      <div class="field" style="margin: 10px 0">
        <input :value="r.reply" placeholder="Responder publicamente (opcional)" maxlength="500"
               @change="update(r, { reply: $event.target.value || null })" />
      </div>
      <div class="chips">
        <button v-if="r.status !== 'approved'" class="btn small" @click="update(r, { status: 'approved' })">Publicar</button>
        <button v-if="r.status !== 'hidden'" class="btn small secondary" @click="update(r, { status: 'hidden' })">Ocultar</button>
        <button class="btn small danger" @click="remove(r)">Excluir</button>
      </div>
    </div>
  </template>
</template>
