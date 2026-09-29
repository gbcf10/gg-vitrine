-- =====================================================================
-- GG Vitrine — 0002: Cardápio online (pedidos pelo WhatsApp)
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- (Precisa que o 0001_init.sql já tenha sido aplicado.)
--
-- Cada estabelecimento passa a ter um tipo (kind):
--   'agenda'   → agendamento de horários (barbearia, salão, estética...)
--   'cardapio' → cardápio online com pedidos (lanchonete, assados, açaí...)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Tipos de negócio e plano Cardápio
-- ---------------------------------------------------------------------

alter table plans
  add column kind text not null default 'agenda' check (kind in ('agenda', 'cardapio'));

insert into plans (id, name, base_price, max_professionals, max_customers, features, sort_order, kind)
values ('cardapio', 'Cardápio', 60, null, null,
        array['cardapio', 'pedidos_whatsapp', 'horario_funcionamento', 'entrega_retirada'], 10, 'cardapio');

alter table businesses
  add column kind             text not null default 'agenda' check (kind in ('agenda', 'cardapio')),
  add column accepting_orders boolean not null default true,     -- pausa manual ("fechado agora")
  add column pickup_enabled   boolean not null default true,
  add column delivery_enabled boolean not null default false,
  add column delivery_fee     numeric(10,2) not null default 0 check (delivery_fee >= 0),
  add column min_order        numeric(10,2) not null default 0 check (min_order >= 0),
  add column delivery_area    text;                              -- ex.: "Centro e bairros próximos"

grant update (accepting_orders, pickup_enabled, delivery_enabled, delivery_fee, min_order, delivery_area)
  on businesses to authenticated;

-- ---------------------------------------------------------------------
-- Cardápio
-- ---------------------------------------------------------------------

create table menu_categories (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  sort_order  int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (business_id, id)
);

create table menu_items (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  category_id uuid not null,
  name        text not null check (char_length(name) between 1 and 80),
  description text,
  price       numeric(10,2) not null check (price >= 0),
  photo_url   text,
  available   boolean not null default true,   -- false = "esgotado"
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  foreign key (business_id, category_id) references menu_categories (business_id, id) on delete cascade
);
create index on menu_items (business_id, category_id);

-- Horário de funcionamento. end_time menor que start_time = vira a noite (ex.: 18:00–02:00).
create table store_hours (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  weekday     smallint not null check (weekday between 0 and 6),   -- 0 = domingo
  start_time  time not null,
  end_time    time not null,
  check (end_time <> start_time)
);
create index on store_hours (business_id, weekday);

alter table menu_categories enable row level security;
alter table menu_items      enable row level security;
alter table store_hours     enable row level security;

do $$
declare t text;
begin
  foreach t in array array['menu_categories', 'menu_items', 'store_hours'] loop
    execute format('create policy %1$s_read   on %1$s for select using (is_member(business_id) or is_platform_admin())', t);
    execute format('create policy %1$s_insert on %1$s for insert with check (can_manage(business_id))', t);
    execute format('create policy %1$s_update on %1$s for update using (can_manage(business_id)) with check (can_manage(business_id))', t);
    execute format('create policy %1$s_delete on %1$s for delete using (can_manage(business_id))', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Página pública: agora inclui o tipo e, para cardápio, os produtos
-- ---------------------------------------------------------------------

create or replace function get_public_business(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', b.id, 'slug', b.slug, 'kind', b.kind, 'name', b.name, 'category', b.category,
    'description', b.description, 'phone', b.phone, 'address', b.address,
    'logo_url', b.logo_url, 'primary_color', b.primary_color, 'timezone', b.timezone,
    'live', business_is_live(b.id),
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
    'store', case when b.kind = 'cardapio' then jsonb_build_object(
      'accepting_orders', b.accepting_orders,
      'pickup_enabled',   b.pickup_enabled,
      'delivery_enabled', b.delivery_enabled,
      'delivery_fee',     b.delivery_fee,
      'min_order',        b.min_order,
      'delivery_area',    b.delivery_area,
      'hours', coalesce((
        select jsonb_agg(jsonb_build_object('weekday', h.weekday, 'start', h.start_time, 'end', h.end_time)
                         order by h.weekday, h.start_time)
          from store_hours h where h.business_id = b.id), '[]'::jsonb),
      'menu', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', c.id, 'name', c.name,
                 'items', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'id', i.id, 'name', i.name, 'description', i.description,
                            'price', i.price, 'photo_url', i.photo_url, 'available', i.available)
                          order by i.sort_order, i.name)
                     from menu_items i where i.category_id = c.id), '[]'::jsonb))
               order by c.sort_order, c.name)
          from menu_categories c where c.business_id = b.id and c.active), '[]'::jsonb))
    end)
  from businesses b
  where b.slug = lower(p_slug) and b.status = 'approved'
