<script setup>
import { FEATURE_LABELS } from '@/config/brand'
import Icon from '@/components/Icon.vue'

defineProps({ feature: { type: String, required: true } })
</script>

<template>
  <div class="card glow" style="text-align: center; padding: 36px 22px">
    <div class="lock"><Icon name="gift" /></div>
    <h2>{{ FEATURE_LABELS[feature] ?? feature }}</h2>
    <p class="muted">Este recurso não faz parte do seu plano atual.</p>
    <RouterLink class="btn" to="/painel/assinatura">Ver planos</RouterLink>
  </div>
</template>

<style scoped>
.lock { width: 60px; height: 60px; margin: 0 auto 14px; border-radius: 50%; display: grid; place-items: center; background: var(--brand-soft); color: var(--brand-ink); border: 1px solid var(--border); }
.lock svg { width: 28px; height: 28px; }
</style>
