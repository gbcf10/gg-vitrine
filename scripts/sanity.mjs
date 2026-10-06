import pg from 'pg'
const c = new pg.Client({ connectionString: process.env.PG_URL })
await c.connect()
for (const q of [
  `select id, name, base_price, max_businesses from plans order by sort_order`,
  `select count(*) from businesses`,
  `select count(*) from subscriptions`,
  `select proname from pg_proc where proname in ('request_business','choose_plan','admin_list_businesses','business_is_live','handle_new_user','billing_webhook','get_public_business','billing_quote') order by proname`,
]) {
  const r = await c.query(q)
  console.log('>', q.split('\n')[0])
  console.table(r.rows)
}
await c.end()
