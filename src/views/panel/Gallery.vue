<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import Icon from '@/components/Icon.vue'
import Upsell from '@/components/Upsell.vue'

const biz = useBusiness()
const photos = ref([])
const error = ref('')
const msg = ref('')
const uploading = ref(0)
const dragover = ref(false)
const fileInput = ref(null)
const MAX = 40

const atLimit = computed(() => photos.value.length >= MAX)
const slotsLeft = computed(() => MAX - photos.value.length)

async function load() {
  photos.value = unwrap(await supabase.from('gallery_photos').select('*')
    .eq('business_id', biz.business.id).order('sort_order').order('created_at', { ascending: false }))
}
onMounted(() => { if (biz.hasFeature('galeria')) load() })

async function uploadFiles(fileList) {
  error.value = ''; msg.value = ''
  const files = [...fileList].slice(0, slotsLeft.value)
  if (!files.length) return
  let ok = 0
  for (const file of files) {
    if (file.size > 5 * 1024 * 1024) { error.value = `"${file.name}" tem mais de 5 MB e foi ignorada.`; continue }
    uploading.value++
    const path = `${biz.business.id}/gallery/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${file.name.split('.').pop().toLowerCase()}`
    const { error: err } = await supabase.storage.from('logos').upload(path, file)
    if (!err) {
      const url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
      await supabase.from('gallery_photos').insert({ business_id: biz.business.id, url })
      ok++
    } else {
      error.value = err.message
    }
    uploading.value--
  }
  if (ok) msg.value = ok === 1 ? '1 foto adicionada.' : `${ok} fotos adicionadas.`
  load()
}

async function onPick(event) {
  await uploadFiles(event.target.files)
  event.target.value = ''
}

async function onDrop(event) {
  event.preventDefault()
  dragover.value = false
  if (atLimit.value) return
  await uploadFiles(event.dataTransfer.files)
}

async function saveCaption(p, caption) {
  await supabase.from('gallery_photos').update({ caption: caption || null }).eq('id', p.id)
  msg.value = 'Legenda salva.'
}

async function remove(p) {
  if (!confirm('Remover esta foto?')) return
  await supabase.from('gallery_photos').delete().eq('id', p.id)
  msg.value = 'Foto removida.'
  load()
}

function openPicker() {
  fileInput.value?.click()
}
</script>

<template>
  <div class="page-header gl-header">
    <div>
      <p class="eyebrow gl-eyebrow">Vitrine</p>
      <h1>Galeria</h1>
      <p class="muted gl-lede">
        Mostre seu trabalho: ambiente, produtos, antes e depois. As fotos aparecem na sua vitrine pública.
      </p>
    </div>
    <span v-if="photos.length" class="gl-count">
      {{ photos.length }} / {{ MAX }} fotos
    </span>
  </div>
  <Upsell v-if="!biz.hasFeature('galeria')" feature="galeria" />

  <template v-else>
    <div v-if="error" class="alert alert-danger">
      <span class="alert-icon"><Icon name="ban" /></span><span>{{ error }}</span>
    </div>
    <div v-if="msg" class="alert alert-success">
      <span class="alert-icon"><Icon name="check" /></span><span>{{ msg }}</span>
    </div>

    <!-- Drop zone -->
    <label class="gl-drop" :class="{ over: dragover, disabled: atLimit, busy: uploading > 0 }"
           @dragover.prevent="dragover = true"
           @dragenter.prevent="dragover = true"
           @dragleave.prevent="dragover = false"
           @drop="onDrop">
      <input ref="fileInput" type="file" accept="image/png,image/jpeg,image/webp" multiple
             :disabled="atLimit" @change="onPick" />
      <div class="gl-drop-icon">
        <Icon :name="uploading > 0 ? 'image' : 'camera'" />
      </div>
      <div class="gl-drop-info">
        <strong v-if="uploading > 0">Enviando {{ uploading === 1 ? '1 foto' : `${uploading} fotos` }}...</strong>
        <strong v-else-if="atLimit">Você atingiu o limite de {{ MAX }} fotos</strong>
        <strong v-else>Arraste fotos aqui ou clique pra escolher</strong>
        <small v-if="!atLimit">PNG, JPG ou WEBP · até 5 MB cada · faltam {{ slotsLeft }} slots</small>
        <small v-else>Remova algumas pra enviar novas.</small>
      </div>
      <button v-if="!atLimit" type="button" class="btn" @click.prevent="openPicker">
        <Icon name="plus" />
        Escolher fotos
      </button>
    </label>

    <!-- Grid -->
    <section class="gl-section">
      <div v-if="!photos.length" class="empty-state">
        <div class="empty-icon-wrap">
          <div class="empty-icon-ring" />
          <div class="empty-icon-core"><Icon name="camera" /></div>
        </div>
        <h3>Sua galeria está vazia</h3>
        <p class="muted">
          Suba 3-5 fotos boas pra começar — ambiente limpo, trabalho finalizado, time sorrindo. Faz muita diferença na decisão do cliente.
        </p>
        <button class="btn" @click="openPicker">
          <Icon name="plus" />
          Enviar primeira foto
        </button>
      </div>

      <div v-else class="gl-grid">
        <article v-for="p in photos" :key="p.id" class="gl-photo">
          <div class="gl-photo-img">
            <img :src="p.url" alt="" loading="lazy" />
            <button class="gl-photo-remove" aria-label="Remover foto" @click="remove(p)">
              <Icon name="trash" />
            </button>
          </div>
          <input class="gl-photo-caption" :value="p.caption" placeholder="Legenda (opcional)"
                 maxlength="120" @change="saveCaption(p, $event.target.value)" />
        </article>
      </div>
    </section>
  </template>
