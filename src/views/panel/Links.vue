<script setup>
import { ref, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { LINK_ICONS } from '@/config/brand'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const links = ref([])
const error = ref('')
const form = ref({ icon: 'instagram', label: 'Instagram', url: '' })

const PLACEHOLDERS = {
  whatsapp: '(11) 99999-9999', instagram: 'instagram.com/seunegocio', facebook: 'facebook.com/seunegocio',
  tiktok: 'tiktok.com/@seunegocio', youtube: 'youtube.com/@seunegocio', globe: 'www.seusite.com.br',
  map: 'Link do Google Maps', mail: 'contato@seunegocio.com.br', phone: '(11) 3333-3333', link: 'https://...',
}

async function load() {
  links.value = unwrap(await supabase.from('business_links').select('*')
    .eq('business_id', biz.business.id).order('sort_order').order('label'))
}
onMounted(() => { if (biz.hasFeature('links')) load() })

function pickIcon(icon) {
  if (!form.value.label || Object.values(LINK_ICONS).includes(form.value.label)) form.value.label = LINK_ICONS[icon]
  form.value.icon = icon
}

async function add() {
  error.value = ''
  const sort = links.value.length ? Math.max(...links.value.map((l) => l.sort_order)) + 1 : 0
  const { error: err } = await supabase.from('business_links').insert({ ...form.value, business_id: biz.business.id, sort_order: sort })
  if (err) { error.value = err.message; return }
  form.value = { icon: 'link', label: '', url: '' }
  load()
}

async function remove(l) {
  await supabase.from('business_links').delete().eq('id', l.id)
  load()
}

async function move(index, delta) {
  const list = [...links.value]
  const target = index + delta
  if (target < 0 || target >= list.length) return
  ;[list[index], list[target]] = [list[target], list[index]]
  await Promise.all(list.map((l, i) => supabase.from('business_links').update({ sort_order: i }).eq('id', l.id)))
  load()
}
</script>

<template>
  <div class="page-header"><p class="eyebrow">Extras</p><h1>Links</h1></div>
  <Upsell v-if="!biz.hasFeature('links')" feature="links" />

  <template v-else>
    <p class="muted">Seus links aparecem na sua vitrine: redes sociais, site, localização, etc.</p>
    <div v-if="error" class="error">{{ error }}</div>

    <form class="card" @submit.prevent="add">
      <div class="field">
        <label>Tipo</label>
        <div class="chips">
          <button v-for="(label, icon) in LINK_ICONS" :key="icon" type="button" class="chip icon-chip"
                  :class="{ selected: form.icon === icon }" @click="pickIcon(icon)">
            <Icon :name="icon" />{{ label }}
          </button>
        </div>
      </div>
      <div class="row">
        <div class="field"><label>Texto do botão</label><input v-model="form.label" required maxlength="60" /></div>
        <div class="field" style="flex-basis: 280px"><label>Endereço</label><input v-model="form.url" required :placeholder="PLACEHOLDERS[form.icon]" /></div>
        <div class="field shrink"><button class="btn">Adicionar</button></div>
      </div>
    </form>

    <div class="card">
      <p v-if="!links.length" class="muted" style="margin: 0">Nenhum link ainda.</p>
      <div v-for="(l, i) in links" :key="l.id" class="spread link-row">
        <div class="row" style="align-items: center; flex: 1; min-width: 0">
          <span class="shrink icon-box"><Icon :name="l.icon" /></span>
          <div style="min-width: 0"><strong>{{ l.label }}</strong><br /><small class="url">{{ l.url }}</small></div>
        </div>
        <div class="chips">
          <button class="btn small secondary" :disabled="i === 0" @click="move(i, -1)">↑</button>
          <button class="btn small secondary" :disabled="i === links.length - 1" @click="move(i, 1)">↓</button>
          <button class="btn small danger" @click="remove(l)">Remover</button>
        </div>
      </div>
    </div>
  </template>
</template>

<style scoped>
.icon-chip { display: inline-flex; align-items: center; gap: 6px; }
.icon-chip svg { width: 16px; height: 16px; }
.link-row { padding: 10px 0; border-bottom: 1px solid var(--border); }
.link-row:last-child { border-bottom: none; }
.icon-box { width: 38px; height: 38px; border-radius: 10px; display: grid; place-items: center; background: var(--brand-soft); color: var(--brand-ink); }
.icon-box svg { width: 18px; height: 18px; }
.url { display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 360px; }
</style>
