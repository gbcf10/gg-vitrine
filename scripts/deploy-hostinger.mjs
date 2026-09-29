// Publica o site na Hostinger: gera o build e envia a pasta dist/ por SSH.
//
// Uso:  npm run deploy
//
// Precisa de um arquivo .env.deploy na raiz do projeto (não vai para o git):
//   HOSTINGER_HOST=IP_DO_SERVIDOR        (hPanel > Avançado > Acesso SSH)
//   HOSTINGER_USER=u123456789
//   HOSTINGER_PORT=65002
//   HOSTINGER_PATH=domains/ggvitrine.com.br/public_html
//
// Na primeira vez, cadastre sua chave SSH no hPanel (Acesso SSH > Chaves SSH)
// ou digite a senha SSH quando for pedida.
import { execSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'

const FILE = '.env.deploy'
if (!existsSync(FILE)) {
  console.error(`Crie o arquivo ${FILE} (veja as instruções no topo de scripts/deploy-hostinger.mjs).`)
  process.exit(1)
}

const env = Object.fromEntries(readFileSync(FILE, 'utf8').split(/\r?\n/)
  .map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))
  .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]))

const { HOSTINGER_HOST: host, HOSTINGER_USER: user, HOSTINGER_PORT: port = '65002', HOSTINGER_PATH: path } = env
if (!host || !user || !path) {
  console.error('Preencha HOSTINGER_HOST, HOSTINGER_USER e HOSTINGER_PATH no .env.deploy.')
  process.exit(1)
}

const run = (cmd) => execSync(cmd, { stdio: 'inherit', shell: true })

console.log('\n1/2 Gerando o build...')
run('npm run build')

console.log(`\n2/2 Enviando para ${user}@${host}:${path} ...`)
// Remove os arquivos antigos de assets (nomes com hash) e extrai o build novo, incluindo o .htaccess.
const remote = `mkdir -p ${path} && rm -rf ${path}/assets && tar -xzf - -C ${path}`
run(`tar -czf - -C dist . | ssh -p ${port} ${user}@${host} "${remote}"`)

console.log('\nPronto! Site publicado.')
