<script setup>
import { ref, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const photos = ref([])
const error = ref('')
const uploading = ref(0)
const MAX = 40

async function load() {
  photos.value = unwrap(await supabase.from('gallery_photos').select('*')
    .eq('business_id', biz.business.id).order('sort_order').order('created_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('galeria')) load() })

async function upload(event) {
  error.value = ''
  const files = [...event.target.files].slice(0, MAX - photos.value.length)
  for (const file of files) {
    if (file.size > 5 * 1024 * 1024) { error.value = `"${file.name}" tem mais de 5 MB e foi ignorada.`; continue }
    uploading.value++
    const path = `${biz.business.id}/gallery/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${file.name.split('.').pop().toLowerCase()}`
    const { error: err } = await supabase.storage.from('logos').upload(path, file)
    if (!err) {
      const url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
      await supabase.from('gallery_photos').insert({ business_id: biz.business.id, url })
    } else {
      error.value = err.message
    }
    uploading.value--
  }
  event.target.value = ''
  load()
}

async function saveCaption(p, caption) {
  await supabase.from('gallery_photos').update({ caption: caption || null }).eq('id', p.id)
}

async function remove(p) {
  if (!confirm('Remover esta foto?')) return
  await supabase.from('gallery_photos').delete().eq('id', p.id)
  load()
}
</script>

<template>
  <div class="page-header"><p class="eyebrow">Extras</p><h1>Galeria</h1></div>
  <Upsell v-if="!biz.hasFeature('galeria')" feature="galeria" />

  <template v-else>
    <p class="muted">Mostre seu trabalho: ambiente, produtos, antes e depois. Até {{ MAX }} fotos.</p>
    <div v-if="error" class="error">{{ error }}</div>

    <div class="card">
      <label class="btn" style="display: inline-flex; width: auto">
        {{ uploading ? `Enviando ${uploading === 1 ? '1 foto' : `${uploading} fotos`}...` : 'Adicionar fotos' }}
        <input type="file" accept="image/png,image/jpeg,image/webp" multiple style="display: none" :disabled="photos.length >= MAX" @change="upload" />
      </label>
      <small style="margin-left: 10px">{{ photos.length }}/{{ MAX }}</small>
    </div>

    <div class="grid" style="grid-template-columns: repeat(auto-fill, minmax(180px, 1fr))">
      <div v-for="p in photos" :key="p.id" class="card photo">
        <img :src="p.url" alt="" />
        <input :value="p.caption" placeholder="Legenda (opcional)" maxlength="120" @change="saveCaption(p, $event.target.value)" />
        <button class="btn small danger block" @click="remove(p)">Remover</button>
      </div>
    </div>
  </template>
</template>

<style scoped>
.photo { padding: 10px; display: grid; gap: 8px; margin: 0; }
.card + .card.photo { margin-top: 0; }
.photo img { width: 100%; aspect-ratio: 1; object-fit: cover; border-radius: 10px; }
.photo input { padding: 7px 10px; font-size: 0.85rem; }
</style>
