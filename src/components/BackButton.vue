<script setup>
import { useRouter } from 'vue-router'

// Volta para a tela anterior; se a pessoa abriu direto por um link, vai para "fallback".
const props = defineProps({ fallback: { type: String, default: '/' }, label: { type: String, default: 'Voltar' } })
const router = useRouter()

function goBack() {
  if (window.history.state?.back) router.back()
  else router.push(props.fallback)
}
</script>

<template>
  <button type="button" class="back-btn" @click="goBack">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M15 18l-6-6 6-6" />
    </svg>
    {{ label }}
  </button>
</template>

<style scoped>
.back-btn {
  display: inline-flex; align-items: center; gap: 4px; margin-bottom: 14px; padding: 6px 12px 6px 8px;
  border-radius: 999px; border: 1px solid var(--border); background: var(--surface); color: var(--silver);
  font: inherit; font-size: 0.88rem; font-weight: 600; cursor: pointer; transition: border-color 0.15s ease, color 0.15s ease;
}
.back-btn:hover { border-color: var(--brand); color: #fff; }
.back-btn svg { width: 18px; height: 18px; }
</style>
