export const DEFAULT_TZ = 'America/Sao_Paulo'
export const WEEKDAYS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']

export function money(value) {
  return Number(value ?? 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
}

export function formatTime(iso, tz = DEFAULT_TZ) {
  return new Date(iso).toLocaleTimeString('pt-BR', { timeZone: tz, hour: '2-digit', minute: '2-digit' })
}

export function formatDate(iso, tz = DEFAULT_TZ, opts = { day: '2-digit', month: '2-digit', year: 'numeric' }) {
  return new Date(iso).toLocaleDateString('pt-BR', { timeZone: tz, ...opts })
}

export function formatDateTime(iso, tz = DEFAULT_TZ) {
  return `${formatDate(iso, tz, { weekday: 'short', day: '2-digit', month: '2-digit' })} às ${formatTime(iso, tz)}`
}

// 'YYYY-MM-DD' de hoje no fuso informado.
export function todayISO(tz = DEFAULT_TZ) {
  return new Date().toLocaleDateString('en-CA', { timeZone: tz })
}

export function addDaysISO(dateStr, days) {
  const [y, m, d] = dateStr.split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10)
}

function tzOffsetMinutes(date, tz) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, hourCycle: 'h23',
    year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(date)
  const p = Object.fromEntries(parts.map((x) => [x.type, Number(x.value)]))
  return (Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second) - date.getTime()) / 60000
}

// Data + hora "de parede" no fuso do estabelecimento -> Date (instante UTC).
export function zonedToUtc(dateStr, timeStr, tz = DEFAULT_TZ) {
  const [y, mo, d] = dateStr.split('-').map(Number)
  const [h, mi] = timeStr.split(':').map(Number)
  const guess = new Date(Date.UTC(y, mo - 1, d, h, mi))
  return new Date(guess.getTime() - tzOffsetMinutes(guess, tz) * 60000)
}

export function slugify(text) {
  return text
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')
    .slice(0, 50)
}

export const APPOINTMENT_STATUS = {
  scheduled: 'Agendado',
  confirmed: 'Confirmado',
  completed: 'Concluído',
  canceled: 'Cancelado',
  no_show: 'Não compareceu',
}

export const BUSINESS_STATUS = {
  pending: 'Em análise',
  approved: 'Aprovado',
  rejected: 'Recusado',
  blocked: 'Bloqueado',
}

export const SUBSCRIPTION_STATUS = {
  pending_payment: 'Aguardando pagamento',
  active: 'Ativa',
  past_due: 'Pagamento atrasado',
  canceled: 'Cancelada',
}
