// Cor de destaque da plataforma (azul G&G).
export const PLATFORM_ACCENT = '#3b82f6'

function parse(hex) {
  const h = /^#[0-9a-f]{6}$/i.test(hex ?? '') ? hex : PLATFORM_ACCENT
  return [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16))
}

function luminance([r, g, b]) {
  const c = [r, g, b].map((v) => {
    v /= 255
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

const mix = (rgb, target, amount) => rgb.map((v, i) => Math.round(v + (target[i] - v) * amount))
const hex = (rgb) => '#' + rgb.map((v) => v.toString(16).padStart(2, '0')).join('')
const rgba = ([r, g, b], a) => `rgba(${r}, ${g}, ${b}, ${a})`

// Variáveis CSS derivadas da cor do estabelecimento. Garante contraste do
// texto sobre a cor e clareia cores muito escuras para uso como texto no fundo escuro.
export function brandVars(color) {
  const rgb = parse(color)
  const lum = luminance(rgb)
  const ink = lum < 0.12 ? mix(rgb, [255, 255, 255], 0.55) : rgb
  return {
    '--brand': hex(rgb),
    '--brand-strong': hex(mix(rgb, [0, 0, 0], 0.28)),
    '--brand-ink': hex(ink),
    '--brand-soft': rgba(rgb, 0.12),
    '--brand-glow': rgba(rgb, 0.45),
    '--brand-contrast': lum > 0.45 ? '#07101f' : '#ffffff',
  }
}
