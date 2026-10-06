// Aplica todas as migrations em ordem usando pg direto.
// Uso: PG_URL='postgresql://...' node scripts/apply-migrations.mjs
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import pg from 'pg'

const url = process.env.PG_URL
if (!url) {
  console.error('Falta PG_URL')
  process.exit(1)
}

const dir = new URL('../supabase/migrations/', import.meta.url).pathname
const only = process.env.ONLY?.split(',')
const files = readdirSync(dir).filter((f) => f.endsWith('.sql') && (!only || only.some((o) => f.includes(o)))).sort()

const client = new pg.Client({ connectionString: url })
await client.connect()
console.log('Conectado.')

for (const f of files) {
  const sql = readFileSync(join(dir, f), 'utf8')
  process.stdout.write(`▶ ${f} ... `)
  try {
    await client.query(sql)
    console.log('ok')
  } catch (e) {
    console.log('ERRO')
    console.error(e.message)
    process.exit(1)
  }
}

await client.end()
console.log('✓ Todas as migrations aplicadas.')
