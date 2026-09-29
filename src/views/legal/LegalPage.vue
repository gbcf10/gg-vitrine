<script setup>
import AppLogo from '@/components/AppLogo.vue'
import BackButton from '@/components/BackButton.vue'
import { LEGAL } from '@/config/brand'

defineProps({ title: { type: String, required: true } })
</script>

<template>
  <nav class="topnav">
    <div class="container">
      <AppLogo />
      <div class="links">
        <RouterLink to="/termos">Termos de uso</RouterLink>
        <RouterLink to="/privacidade">Privacidade</RouterLink>
      </div>
    </div>
  </nav>
  <main class="container legal">
    <BackButton />
    <p class="eyebrow">Documentos</p>
    <h1 class="gradient-text">{{ title }}</h1>
    <p class="muted">Última atualização: {{ LEGAL.updatedAt }}</p>
    <div class="card legal-body">
      <slot />
    </div>
  </main>
</template>

<style scoped>
.topnav .links a { color: var(--text); font-weight: 500; font-size: 0.95rem; padding: 0 6px; }
.legal { max-width: 820px; padding: 40px 0 64px; }
.legal-body { line-height: 1.7; }
.legal-body :deep(h2) { font-size: 1.15rem; margin: 28px 0 8px; }
.legal-body :deep(h2:first-child) { margin-top: 0; }
.legal-body :deep(p), .legal-body :deep(li) { color: var(--silver); }
.legal-body :deep(ul) { padding-left: 20px; }
.legal-body :deep(strong) { color: var(--text); }
</style>
