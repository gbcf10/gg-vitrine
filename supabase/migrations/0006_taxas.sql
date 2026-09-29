-- =====================================================================
-- GG Vitrine — 0006: repasse da taxa do meio de pagamento
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- Pode ser rodado de novo com segurança.
--
-- A mensalidade cobrada = preço do plano (com desconto, se houver)
--                       + taxa do Asaas conforme a forma de pagamento escolhida.
-- No cartão, a taxa é calculada "por dentro", para você receber o valor cheio do plano.
-- =====================================================================

alter table subscriptions add column if not exists billing_method text
  check (billing_method in ('cartao', 'pix', 'boleto'));

-- Taxas do Asaas (tabela de 29/09/2026). Se mudarem, atualize só aqui e rode de novo.
create or replace function billing_fee(p_base numeric, p_method text) returns numeric
language sql immutable as $$
  select case p_method
    when 'cartao' then round((p_base + 0.49) / (1 - 0.0299), 2) - p_base   -- 2,99% + R$ 0,49
    when 'pix'    then 1.99
    when 'boleto' then 1.99
    else 0 end
$$;

-- Valor final da mensalidade (disponível na API como coluna calculada: charge_value).
create or replace function charge_value(s subscriptions) returns numeric
language sql stable as $$
  select effective_price(s) + billing_fee(effective_price(s), coalesce(s.billing_method, 'pix'))
$$;

-- Quanto fica em cada forma de pagamento (mostrado na tela de Assinatura).
create or replace function billing_quote(p_business uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  s      subscriptions;
  v_base numeric;
begin
  if not (is_member(p_business) or is_platform_admin()) then
    raise exception 'Sem permissão.';
  end if;
  select * into s from subscriptions where business_id = p_business;
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

-- Mesmo webhook do 0005, agora comparando com o valor final (plano + taxa).
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
     where id = s.business_id and billing_blocked;
  elsif v_status = 'overdue' then
    update subscriptions set status = 'past_due' where id = s.id and status = 'active';
  end if;

  if p_event = 'PAYMENT_CREATED' then
    select charge_value(x) into v_want from subscriptions x where x.id = s.id;
    if v_want is not null and v_want <> (p->>'value')::numeric then
      return jsonb_build_object('ok', true, 'adjust_value', v_want);
    end if;
  end if;
  return jsonb_build_object('ok', true);
end $$;
revoke execute on function billing_webhook(text, jsonb) from public, anon, authenticated;
grant execute on function billing_webhook(text, jsonb) to service_role;
