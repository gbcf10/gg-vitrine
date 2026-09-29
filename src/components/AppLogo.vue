<script setup>
import { APP_NAME } from '@/config/brand'

defineProps({ to: { type: String, default: '/' } })
</script>

<template>
  <RouterLink :to="to" class="logo">
    <span class="logo-mark">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M4.5 4h15l1.8 5.5H2.7z" /><path d="M4.5 9.5V20h15V9.5M10 20v-5h4v5M8.5 4 7.8 9.5M15.5 4l.7 5.5" />
      </svg>
    </span>
    <span class="gradient-text">{{ APP_NAME }}</span>
  </RouterLink>
</template>
