// Identidade da plataforma. Trocar o nome aqui muda em todo o sistema.
export const APP_NAME = 'GG Vitrine'
export const APP_DOMAIN = 'ggvitrine.com.br'
export const APP_SLOGAN = 'Mostre seus serviços. Receba clientes.'
export const SUPPORT_WHATSAPP = '' // ex.: '5511999999999'

// Tipos de vitrine (coluna businesses.kind). A ordem é a exibida no cadastro.
export const KINDS = {
  agenda: {
    label: 'Agendamento',
    description: 'Clientes marcam horário: barbearia, clínica, quadra, aulas...',
    icon: 'calendar',
    action: 'Agendar',
  },
  cardapio: {
    label: 'Catálogo e pedidos',
    description: 'Clientes fazem pedidos: lanchonete, doces, loja, açaí...',
    icon: 'bag',
    action: 'Fazer pedido',
  },
  orcamento: {
    label: 'Orçamentos',
    description: 'Clientes pedem orçamento: eletricista, pintor, montador...',
    icon: 'clipboard',
    action: 'Pedir orçamento',
  },
  reserva: {
    label: 'Reservas',
    description: 'Mesa no restaurante, diárias de chalé, aluguel de itens...',
    icon: 'key',
    action: 'Reservar',
  },
  evento: {
    label: 'Eventos e turmas',
    description: 'Workshops, aulas coletivas e cursos com vagas limitadas.',
    icon: 'ticket',
    action: 'Inscrever-se',
  },
  cartao: {
    label: 'Cartão digital',
    description: 'Página com seus contatos, redes, fotos e avaliações.',
    icon: 'idcard',
    action: 'Falar comigo',
  },
}

export const CATEGORIES_BY_KIND = {
  agenda: [
    'Barbearia',
    'Salão de beleza',
    'Manicure e pedicure',
    'Estética',
    'Sobrancelhas e cílios',
    'Massagem',
    'Tatuagem e piercing',
    'Psicologia',
    'Nutrição',
    'Fisioterapia',
    'Personal trainer',
    'Pilates e yoga',
    'Odontologia',
    'Banho e tosa',
    'Veterinário',
    'Aulas particulares',
    'Aulas de música',
    'Idiomas',
    'Autoescola / instrutor',
    'Lava-jato',
    'Estética automotiva',
    'Oficina mecânica',
    'Quadra esportiva',
    'Sala / coworking',
    'Estúdio de fotografia',
    'Estúdio de gravação',
    'Diarista',
    'Outro',
  ],
  cardapio: [
    'Assados e frango',
    'Lanchonete',
    'Pizzaria',
    'Restaurante',
    'Marmitaria',
    'Açaí e sorvetes',
    'Doces e bolos',
    'Padaria',
    'Açougue',
    'Hortifrúti',
    'Gás e água',
    'Roupas e acessórios',
    'Cosméticos',
    'Semijoias',
    'Artesanato',
    'Outro',
  ],
  orcamento: [
    'Eletricista',
    'Encanador',
    'Pintor',
    'Pedreiro',
    'Marido de aluguel',
    'Montador de móveis',
    'Marceneiro',
    'Serralheiro',
    'Jardinagem',
    'Limpeza e dedetização',
    'Ar-condicionado',
    'Assistência técnica',
    'Fotografia e filmagem',
    'Decoração de festas',
    'Outro',
  ],
  reserva: [
    'Restaurante',
    'Bar',
    'Chalé / pousada',
    'Casa de temporada',
    'Salão de festas',
    'Aluguel para festas',
    'Aluguel de equipamentos',
    'Camping',
    'Outro',
  ],
  evento: [
    'Workshop',
    'Curso',
    'Aula coletiva',
    'Palestra',
    'Retiro',
    'Festa',
    'Esporte',
    'Outro',
  ],
  cartao: [
    'Profissional autônomo',
    'Fotógrafo',
    'Designer',
    'Advogado',
    'Contador',
    'Corretor de imóveis',
    'Consultor',
    'Artista',
    'Influenciador',
    'Outro',
  ],
}

export const CATEGORIES = CATEGORIES_BY_KIND.agenda

// Sugestões para o nome de "quem atende" na agenda.
export const STAFF_LABELS = ['Profissional', 'Quadra', 'Sala', 'Espaço', 'Instrutor', 'Professor', 'Box', 'Equipamento']

// Palavra usada para o catálogo conforme o segmento.
const FOOD = ['Assados e frango', 'Lanchonete', 'Pizzaria', 'Restaurante', 'Marmitaria', 'Açaí e sorvetes', 'Doces e bolos', 'Padaria']
export function catalogWord(category) {
  return FOOD.includes(category) ? 'Cardápio' : 'Catálogo'
}

// Ícones disponíveis para os links do cartão digital.
export const LINK_ICONS = {
  whatsapp: 'WhatsApp',
  instagram: 'Instagram',
  facebook: 'Facebook',
  tiktok: 'TikTok',
  youtube: 'YouTube',
  globe: 'Site',
  map: 'Localização',
  mail: 'E-mail',
  phone: 'Telefone',
  link: 'Outro link',
}

// Nome amigável de cada recurso dos planos (tabela plans.features).
export const FEATURE_LABELS = {
  agenda: 'Agenda',
  servicos: 'Serviços com preço e duração',
  horarios: 'Configuração de horários',
  clientes: 'Cadastro de clientes',
  agendamento_online: 'Link próprio de agendamento online',
  historico_agendamentos: 'Histórico de agendamentos',
  multi_profissional: 'Agenda individual por profissional',
  relatorios: 'Relatórios',
  historico_clientes: 'Histórico dos clientes',
  bloqueios: 'Bloqueio de horários',
  folgas: 'Controle de folgas',
  lembretes: 'Lembretes pelo WhatsApp',
  relatorios_avancados: 'Relatórios avançados',
  financeiro: 'Controle financeiro e faturamento',
  dashboard: 'Dashboard completo',
  comunicacao_avancada: 'Recursos avançados de comunicação',
  suporte_prioritario: 'Prioridade no suporte',
  cardapio: 'Catálogo ou cardápio com fotos e preços',
  pedidos_whatsapp: 'Pedidos chegam prontos no seu WhatsApp',
  pedidos: 'Painel de pedidos com status',
  horario_funcionamento: 'Horário de funcionamento e pausa',
  entrega_retirada: 'Entrega e retirada, com taxa e pedido mínimo',
  links: 'Links para WhatsApp, redes sociais e site',
  galeria: 'Galeria de fotos',
  avaliacoes: 'Avaliações dos clientes',
  qrcode: 'QR Code pronto para imprimir',
  fidelidade: 'Cartão fidelidade digital',
  cupons: 'Cupons de desconto',
  orcamentos: 'Pedidos de orçamento organizados',
  servicos_oferecidos: 'Lista de serviços e preços',
  reservas: 'Reservas por horário ou por diária',
  eventos: 'Eventos e turmas com vagas',
  inscricoes: 'Lista de inscritos',
}