$$;

-- ---------------------------------------------------------------------
-- Cadastro com tipo de negócio
-- ---------------------------------------------------------------------

drop function request_business(text, text, text, text);

create function request_business(p_name text, p_slug text, p_category text default null,
                                 p_phone text default null, p_kind text default 'agenda')
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Faça login para cadastrar o estabelecimento.';
  end if;
  insert into businesses (name, slug, category, phone, kind, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_category, p_phone, coalesce(p_kind, 'agenda'), auth.uid())
  returning id into v_id;
  insert into business_members (business_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
exception
  when unique_violation then
    raise exception 'O link "%" já está em uso. Escolha outro.', p_slug;
  when check_violation then
    raise exception 'Dados inválidos. O nome precisa ter de 2 a 80 caracteres e o link de 3 a 50 letras minúsculas, números e hífens.';
end $$;

create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := new.raw_user_meta_data;
  v_kind text  := case when new.raw_user_meta_data->>'business_kind' = 'cardapio' then 'cardapio' else 'agenda' end;
  v_id   uuid;
begin
  if v_meta ? 'business_name' and v_meta ? 'business_slug' then
    begin
      insert into businesses (name, slug, category, phone, kind, created_by)
      values (trim(v_meta->>'business_name'), lower(trim(v_meta->>'business_slug')),
              v_meta->>'business_category', v_meta->>'business_phone', v_kind, new.id)
      returning id into v_id;
      insert into business_members (business_id, user_id, role) values (v_id, new.id, 'owner');
    exception when others then
      null;
    end;
  end if;
  return new;
end $$;

-- O plano precisa ser do mesmo tipo do estabelecimento.
create or replace function choose_plan(p_business uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
declare v_sub subscriptions;
begin
  if not is_owner(p_business) then
    raise exception 'Sem permissão.';
  end if;
  if not exists (select 1 from businesses where id = p_business and status = 'approved') then
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
    update subscriptions set plan_id = p_plan, status = 'pending_payment' where id = v_sub.id;
  else
    raise exception 'Para trocar de plano com a assinatura ativa, fale com o suporte.';
  end if;
end $$;

create or replace function admin_update_subscription(p_business uuid, p_plan text, p_custom_price numeric,
                                                     p_discount_amount numeric, p_discount_until date,
                                                     p_discount_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  if not exists (select 1 from plans p join businesses b on b.kind = p.kind
                  where p.id = p_plan and b.id = p_business) then
    raise exception 'Este plano não é do mesmo tipo do estabelecimento.';
  end if;
  insert into subscriptions (business_id, plan_id, custom_price, discount_amount, discount_until, discount_note)
  values (p_business, p_plan, p_custom_price, coalesce(p_discount_amount, 0), p_discount_until, p_discount_note)
  on conflict (business_id) do update
    set plan_id         = excluded.plan_id,
        custom_price    = excluded.custom_price,
        discount_amount = excluded.discount_amount,
        discount_until  = excluded.discount_until,
        discount_note   = excluded.discount_note;
end $$;

-- Lista do admin ganha a coluna "kind" (muda o retorno, por isso drop + create).
drop function admin_list_businesses();

create function admin_list_businesses()
returns table (id uuid, slug text, kind text, name text, category text, phone text, status business_status,
               status_reason text, created_at timestamptz, owner_email text,
               plan_id text, plan_name text, base_price numeric, subscription_status subscription_status,
               custom_price numeric, discount_amount numeric, discount_until date, discount_note text,
               monthly_price numeric, current_period_end timestamptz,
               professionals_count bigint, customers_count bigint, appointments_count bigint,
               menu_items_count bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  return query
  select b.id, b.slug, b.kind, b.name, b.category, b.phone, b.status, b.status_reason, b.created_at,
         u.email::text,
         s.plan_id, p.name, p.base_price, s.status,
         s.custom_price, s.discount_amount, s.discount_until, s.discount_note,
         case when s.id is null then null else effective_price(s) end,
         s.current_period_end,
         (select count(*) from professionals x where x.business_id = b.id and x.active),
         (select count(*) from customers x where x.business_id = b.id),
         (select count(*) from appointments x where x.business_id = b.id),
         (select count(*) from menu_items x where x.business_id = b.id)
    from businesses b
    left join auth.users u    on u.id = b.created_by
    left join subscriptions s on s.business_id = b.id
    left join plans p         on p.id = s.plan_id
   order by (b.status = 'pending') desc, b.created_at desc;
end $$;

revoke execute on function handle_new_user() from public, anon, authenticated;
