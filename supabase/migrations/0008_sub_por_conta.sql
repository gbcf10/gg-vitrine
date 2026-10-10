-- =====================================================================
-- GG Vitrine — 0008: assinatura por conta + limite de estabelecimentos
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- Pode ser rodado de novo com segurança.
--
-- Antes:  cada estabelecimento tinha a própria assinatura (1 vitrine = 1 cobrança).
-- Depois: o dono paga 1 vez por mês e cadastra até N estabelecimentos conforme o plano.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Planos: 3 planos (Solo / Equipe / Rede) com limite de estabelecimentos
-- ---------------------------------------------------------------------
alter table plans add column if not exists max_businesses int not null default 1;

-- Migra assinaturas existentes pro novo plano "solo" antes de deletar os antigos.
insert into plans (id, name, base_price, max_professionals, max_customers, max_businesses, features, sort_order)
values ('solo', 'Solo', 29.90, null, null, 1, array[]::text[], 1)
on conflict (id) do nothing;
update subscriptions set plan_id = 'solo' where plan_id <> 'solo';
delete from plans where id <> 'solo';

insert into plans (id, name, base_price, max_professionals, max_customers, max_businesses, features, sort_order) values
  ('equipe', 'Equipe', 59.90,  null, null, 3, array[]::text[], 2),
  ('rede',   'Rede',   89.90, null, null, 5, array[]::text[], 3)
on conflict (id) do nothing;

-- Features são iguais nos 3 planos: tudo incluso.
update plans set
  max_professionals = null,
  max_customers     = null,
  features = array['agenda', 'servicos', 'horarios', 'clientes', 'agendamento_online',
                   'historico_agendamentos', 'multi_profissional', 'bloqueios', 'folgas',
                   'lembretes', 'galeria', 'avaliacoes', 'fidelidade', 'cupons', 'qrcode']
 where id in ('solo', 'equipe', 'rede');

-- ---------------------------------------------------------------------
-- subscriptions: muda de business_id pra owner_id
-- ---------------------------------------------------------------------
alter table subscriptions add column if not exists owner_id uuid references auth.users (id) on delete cascade;

-- Backfill: cada assinatura pertence ao dono do estabelecimento.
update subscriptions s set owner_id = b.created_by
  from businesses b where b.id = s.business_id and s.owner_id is null;

-- Se um usuário tiver mais de uma assinatura (vários estabelecimentos no modelo antigo),
-- mantém a mais recente e deleta as outras.
delete from subscriptions
 where id not in (
   select id from (
     select id, row_number() over (partition by owner_id order by created_at desc) as rn
       from subscriptions where owner_id is not null) t
   where rn = 1)
   and owner_id is not null;

-- Agora owner_id vira obrigatório e único; business_id pode ser removido (payments
-- continua apontando pra business_id de forma independente).
alter table subscriptions alter column owner_id set not null;

do $$ begin
  alter table subscriptions drop constraint subscriptions_business_id_key;
exception when undefined_object then null; end $$;

alter table subscriptions add constraint subscriptions_owner_id_key unique (owner_id);
-- Precisa dropar a policy antiga antes do column, porque ela referencia business_id.
drop policy if exists subscriptions_read on subscriptions;
drop policy if exists payments_read on payments;
alter table subscriptions drop column if exists business_id;

-- Payments: business_id passa a ser opcional (uma cobrança cobre a assinatura toda,
-- mas registramos qual estabelecimento foi aprovado no momento do pagamento).
alter table payments alter column business_id drop not null;

-- ---------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------
drop policy if exists subscriptions_read on subscriptions;
create policy subscriptions_read on subscriptions for select
  using (owner_id = auth.uid() or is_platform_admin());

drop policy if exists payments_read on payments;
create policy payments_read on payments for select
  using (exists (select 1 from subscriptions s
                  where s.id = payments.subscription_id and s.owner_id = auth.uid())
         or is_platform_admin());

