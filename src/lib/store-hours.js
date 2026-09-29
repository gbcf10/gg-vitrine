import { WEEKDAYS } from './format'

// "Agora" no fuso da loja: dia da semana (0 = domingo) e minutos desde 00:00.
function nowIn(tz) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(new Date())
  const p = Object.fromEntries(parts.map((x) => [x.type, x.value]))
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(p.weekday)
  return { weekday, minutes: Number(p.hour) * 60 + Number(p.minute) }
}

const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5))

// hours: [{ weekday, start: 'HH:MM:SS', end: 'HH:MM:SS' }]. Fechamento antes
// da abertura significa que o turno vira a noite (ex.: 18:00–01:00).
export function isOpenNow(hours, tz) {
  const now = nowIn(tz)
  return hours.some((h) => {
    const start = toMin(h.start)
    const end = toMin(h.end)
    if (end > start) return h.weekday === now.weekday && now.minutes >= start && now.minutes < end
    return (h.weekday === now.weekday && now.minutes >= start) ||
           ((h.weekday + 1) % 7 === now.weekday && now.minutes < end)
  })
}

// Texto da próxima abertura, ex.: "hoje às 18:00" ou "sábado às 18:00".
export function nextOpening(hours, tz) {
  if (!hours.length) return null
  const now = nowIn(tz)
  for (let offset = 0; offset < 8; offset++) {
    const day = (now.weekday + offset) % 7
    const starts = hours
      .filter((h) => h.weekday === day)
      .map((h) => toMin(h.start))
      .filter((m) => offset > 0 || m > now.minutes)
      .sort((a, b) => a - b)
    if (starts.length) {
      const hhmm = `${String(Math.floor(starts[0] / 60)).padStart(2, '0')}:${String(starts[0] % 60).padStart(2, '0')}`
      const when = offset === 0 ? 'hoje' : offset === 1 ? 'amanhã' : WEEKDAYS[day].toLowerCase()
      return `${when} às ${hhmm}`
    }
  }
  return null
}

// Resumo dos horários para exibir, agrupado por dia.
export function hoursSummary(hours) {
  return WEEKDAYS.map((name, weekday) => ({
    name,
    ranges: hours.filter((h) => h.weekday === weekday).map((h) => `${h.start.slice(0, 5)}–${h.end.slice(0, 5)}`),
  })).filter((d) => d.ranges.length)
}
