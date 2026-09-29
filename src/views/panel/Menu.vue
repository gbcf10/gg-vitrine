<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase, unwrap } from '@/lib/supabase'
import { useBusiness } from '@/lib/business'
import { money, plural } from '@/lib/format'
import Icon from '@/components/Icon.vue'
import { catalogWord } from '@/config/brand'

const biz = useBusiness()
const categories = ref([])
const items = ref([])
const error = ref('')
const newCategory = ref('')
const editing = ref(null)   // produto aberto no formulário
const uploading = ref(false)
const isQuote = computed(() => biz.business.kind === 'orcamento')
const T = computed(() => isQuote.value
  ? { eyebrow: 'Orçamentos', title: 'Serviços oferecidos', item: 'serviço', itemCap: 'Serviço', price: 'Preço "a partir de" (R$)', priceHint: '0 = sob consulta',
      namePh: 'Ex.: Instalação de chuveiro', descPh: 'Ex.: Inclui mão de obra. Material por conta do cliente.', catPh: 'Ex.: Elétrica, Hidráulica, Manutenção', off: 'Ocultar', on: 'Mostrar', offBadge: 'Oculto', available: 'Visível na vitrine' }
  : { eyebrow: catalogWord(biz.business.category), title: 'Produtos', item: 'produto', itemCap: 'Produto', price: 'Preço (R$)', priceHint: '',
      namePh: 'Ex.: Frango assado inteiro', descPh: 'Ex.: Acompanha farofa e vinagrete. Serve 3 pessoas.', catPh: 'Ex.: Frangos, Acompanhamentos, Bebidas', off: 'Esgotar', on: 'Disponibilizar', offBadge: 'Esgotado', available: 'Disponível para venda' })

const itemsByCategory = computed(() => {
  const map = Object.fromEntries(categories.value.map((c) => [c.id, []]))
  for (const i of items.value) map[i.category_id]?.push(i)
  return map
})

async function load() {
  const bid = biz.business.id
  categories.value = unwrap(await supabase.from('menu_categories').select('*')
    .eq('business_id', bid).order('sort_order').order('name'))
  items.value = unwrap(await supabase.from('menu_items').select('*')
    .eq('business_id', bid).order('sort_order').order('name'))
}
onMounted(load)

async function run(promise) {
  error.value = ''
  const { error: err } = await promise
  if (err) error.value = err.message
  await load()
  return !err
}

// ---- Categorias ----
async function addCategory() {
  const name = newCategory.value.trim()
  if (!name) return
  const sort = categories.value.length ? Math.max(...categories.value.map((c) => c.sort_order)) + 1 : 0
  if (await run(supabase.from('menu_categories').insert({ business_id: biz.business.id, name, sort_order: sort }))) {
    newCategory.value = ''
  }
}

function renameCategory(c) {
  const name = prompt('Novo nome da categoria:', c.name)
  if (name?.trim()) run(supabase.from('menu_categories').update({ name: name.trim() }).eq('id', c.id))
}

function removeCategory(c) {
  const count = itemsByCategory.value[c.id].length
  if (!confirm(count ? `Excluir "${c.name}" e o que está dentro dela (${count})?` : `Excluir "${c.name}"?`)) return
  run(supabase.from('menu_categories').delete().eq('id', c.id))
}

async function moveCategory(index, delta) {
  const list = [...categories.value]
  const target = index + delta
  if (target < 0 || target >= list.length) return
  ;[list[index], list[target]] = [list[target], list[index]]
  await Promise.all(list.map((c, i) => supabase.from('menu_categories').update({ sort_order: i }).eq('id', c.id)))
  load()
}