</template>

<style scoped>
/* ===== Header ===== */
.gl-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
.gl-eyebrow { display: inline-block; margin-bottom: 6px; }
.gl-lede { font-size: 0.95rem; max-width: 560px; margin: 4px 0 0; }
.gl-count {
  padding: 6px 14px; border-radius: 999px;
  background: var(--surface); border: 1px solid var(--border);
  color: var(--silver); font-size: 0.82rem; font-weight: 600;
  white-space: nowrap;
}

/* ===== Alertas ===== */
.alert {
  display: flex; align-items: flex-start; gap: 12px;
  padding: 12px 14px; border-radius: var(--radius-sm);
  border: 1px solid; margin-bottom: 16px; line-height: 1.5;
  font-size: 0.92rem;
}
.alert-danger { color: #fecaca; background: var(--danger-soft); border-color: rgba(248, 113, 113, 0.35); }
.alert-success { color: #bbf7d0; background: var(--success-soft); border-color: rgba(74, 222, 128, 0.35); }
.alert-icon { flex-shrink: 0; width: 28px; height: 28px; border-radius: 10px; display: grid; place-items: center; }
.alert-danger .alert-icon { background: rgba(248, 113, 113, 0.2); color: var(--danger); }
.alert-success .alert-icon { background: rgba(74, 222, 128, 0.2); color: var(--success); }
.alert-icon :deep(svg) { width: 15px; height: 15px; stroke-width: 2.4; }

/* ===== Drop zone ===== */
.gl-drop {
  display: flex; align-items: center; gap: 16px;
  padding: 22px;
  margin-bottom: 20px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 2px dashed var(--border);
  cursor: pointer;
  transition: border-color 0.2s ease, background 0.2s ease, box-shadow 0.2s ease;
}
.gl-drop:hover { border-color: var(--brand); box-shadow: 0 0 24px var(--brand-soft); }
.gl-drop.over {
  border-color: var(--brand);
  background:
    radial-gradient(ellipse 500px 300px at 50% 50%, var(--brand-soft), transparent 70%),
    var(--surface);
  box-shadow: 0 0 32px var(--brand-glow);
  transform: scale(1.005);
}
.gl-drop.disabled { opacity: 0.6; cursor: not-allowed; }
.gl-drop.busy { pointer-events: none; }
.gl-drop input[type="file"] { position: absolute; opacity: 0; pointer-events: none; }

.gl-drop-icon {
  width: 56px; height: 56px; flex-shrink: 0;
  border-radius: 16px;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.gl-drop-icon :deep(svg) { width: 24px; height: 24px; }
.gl-drop.busy .gl-drop-icon { animation: dropPulse 1.4s ease-in-out infinite; }
@keyframes dropPulse {
  0%, 100% { transform: scale(1); box-shadow: 0 0 18px var(--brand-glow); }
  50% { transform: scale(1.08); box-shadow: 0 0 32px var(--brand-glow); }
}

.gl-drop-info { flex: 1; min-width: 0; }
.gl-drop-info strong { display: block; font-size: 1rem; font-weight: 700; color: var(--text); }
.gl-drop-info small { display: block; font-size: 0.85rem; color: var(--muted); margin-top: 4px; }

.gl-drop .btn { flex-shrink: 0; }
.gl-drop .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Grid ===== */
.gl-section { margin-top: 4px; }
.gl-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: 12px;
}
.gl-photo {
  display: flex; flex-direction: column; gap: 8px;
  padding: 10px;
  border-radius: var(--radius-sm);
  background: var(--surface);
  border: 1px solid var(--border);
  transition: border-color 0.2s ease, box-shadow 0.2s ease, transform 0.2s ease;
}
.gl-photo:hover {
  border-color: var(--brand);
  box-shadow: 0 0 20px var(--brand-soft);
  transform: translateY(-2px);
}

.gl-photo-img {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
}
.gl-photo-img img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: cover;
  display: block;
  transition: transform 0.3s ease;
}
.gl-photo:hover .gl-photo-img img { transform: scale(1.05); }

.gl-photo-remove {
  position: absolute;
  top: 8px; right: 8px;
  width: 34px; height: 34px;
  border-radius: 10px;
  display: grid; place-items: center;
  background: rgba(5, 11, 22, 0.75);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.2);
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s ease, background 0.15s ease, border-color 0.15s ease, transform 0.15s ease;
  backdrop-filter: blur(6px);
}
.gl-photo:hover .gl-photo-remove,
.gl-photo-remove:focus-visible { opacity: 1; }
.gl-photo-remove:hover {
  background: var(--danger-soft);
  color: var(--danger);
  border-color: var(--danger);
}
.gl-photo-remove :deep(svg) { width: 14px; height: 14px; }

