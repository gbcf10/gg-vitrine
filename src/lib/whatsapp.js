// Número no formato do wa.me (só dígitos, com DDI 55 do Brasil).
export function waNumber(phone) {
  let digits = (phone ?? '').replace(/\D/g, '')
  if (!digits) return null
  if (!(digits.startsWith('55') && digits.length >= 12)) digits = '55' + digits
  return digits
}

export function waLink(phone, text = '') {
  const number = waNumber(phone)
  if (!number) return null
  return `https://wa.me/${number}${text ? `?text=${encodeURIComponent(text)}` : ''}`
}

export function openWhatsApp(phone, text) {
  const url = waLink(phone, text)
  if (url) window.open(url, '_blank', 'noopener')
  return Boolean(url)
}
