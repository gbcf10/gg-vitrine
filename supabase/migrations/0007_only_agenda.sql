-- =====================================================================
-- GG Vitrine — 0007: refactor pra ser SÓ agendamento
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- Pode ser rodado de novo com segurança.
--
-- Remove tudo que era de outras verticals (cardápio, orçamento, reserva,
-- evento, cartão) e simplifica as funções genéricas pra não mencionar
-- mais `kind`.
-- =====================================================================

-- Trigger de fidelidade do cardápio (pedidos): some junto com a tabela.
drop trigger if exists loyalty_stamp_order on orders;

-- ---------------------------------------------------------------------
-- Tabelas das verticals não-agenda
-- ---------------------------------------------------------------------
drop table if exists event_registrations cascade;
drop table if exists events              cascade;
drop table if exists reservations        cascade;
drop table if exists reservation_units   cascade;
drop table if exists quote_requests      cascade;
drop table if exists order_items         cascade;
drop table if exists orders              cascade;
drop table if exists menu_items          cascade;
drop table if exists menu_categories     cascade;
drop table if exists store_hours         cascade;

-- ---------------------------------------------------------------------
-- Funções específicas de outras verticals
-- ---------------------------------------------------------------------
drop function if exists is_store_open(uuid)                                                                       cascade;
drop function if exists place_order(uuid, jsonb, text, text, text, text, text, numeric, text, text)               cascade;
drop function if exists submit_quote(uuid, text, text, text, text, date)                                          cascade;
drop function if exists request_reservation(uuid, text, text, date, date, time, int, uuid, text, text)            cascade;
drop function if exists get_unit_busy_dates(uuid)                                                                 cascade;
drop function if exists register_event(uuid, text, text, int, text, text)                                         cascade;
drop function if exists loyalty_on_order()                                                                        cascade;

-- ---------------------------------------------------------------------
-- Planos: simplifica pra 1 plano único com tudo incluso.
-- ---------------------------------------------------------------------
-- Primeiro, mandar todas as assinaturas pro plano único ('basico') antes
-- de deletar os outros.
update subscriptions set plan_id = 'basico' where plan_id in ('profissional', 'premium');
delete from subscriptions where plan_id in (select id from plans where coalesce(kind, 'agenda') <> 'agenda');
delete from plans         where id <> 'basico' or coalesce(kind, 'agenda') <> 'agenda';

update plans set
  name              = 'Mensal',
  base_price        = 49.90,
  max_professionals = null,
  max_customers     = null,
  features          = array['agenda', 'servicos', 'horarios', 'clientes', 'agendamento_online',
                            'historico_agendamentos', 'multi_profissional', 'bloqueios', 'folgas',
                            'lembretes', 'galeria', 'avaliacoes', 'fidelidade', 'cupons', 'qrcode'],
  sort_order        = 1
 where id = 'basico';

-- ---------------------------------------------------------------------
-- Colunas específicas de outras verticals em `businesses`
-- ---------------------------------------------------------------------
alter table businesses drop constraint if exists businesses_kind_check;
alter table businesses drop column if exists kind;
alter table businesses drop column if exists accepting_orders;
alter table businesses drop column if exists pickup_enabled;
alter table businesses drop column if exists delivery_enabled;
alter table businesses drop column if exists delivery_fee;
alter table businesses drop column if exists min_order;
alter table businesses drop column if exists delivery_area;
alter table businesses drop column if exists reservation_mode;
alter table businesses drop column if exists max_party;
alter table businesses drop column if exists reservation_notice;

-- Coluna `kind` em `plans`: todos os planos agora são de agenda.
alter table plans drop constraint if exists plans_kind_check;
alter table plans drop column if exists kind;

-- ---------------------------------------------------------------------
-- Reescrita das funções genéricas (sem `kind`)
-- ---------------------------------------------------------------------

-- Cadastro pelo signup: cria o estabelecimento junto com o usuário.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := new.raw_user_meta_data;
  v_id   uuid;
begin
  if v_meta ? 'business_name' and v_meta ? 'business_slug' then
    begin
      insert into businesses (name, slug, category, phone, created_by)
      values (trim(v_meta->>'business_name'), lower(trim(v_meta->>'business_slug')),
              v_meta->>'business_category', v_meta->>'business_phone', new.id)
      returning id into v_id;
      insert into business_members (business_id, user_id, role) values (v_id, new.id, 'owner');
    exception when others then
      null;
    end;
  end if;
  return new;
end $$;
revoke execute on function handle_new_user() from public, anon, authenticated;

