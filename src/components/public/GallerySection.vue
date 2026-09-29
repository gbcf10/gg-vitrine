<script setup>
import { ref } from 'vue'

defineProps({ photos: { type: Array, required: true } })
const open = ref(null)
</script>

<template>
  <section v-if="photos.length" class="pub-section">
    <h2>Galeria</h2>
    <div class="gallery">
      <button v-for="p in photos" :key="p.id" class="thumb" @click="open = p">
        <img :src="p.url" :alt="p.caption || ''" loading="lazy" />
      </button>
    </div>
    <div v-if="open" class="sheet-backdrop" @click="open = null">
      <figure class="viewer">
        <img :src="open.url" :alt="open.caption || ''" />
        <figcaption v-if="open.caption">{{ open.caption }}</figcaption>
      </figure>
    </div>
  </section>
</template>

<style scoped>
.gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 8px; }
.thumb { padding: 0; border: 1px solid var(--border); border-radius: 14px; overflow: hidden; aspect-ratio: 1; cursor: zoom-in; background: var(--surface); }
.thumb img { width: 100%; height: 100%; object-fit: cover; transition: transform 0.25s ease; }
.thumb:hover img { transform: scale(1.04); }
.viewer { margin: auto; max-width: min(920px, 94vw); text-align: center; }
.viewer img { max-height: 82vh; border-radius: 16px; }
.viewer figcaption { color: var(--silver); margin-top: 10px; }
</style>
