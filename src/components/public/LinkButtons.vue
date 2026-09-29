<script setup>
import { computed } from 'vue'
import Icon from '@/components/Icon.vue'
import { waLink } from '@/lib/whatsapp'

// big = botões grandes (cartão digital); senão, chips compactos.
const props = defineProps({
  business: { type: Object, required: true },
  big: { type: Boolean, default: false },
})

function href(link) {
  const url = link.url.trim()
  if (link.icon === 'whatsapp' && !/^https?:/.test(url)) return waLink(url)
  if (link.icon === 'mail' && !url.startsWith('mailto:')) return `mailto:${url}`
  if (link.icon === 'phone' && !url.startsWith('tel:')) return `tel:${url.replace(/[^\d+]/g, '')}`
  return /^[a-z]+:/i.test(url) ? url : `https://${url}`
}

const items = computed(() => {
  const list = props.business.links.map((l) => ({ ...l, href: href(l) }))
  // O WhatsApp do cadastro sempre aparece primeiro no cartão digital.
  if (props.big && props.business.phone && !list.some((l) => l.icon === 'whatsapp')) {
    list.unshift({ id: 'wa', label: 'WhatsApp', icon: 'whatsapp', href: waLink(props.business.phone) })
  }
  if (props.big && props.business.address && !list.some((l) => l.icon === 'map')) {
    list.push({ id: 'map', label: 'Como chegar', icon: 'map',
      href: `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(props.business.address)}` })
  }
  return list
})
</script>

<template>
  <div v-if="items.length" :class="big ? 'link-list' : 'link-chips'">
    <a v-for="l in items" :key="l.id" :href="l.href" target="_blank" rel="noopener" :class="big ? 'btn large block link-big' : 'chip link-chip'">
      <Icon :name="l.icon" />{{ l.label }}
    </a>
  </div>
</template>

<style scoped>
.link-list { display: grid; gap: 12px; }
.link-big { justify-content: flex-start; padding-left: 22px; }
.link-big:not(:first-child) { background: var(--surface); color: var(--text); border-color: var(--border); box-shadow: none; }
.link-big:not(:first-child):hover { border-color: var(--brand); }
.link-big svg { width: 20px; height: 20px; }
.link-chips { display: flex; flex-wrap: wrap; gap: 8px; margin: 4px 0 8px; }
.link-chip { display: inline-flex; align-items: center; gap: 6px; font-size: 0.88rem; padding: 7px 12px; color: var(--silver); }
.link-chip svg { width: 16px; height: 16px; color: var(--brand-ink); }
</style>
