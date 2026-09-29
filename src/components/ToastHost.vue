<script setup>
import { toasts } from '@/lib/toast'
import Icon from '@/components/Icon.vue'
</script>

<template>
  <div class="toast-host" role="status" aria-live="polite">
    <TransitionGroup name="toast">
      <div v-for="t in toasts" :key="t.id" :class="['toast', t.type]">
        <Icon :name="t.type === 'success' ? 'check' : 'ban'" />{{ t.message }}
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.toast-host { position: fixed; right: 20px; bottom: 20px; z-index: 100; display: grid; gap: 8px; pointer-events: none; }
.toast {
  display: flex; align-items: center; gap: 10px; padding: 12px 18px; border-radius: 12px; font-weight: 600;
  background: rgba(11, 23, 48, 0.95); border: 1px solid rgba(74, 222, 128, 0.45); color: #bbf7d0;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.4), 0 0 20px rgba(74, 222, 128, 0.15); backdrop-filter: blur(8px);
}
.toast.error { border-color: rgba(248, 113, 113, 0.45); color: #fecaca; }
.toast svg { width: 18px; height: 18px; }
.toast-enter-active, .toast-leave-active { transition: all 0.25s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translateY(10px); }
@media (max-width: 600px) { .toast-host { left: 16px; right: 16px; bottom: 16px; } }
</style>