.gl-photo-caption {
  padding: 8px 10px;
  min-height: 36px;
  font-size: 0.85rem;
  background: var(--input);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text);
}
.gl-photo-caption:focus { outline: 2px solid var(--brand); outline-offset: 1px; }

/* ===== Empty state ===== */
.empty-state {
  text-align: center;
  padding: 48px 24px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 400px 200px at 50% 0%, var(--brand-soft), transparent 70%),
    var(--surface);
  border: 1px dashed var(--border);
}
.empty-icon-wrap { position: relative; width: 88px; height: 88px; margin: 0 auto 20px; }
.empty-icon-ring {
  position: absolute; inset: 0; border-radius: 50%;
  background: radial-gradient(circle, var(--brand-glow), transparent 70%);
  animation: ringPulse 2.4s ease-in-out infinite;
}
@keyframes ringPulse {
  0%, 100% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.12); opacity: 0.35; }
}
.empty-icon-core {
  position: absolute; inset: 12px;
  border-radius: 50%; display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 10px 30px var(--brand-glow);
}
.empty-icon-core :deep(svg) { width: 26px; height: 26px; }
.empty-state h3 { font-size: 1.2rem; font-weight: 800; letter-spacing: -0.02em; margin: 0 0 8px; }
.empty-state p { margin: 0 auto 20px; max-width: 420px; font-size: 0.92rem; line-height: 1.5; }
.empty-state .btn :deep(svg) { width: 15px; height: 15px; }

/* ===== Responsive ===== */
@media (max-width: 640px) {
  .gl-drop { flex-wrap: wrap; }
  .gl-drop .btn { width: 100%; justify-content: center; }
  .gl-grid { grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); }
  .gl-photo-remove { opacity: 1; }
}
@media (prefers-reduced-motion: reduce) {
  .empty-icon-ring, .gl-drop.busy .gl-drop-icon { animation: none; }
  .gl-photo:hover .gl-photo-img img { transform: none; }
}
</style>