-- Cadastro pelo painel (quem criou a conta sem os dados do estabelecimento).
drop function if exists request_business(text, text, text, text, text);
drop function if exists request_business(text, text, text, text);
create function request_business(p_name text, p_slug text, p_category text default null,
                                 p_phone text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Faça login primeiro.';
  end if;
  insert into businesses (name, slug, category, phone, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_category, p_phone, auth.uid())
  returning id into v_id;
  insert into business_members (business_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end $$;

-- Escolher plano: sem validação de `kind`.
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
  if not exists (select 1 from plans where id = p_plan) then
    raise exception 'Plano inválido.';
  end if;

  select * into v_sub from subscriptions where business_id = p_business;
  if not found then
    insert into subscriptions (business_id, plan_id) values (p_business, p_plan);
  elsif v_sub.status in ('pending_payment', 'canceled') then
    update subscriptions
       set plan_id = p_plan, status = 'pending_payment', gateway_subscription_id = null
     where id = v_sub.id;
  else
    raise exception 'Para trocar de plano com a assinatura ativa, fale com o suporte.';
  end if;
end $$;

-- Admin: ajustar plano e preço (sem validação de `kind`).
drop function if exists admin_update_subscription(uuid, text, numeric, numeric, date, text);
create function admin_update_subscription(p_business uuid, p_plan text, p_custom_price numeric,
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
   where business_id = p_business;
  if not found then
    insert into subscriptions (business_id, plan_id, custom_price, discount_amount, discount_until, discount_note)
    values (p_business, p_plan, p_custom_price, coalesce(p_discount_amount, 0), p_discount_until, p_discount_note);
  end if;
end $$;

-- Página pública: só a parte de agenda. Mantém features genéricas (links, galeria, avaliações, fidelidade).
create or replace function get_public_business(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', b.id, 'slug', b.slug, 'name', b.name, 'category', b.category,
    'description', b.description, 'phone', b.phone, 'address', b.address,
    'logo_url', b.logo_url, 'primary_color', b.primary_color, 'timezone', b.timezone,
    'staff_label', b.staff_label,
    'live', business_is_live(b.id),
    'features', coalesce((select to_jsonb(p.features) from subscriptions s join plans p on p.id = s.plan_id
                           where s.business_id = b.id), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'name', s.name, 'description', s.description,
               'price', s.price, 'duration_min', s.duration_min) order by s.name)
        from services s where s.business_id = b.id and s.active), '[]'::jsonb),
    'professionals', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.name, 'photo_url', p.photo_url,
               'service_ids', coalesce((select jsonb_agg(ps.service_id)
                                          from professional_services ps
                                         where ps.professional_id = p.id), '[]'::jsonb)) order by p.name)
        from professionals p where p.business_id = b.id and p.active), '[]'::jsonb),
    'links', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'label', l.label, 'url', l.url, 'icon', l.icon)
                       order by l.sort_order, l.label)
        from business_links l where l.business_id = b.id), '[]'::jsonb),
    'gallery', coalesce((
      select jsonb_agg(jsonb_build_object('id', g.id, 'url', g.url, 'caption', g.caption)
                       order by g.sort_order, g.created_at desc)
        from gallery_photos g where g.business_id = b.id), '[]'::jsonb),
    'reviews', case when has_feature(b.id, 'avaliacoes') then jsonb_build_object(
      'average', (select round(avg(r.rating), 1) from reviews r where r.business_id = b.id and r.status = 'approved'),
      'count',   (select count(*) from reviews r where r.business_id = b.id and r.status = 'approved'),
      'latest',  coalesce((
        select jsonb_agg(x order by x.created_at desc) from (
          select r.author_name, r.rating, r.comment, r.reply, r.created_at
            from reviews r where r.business_id = b.id and r.status = 'approved'
           order by r.created_at desc limit 12) x), '[]'::jsonb)) end,
    'loyalty', (select jsonb_build_object('required', lp.stamps_required, 'reward', lp.reward)
                  from loyalty_programs lp
                 where lp.business_id = b.id and lp.active and has_feature(b.id, 'fidelidade')))
  from businesses b
  where b.slug = lower(p_slug) and b.status = 'approved'
$$;

-- Lista do admin: só agendamentos.
drop function if exists admin_list_businesses();
create function admin_list_businesses()
returns table (id uuid, slug text, name text, category text, phone text, status business_status,
               status_reason text, created_at timestamptz, owner_email text,
               plan_id text, plan_name text, base_price numeric, subscription_status subscription_status,
               custom_price numeric, discount_amount numeric, discount_until date, discount_note text,
               monthly_price numeric, current_period_end timestamptz,
               professionals_count bigint, customers_count bigint, activity_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  return query
  select b.id, b.slug, b.name, b.category, b.phone, b.status, b.status_reason, b.created_at,
         u.email::text,
         s.plan_id, p.name, p.base_price, s.status,
         s.custom_price, s.discount_amount, s.discount_until, s.discount_note,
         case when s.id is null then null else effective_price(s) end,
         s.current_period_end,
         (select count(*) from professionals x where x.business_id = b.id and x.active),
         (select count(*) from customers x     where x.business_id = b.id),
         (select count(*) from appointments x  where x.business_id = b.id)
    from businesses b
    left join auth.users u    on u.id = b.created_by
    left join subscriptions s on s.business_id = b.id
    left join plans p         on p.id = s.plan_id
   order by (b.status = 'pending') desc, b.created_at desc;
end $$;
