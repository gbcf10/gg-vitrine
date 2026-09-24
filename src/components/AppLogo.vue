<script setup>
import { APP_NAME } from '@/config/brand'

defineProps({ to: { type: String, default: '/' } })
</script>

<template>
  <RouterLink :to="to" class="logo">
    <span class="logo-mark">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="3" y="5" width="18" height="16" rx="3" /><path d="M3 10h18M8 3v4M16 3v4M9 15.5l2.2 2L15.5 13" />
      </svg>
    </span>
    <span class="gradient-text">{{ APP_NAME }}</span>
  </RouterLink>
</template>
