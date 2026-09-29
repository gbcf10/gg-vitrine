<script setup>
defineProps({ value: { type: Number, default: 0 } })
</script>

<template>
  <span class="stars" :aria-label="`${value} de 5 estrelas`">
    <svg v-for="n in 5" :key="n" viewBox="0 0 24 24" :fill="n <= Math.round(value) ? 'currentColor' : 'none'"
         stroke="currentColor" stroke-width="2" stroke-linejoin="round">
      <path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z" />
    </svg>
  </span>
</template>
