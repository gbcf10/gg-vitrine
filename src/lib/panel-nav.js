// Menu do painel. "kinds" limita a item a certos tipos de vitrine;
// "feature" marca itens que dependem do plano (aparecem com cadeado sem o recurso).
export const PANEL_NAV = [
  { to: '/painel', label: 'Agenda', icon: 'calendar', kinds: ['agenda'] },
  { to: '/painel/servicos', label: 'Serviços', icon: 'scissors', kinds: ['agenda'] },
  { to: '/painel/profissionais', label: 'Profissionais', staffLabel: true, icon: 'users', kinds: ['agenda'] },
  { to: '/painel/horarios', label: 'Horários', icon: 'clock', kinds: ['agenda'] },
  { to: '/painel/clientes', label: 'Clientes', icon: 'contact', kinds: ['agenda'] },
  { to: '/painel/bloqueios', label: 'Folgas e bloqueios', icon: 'ban', kinds: ['agenda'] },

  { to: '/painel/pedidos', label: 'Pedidos', icon: 'bag', kinds: ['cardapio'] },
  { to: '/painel/cardapio', label: 'Produtos', icon: 'utensils', kinds: ['cardapio'] },
  { to: '/painel/funcionamento', label: 'Funcionamento', icon: 'clock', kinds: ['cardapio'] },

  { to: '/painel/orcamentos', label: 'Orçamentos', icon: 'clipboard', kinds: ['orcamento'] },
  { to: '/painel/servicos-oferecidos', label: 'Serviços oferecidos', icon: 'scissors', kinds: ['orcamento'] },

  { to: '/painel/reservas', label: 'Reservas', icon: 'key', kinds: ['reserva'] },
  { to: '/painel/eventos', label: 'Eventos', icon: 'ticket', kinds: ['evento'] },

  { to: '/painel/links', label: 'Links', icon: 'link', feature: 'links' },
  { to: '/painel/galeria', label: 'Galeria', icon: 'image', feature: 'galeria' },
  { to: '/painel/avaliacoes', label: 'Avaliações', icon: 'star', feature: 'avaliacoes' },
  { to: '/painel/fidelidade', label: 'Fidelidade', icon: 'gift', feature: 'fidelidade', kinds: ['agenda', 'cardapio'] },
  { to: '/painel/cupons', label: 'Cupons', icon: 'tag', feature: 'cupons', kinds: ['agenda', 'cardapio', 'evento'] },
  { to: '/painel/divulgar', label: 'Divulgar', icon: 'qr' },
  { to: '/painel/perfil', label: 'Perfil', icon: 'store' },
  { to: '/painel/assinatura', label: 'Assinatura', icon: 'card' },
]

export function navFor(kind) {
  return PANEL_NAV.filter((i) => !i.kinds || i.kinds.includes(kind))
}

// Página inicial do painel para cada tipo.
export function homeFor(kind) {
  return navFor(kind)[0].to
}

export function routeAllowed(path, kind) {
  const item = PANEL_NAV.find((i) => i.to === path)
  return !item || !item.kinds || item.kinds.includes(kind)
}
