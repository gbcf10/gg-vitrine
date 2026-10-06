<script setup>
import { ref } from 'vue'

defineProps({ photos: { type: Array, required: true } })
const open = ref(null)
</script>

<template>
  <div v-if="photos.length" class="gal-grid">
    <button v-for="p in photos" :key="p.id" class="gal-thumb" @click="open = p" :aria-label="p.caption || 'Ampliar foto'">
      <img :src="p.url" :alt="p.caption || ''" loading="lazy" />
    </button>
    <div v-if="open" class="sheet-backdrop" @click="open = null">
      <figure class="viewer">
        <img :src="open.url" :alt="open.caption || ''" />
        <figcaption v-if="open.caption">{{ open.caption }}</figcaption>
      </figure>
    </div>
  </div>
</template>

<style scoped>
.viewer { margin: auto; max-width: min(920px, 94vw); text-align: center; }
.viewer img { max-height: 82vh; border-radius: 16px; }
.viewer figcaption { color: var(--silver); margin-top: 10px; }
</style>
