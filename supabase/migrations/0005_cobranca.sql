-- =====================================================================
-- GG Vitrine — 0005: cobrança automática da mensalidade (Asaas)
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- Pode ser rodado de novo com segurança.
--
-- Fluxo:
--   * O dono paga pela página do Asaas (cartão, PIX ou boleto).
--   * O Asaas avisa o sistema (webhook -> Edge Function asaas-webhook ->
--     função billing_webhook abaixo), que ativa a assinatura.
--   * Fatura vencida deixa a assinatura "em atraso"; depois de 5 dias a
--     vitrine é bloqueada sozinha, e volta sozinha quando o pagamento entra.
--   * Assinatura cancelada fica no ar até o fim do período já pago.
-- =====================================================================

alter table subscriptions add column if not exists billing_document text;
alter table payments      add column if not exists invoice_url text;
alter table businesses    add column if not exists billing_blocked boolean not null default false;

-- Cancelada continua no ar até acabar o período pago.
create or replace function business_is_live(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from businesses b
    join subscriptions s on s.business_id = b.id
    where b.id = bid and b.status = 'approved'
      and (s.status in ('active', 'past_due')
           or (s.status = 'canceled' and s.current_period_end > now())))
$$;

-- ---------------------------------------------------------------------
-- Eventos do Asaas (chamada só pela Edge Function, com a chave de serviço)
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

  insert into payments (business_id, subscription_id, amount, status, method, due_date, paid_at, gateway_payment_id, invoice_url)
  values (s.business_id, s.id, (p->>'value')::numeric, v_status::payment_status, v_method, v_due,
          case when v_status = 'paid' then now() end, p->>'id', p->>'invoiceUrl')
  on conflict (gateway_payment_id) do update set
    amount      = excluded.amount,
    -- um pagamento já pago não volta para pendente/atrasado por evento fora de ordem
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
    -- desbloqueia quem foi bloqueado automaticamente por atraso
    update businesses set status = 'approved', status_reason = null, billing_blocked = false
     where id = s.business_id and billing_blocked;
  elsif v_status = 'overdue' then
    update subscriptions set status = 'past_due' where id = s.id and status = 'active';
  end if;

  -- Fatura nova com valor diferente do contratado (ex.: desconto acabou):
  -- a Edge Function corrige o valor no Asaas.
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
-- Rotina diária: atrasos e bloqueio automático
-- ---------------------------------------------------------------------

create or replace function billing_daily() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_late    int;
  v_blocked int;
begin
  -- Assinaturas pagas por fora (PIX manual): período acabou sem novo pagamento.
  update subscriptions set status = 'past_due'
   where gateway is null and status = 'active' and current_period_end < now();
  get diagnostics v_late = row_count;

  -- 5 dias de tolerância, depois bloqueia a vitrine.
  update businesses b
     set status = 'blocked', billing_blocked = true,
         status_reason = 'Pagamento em atraso. Pague a fatura em aberto para reativar sua vitrine.'
    from subscriptions s
   where s.business_id = b.id and b.status = 'approved' and s.status = 'past_due'
     and (
       (s.gateway is null and s.current_period_end < now() - interval '5 days')
       or exists (select 1 from payments p
                   where p.subscription_id = s.id and p.status = 'overdue'
                     and p.due_date < current_date - 5));
  get diagnostics v_blocked = row_count;

  return jsonb_build_object('em_atraso', v_late, 'bloqueadas', v_blocked);
end $$;
revoke execute on function billing_daily() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'gg-vitrine-cobranca';
select cron.schedule('gg-vitrine-cobranca', '0 12 * * *', $$select public.billing_daily()$$);   -- 9h de Brasília

-- Pagamento manual pelo admin também desbloqueia.
create or replace function admin_register_payment(p_business uuid, p_amount numeric, p_months int default 1,
                                                  p_method text default 'manual', p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_sub subscriptions;
begin
  perform assert_platform_admin();
  select * into v_sub from subscriptions where business_id = p_business;
  if not found then
    raise exception 'A empresa ainda não escolheu um plano.';
  end if;
  insert into payments (business_id, subscription_id, amount, status, method, paid_at, note)
  values (p_business, v_sub.id, p_amount, 'paid', p_method, now(), p_note);
  update subscriptions
     set status = 'active',
         current_period_end = greatest(coalesce(current_period_end, now()), now())
                              + make_interval(months => greatest(p_months, 1))
   where id = v_sub.id;
  update businesses set status = 'approved', status_reason = null, billing_blocked = false
   where id = p_business and billing_blocked;
end $$;

-- Dono pode voltar a escolher plano depois de cancelar ou atrasar.
create or replace function choose_plan(p_business uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
declare v_sub subscriptions;
begin
  if not is_owner(p_business) then
    raise exception 'Sem permissão.';
  end if;
  if not exists (select 1 from businesses where id = p_business and status in ('approved', 'blocked')) then
    raise exception 'O estabelecimento ainda não foi aprovado.';
  end if;
  if not exists (select 1 from plans p join businesses b on b.kind = p.kind
                  where p.id = p_plan and b.id = p_business) then
    raise exception 'Plano inválido para este tipo de estabelecimento.';
  end if;

  select * into v_sub from subscriptions where business_id = p_business;
  if not found then
    insert into subscriptions (business_id, plan_id) values (p_business, p_plan);
  elsif v_sub.status in ('pending_payment', 'canceled') then
    -- plano novo = assinatura nova no Asaas
    update subscriptions
       set plan_id = p_plan, status = 'pending_payment', gateway_subscription_id = null
     where id = v_sub.id;
  else
    raise exception 'Para trocar de plano com a assinatura ativa, fale com o suporte.';
  end if;
end $$;
