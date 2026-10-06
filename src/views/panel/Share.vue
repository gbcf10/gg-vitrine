<script setup>
import { ref, computed, onMounted } from 'vue'
import QRCode from 'qrcode'
import { useBusiness } from '@/lib/business'
import { APP_NAME } from '@/config/brand'
import Icon from '@/components/Icon.vue'

const biz = useBusiness()
const link = computed(() => `${location.origin}/${biz.business.slug}`)
const linkShort = computed(() => link.value.replace(/^https?:\/\//, ''))
const qr = ref('')
const copied = ref(false)
const bioCopied = ref(false)
const cta = 'Agendar'

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

async function copyBio() {
  await navigator.clipboard.writeText(bioText.value)
  bioCopied.value = true
  setTimeout(() => { bioCopied.value = false }, 2000)
}

const shareText = computed(() => `${cta} com ${biz.business.name} pelo link: ${link.value}`)
const whatsappShare = computed(() => `https://wa.me/?text=${encodeURIComponent(shareText.value)}`)
const bioText = computed(() => `${cta} aqui 👇\n${link.value}`)

const SPOTS = [
  { icon: 'instagram', label: 'Bio do Instagram' },
  { icon: 'whatsapp', label: 'Mensagem automática do WhatsApp Business' },
  { icon: 'map', label: 'Google Meu Negócio' },
  { icon: 'idcard', label: 'Cartão de visita' },
  { icon: 'store', label: 'Cartaz no balcão' },
  { icon: 'facebook', label: 'Perfil do Facebook' },
]

function printPoster() {
  window.print()
}
</script>

<template>
  <div class="page-header no-print sh-header">
    <p class="eyebrow sh-eyebrow">Divulgação</p>
    <h1>Divulgar sua vitrine</h1>
    <p class="muted sh-lede">
      Compartilhe seu link em todo lugar — WhatsApp, Instagram, cartão de visita, cartaz na parede. Quanto mais pessoas virem, mais agendamentos você recebe.
    </p>
  </div>

  <div class="no-print sh-grid">
    <!-- Card do link -->
    <section class="sh-card">
      <div class="section-head">
        <span class="section-badge"><Icon name="link" /></span>
        <div>
          <h3>Seu link público</h3>
          <small class="muted">É o mesmo link pra tudo. Clientes clicam, escolhem o horário e pronto.</small>
        </div>
      </div>

      <div class="sh-urlbar">
        <span class="sh-dots" aria-hidden="true"><span /><span /><span /></span>
        <code class="sh-url">
          <span class="sh-url-host">{{ linkShort.split('/')[0] }}/</span><strong>{{ linkShort.split('/').slice(1).join('/') }}</strong>
        </code>
      </div>

      <div class="sh-actions">
        <button class="btn sh-action primary" @click="copy">
          <Icon :name="copied ? 'check' : 'copy'" />
          {{ copied ? 'Copiado!' : 'Copiar link' }}
        </button>
        <a class="btn secondary sh-action" :href="whatsappShare" target="_blank" rel="noopener">
          <Icon name="whatsapp" />
          WhatsApp
        </a>
        <a class="btn secondary sh-action" :href="link" target="_blank" rel="noopener">
          <Icon name="globe" />
          Abrir
        </a>
      </div>

      <div class="sh-bio">
        <div class="sh-bio-head">
          <span class="sh-bio-label"><Icon name="instagram" /> Texto pronto pra bio</span>
          <button type="button" class="sh-bio-copy" @click="copyBio" :aria-label="bioCopied ? 'Copiado' : 'Copiar texto da bio'">
            <Icon :name="bioCopied ? 'check' : 'copy'" />
            {{ bioCopied ? 'Copiado' : 'Copiar' }}
          </button>
        </div>
        <pre class="sh-bio-text">{{ bioText }}</pre>
      </div>

      <div class="sh-spots">
        <small class="muted sh-spots-title">Onde colar o link:</small>
        <div class="sh-spots-list">
          <span v-for="s in SPOTS" :key="s.label" class="sh-spot">
            <Icon :name="s.icon" />
            {{ s.label }}
          </span>
        </div>
      </div>
    </section>

    <!-- Card do QR Code -->
    <section class="sh-card sh-card-qr">
      <div class="section-head">
        <span class="section-badge"><Icon name="qr" /></span>
        <div>
          <h3>QR Code</h3>
          <small class="muted">Aponte a câmera e abre direto. Perfeito pra deixar impresso.</small>
        </div>
      </div>

      <div class="sh-qr-stage">
        <div class="sh-qr-frame">
          <strong class="sh-qr-biz">{{ biz.business.name }}</strong>
          <img v-if="qr" :src="qr" :alt="`QR Code de ${biz.business.name}`" class="sh-qr" />
          <small class="sh-qr-hint">Aponte a câmera do celular</small>
        </div>
      </div>

      <div class="sh-actions">
        <a v-if="qr" class="btn sh-action primary" :href="qr" :download="`qrcode-${biz.business.slug}.png`">
          <Icon name="image" />
          Baixar PNG
        </a>
        <button class="btn secondary sh-action" @click="printPoster">
          <Icon name="clipboard" />
          Imprimir cartaz
        </button>
      </div>
      <p class="muted sh-qr-note">Deixe no balcão, na mesa, na vitrine ou no cartão de visita.</p>
    </section>
  </div>

  <!-- Cartaz para impressão -->
  <div class="poster">
    <img v-if="biz.business.logo_url" :src="biz.business.logo_url" alt="" class="poster-logo" />
    <h1>{{ biz.business.name }}</h1>
    <p class="poster-cta">{{ cta }} pelo celular</p>
    <img v-if="qr" :src="qr" alt="" class="poster-qr" />
    <p class="poster-hint">Aponte a câmera do celular para o código</p>
    <p class="poster-link">{{ linkShort }}</p>
    <small>{{ APP_NAME }}</small>
  </div>
</template>

<style scoped>
/* ===== Header ===== */
.sh-eyebrow { display: inline-block; margin-bottom: 6px; }
.sh-lede { font-size: 0.95rem; max-width: 600px; margin: 4px 0 0; }

/* ===== Grid ===== */
.sh-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr);
  gap: 16px;
  align-items: start;
}

