import { createRouter, createWebHistory } from 'vue-router'
import { session, isPlatformAdmin } from '@/lib/session'

const routes = [
  { path: '/', component: () => import('@/views/Landing.vue') },
  { path: '/entrar', component: () => import('@/views/auth/Login.vue') },
  { path: '/cadastro', component: () => import('@/views/auth/Signup.vue') },
  {
    path: '/painel',
    component: () => import('@/views/panel/PanelLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', component: () => import('@/views/panel/Agenda.vue') },
      { path: 'servicos', component: () => import('@/views/panel/Services.vue') },
      { path: 'profissionais', component: () => import('@/views/panel/Professionals.vue') },
      { path: 'horarios', component: () => import('@/views/panel/Hours.vue') },
      { path: 'clientes', component: () => import('@/views/panel/Customers.vue') },
      { path: 'bloqueios', component: () => import('@/views/panel/TimeOff.vue') },
      { path: 'perfil', component: () => import('@/views/panel/Profile.vue') },
      { path: 'assinatura', component: () => import('@/views/panel/Subscription.vue') },
    ],
  },
  {
    path: '/admin',
    component: () => import('@/views/admin/AdminLayout.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
    children: [
      { path: '', component: () => import('@/views/admin/Overview.vue') },
      { path: 'empresas', component: () => import('@/views/admin/Businesses.vue') },
    ],
  },
  // Página pública de cada estabelecimento: precisa ser a última rota.
  { path: '/:slug', component: () => import('@/views/public/BookingPage.vue') },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  if (to.meta.requiresAuth && !session.user) {
    return { path: '/entrar', query: { redirect: to.fullPath } }
  }
  if (to.meta.requiresAdmin && !(await isPlatformAdmin())) {
    return '/painel'
  }
})

export default router
