<script setup>
// Pré-visualização da vitrine com dados de exemplo. Só existe em desenvolvimento
// (npm run dev): /dev/vitrine.
import PublicPage from './PublicPage.vue'

const soon = (days, h) => new Date(Date.now() + days * 86400000 + h * 3600000).toISOString()
const photo = (seed) => `https://picsum.photos/seed/${seed}/600/600`

const preset = {
  id: '00000000-0000-0000-0000-000000000000', slug: 'exemplo', timezone: 'America/Sao_Paulo',
  phone: '(11) 98888-7777', address: 'Rua das Flores, 123 - Centro', logo_url: null, live: true,
  staff_label: 'Profissional', description: 'Atendimento com carinho desde 2015.',
  features: ['galeria', 'avaliacoes', 'qrcode', 'fidelidade', 'cupons'],
  links: [
    { id: 'l1', label: 'Instagram', url: 'instagram.com/exemplo', icon: 'instagram' },
    { id: 'l2', label: 'Localização', url: 'https://maps.google.com', icon: 'map' },
  ],
  gallery: [1, 2, 3, 4, 5, 6].map((n) => ({ id: `g${n}`, url: photo(`gg${n}`), caption: n === 1 ? 'Nosso espaço' : null })),
  reviews: {
    average: 4.8, count: 23,
    latest: [
      { author_name: 'Mariana', rating: 5, comment: 'Atendimento impecável, super recomendo!', reply: 'Obrigado, Mariana!', created_at: soon(-2, 0) },
      { author_name: 'Carlos', rating: 4, comment: 'Muito bom, voltarei.', reply: null, created_at: soon(-9, 0) },
    ],
  },
  loyalty: { required: 10, reward: '1 serviço grátis' },
  name: 'Barbearia do Zé', category: 'Barbearia', primary_color: '#b45309',
  services: [
    { id: 's1', name: 'Corte', description: 'Tesoura ou máquina', price: 40, duration_min: 30 },
    { id: 's2', name: 'Corte + barba', description: null, price: 60, duration_min: 60 },
  ],
  professionals: [
    { id: 'p1', name: 'Zé', photo_url: null, service_ids: ['s1', 's2'] },
    { id: 'p2', name: 'Léo', photo_url: null, service_ids: ['s1'] },
  ],
}
</script>

<template>
  <PublicPage :preset="preset" />
</template>