/* ===== Cards ===== */
.sh-card {
  padding: 22px;
  border-radius: var(--radius);
  background:
    radial-gradient(ellipse 320px 180px at 100% 0%, var(--brand-soft), transparent 65%),
    var(--surface);
  border: 1px solid var(--border);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  box-shadow: 0 0 24px rgba(59, 130, 246, 0.06);
}

.section-head { display: flex; align-items: center; gap: 12px; margin-bottom: 18px; }
.section-badge {
  width: 40px; height: 40px; border-radius: 12px; flex-shrink: 0;
  display: grid; place-items: center;
  background: linear-gradient(140deg, var(--brand), var(--brand-strong));
  color: #fff;
  box-shadow: 0 0 18px var(--brand-glow);
}
.section-badge :deep(svg) { width: 18px; height: 18px; }
.section-head h3 { margin: 0; font-size: 1.1rem; font-weight: 700; letter-spacing: -0.01em; }
.section-head small { display: block; font-size: 0.85rem; margin-top: 2px; }

/* ===== URL bar ===== */
.sh-urlbar {
  display: flex; align-items: center; gap: 12px;
  padding: 12px 16px;
  border-radius: 12px;
  background: rgba(5, 11, 22, 0.6);
  border: 1px solid var(--border);
  margin-bottom: 12px;
  overflow: hidden;
}
.sh-dots { display: inline-flex; gap: 5px; flex-shrink: 0; }
.sh-dots span {
  width: 10px; height: 10px; border-radius: 50%;
  background: rgba(148, 180, 220, 0.3);
}
.sh-dots span:nth-child(1) { background: rgba(248, 113, 113, 0.6); }
.sh-dots span:nth-child(2) { background: rgba(251, 191, 36, 0.6); }
.sh-dots span:nth-child(3) { background: rgba(74, 222, 128, 0.6); }
.sh-url {
  flex: 1; min-width: 0;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.95rem;
  background: none; padding: 0;
  color: var(--muted);
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.sh-url-host { color: var(--muted); }
.sh-url strong { color: var(--brand-ink); font-weight: 700; }

/* ===== Action buttons ===== */
.sh-actions { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 4px; }
.sh-action { min-height: 44px; padding: 10px 16px; font-weight: 600; }
.sh-action :deep(svg) { width: 16px; height: 16px; }

/* ===== Bio copy block ===== */
.sh-bio {
  margin-top: 22px;
  border-radius: 12px;
  background: rgba(5, 11, 22, 0.55);
  border: 1px solid var(--border);
  overflow: hidden;
}
.sh-bio-head {
  display: flex; align-items: center; justify-content: space-between;
  gap: 10px; padding: 10px 14px;
  border-bottom: 1px solid var(--border);
  background: var(--surface);
}
.sh-bio-label {
  display: inline-flex; align-items: center; gap: 6px;
  color: var(--brand-ink); font-size: 0.78rem; font-weight: 700;
  letter-spacing: 0.04em; text-transform: uppercase;
}
.sh-bio-label :deep(svg) { width: 14px; height: 14px; }
.sh-bio-copy {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 5px 10px;
  border-radius: 8px;
  background: var(--surface-strong);
  border: 1px solid var(--border);
  color: var(--silver);
  font: inherit; font-size: 0.78rem; font-weight: 600;
  cursor: pointer;
  transition: border-color 0.15s ease, color 0.15s ease;
}
.sh-bio-copy:hover { border-color: var(--brand); color: var(--brand-ink); }
.sh-bio-copy :deep(svg) { width: 12px; height: 12px; }
.sh-bio-text {
  margin: 0; padding: 14px;
  font-family: 'SF Mono', Menlo, Consolas, monospace;
  font-size: 0.9rem; line-height: 1.6;
  color: var(--text);
  white-space: pre-wrap; word-break: break-word;
}

/* ===== Spots chips ===== */
.sh-spots { margin-top: 22px; }
.sh-spots-title { display: block; margin-bottom: 10px; font-size: 0.82rem; }
.sh-spots-list { display: flex; flex-wrap: wrap; gap: 6px; }
.sh-spot {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 6px 12px;
  border-radius: 999px;
  background: var(--brand-soft);
  border: 1px solid rgba(59, 130, 246, 0.25);
  color: var(--silver);
  font-size: 0.78rem; font-weight: 500;
}
.sh-spot :deep(svg) { width: 13px; height: 13px; color: var(--brand-ink); }

/* ===== QR Card ===== */
.sh-card-qr { text-align: left; }
.sh-qr-stage {
  display: flex; justify-content: center;
  margin: 4px 0 18px;
}
.sh-qr-frame {
  width: 100%; max-width: 300px;
  padding: 20px 20px 16px;
  border-radius: 20px;
  background:
    radial-gradient(ellipse 220px 160px at 50% 0%, rgba(255, 255, 255, 0.9), #ffffff 70%);
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.45), 0 0 32px var(--brand-glow);
  text-align: center;
  position: relative;
}
.sh-qr-frame::before {
  content: '';
  position: absolute; inset: -1px;
  border-radius: 20px;
  padding: 1px;
  background: linear-gradient(135deg, var(--brand), transparent 50%, var(--brand-strong));
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
.sh-qr-biz {
  display: block;
  font-size: 1rem; font-weight: 800;
  letter-spacing: -0.01em;
  color: #0b1220;
  margin-bottom: 10px;
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.sh-qr { width: 100%; max-width: 220px; aspect-ratio: 1; display: block; margin: 0 auto; }
.sh-qr-hint {
  display: block;
  margin-top: 10px;
  font-size: 0.76rem; font-weight: 600;
  color: #475569;
}
.sh-qr-note { font-size: 0.82rem; margin: 12px 0 0; line-height: 1.5; }

/* ===== Poster print ===== */
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

/* ===== Responsive ===== */
@media (max-width: 900px) {
  .sh-grid { grid-template-columns: 1fr; }
}
@media (max-width: 640px) {
  .sh-card { padding: 18px; }
  .sh-urlbar { padding: 10px 12px; gap: 10px; }
  .sh-url { font-size: 0.85rem; }
  .sh-action { flex: 1; justify-content: center; min-width: 0; padding: 10px 12px; }
  .sh-qr-frame { max-width: 100%; }
  .sh-qr { max-width: 200px; }
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
