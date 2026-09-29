<script setup>
// Pré-visualização das vitrines com dados de exemplo. Só existe em desenvolvimento
// (npm run dev): /dev/vitrine/agenda, /dev/vitrine/cardapio, etc.
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import PublicPage from './PublicPage.vue'

const route = useRoute()
const soon = (days, h) => new Date(Date.now() + days * 86400000 + h * 3600000).toISOString()
const photo = (seed) => `https://picsum.photos/seed/${seed}/600/600`

const base = {
  id: '00000000-0000-0000-0000-000000000000', slug: 'exemplo', timezone: 'America/Sao_Paulo',
  phone: '(11) 98888-7777', address: 'Rua das Flores, 123 - Centro', logo_url: null, live: true,
  staff_label: 'Profissional', description: 'Atendimento com carinho desde 2015.',
  features: ['links', 'galeria', 'avaliacoes', 'qrcode', 'fidelidade', 'cupons'],
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
  services: null, professionals: null, menu: null, store: null, reservation: null, events: null,
}

const allHours = [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '00:00:00', end: '23:59:00' }))

const PRESETS = {
  agenda: {
    ...base, kind: 'agenda', name: 'Barbearia do Zé', category: 'Barbearia', primary_color: '#b45309',
    services: [
      { id: 's1', name: 'Corte', description: 'Tesoura ou máquina', price: 40, duration_min: 30 },
      { id: 's2', name: 'Corte + barba', description: null, price: 60, duration_min: 60 },
    ],
    professionals: [
      { id: 'p1', name: 'Zé', photo_url: null, service_ids: ['s1', 's2'] },
      { id: 'p2', name: 'Léo', photo_url: null, service_ids: ['s1'] },
    ],
  },
  cardapio: {
    ...base, kind: 'cardapio', name: 'Frango do Beto', category: 'Assados e frango', primary_color: '#dc2626',
    loyalty: { required: 8, reward: '1 frango grátis' },
    store: { accepting_orders: true, open_now: true, pickup_enabled: true, delivery_enabled: true, delivery_fee: 7, min_order: 30, delivery_area: 'Centro e Vila Nova', hours: allHours },
    menu: [
      { id: 'c1', name: 'Frangos', items: [
        { id: 'i1', name: 'Frango assado inteiro', description: 'Acompanha farofa e vinagrete. Serve 3 pessoas.', price: 55, photo_url: photo('frango'), available: true },
        { id: 'i2', name: 'Meio frango', description: 'Serve 2 pessoas.', price: 32, photo_url: null, available: false },
      ] },
      { id: 'c2', name: 'Acompanhamentos', items: [
        { id: 'i3', name: 'Maionese caseira 500 g', description: null, price: 14, photo_url: null, available: true },
      ] },
    ],
  },
  orcamento: {
    ...base, kind: 'orcamento', name: 'Elétrica Silva', category: 'Eletricista', primary_color: '#ca8a04', loyalty: null,
    menu: [{ id: 'c1', name: 'Elétrica', items: [
      { id: 'i1', name: 'Instalação de chuveiro', description: 'Mão de obra.', price: 80, photo_url: null, available: true },
      { id: 'i2', name: 'Troca de disjuntor', description: null, price: 0, photo_url: null, available: true },
    ] }],
  },
  reserva: {
    ...base, kind: 'reserva', name: 'Chalés da Serra', category: 'Chalé / pousada', primary_color: '#15803d', loyalty: null,
    reservation: { mode: 'diaria', max_party: 10, notice: 'Check-in às 14h, check-out às 12h.', units: [
      { id: 'u1', name: 'Chalé com hidro', description: 'Lareira e vista para a serra', capacity: 2, price: 380, photo_url: photo('chale') },
      { id: 'u2', name: 'Chalé família', description: null, capacity: 5, price: 520, photo_url: null },
    ] },
  },
  evento: {
    ...base, kind: 'evento', name: 'Studio Yoga Luz', category: 'Aula coletiva', primary_color: '#7c3aed', loyalty: null,
    events: [
      { id: 'e1', title: 'Yoga ao ar livre', description: 'Traga seu tapete e uma garrafa de água.', starts_at: soon(3, 2), ends_at: soon(3, 3), location: 'Parque Central', price: 30, photo_url: photo('yoga'), capacity: 20, spots_left: 4 },
      { id: 'e2', title: 'Workshop de respiração', description: null, starts_at: soon(10, 5), ends_at: null, location: 'Online', price: 0, photo_url: null, capacity: null, spots_left: null },
    ],
  },
  cartao: {
    ...base, kind: 'cartao', name: 'Ana Souza Fotografia', category: 'Fotógrafo', primary_color: '#db2777', loyalty: null,
    description: 'Ensaios, casamentos e eventos em São Paulo e região.',
  },
}

const preset = computed(() => PRESETS[route.params.kind] ?? PRESETS.agenda)
</script>

<template>
  <PublicPage :key="route.params.kind" :preset="preset" />
</template>