// ---- Produtos ----
function newItem(category) {
  editing.value = { id: null, category_id: category.id, name: '', description: '', price: '', photo_url: null, available: true }
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function editItem(i) {
  const { id, category_id, name, description, price, photo_url, available } = i
  editing.value = { id, category_id, name, description, price, photo_url, available }
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function saveItem() {
  const { id, ...fields } = editing.value
  const payload = { ...fields, price: Number(fields.price), business_id: biz.business.id }
  const ok = await run(id
    ? supabase.from('menu_items').update(payload).eq('id', id)
    : supabase.from('menu_items').insert(payload))
  if (ok) editing.value = null
}

function removeItem(i) {
  if (confirm(`Excluir "${i.name}"?`)) run(supabase.from('menu_items').delete().eq('id', i.id))
}

function toggleAvailable(i) {
  run(supabase.from('menu_items').update({ available: !i.available }).eq('id', i.id))
}

async function uploadPhoto(event) {
  const file = event.target.files[0]
  if (!file) return
  if (file.size > 3 * 1024 * 1024) { error.value = 'A foto precisa ter no máximo 3 MB.'; return }
  uploading.value = true
  error.value = ''
  const ext = file.name.split('.').pop().toLowerCase()
  const path = `${biz.business.id}/menu/${Date.now()}.${ext}`
  const { error: err } = await supabase.storage.from('logos').upload(path, file)
  uploading.value = false
  if (err) { error.value = err.message; return }
  editing.value.photo_url = supabase.storage.from('logos').getPublicUrl(path).data.publicUrl
}
</script>

<template>
  <div class="page-header spread">
    <div>
      <p class="eyebrow">{{ T.eyebrow }}</p>
      <h1>{{ T.title }}</h1>
    </div>
    <a class="btn secondary" :href="`/${biz.business.slug}`" target="_blank">Ver minha vitrine</a>
  </div>
  <div v-if="error" class="error">{{ error }}</div>

  <!-- Formulário de produto -->
  <div v-if="editing" class="card glow">
    <div class="spread">
      <h3>{{ editing.id ? `Editar ${T.item}` : `Novo ${T.item}` }}</h3>
      <button class="btn small secondary" @click="editing = null">Fechar</button>
    </div>
    <form @submit.prevent="saveItem">
      <div class="row">
        <div class="field" style="flex-basis: 280px"><label>Nome</label><input v-model="editing.name" required :placeholder="T.namePh" /></div>
        <div class="field"><label>{{ T.price }} <small v-if="T.priceHint">{{ T.priceHint }}</small></label><input v-model="editing.price" type="number" min="0" step="0.01" required /></div>
        <div class="field">
          <label>Categoria</label>
          <select v-model="editing.category_id">
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
      </div>
      <div class="field">
        <label>Descrição <small>(opcional)</small></label>
        <textarea v-model="editing.description" rows="2" :placeholder="T.descPh" />
      </div>
      <div class="row" style="align-items: center">
        <img v-if="editing.photo_url" :src="editing.photo_url" alt="" class="shrink thumb large" />
        <div class="field">
          <label>Foto <small>(opcional, deixa sua vitrine muito mais bonita)</small></label>
          <input type="file" accept="image/png,image/jpeg,image/webp" @change="uploadPhoto" />
          <small v-if="uploading">Enviando foto...</small>
        </div>
      </div>
      <div class="spread">
        <label><input v-model="editing.available" type="checkbox" /> {{ T.available }}</label>
        <button class="btn" :disabled="uploading">{{ editing.id ? 'Salvar' : `Adicionar ${T.item}` }}</button>
      </div>
    </form>
  </div>

  <!-- Nova categoria -->
  <form class="card" @submit.prevent="addCategory">
    <div class="row">
      <div class="field" style="margin: 0">
        <label>Nova categoria</label>
        <input v-model="newCategory" :placeholder="T.catPh" />
      </div>
      <div class="shrink"><button class="btn">Adicionar</button></div>
    </div>
  </form>

  <p v-if="!categories.length" class="notice">
    Comece criando as categorias ({{ T.catPh.replace('Ex.: ', 'ex.: ') }}). Depois adicione os {{ T.item }}s em cada uma.
  </p>

  <!-- Categorias e produtos -->
  <div v-for="(c, index) in categories" :key="c.id" class="card">
    <div class="spread" style="margin-bottom: 8px">
      <h3 style="margin: 0">{{ c.name }} <small>· {{ plural(itemsByCategory[c.id].length, T.item, T.item + 's') }}</small></h3>
      <div class="chips">
        <button class="btn small secondary" :disabled="index === 0" title="Subir" @click="moveCategory(index, -1)">↑</button>
        <button class="btn small secondary" :disabled="index === categories.length - 1" title="Descer" @click="moveCategory(index, 1)">↓</button>
        <button class="btn small secondary" @click="renameCategory(c)">Renomear</button>
        <button class="btn small danger" @click="removeCategory(c)">Excluir</button>
        <button class="btn small" @click="newItem(c)"><Icon name="plus" style="width: 15px; height: 15px" />{{ T.itemCap }}</button>
      </div>
    </div>

    <p v-if="!itemsByCategory[c.id].length" class="muted" style="margin: 8px 0 0">Nenhum {{ T.item }} nesta categoria.</p>
    <div v-for="i in itemsByCategory[c.id]" :key="i.id" class="item-row" :class="{ off: !i.available }">
      <img v-if="i.photo_url" :src="i.photo_url" alt="" class="thumb" />
      <div v-else class="thumb empty"><Icon name="utensils" /></div>
      <div style="flex: 1; min-width: 0">
        <strong>{{ i.name }}</strong>
        <span v-if="!i.available" class="badge red" style="margin-left: 6px">{{ T.offBadge }}</span>
        <div class="muted desc">{{ i.description }}</div>
      </div>
      <strong class="price">{{ isQuote && !Number(i.price) ? 'sob consulta' : money(i.price) }}</strong>
      <div class="chips actions">
        <button class="btn small secondary" @click="toggleAvailable(i)">{{ i.available ? T.off : T.on }}</button>
        <button class="btn small secondary" @click="editItem(i)">Editar</button>
        <button class="btn small secondary" title="Excluir" @click="removeItem(i)">✕</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.item-row { display: flex; gap: 14px; align-items: center; padding: 12px 0; border-top: 1px solid var(--border); flex-wrap: wrap; }
.item-row.off { opacity: 0.6; }
.thumb { width: 56px; height: 56px; border-radius: 12px; object-fit: cover; flex-shrink: 0; border: 1px solid var(--border); }
.thumb.large { width: 84px; height: 84px; }
.thumb.empty { display: grid; place-items: center; background: var(--surface); color: var(--muted); }
.thumb.empty svg { width: 22px; height: 22px; }
.desc { font-size: 0.85rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.price { white-space: nowrap; }
@media (max-width: 640px) { .actions { width: 100%; } }
</style>
