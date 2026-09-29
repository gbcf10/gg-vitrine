<script setup>
import { ref, computed, onMounted } from 'vue'
import QRCode from 'qrcode'
import { useBusiness } from '@/lib/business'
import { KINDS, APP_NAME } from '@/config/brand'
import { waLink } from '@/lib/whatsapp'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const link = computed(() => `${location.origin}/${biz.business.slug}`)
const qr = ref('')
const copied = ref(false)
const cta = computed(() => KINDS[biz.business.kind]?.action ?? 'Acesse')

onMounted(async () => {
  qr.value = await QRCode.toDataURL(link.value, {
    width: 720, margin: 1, errorCorrectionLevel: 'M',
    color: { dark: '#050b16', light: '#ffffff' },
  })
})

async function copy() {
  await navigator.clipboard.writeText(link.value)
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

const shareText = computed(() => `${cta.value} com ${biz.business.name} pelo link: ${link.value}`)
const whatsappShare = computed(() => `https://wa.me/?text=${encodeURIComponent(shareText.value)}`)
const bioText = computed(() => `${cta.value} aqui 👇\n${link.value}`)

function printPoster() {
  window.print()
}
</script>

<template>
  <div class="page-header no-print"><p class="eyebrow">Extras</p><h1>Divulgar sua vitrine</h1></div>

  <div class="grid no-print" style="grid-template-columns: repeat(auto-fit, minmax(280px, 1fr))">
    <div class="card" style="margin: 0">
      <h3>Seu link</h3>
      <div class="link-box">{{ link }}</div>
      <div class="chips" style="margin-top: 12px">
        <button class="btn" @click="copy"><Icon name="link" style="width: 16px; height: 16px" />{{ copied ? 'Copiado!' : 'Copiar link' }}</button>
        <a class="btn secondary" :href="whatsappShare" target="_blank" rel="noopener"><Icon name="whatsapp" style="width: 16px; height: 16px" />Enviar no WhatsApp</a>
        <a class="btn secondary" :href="link" target="_blank" rel="noopener">Abrir</a>
      </div>
      <h3 style="margin-top: 22px">Texto para a bio do Instagram</h3>
      <textarea :value="bioText" rows="2" readonly @focus="$event.target.select()" />
      <p class="muted" style="font-size: 0.85rem; margin-top: 10px">
        Dica: coloque o link na bio do Instagram, na mensagem automática do WhatsApp Business e no Google Meu Negócio.
      </p>
    </div>

    <div class="card" style="margin: 0; text-align: center">
      <h3>QR Code</h3>
      <img v-if="qr" :src="qr" alt="QR Code da vitrine" class="qr" />
      <div class="chips" style="justify-content: center; margin-top: 12px">
        <a v-if="qr" class="btn" :href="qr" :download="`qrcode-${biz.business.slug}.png`">Baixar imagem</a>
        <button class="btn secondary" @click="printPoster">Imprimir cartaz</button>
      </div>
      <p class="muted" style="font-size: 0.85rem; margin-top: 10px">Deixe no balcão, na mesa, na vitrine ou no cartão de visita.</p>
    </div>
  </div>

  <!-- Cartaz para impressão -->
  <div class="poster">
    <img v-if="biz.business.logo_url" :src="biz.business.logo_url" alt="" class="poster-logo" />
    <h1>{{ biz.business.name }}</h1>
    <p class="poster-cta">{{ cta }} pelo celular</p>
    <img v-if="qr" :src="qr" alt="" class="poster-qr" />
    <p class="poster-hint">Aponte a câmera do celular para o código</p>
    <p class="poster-link">{{ link.replace(/^https?:\/\//, '') }}</p>
    <small>{{ APP_NAME }}</small>
  </div>
</template>

<style scoped>
.link-box { padding: 12px 14px; border-radius: var(--radius-sm); background: var(--input); border: 1px solid var(--border); word-break: break-all; font-weight: 600; }
.qr { width: 240px; max-width: 100%; border-radius: 14px; background: #fff; padding: 10px; }
.poster { display: none; }

@media print {
  .poster {
    display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center;
    min-height: 95vh; color: #0b1220; font-family: 'Inter', sans-serif;
  }
  .poster h1 { font-size: 42px; margin: 12px 0 4px; color: #0b1220; }
  .poster-logo { width: 110px; height: 110px; object-fit: cover; border-radius: 24px; }
  .poster-cta { font-size: 28px; font-weight: 700; margin: 0 0 24px; }
  .poster-qr { width: 360px; height: 360px; }
  .poster-hint { font-size: 18px; margin: 18px 0 4px; }
  .poster-link { font-size: 20px; font-weight: 700; }
  .poster small { color: #555; margin-top: 16px; }
}
</style>

<style>
/* Na impressão, esconde o painel e deixa só o cartaz. */
@media print {
  body { background: #fff !important; }
  .sidebar, .no-print { display: none !important; }
  .app-shell { display: block !important; }
  .main { padding: 0 !important; }
}
</style>
