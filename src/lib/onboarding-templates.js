// Templates por categoria pra popular serviços e horários no cadastro.
// weekday: 0=domingo, 6=sábado.

const BUSINESS_HOURS = [
  { weekday: 1, start: '09:00', end: '19:00' },
  { weekday: 2, start: '09:00', end: '19:00' },
  { weekday: 3, start: '09:00', end: '19:00' },
  { weekday: 4, start: '09:00', end: '19:00' },
  { weekday: 5, start: '09:00', end: '19:00' },
  { weekday: 6, start: '09:00', end: '14:00' },
]
const CLINIC_HOURS = [
  { weekday: 1, start: '08:00', end: '18:00' },
  { weekday: 2, start: '08:00', end: '18:00' },
  { weekday: 3, start: '08:00', end: '18:00' },
  { weekday: 4, start: '08:00', end: '18:00' },
  { weekday: 5, start: '08:00', end: '17:00' },
]
const EVENING_HOURS = [
  { weekday: 1, start: '14:00', end: '22:00' },
  { weekday: 2, start: '14:00', end: '22:00' },
  { weekday: 3, start: '14:00', end: '22:00' },
  { weekday: 4, start: '14:00', end: '22:00' },
  { weekday: 5, start: '14:00', end: '22:00' },
  { weekday: 6, start: '10:00', end: '18:00' },
]
const FULL_WEEK_HOURS = [0, 1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, start: '08:00', end: '22:00' }))

