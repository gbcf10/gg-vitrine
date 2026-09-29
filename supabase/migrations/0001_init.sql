-- =====================================================================
-- GG Vitrine — esquema inicial (multiempresa)
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
--
-- Princípios:
--   * Toda tabela de dados de empresa tem business_id e RLS ligado.
--   * Chaves estrangeiras compostas (business_id, id) impedem que um
--     registro aponte para dados de outra empresa.
--   * O banco recusa dois agendamentos sobrepostos para o mesmo
--     profissional (exclusion constraint), mesmo em acessos simultâneos.
--   * Operações sensíveis (cadastro, agendamento público, ações do admin)
--     passam por funções RPC que validam tudo no servidor.
-- =====================================================================

create extension if not exists btree_gist;

create type business_status     as enum ('pending', 'approved', 'rejected', 'blocked');
create type member_role         as enum ('owner', 'staff');
create type subscription_status as enum ('pending_payment', 'active', 'past_due', 'canceled');
create type payment_status      as enum ('pending', 'paid', 'overdue', 'refunded', 'canceled');
create type appointment_status  as enum ('scheduled', 'confirmed', 'completed', 'canceled', 'no_show');
create type time_off_kind       as enum ('folga', 'bloqueio');

-- ---------------------------------------------------------------------
-- Plataforma
-- ---------------------------------------------------------------------

create table plans (
  id                text primary key,
  name              text not null,
  base_price        numeric(10,2) not null check (base_price >= 0),
  max_professionals int,            -- null = ilimitado
  max_customers     int,            -- null = ilimitado
  features          text[] not null default '{}',
  sort_order        int not null default 0
);

insert into plans (id, name, base_price, max_professionals, max_customers, features, sort_order) values
  ('basico', 'Básico', 50, 1, 300,
    array['agenda', 'servicos', 'horarios', 'clientes', 'agendamento_online', 'historico_agendamentos'], 1),
  ('profissional', 'Profissional', 80, 5, null,
    array['agenda', 'servicos', 'horarios', 'clientes', 'agendamento_online', 'historico_agendamentos',
          'multi_profissional', 'relatorios', 'historico_clientes', 'bloqueios', 'folgas', 'lembretes'], 2),
  ('premium', 'Premium', 120, null, null,
    array['agenda', 'servicos', 'horarios', 'clientes', 'agendamento_online', 'historico_agendamentos',
          'multi_profissional', 'relatorios', 'historico_clientes', 'bloqueios', 'folgas', 'lembretes',
          'relatorios_avancados', 'financeiro', 'dashboard', 'comunicacao_avancada', 'suporte_prioritario'], 3);

create table platform_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table businesses (
  id                uuid primary key default gen_random_uuid(),
  slug              text not null unique
                    check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) between 3 and 50)
                    check (slug not in ('admin', 'painel', 'entrar', 'cadastro', 'sair', 'api', 'app', 'www',
                                        'planos', 'conta', 'login', 'suporte', 'ajuda', 'termos', 'privacidade')),
  name              text not null check (char_length(name) between 2 and 80),
  category          text,
  description       text,
  phone             text,
  address           text,
  logo_url          text,
  primary_color     text not null default '#6d28d9' check (primary_color ~ '^#[0-9a-fA-F]{6}$'),
  timezone          text not null default 'America/Sao_Paulo',
  slot_interval_min int  not null default 30 check (slot_interval_min between 5 and 120),
  status            business_status not null default 'pending',
  status_reason     text,
  created_by        uuid not null references auth.users (id),
  created_at        timestamptz not null default now(),
  approved_at       timestamptz
);