-- ---------------------------------------------------------------------
-- business_is_live: assinatura é do dono, cobre todos os estabelecimentos dele
-- ---------------------------------------------------------------------
create or replace function business_is_live(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from businesses b
    join subscriptions s on s.owner_id = b.created_by
    where b.id = bid and b.status = 'approved'
      and (s.status in ('active', 'past_due')
           or (s.status = 'canceled' and s.current_period_end > now())))
$$;

-- ---------------------------------------------------------------------
-- request_business: enforce limite do plano
-- ---------------------------------------------------------------------
drop function if exists request_business(text, text, text, text, text);
drop function if exists request_business(text, text, text, text);
create function request_business(p_name text, p_slug text, p_category text default null,
                                 p_phone text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id    uuid;
  v_count int;
  v_sub   subscriptions;
  v_max   int;
begin
  if auth.uid() is null then
    raise exception 'Faça login primeiro.';
  end if;
  select count(*) into v_count from businesses where created_by = auth.uid();
  -- A primeira vitrine é sempre liberada (pra o usuário poder assinar depois).
  if v_count >= 1 then
    select * into v_sub from subscriptions where owner_id = auth.uid();
    if v_sub.id is null or v_sub.status not in ('active', 'past_due', 'pending_payment') then
      raise exception 'Assine um plano antes de cadastrar outra vitrine.';
    end if;
    select max_businesses into v_max from plans where id = v_sub.plan_id;
    if v_count >= v_max then
      raise exception 'Seu plano permite até % estabelecimento(s). Faça upgrade para cadastrar mais.', v_max;
    end if;
  end if;
  insert into businesses (name, slug, category, phone, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_category, p_phone, auth.uid())
  returning id into v_id;
  insert into business_members (business_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- choose_plan: agora é por dono (não precisa mais do p_business)
-- ---------------------------------------------------------------------
drop function if exists choose_plan(uuid, text);
drop function if exists choose_plan(text);
create function choose_plan(p_plan text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_sub   subscriptions;
  v_count int;
  v_max   int;
begin
  if auth.uid() is null then
    raise exception 'Faça login primeiro.';
  end if;
  if not exists (select 1 from plans where id = p_plan) then
    raise exception 'Plano inválido.';
  end if;
  select count(*) into v_count from businesses where created_by = auth.uid();
  select max_businesses into v_max from plans where id = p_plan;
  if v_count > v_max then
    raise exception 'Você tem % vitrine(s) e o plano escolhido permite até %. Remova alguma antes.', v_count, v_max;
  end if;
  select * into v_sub from subscriptions where owner_id = auth.uid();
  if not found then
    insert into subscriptions (owner_id, plan_id) values (auth.uid(), p_plan);
  elsif v_sub.status in ('pending_payment', 'canceled') then
    update subscriptions
       set plan_id = p_plan, status = 'pending_payment', gateway_subscription_id = null
     where id = v_sub.id;
  else
    update subscriptions set plan_id = p_plan where id = v_sub.id;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Admin: p_business → p_owner. A UI do admin passa o owner_id de dono.
-- ---------------------------------------------------------------------
drop function if exists admin_update_subscription(uuid, text, numeric, numeric, date, text);
create function admin_update_subscription(p_owner uuid, p_plan text, p_custom_price numeric,
                                          p_discount_amount numeric, p_discount_until date,
                                          p_discount_note text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  if not exists (select 1 from plans where id = p_plan) then
    raise exception 'Plano inválido.';
  end if;
  update subscriptions
     set plan_id         = p_plan,
         custom_price    = p_custom_price,
         discount_amount = coalesce(p_discount_amount, 0),
         discount_until  = p_discount_until,
         discount_note   = p_discount_note
   where owner_id = p_owner;
  if not found then
    insert into subscriptions (owner_id, plan_id, custom_price, discount_amount, discount_until, discount_note)
    values (p_owner, p_plan, p_custom_price, coalesce(p_discount_amount, 0), p_discount_until, p_discount_note);
  end if;
end $$;

drop function if exists admin_register_payment(uuid, numeric, int, text, text);
create function admin_register_payment(p_owner uuid, p_amount numeric, p_months int default 1,
                                       p_method text default 'manual', p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_sub subscriptions;
begin
  perform assert_platform_admin();
  select * into v_sub from subscriptions where owner_id = p_owner;
  if not found then
    raise exception 'Essa conta ainda não escolheu um plano.';
  end if;
  insert into payments (subscription_id, amount, status, method, paid_at, note)
  values (v_sub.id, p_amount, 'paid', p_method, now(), p_note);
  update subscriptions
     set status = 'active',
         current_period_end = greatest(coalesce(current_period_end, now()), now())
                              + make_interval(months => greatest(p_months, 1))
   where id = v_sub.id;
  -- Reativa todos os estabelecimentos do dono.
  update businesses set status = 'approved', status_reason = null, billing_blocked = false
   where created_by = p_owner and billing_blocked;
end $$;

-- ---------------------------------------------------------------------
-- admin_list_businesses: cada linha mostra os dados da assinatura do dono
-- ---------------------------------------------------------------------
drop function if exists admin_list_businesses();
create function admin_list_businesses()
returns table (id uuid, slug text, name text, category text, phone text, status business_status,
               status_reason text, created_at timestamptz, owner_id uuid, owner_email text,
               plan_id text, plan_name text, base_price numeric, subscription_status subscription_status,
               custom_price numeric, discount_amount numeric, discount_until date, discount_note text,
               monthly_price numeric, current_period_end timestamptz, max_businesses int,
               businesses_count bigint, professionals_count bigint, customers_count bigint, activity_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  return query
  select b.id, b.slug, b.name, b.category, b.phone, b.status, b.status_reason, b.created_at,
         b.created_by, u.email::text,
         s.plan_id, p.name, p.base_price, s.status,
         s.custom_price, s.discount_amount, s.discount_until, s.discount_note,
         case when s.id is null then null else effective_price(s) end,
         s.current_period_end, p.max_businesses,
         (select count(*) from businesses x where x.created_by = b.created_by),
         (select count(*) from professionals x where x.business_id = b.id and x.active),
         (select count(*) from customers x     where x.business_id = b.id),
         (select count(*) from appointments x  where x.business_id = b.id)
    from businesses b
    left join auth.users u    on u.id = b.created_by
    left join subscriptions s on s.owner_id = b.created_by
    left join plans p         on p.id = s.plan_id
   order by (b.status = 'pending') desc, b.created_at desc;
end $$;

-- ---------------------------------------------------------------------
-- billing_webhook: identifica a assinatura por gateway_subscription_id,
-- que continua único por dono. Só precisa ignorar payments.business_id.
-- ---------------------------------------------------------------------
create or replace function billing_webhook(p_event text, p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s        subscriptions;
  v_status text;
  v_method text;
  v_due    date := (p->>'dueDate')::date;
  v_want   numeric;
begin
  select * into s from subscriptions where gateway_subscription_id = p->>'subscription';
  if not found then
    return jsonb_build_object('ignored', 'assinatura não encontrada');
  end if;

  v_status := case
    when p_event in ('PAYMENT_CONFIRMED', 'PAYMENT_RECEIVED', 'PAYMENT_RECEIVED_IN_CASH') then 'paid'
    when p_event = 'PAYMENT_OVERDUE' then 'overdue'
    when p_event in ('PAYMENT_REFUNDED', 'PAYMENT_PARTIALLY_REFUNDED', 'PAYMENT_CHARGEBACK_REQUESTED') then 'refunded'
    when p_event = 'PAYMENT_DELETED' then 'canceled'
    when p->>'status' in ('CONFIRMED', 'RECEIVED', 'RECEIVED_IN_CASH') then 'paid'
    when p->>'status' = 'OVERDUE' then 'overdue'
    else 'pending' end;
  v_method := case p->>'billingType'
    when 'PIX' then 'pix' when 'BOLETO' then 'boleto' when 'CREDIT_CARD' then 'cartao' else 'a definir' end;

  insert into payments (subscription_id, amount, status, method, due_date, paid_at, gateway_payment_id, invoice_url)
  values (s.id, (p->>'value')::numeric, v_status::payment_status, v_method, v_due,
          case when v_status = 'paid' then now() end, p->>'id', p->>'invoiceUrl')
  on conflict (gateway_payment_id) do update set
    amount      = excluded.amount,
    status      = case when payments.status = 'paid' and excluded.status in ('pending', 'overdue')
                       then payments.status else excluded.status end,
    method      = excluded.method,
    due_date    = excluded.due_date,
    paid_at     = coalesce(payments.paid_at, excluded.paid_at),
    invoice_url = coalesce(excluded.invoice_url, payments.invoice_url);

  if v_status = 'paid' then
    update subscriptions
       set status = 'active',
           current_period_end = greatest(coalesce(current_period_end, now()), (v_due + interval '1 month')::timestamptz)
     where id = s.id;
    update businesses set status = 'approved', status_reason = null, billing_blocked = false
     where created_by = s.owner_id and billing_blocked;
  elsif v_status = 'overdue' then
    update subscriptions set status = 'past_due' where id = s.id and status = 'active';
  end if;

  if p_event = 'PAYMENT_CREATED' then
    select effective_price(x) into v_want from subscriptions x where x.id = s.id;
    if v_want is not null and v_want <> (p->>'value')::numeric then
      return jsonb_build_object('ok', true, 'adjust_value', v_want);
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke execute on function billing_webhook(text, jsonb) from public, anon, authenticated;
grant execute on function billing_webhook(text, jsonb) to service_role;

-- ---------------------------------------------------------------------
-- billing_daily: bloqueia TODOS os estabelecimentos do dono quando atrasa
-- ---------------------------------------------------------------------
create or replace function billing_daily() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_late    int;
  v_blocked int;
begin
  update subscriptions set status = 'past_due'
   where gateway is null and status = 'active' and current_period_end < now();
  get diagnostics v_late = row_count;

  update businesses b
     set status = 'blocked', billing_blocked = true,
         status_reason = 'Pagamento em atraso. Pague a fatura em aberto para reativar sua vitrine.'
    from subscriptions s
   where s.owner_id = b.created_by and b.status = 'approved' and s.status = 'past_due'
     and (
       (s.gateway is null and s.current_period_end < now() - interval '5 days')
       or exists (select 1 from payments p
                   where p.subscription_id = s.id and p.status = 'overdue'
                     and p.due_date < current_date - 5));
  get diagnostics v_blocked = row_count;

  return jsonb_build_object('em_atraso', v_late, 'bloqueadas', v_blocked);
end $$;
revoke execute on function billing_daily() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- billing_quote: assinatura do dono logado (sem mais p_business)
-- ---------------------------------------------------------------------
drop function if exists billing_quote(uuid);
create function billing_quote() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s      subscriptions;
  v_base numeric;
begin
  if auth.uid() is null then
    raise exception 'Sem permissão.';
  end if;
  select * into s from subscriptions where owner_id = auth.uid();
  if not found then
    return null;
  end if;
  v_base := effective_price(s);
  return jsonb_build_object(
    'base', v_base,
    'method', s.billing_method,
    'options', jsonb_build_object(
      'cartao', jsonb_build_object('fee', billing_fee(v_base, 'cartao'), 'total', v_base + billing_fee(v_base, 'cartao')),
      'pix',    jsonb_build_object('fee', billing_fee(v_base, 'pix'),    'total', v_base + billing_fee(v_base, 'pix')),
      'boleto', jsonb_build_object('fee', billing_fee(v_base, 'boleto'), 'total', v_base + billing_fee(v_base, 'boleto'))));
end $$;
