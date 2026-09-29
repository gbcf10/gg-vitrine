<script setup>
import { useRoute, useRouter } from 'vue-router'
import { signOut } from '@/lib/session'
import AppLogo from '@/components/AppLogo.vue'
import Icon from '@/components/Icon.vue'
import BackButton from '@/components/BackButton.vue'

const route = useRoute()
const router = useRouter()
async function logout() {
  await signOut()
  router.push('/entrar')
}
</script>

<template>
  <div class="app-shell">
    <aside class="sidebar">
      <div class="brand">
        <AppLogo to="/admin" />
      </div>
      <p class="eyebrow" style="padding: 0 12px; margin: 8px 0">Administração</p>
      <nav>
        <RouterLink to="/admin"><Icon name="chart" />Resumo</RouterLink>
        <RouterLink to="/admin/empresas"><Icon name="building" />Empresas</RouterLink>
        <RouterLink to="/painel"><Icon name="store" />Meu painel</RouterLink>
        <a href="#" @click.prevent="logout"><Icon name="logout" />Sair</a>
      </nav>
      <div class="footer">G&amp;G Soluções</div>
    </aside>
    <main class="main">
      <BackButton v-if="route.path !== '/admin'" fallback="/admin" />
      <RouterView />
    </main>
  </div>
</template>
