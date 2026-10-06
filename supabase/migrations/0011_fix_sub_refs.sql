-- =====================================================================
-- MarqueAí — 0011: corrige funções que ainda apontam pra subscriptions.business_id
--
-- Como aplicar: Supabase > SQL Editor > cole e Run. Idempotente.
--
-- 0008 renomeou subscriptions.business_id → owner_id mas essas 2 funções
-- continuaram usando o nome antigo e falham quando o trigger / policy roda.
-- =====================================================================

-- Limite de profissionais / clientes por plano (hoje todos ilimitados nos 3 planos).
create or replace function enforce_plan_limits() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_max   int;
  v_count int;
  v_owner uuid;
begin
  select created_by into v_owner from businesses where id = new.business_id;

  if tg_table_name = 'professionals' then
    if not new.active or (tg_op = 'UPDATE' and old.active) then
      return new;
    end if;
    select p.max_professionals into v_max
      from subscriptions s join plans p on p.id = s.plan_id
     where s.owner_id = v_owner;
    if v_max is not null then
      select count(*) into v_count from professionals
       where business_id = new.business_id and active and id <> new.id;
      if v_count >= v_max then
        raise exception 'Seu plano permite até % profissional(is) ativo(s). Faça upgrade para adicionar mais.', v_max;
      end if;
    end if;

  elsif tg_table_name = 'customers' then
    if new.auth_user_id is not null and exists (
         select 1 from customers where business_id = new.business_id and auth_user_id = new.auth_user_id) then
      return new;
    end if;
    select p.max_customers into v_max
      from subscriptions s join plans p on p.id = s.plan_id
     where s.owner_id = v_owner;
    if v_max is not null then
      select count(*) into v_count from customers where business_id = new.business_id;
      if v_count >= v_max then
        raise exception 'Limite de % clientes do plano atingido. Faça upgrade para clientes ilimitados.', v_max;
      end if;
    end if;
  end if;
  return new;
end $$;

-- Feature gating (fidelidade, cupons, galeria etc). A assinatura é do dono.
create or replace function has_feature(bid uuid, feature text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from businesses b
    join subscriptions s on s.owner_id = b.created_by
    join plans p         on p.id = s.plan_id
    where b.id = bid and feature = any (p.features))
$$;