create table business_members (
  business_id uuid not null references businesses (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        member_role not null default 'owner',
  primary key (business_id, user_id)
);
create index on business_members (user_id);

create table subscriptions (
  id                      uuid primary key default gen_random_uuid(),
  business_id             uuid not null unique references businesses (id) on delete cascade,
  plan_id                 text not null references plans (id),
  status                  subscription_status not null default 'pending_payment',
  -- Preço negociado: custom_price substitui o preço oficial do plano;
  -- discount_amount é abatido até discount_until (null = permanente).
  custom_price            numeric(10,2) check (custom_price >= 0),
  discount_amount         numeric(10,2) not null default 0 check (discount_amount >= 0),
  discount_until          date,
  discount_note           text,
  current_period_end      timestamptz,
  gateway                 text,
  gateway_customer_id     text,
  gateway_subscription_id text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

create table payments (
  id                 uuid primary key default gen_random_uuid(),
  business_id        uuid not null references businesses (id) on delete cascade,
  subscription_id    uuid not null references subscriptions (id) on delete cascade,
  amount             numeric(10,2) not null check (amount >= 0),
  status             payment_status not null default 'pending',
  method             text,          -- pix | boleto | cartao | manual
  due_date           date,
  paid_at            timestamptz,
  gateway_payment_id text unique,
  note               text,
  created_at         timestamptz not null default now()
);
create index on payments (business_id, created_at desc);

-- Valor mensal efetivamente cobrado (considera preço negociado e desconto vigente).
-- Pode ser pedido pela API como coluna calculada: subscriptions?select=*,effective_price
create function effective_price(s subscriptions) returns numeric
language sql stable as $$
  select greatest(0,
           coalesce(s.custom_price, p.base_price)
           - case when s.discount_until is null or s.discount_until >= current_date
                  then s.discount_amount else 0 end)
  from plans p where p.id = s.plan_id
$$;

-- ---------------------------------------------------------------------
-- Dados de cada estabelecimento
-- ---------------------------------------------------------------------

create table professionals (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  photo_url   text,
  active      boolean not null default true,
  user_id     uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  unique (business_id, id)
);

create table services (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references businesses (id) on delete cascade,
  name         text not null check (char_length(name) between 1 and 80),
  description  text,
  price        numeric(10,2) not null default 0 check (price >= 0),
  duration_min int not null check (duration_min between 5 and 720),
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (business_id, id)
);

create table professional_services (
  business_id     uuid not null,
  professional_id uuid not null,
  service_id      uuid not null,
  primary key (professional_id, service_id),
  foreign key (business_id, professional_id) references professionals (business_id, id) on delete cascade,
  foreign key (business_id, service_id)      references services (business_id, id) on delete cascade
);

create table working_hours (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null,
  professional_id uuid not null,
  weekday         smallint not null check (weekday between 0 and 6),   -- 0 = domingo
  start_time      time not null,
  end_time        time not null,
  check (end_time > start_time),
  foreign key (business_id, professional_id) references professionals (business_id, id) on delete cascade
);
create index on working_hours (professional_id, weekday);

-- Folgas e bloqueios. professional_id nulo = vale para o estabelecimento inteiro.
create table time_off (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references businesses (id) on delete cascade,
  professional_id uuid,
  kind            time_off_kind not null default 'bloqueio',
  starts_at       timestamptz not null,
  ends_at         timestamptz not null,
  reason          text,
  created_at      timestamptz not null default now(),
  check (ends_at > starts_at),
  foreign key (business_id, professional_id) references professionals (business_id, id) on delete cascade
);
create index on time_off (business_id, starts_at);

create table customers (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references businesses (id) on delete cascade,
  auth_user_id uuid references auth.users (id) on delete set null,  -- preenchido quando o cliente agenda online
  name         text not null check (char_length(name) between 1 and 100),
  phone        text,
  email        text,
  notes        text,
  created_at   timestamptz not null default now(),
  unique (business_id, id),
  unique (business_id, auth_user_id)
);
create index on customers (business_id, name);

create table appointments (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references businesses (id) on delete cascade,
  professional_id uuid not null,
  service_id      uuid not null,
  customer_id     uuid not null,
  starts_at       timestamptz not null,
  ends_at         timestamptz not null,
  status          appointment_status not null default 'scheduled',
  price           numeric(10,2) not null default 0 check (price >= 0),
  notes           text,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  canceled_at     timestamptz,
  check (ends_at > starts_at),
  foreign key (business_id, professional_id) references professionals (business_id, id),
  foreign key (business_id, service_id)      references services (business_id, id),
  foreign key (business_id, customer_id)     references customers (business_id, id),
  constraint appointments_no_overlap exclude using gist (
    professional_id with =,
    tstzrange(starts_at, ends_at) with &&
  ) where (status <> 'canceled')
);
create index on appointments (business_id, starts_at);
create index on appointments (customer_id, starts_at desc);

-- ---------------------------------------------------------------------
-- Funções auxiliares de permissão
-- ---------------------------------------------------------------------

create function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admins where user_id = auth.uid())
$$;

create function is_member(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from business_members where business_id = bid and user_id = auth.uid())
$$;

create function is_owner(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from business_members
                 where business_id = bid and user_id = auth.uid() and role = 'owner')
$$;

-- Estabelecimento aprovado e com assinatura em dia (past_due = carência;
-- para cortar o acesso, o admin bloqueia a empresa).
create function business_is_live(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from businesses b
    join subscriptions s on s.business_id = b.id
    where b.id = bid and b.status = 'approved' and s.status in ('active', 'past_due'))
$$;

create function can_manage(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select is_platform_admin() or (is_member(bid) and business_is_live(bid))
$$;

create function has_feature(bid uuid, feature text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from subscriptions s join plans p on p.id = s.plan_id
    where s.business_id = bid and feature = any (p.features))
$$;

-- ---------------------------------------------------------------------
-- Limites dos planos
-- ---------------------------------------------------------------------

create function enforce_plan_limits() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_max   int;
  v_count int;
begin
  if tg_table_name = 'professionals' then
    -- Só conta quando um profissional passa a ficar ativo.
    if not new.active or (tg_op = 'UPDATE' and old.active) then
      return new;
    end if;
    select p.max_professionals into v_max
      from subscriptions s join plans p on p.id = s.plan_id
     where s.business_id = new.business_id;
    if v_max is not null then
      select count(*) into v_count from professionals
       where business_id = new.business_id and active and id <> new.id;
      if v_count >= v_max then
        raise exception 'Seu plano permite até % profissional(is) ativo(s). Faça upgrade para adicionar mais.', v_max;
      end if;
    end if;

  elsif tg_table_name = 'customers' then
    -- Cliente que já existe (upsert do agendamento online) não conta de novo.
    if new.auth_user_id is not null and exists (
         select 1 from customers where business_id = new.business_id and auth_user_id = new.auth_user_id) then
      return new;
    end if;
    select p.max_customers into v_max
      from subscriptions s join plans p on p.id = s.plan_id
     where s.business_id = new.business_id;
    if v_max is not null then
      select count(*) into v_count from customers where business_id = new.business_id;
      if v_count >= v_max then
        raise exception 'Limite de % clientes do plano atingido. Faça upgrade para clientes ilimitados.', v_max;
      end if;
    end if;
  end if;
  return new;
end $$;

create trigger professionals_plan_limit before insert or update of active on professionals
  for each row execute function enforce_plan_limits();
create trigger customers_plan_limit before insert on customers
  for each row execute function enforce_plan_limits();

create function touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
create trigger subscriptions_touch before update on subscriptions
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------

alter table plans                 enable row level security;
alter table platform_admins       enable row level security;
alter table businesses            enable row level security;
alter table business_members      enable row level security;
alter table subscriptions         enable row level security;
alter table payments              enable row level security;
alter table professionals         enable row level security;
alter table services              enable row level security;
alter table professional_services enable row level security;
alter table working_hours         enable row level security;
alter table time_off              enable row level security;
alter table customers             enable row level security;
alter table appointments          enable row level security;

create policy plans_read on plans for select using (true);

create policy admins_self on platform_admins for select using (user_id = auth.uid());

create policy businesses_read on businesses for select
  using (is_member(id) or is_platform_admin());
create policy businesses_update on businesses for update
  using (is_owner(id)) with check (is_owner(id));
-- O dono só altera os campos de perfil; status, slug e demais campos
-- mudam apenas pelas funções do admin.
revoke insert, update, delete on businesses from anon, authenticated;
grant update (name, category, description, phone, address, logo_url, primary_color, slot_interval_min)
  on businesses to authenticated;

create policy members_read on business_members for select
  using (user_id = auth.uid() or is_platform_admin());
revoke insert, update, delete on business_members from anon, authenticated;

create policy subscriptions_read on subscriptions for select
  using (is_member(business_id) or is_platform_admin());
revoke insert, update, delete on subscriptions from anon, authenticated;

create policy payments_read on payments for select
  using (is_member(business_id) or is_platform_admin());
revoke insert, update, delete on payments from anon, authenticated;

-- Tabelas do painel: membros leem; escrever exige empresa ativa.
do $$
declare t text;
begin
  foreach t in array array['professionals', 'services', 'professional_services',
                           'working_hours', 'customers', 'appointments'] loop
    execute format('create policy %1$s_read   on %1$s for select using (is_member(business_id) or is_platform_admin())', t);
    execute format('create policy %1$s_insert on %1$s for insert with check (can_manage(business_id))', t);
    execute format('create policy %1$s_update on %1$s for update using (can_manage(business_id)) with check (can_manage(business_id))', t);
    execute format('create policy %1$s_delete on %1$s for delete using (can_manage(business_id))', t);
  end loop;
end $$;

-- Folgas e bloqueios dependem do plano.
create policy time_off_read on time_off for select
  using (is_member(business_id) or is_platform_admin());
create policy time_off_insert on time_off for insert
  with check (can_manage(business_id)
              and has_feature(business_id, case when kind = 'folga' then 'folgas' else 'bloqueios' end));
create policy time_off_update on time_off for update
  using (can_manage(business_id))
  with check (can_manage(business_id)
              and has_feature(business_id, case when kind = 'folga' then 'folgas' else 'bloqueios' end));
create policy time_off_delete on time_off for delete using (can_manage(business_id));

-- Cliente final enxerga o próprio cadastro.
create policy customers_self on customers for select using (auth_user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Cadastro de estabelecimento
-- ---------------------------------------------------------------------

create function is_slug_available(p_slug text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from businesses where slug = lower(p_slug))
$$;

create function request_business(p_name text, p_slug text, p_category text default null, p_phone text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Faça login para cadastrar o estabelecimento.';
  end if;
  insert into businesses (name, slug, category, phone, created_by)
  values (trim(p_name), lower(trim(p_slug)), p_category, p_phone, auth.uid())
  returning id into v_id;
  insert into business_members (business_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
exception
  when unique_violation then
    raise exception 'O link "%" já está em uso. Escolha outro.', p_slug;
  when check_violation then
    raise exception 'Dados inválidos. O nome precisa ter de 2 a 80 caracteres e o link de 3 a 50 letras minúsculas, números e hífens.';
end $$;

-- Cria o estabelecimento no momento do cadastro, a partir dos dados
-- enviados em signUp({ options: { data: { business_name, business_slug, ... } } }).
-- Assim funciona mesmo com confirmação de e-mail ligada. Se falhar
-- (ex.: link já usado), o cadastro da conta segue e o painel pede os dados de novo.
create function handle_new_user() returns trigger
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

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Dono escolhe o plano depois da aprovação.
create function choose_plan(p_business uuid, p_plan text) returns void
language plpgsql security definer set search_path = public as $$
declare v_sub subscriptions;
begin
  if not is_owner(p_business) then
    raise exception 'Sem permissão.';
  end if;
  if not exists (select 1 from businesses where id = p_business and status = 'approved') then
    raise exception 'O estabelecimento ainda não foi aprovado.';
  end if;
  if not exists (select 1 from plans where id = p_plan) then
    raise exception 'Plano inválido.';
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

-- ---------------------------------------------------------------------
-- Página pública e agendamento online
-- ---------------------------------------------------------------------

create function get_public_business(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', b.id, 'slug', b.slug, 'name', b.name, 'category', b.category,
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
        from professionals p where p.business_id = b.id and p.active), '[]'::jsonb))
  from businesses b
  where b.slug = lower(p_slug) and b.status = 'approved'
$$;

-- Horários livres de um dia (data no fuso do estabelecimento).
-- Uso interno: não é exposta pela API.
create function _free_slots(p_business uuid, p_service uuid, p_date date,
                            p_professional uuid default null, p_exclude uuid default null)
returns table (professional_id uuid, starts_at timestamptz)
language sql stable security definer set search_path = public as $$
  with cfg as (
    select b.timezone as tz,
           make_interval(mins => b.slot_interval_min) as step,
           make_interval(mins => s.duration_min)      as dur
      from businesses b join services s on s.business_id = b.id
     where b.id = p_business and s.id = p_service and s.active
  )
  select p.id, gs
    from cfg
    join professionals p on p.business_id = p_business and p.active
                        and (p_professional is null or p.id = p_professional)
    join professional_services ps on ps.professional_id = p.id and ps.service_id = p_service
    join working_hours wh on wh.professional_id = p.id and wh.weekday = extract(dow from p_date)
    cross join lateral generate_series(
      (p_date + wh.start_time) at time zone cfg.tz,
      (p_date + wh.end_time)   at time zone cfg.tz - cfg.dur,
      cfg.step) gs
   where gs > now()
     and p_date <= current_date + 90
     and not exists (
       select 1 from appointments a
        where a.professional_id = p.id and a.status <> 'canceled'
          and (p_exclude is null or a.id <> p_exclude)
          and tstzrange(a.starts_at, a.ends_at) && tstzrange(gs, gs + cfg.dur))
     and not exists (
       select 1 from time_off t
        where t.business_id = p_business
          and (t.professional_id is null or t.professional_id = p.id)
          and tstzrange(t.starts_at, t.ends_at) && tstzrange(gs, gs + cfg.dur))
   order by gs, p.name
$$;
revoke execute on function _free_slots(uuid, uuid, date, uuid, uuid) from public, anon, authenticated;

create function get_available_slots(p_business uuid, p_service uuid, p_date date, p_professional uuid default null)
returns table (professional_id uuid, starts_at timestamptz)
language sql stable security definer set search_path = public as $$
  select f.professional_id, f.starts_at
    from _free_slots(p_business, p_service, p_date, p_professional) f
   where business_is_live(p_business)
$$;

create function book_appointment(p_business uuid, p_service uuid, p_professional uuid,
                                 p_starts_at timestamptz, p_name text, p_phone text,
                                 p_notes text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_tz       text;
  v_duration int;
  v_price    numeric;
  v_customer uuid;
  v_id       uuid;
begin
  if v_uid is null then
    raise exception 'Faça login para confirmar o agendamento.';
  end if;
  if not business_is_live(p_business) then
    raise exception 'Este estabelecimento não está recebendo agendamentos no momento.';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Informe seu nome.';
  end if;

  select timezone into v_tz from businesses where id = p_business;
  select duration_min, price into v_duration, v_price
    from services where id = p_service and business_id = p_business and active;
  if not found then
    raise exception 'Serviço não encontrado.';
  end if;

  if not exists (
    select 1 from _free_slots(p_business, p_service, (p_starts_at at time zone v_tz)::date, p_professional) f
     where f.professional_id = p_professional and f.starts_at = p_starts_at) then
    raise exception 'Este horário não está mais disponível. Escolha outro.';
  end if;

  insert into customers (business_id, auth_user_id, name, phone, email)
  values (p_business, v_uid, trim(p_name), nullif(trim(p_phone), ''), auth.jwt() ->> 'email')
  on conflict (business_id, auth_user_id) do update
    set name  = excluded.name,
        phone = coalesce(excluded.phone, customers.phone),
        email = coalesce(excluded.email, customers.email)
  returning id into v_customer;

  insert into appointments (business_id, professional_id, service_id, customer_id,
                            starts_at, ends_at, price, notes, created_by)
  values (p_business, p_professional, p_service, v_customer,
          p_starts_at, p_starts_at + make_interval(mins => v_duration), v_price, p_notes, v_uid)
  returning id into v_id;

  return v_id;
exception
  when exclusion_violation then
    raise exception 'Este horário acabou de ser reservado por outra pessoa. Escolha outro.';
end $$;

create function my_appointments(p_business uuid)
returns table (id uuid, starts_at timestamptz, ends_at timestamptz, status appointment_status,
               price numeric, service_id uuid, service_name text,
               professional_id uuid, professional_name text)
language sql stable security definer set search_path = public as $$
  select a.id, a.starts_at, a.ends_at, a.status, a.price,
         s.id, s.name, p.id, p.name
    from appointments a
    join customers c     on c.id = a.customer_id
    join services s      on s.id = a.service_id
    join professionals p on p.id = a.professional_id
   where a.business_id = p_business and c.auth_user_id = auth.uid()
   order by a.starts_at desc
   limit 50
$$;

create function cancel_my_appointment(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update appointments a
     set status = 'canceled', canceled_at = now()
    from customers c
   where a.id = p_id and c.id = a.customer_id and c.auth_user_id = auth.uid()
     and a.status in ('scheduled', 'confirmed') and a.starts_at > now();
  if not found then
    raise exception 'Agendamento não encontrado ou não pode mais ser cancelado.';
  end if;
end $$;

create function reschedule_my_appointment(p_id uuid, p_starts_at timestamptz, p_professional uuid default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_appt appointments;
  v_tz   text;
  v_prof uuid;
  v_dur  int;
begin
  select a.* into v_appt
    from appointments a join customers c on c.id = a.customer_id
   where a.id = p_id and c.auth_user_id = auth.uid()
     and a.status in ('scheduled', 'confirmed') and a.starts_at > now();
  if not found then
    raise exception 'Agendamento não encontrado ou não pode mais ser remarcado.';
  end if;

  v_prof := coalesce(p_professional, v_appt.professional_id);
  select timezone into v_tz from businesses where id = v_appt.business_id;
  select duration_min into v_dur from services where id = v_appt.service_id;

  if not exists (
    select 1 from _free_slots(v_appt.business_id, v_appt.service_id,
                              (p_starts_at at time zone v_tz)::date, v_prof, p_id) f
     where f.professional_id = v_prof and f.starts_at = p_starts_at) then
    raise exception 'Este horário não está disponível. Escolha outro.';
  end if;

  update appointments
     set starts_at = p_starts_at,
         ends_at = p_starts_at + make_interval(mins => v_dur),
         professional_id = v_prof,
         status = 'scheduled'
   where id = p_id;
exception
  when exclusion_violation then
    raise exception 'Este horário acabou de ser reservado por outra pessoa. Escolha outro.';
end $$;

-- ---------------------------------------------------------------------
-- Painel administrativo da plataforma
-- ---------------------------------------------------------------------

create function assert_platform_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_admin() then
    raise exception 'Acesso restrito ao administrador da plataforma.';
  end if;
end $$;

create function admin_list_businesses()
returns table (id uuid, slug text, name text, category text, phone text, status business_status,
               status_reason text, created_at timestamptz, owner_email text,
               plan_id text, plan_name text, base_price numeric, subscription_status subscription_status,
               custom_price numeric, discount_amount numeric, discount_until date, discount_note text,
               monthly_price numeric, current_period_end timestamptz,
               professionals_count bigint, customers_count bigint, appointments_count bigint)
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
         (select count(*) from customers x where x.business_id = b.id),
         (select count(*) from appointments x where x.business_id = b.id)
    from businesses b
    left join auth.users u   on u.id = b.created_by
    left join subscriptions s on s.business_id = b.id
    left join plans p         on p.id = s.plan_id
   order by (b.status = 'pending') desc, b.created_at desc;
end $$;

create function admin_set_business_status(p_business uuid, p_status business_status, p_reason text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  update businesses
     set status = p_status,
         status_reason = p_reason,
         approved_at = case when p_status = 'approved' then coalesce(approved_at, now()) else approved_at end
   where id = p_business;
end $$;

-- Altera plano e preço negociado. p_discount_until nulo = desconto permanente.
create function admin_update_subscription(p_business uuid, p_plan text, p_custom_price numeric,
                                          p_discount_amount numeric, p_discount_until date,
                                          p_discount_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  insert into subscriptions (business_id, plan_id, custom_price, discount_amount, discount_until, discount_note)
  values (p_business, p_plan, p_custom_price, coalesce(p_discount_amount, 0), p_discount_until, p_discount_note)
  on conflict (business_id) do update
    set plan_id         = excluded.plan_id,
        custom_price    = excluded.custom_price,
        discount_amount = excluded.discount_amount,
        discount_until  = excluded.discount_until,
        discount_note   = excluded.discount_note;
end $$;

-- Registra um pagamento recebido fora do gateway (ex.: PIX manual) e
-- estende o período da assinatura. Útil enquanto o gateway não estiver integrado.
create function admin_register_payment(p_business uuid, p_amount numeric, p_months int default 1,
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
end $$;

create function admin_set_subscription_status(p_business uuid, p_status subscription_status)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  update subscriptions set status = p_status where business_id = p_business;
end $$;

create function admin_platform_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform assert_platform_admin();
  return jsonb_build_object(
    'businesses_by_status', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
                               from (select status, count(*) n from businesses group by status) x),
    'active_by_plan',       (select coalesce(jsonb_object_agg(plan_id, n), '{}'::jsonb)
                               from (select plan_id, count(*) n from subscriptions
                                      where status in ('active', 'past_due') group by plan_id) x),
    'mrr',                  (select coalesce(sum(effective_price(s)), 0) from subscriptions s
                              where s.status in ('active', 'past_due')),
    'received_this_month',  (select coalesce(sum(amount), 0) from payments
                              where status = 'paid' and paid_at >= date_trunc('month', now())),
    'customers_total',      (select count(*) from customers),
    'appointments_total',   (select count(*) from appointments),
    'appointments_this_month', (select count(*) from appointments
                                 where starts_at >= date_trunc('month', now()) and status <> 'canceled')
  );
end $$;

-- Funções internas de apoio: não precisam ser chamadas pela API.
revoke execute on function enforce_plan_limits() from public, anon, authenticated;
revoke execute on function handle_new_user()     from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- Storage: logos (bucket público; cada empresa grava em <business_id>/...)
-- ---------------------------------------------------------------------

insert into storage.buckets (id, name, public) values ('logos', 'logos', true)
on conflict (id) do nothing;

create policy logos_public_read on storage.objects for select
  using (bucket_id = 'logos');
create policy logos_member_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'logos' and is_member(((storage.foldername(name))[1])::uuid));
create policy logos_member_update on storage.objects for update to authenticated
  using (bucket_id = 'logos' and is_member(((storage.foldername(name))[1])::uuid));
create policy logos_member_delete on storage.objects for delete to authenticated
  using (bucket_id = 'logos' and is_member(((storage.foldername(name))[1])::uuid));

-- ---------------------------------------------------------------------
-- Depois de criar sua conta no site, torne-se administrador da plataforma:
--   insert into platform_admins (user_id)
--   select id from auth.users where email = 'seu-email@exemplo.com';
-- ---------------------------------------------------------------------