export const TEMPLATES = {
  'Barbearia': {
    staff_label: 'Profissional',
    services: [
      { name: 'Corte', duration_min: 30, price: 50 },
      { name: 'Barba', duration_min: 30, price: 35 },
      { name: 'Corte + barba', duration_min: 60, price: 75 },
      { name: 'Sobrancelha', duration_min: 15, price: 20 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Salão de beleza': {
    staff_label: 'Profissional',
    services: [
      { name: 'Corte feminino', duration_min: 45, price: 80 },
      { name: 'Escova', duration_min: 45, price: 70 },
      { name: 'Hidratação', duration_min: 60, price: 120 },
      { name: 'Coloração', duration_min: 120, price: 180 },
      { name: 'Maquiagem', duration_min: 60, price: 150 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Manicure e pedicure': {
    staff_label: 'Profissional',
    services: [
      { name: 'Mão', duration_min: 45, price: 40 },
      { name: 'Pé', duration_min: 45, price: 45 },
      { name: 'Mão + pé', duration_min: 90, price: 75 },
      { name: 'Esmaltação em gel', duration_min: 60, price: 70 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Estética': {
    staff_label: 'Profissional',
    services: [
      { name: 'Limpeza de pele', duration_min: 60, price: 120 },
      { name: 'Peeling químico', duration_min: 60, price: 180 },
      { name: 'Massagem modeladora', duration_min: 60, price: 150 },
      { name: 'Drenagem linfática', duration_min: 60, price: 130 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Sobrancelhas e cílios': {
    staff_label: 'Profissional',
    services: [
      { name: 'Design de sobrancelha', duration_min: 30, price: 50 },
      { name: 'Design + henna', duration_min: 45, price: 70 },
      { name: 'Lash lifting', duration_min: 60, price: 150 },
      { name: 'Extensão de cílios', duration_min: 120, price: 200 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Massagem': {
    staff_label: 'Profissional',
    services: [
      { name: 'Relaxante 60 min', duration_min: 60, price: 150 },
      { name: 'Modeladora', duration_min: 60, price: 170 },
      { name: 'Pedras quentes', duration_min: 90, price: 220 },
      { name: 'Shiatsu', duration_min: 60, price: 180 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Tatuagem e piercing': {
    staff_label: 'Profissional',
    services: [
      { name: 'Tatuagem pequena', duration_min: 60, price: 250 },
      { name: 'Tatuagem média', duration_min: 180, price: 600 },
      { name: 'Piercing', duration_min: 30, price: 80 },
      { name: 'Orçamento presencial', duration_min: 30, price: 0 },
    ],
    hours: EVENING_HOURS,
  },
  'Psicologia': {
    staff_label: 'Profissional',
    services: [
      { name: 'Sessão individual', duration_min: 50, price: 180 },
      { name: 'Primeira consulta', duration_min: 60, price: 220 },
      { name: 'Terapia de casal', duration_min: 60, price: 250 },
    ],
    hours: CLINIC_HOURS,
  },
  'Nutrição': {
    staff_label: 'Profissional',
    services: [
      { name: 'Consulta inicial', duration_min: 60, price: 200 },
      { name: 'Retorno', duration_min: 45, price: 150 },
      { name: 'Avaliação de bioimpedância', duration_min: 30, price: 100 },
    ],
    hours: CLINIC_HOURS,
  },
  'Fisioterapia': {
    staff_label: 'Profissional',
    services: [
      { name: 'Sessão de fisioterapia', duration_min: 50, price: 150 },
      { name: 'Avaliação postural', duration_min: 60, price: 180 },
      { name: 'Pilates clínico', duration_min: 50, price: 130 },
    ],
    hours: CLINIC_HOURS,
  },
  'Personal trainer': {
    staff_label: 'Profissional',
    services: [
      { name: 'Treino individual', duration_min: 60, price: 100 },
      { name: 'Avaliação física', duration_min: 60, price: 150 },
      { name: 'Treino em dupla', duration_min: 60, price: 150 },
    ],
    hours: EVENING_HOURS,
  },
  'Pilates e yoga': {
    staff_label: 'Sala',
    services: [
      { name: 'Aula de pilates', duration_min: 50, price: 90 },
      { name: 'Aula de yoga', duration_min: 60, price: 80 },
      { name: 'Aula experimental', duration_min: 50, price: 0 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Odontologia': {
    staff_label: 'Profissional',
    services: [
      { name: 'Consulta de rotina', duration_min: 30, price: 150 },
      { name: 'Limpeza', duration_min: 45, price: 180 },
      { name: 'Clareamento', duration_min: 60, price: 400 },
      { name: 'Avaliação ortodôntica', duration_min: 30, price: 100 },
    ],
    hours: CLINIC_HOURS,
  },
  'Banho e tosa': {
    staff_label: 'Profissional',
    services: [
      { name: 'Banho (porte pequeno)', duration_min: 45, price: 60 },
      { name: 'Banho + tosa higiênica', duration_min: 75, price: 90 },
      { name: 'Tosa na tesoura', duration_min: 90, price: 150 },
      { name: 'Hidratação', duration_min: 30, price: 40 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Veterinário': {
    staff_label: 'Profissional',
    services: [
      { name: 'Consulta', duration_min: 30, price: 150 },
      { name: 'Vacinação', duration_min: 20, price: 80 },
      { name: 'Castração', duration_min: 90, price: 500 },
    ],
    hours: CLINIC_HOURS,
  },
  'Aulas particulares': {
    staff_label: 'Professor',
    services: [
      { name: 'Aula avulsa', duration_min: 60, price: 80 },
      { name: 'Aula em dupla', duration_min: 60, price: 120 },
      { name: 'Aula online', duration_min: 60, price: 70 },
    ],
    hours: EVENING_HOURS,
  },
  'Aulas de música': {
    staff_label: 'Professor',
    services: [
      { name: 'Aula de instrumento', duration_min: 50, price: 100 },
      { name: 'Aula de canto', duration_min: 50, price: 100 },
      { name: 'Aula experimental', duration_min: 30, price: 0 },
    ],
    hours: EVENING_HOURS,
  },
  'Idiomas': {
    staff_label: 'Professor',
    services: [
      { name: 'Aula individual', duration_min: 60, price: 80 },
      { name: 'Conversação', duration_min: 60, price: 70 },
      { name: 'Aula experimental', duration_min: 45, price: 0 },
    ],
    hours: EVENING_HOURS,
  },
  'Autoescola / instrutor': {
    staff_label: 'Instrutor',
    services: [
      { name: 'Aula prática', duration_min: 50, price: 90 },
      { name: 'Aula noturna', duration_min: 50, price: 110 },
      { name: 'Simulação de prova', duration_min: 60, price: 120 },
    ],
    hours: EVENING_HOURS,
  },
  'Lava-jato': {
    staff_label: 'Box',
    services: [
      { name: 'Lavagem simples', duration_min: 30, price: 40 },
      { name: 'Lavagem completa', duration_min: 60, price: 80 },
      { name: 'Enceramento', duration_min: 90, price: 150 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Estética automotiva': {
    staff_label: 'Box',
    services: [
      { name: 'Polimento', duration_min: 180, price: 400 },
      { name: 'Cristalização', duration_min: 240, price: 600 },
      { name: 'Higienização interna', duration_min: 180, price: 350 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Oficina mecânica': {
    staff_label: 'Box',
    services: [
      { name: 'Troca de óleo', duration_min: 30, price: 150 },
      { name: 'Revisão', duration_min: 120, price: 400 },
      { name: 'Diagnóstico', duration_min: 60, price: 100 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Quadra esportiva': {
    staff_label: 'Quadra',
    services: [
      { name: 'Aluguel 1h', duration_min: 60, price: 80 },
      { name: 'Aluguel 2h', duration_min: 120, price: 150 },
    ],
    hours: FULL_WEEK_HOURS,
  },
  'Sala / coworking': {
    staff_label: 'Sala',
    services: [
      { name: 'Reserva 1h', duration_min: 60, price: 40 },
      { name: 'Reserva 4h', duration_min: 240, price: 120 },
      { name: 'Day pass', duration_min: 480, price: 180 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Estúdio de fotografia': {
    staff_label: 'Sala',
    services: [
      { name: 'Ensaio 1h', duration_min: 60, price: 300 },
      { name: 'Ensaio 2h', duration_min: 120, price: 500 },
      { name: 'Ensaio book completo', duration_min: 180, price: 800 },
    ],
    hours: BUSINESS_HOURS,
  },
  'Estúdio de gravação': {
    staff_label: 'Sala',
    services: [
      { name: 'Hora de estúdio', duration_min: 60, price: 150 },
      { name: 'Pacote 4h', duration_min: 240, price: 500 },
      { name: 'Mixagem', duration_min: 120, price: 300 },
    ],
    hours: EVENING_HOURS,
  },
  'Diarista': {
    staff_label: 'Profissional',
    services: [
      { name: 'Diária 4h', duration_min: 240, price: 150 },
      { name: 'Diária 8h', duration_min: 480, price: 250 },
      { name: 'Faxina pesada', duration_min: 480, price: 350 },
    ],
    hours: BUSINESS_HOURS,
  },
}

// Template vazio pra "Outro" ou pra quem quer começar do zero.
export const EMPTY_TEMPLATE = {
  staff_label: 'Profissional',
  services: [],
  hours: BUSINESS_HOURS,
}

export function templateFor(category) {
  return TEMPLATES[category] ?? EMPTY_TEMPLATE
}
