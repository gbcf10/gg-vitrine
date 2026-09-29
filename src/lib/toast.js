import { reactive } from 'vue'

// Avisos rápidos no canto da tela ("Salvo com sucesso", etc.).
export const toasts = reactive([])
let nextId = 1

export function toast(message, type = 'success', ms = 2600) {
  // Evita repetir o mesmo aviso quando um "salvar" faz várias gravações seguidas.
  if (toasts.some((t) => t.message === message)) return
  const id = nextId++
  toasts.push({ id, message, type })
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === id)
    if (i >= 0) toasts.splice(i, 1)
  }, ms)
}
