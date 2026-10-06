// Menu do painel. "feature" marca itens que dependem do plano
// (aparecem com cadeado quando o plano não inclui o recurso).
export const PANEL_NAV = [
  { to: '/painel', label: 'Agenda', icon: 'calendar' },
  { to: '/painel/servicos', label: 'Serviços', icon: 'scissors' },
  { to: '/painel/profissionais', label: 'Profissionais', staffLabel: true, icon: 'users' },
  { to: '/painel/horarios', label: 'Horários', icon: 'clock' },
  { to: '/painel/clientes', label: 'Clientes', icon: 'contact' },
  { to: '/painel/bloqueios', label: 'Folgas e bloqueios', icon: 'ban' },
  { to: '/painel/lembretes', label: 'Lembretes', icon: 'bell', feature: 'lembretes' },
  { to: '/painel/galeria', label: 'Galeria', icon: 'image', feature: 'galeria' },
  { to: '/painel/avaliacoes', label: 'Avaliações', icon: 'star', feature: 'avaliacoes' },
  { to: '/painel/fidelidade', label: 'Fidelidade', icon: 'gift', feature: 'fidelidade' },
  { to: '/painel/cupons', label: 'Cupons', icon: 'tag', feature: 'cupons' },
  { to: '/painel/divulgar', label: 'Divulgar', icon: 'qr' },
  { to: '/painel/perfil', label: 'Perfil', icon: 'store' },
  { to: '/painel/assinatura', label: 'Assinatura', icon: 'card' },
]

export const PANEL_HOME = '/painel'

export function routeAllowed(path) {
  return PANEL_NAV.some((i) => i.to === path)
}
