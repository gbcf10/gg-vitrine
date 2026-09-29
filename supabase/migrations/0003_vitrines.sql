-- =====================================================================
-- GG Vitrine — 0003: todos os tipos de vitrine e os extras
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- (Precisa que 0001 e 0002 já tenham sido aplicados.)
--
-- Tipos de vitrine (businesses.kind):
--   agenda    → agendamento de horários (barbearia, clínica, quadra, aula...)
--   cardapio  → catálogo/cardápio com pedidos (lanchonete, loja, doces...)
--   cartao    → cartão digital: links, contatos, galeria
--   orcamento → pedidos de orçamento (eletricista, pintor, montador...)
--   reserva   → reservas por horário (mesa) ou por diária (chalé, aluguel)
--   evento    → eventos e turmas com vagas limitadas
--
-- Extras: links, galeria, avaliações, fidelidade, cupons, pedidos salvos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Novos tipos e configurações
-- ---------------------------------------------------------------------

alter table businesses drop constraint businesses_kind_check;
alter table businesses add constraint businesses_kind_check
  check (kind in ('agenda', 'cardapio', 'cartao', 'orcamento', 'reserva', 'evento'));
alter table plans drop constraint plans_kind_check;
alter table plans add constraint plans_kind_check
  check (kind in ('agenda', 'cardapio', 'cartao', 'orcamento', 'reserva', 'evento'));

alter table businesses
  add column staff_label        text not null default 'Profissional' check (char_length(staff_label) between 2 and 30),
  add column reservation_mode   text not null default 'horario' check (reservation_mode in ('horario', 'diaria')),
  add column max_party          int  not null default 10 check (max_party between 1 and 500),
  add column reservation_notice text;

grant update (staff_label, reservation_mode, max_party, reservation_notice) on businesses to authenticated;

update plans set name = 'Catálogo' where id = 'cardapio';

insert into plans (id, name, base_price, max_professionals, max_customers, features, sort_order, kind) values
  ('cartao', 'Cartão digital', 25, null, null,
    array['links', 'galeria', 'avaliacoes', 'qrcode'], 20, 'cartao'),
  ('orcamento', 'Orçamentos', 40, null, null,
    array['orcamentos', 'servicos_oferecidos', 'links', 'galeria', 'avaliacoes', 'qrcode'], 30, 'orcamento'),
  ('reserva', 'Reservas', 60, null, null,
    array['reservas', 'links', 'galeria', 'avaliacoes', 'qrcode'], 40, 'reserva'),
  ('evento', 'Eventos e turmas', 50, null, null,
    array['eventos', 'inscricoes', 'links', 'galeria', 'avaliacoes', 'qrcode', 'cupons'], 50, 'evento');

update plans set features = features || array['links', 'galeria', 'avaliacoes', 'qrcode']
 where id in ('basico', 'profissional', 'premium', 'cardapio');
update plans set features = features || array['fidelidade', 'cupons']
 where id in ('profissional', 'premium', 'cardapio');
update plans set features = features || array['pedidos'] where id = 'cardapio';

-- ---------------------------------------------------------------------
-- Tabelas dos extras
-- ---------------------------------------------------------------------

create table business_links (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  label       text not null check (char_length(label) between 1 and 60),
  url         text not null check (char_length(url) between 3 and 500),
  icon        text not null default 'link',
  sort_order  int not null default 0
);
create index on business_links (business_id, sort_order);

create table gallery_photos (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  url         text not null,
  caption     text check (char_length(caption) <= 120),
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index on gallery_photos (business_id, sort_order);

create table reviews (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  author_name text not null check (char_length(author_name) between 1 and 60),
  rating      smallint not null check (rating between 1 and 5),
  comment     text check (char_length(comment) <= 500),
  reply       text check (char_length(reply) <= 500),
  status      text not null default 'pending' check (status in ('pending', 'approved', 'hidden')),
  created_at  timestamptz not null default now()
);
create index on reviews (business_id, status, created_at desc);

create table loyalty_programs (
  business_id     uuid primary key references businesses (id) on delete cascade,
  active          boolean not null default true,
  stamps_required int not null default 10 check (stamps_required between 2 and 50),
  reward          text not null default '1 serviço grátis' check (char_length(reward) between 2 and 100)
);

create table loyalty_cards (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references businesses (id) on delete cascade,
  phone            text not null check (phone ~ '^[0-9]{8,15}$'),
  name             text,
  stamps           int not null default 0 check (stamps >= 0),
  rewards_redeemed int not null default 0,
  updated_at       timestamptz not null default now(),
  unique (business_id, phone)
);

create table coupons (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  code        text not null check (code ~ '^[A-Za-z0-9_-]{3,20}$'),
  kind        text not null default 'percent' check (kind in ('percent', 'fixed')),
  value       numeric(10,2) not null check (value > 0),
  min_order   numeric(10,2) not null default 0 check (min_order >= 0),
  valid_until date,
  max_uses    int check (max_uses > 0),
  uses        int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  check (kind <> 'percent' or value <= 100)
);
create unique index coupons_code_unique on coupons (business_id, upper(code));

-- ---------------------------------------------------------------------
-- Catálogo: pedidos salvos
-- ---------------------------------------------------------------------

create table orders (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references businesses (id) on delete cascade,
  number        int not null,
  customer_name text not null,
  phone         text not null,
  mode          text not null check (mode in ('retirada', 'entrega')),
  address       text,
  payment       text not null,
  change_for    numeric(10,2),
  notes         text,
  subtotal      numeric(10,2) not null,
  delivery_fee  numeric(10,2) not null default 0,
  discount      numeric(10,2) not null default 0,
  total         numeric(10,2) not null,
  coupon_code   text,
  status        text not null default 'novo' check (status in ('novo', 'preparando', 'pronto', 'entregue', 'cancelado')),
  created_at    timestamptz not null default now(),
  unique (business_id, number),
  unique (business_id, id)
);
create index on orders (business_id, created_at desc);

create table order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders (id) on delete cascade,
  business_id uuid not null references businesses (id) on delete cascade,
  item_id     uuid references menu_items (id) on delete set null,
  name        text not null,
  unit_price  numeric(10,2) not null,
  qty         int not null check (qty between 1 and 99),
  total       numeric(10,2) not null
);
create index on order_items (order_id);

-- ---------------------------------------------------------------------
-- Orçamentos
-- ---------------------------------------------------------------------

create table quote_requests (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references businesses (id) on delete cascade,
  name           text not null check (char_length(name) between 1 and 80),
  phone          text not null check (char_length(phone) between 8 and 30),
  description    text not null check (char_length(description) between 5 and 2000),
  district       text check (char_length(district) <= 80),
  preferred_date date,
  status         text not null default 'novo' check (status in ('novo', 'respondido', 'fechado', 'perdido')),
  internal_notes text,
  created_at     timestamptz not null default now()
);
create index on quote_requests (business_id, created_at desc);

-- ---------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------

create table reservation_units (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  description text,
  capacity    int not null default 2 check (capacity between 1 and 500),
  price       numeric(10,2) not null default 0 check (price >= 0),   -- por diária
  photo_url   text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (business_id, id)
);

create table reservations (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  unit_id     uuid,
  name        text not null check (char_length(name) between 1 and 80),
  phone       text not null check (char_length(phone) between 8 and 30),
  email       text,
  party_size  int not null default 1 check (party_size between 1 and 500),
  start_date  date not null,
  end_date    date not null,           -- saída (exclusivo). Reserva por horário: start_date + 1
  at_time     time,                     -- só para reserva por horário
  notes       text check (char_length(notes) <= 500),
  total       numeric(10,2) not null default 0,
  status      text not null default 'pendente' check (status in ('pendente', 'confirmada', 'recusada', 'cancelada')),
  created_at  timestamptz not null default now(),
  check (end_date > start_date),
  foreign key (business_id, unit_id) references reservation_units (business_id, id),
  constraint reservations_no_overlap exclude using gist (
    unit_id with =, daterange(start_date, end_date) with &&
  ) where (status = 'confirmada' and unit_id is not null)
);
create index on reservations (business_id, start_date);

-- ---------------------------------------------------------------------
-- Eventos e turmas
-- ---------------------------------------------------------------------

create table events (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses (id) on delete cascade,
  title       text not null check (char_length(title) between 2 and 100),
  description text,
  starts_at   timestamptz not null,
  ends_at     timestamptz,
  location    text,
  price       numeric(10,2) not null default 0 check (price >= 0),
  capacity    int check (capacity > 0),   -- null = sem limite
  photo_url   text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at),
  unique (business_id, id)
);
create index on events (business_id, starts_at);

create table event_registrations (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  event_id    uuid not null,
  name        text not null check (char_length(name) between 1 and 80),
  phone       text not null check (char_length(phone) between 8 and 30),
  email       text,
  quantity    int not null default 1 check (quantity between 1 and 20),
  total       numeric(10,2) not null default 0,
  coupon_code text,
  status      text not null default 'confirmada' check (status in ('confirmada', 'cancelada')),
  created_at  timestamptz not null default now(),
  foreign key (business_id, event_id) references events (business_id, id) on delete cascade
);
create index on event_registrations (event_id);

-- ---------------------------------------------------------------------
-- RLS: membros leem, empresa ativa escreve
-- ---------------------------------------------------------------------

alter table business_links      enable row level security;
alter table gallery_photos      enable row level security;
alter table reviews             enable row level security;
alter table loyalty_programs    enable row level security;
alter table loyalty_cards       enable row level security;
alter table coupons             enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table quote_requests      enable row level security;
alter table reservation_units   enable row level security;
alter table reservations        enable row level security;
alter table events              enable row level security;
alter table event_registrations enable row level security;

do $$
declare t text;
begin
  foreach t in array array['business_links', 'gallery_photos', 'loyalty_programs', 'loyalty_cards', 'coupons',
                           'reservation_units', 'reservations', 'events', 'event_registrations',
                           'orders', 'order_items', 'quote_requests'] loop
    execute format('create policy %1$s_read   on %1$s for select using (is_member(business_id) or is_platform_admin())', t);
    execute format('create policy %1$s_insert on %1$s for insert with check (can_manage(business_id))', t);
    execute format('create policy %1$s_update on %1$s for update using (can_manage(business_id)) with check (can_manage(business_id))', t);
    execute format('create policy %1$s_delete on %1$s for delete using (can_manage(business_id))', t);
  end loop;
end $$;

-- Avaliações só entram pela função submit_review (moderadas pelo dono).
create policy reviews_read   on reviews for select using (is_member(business_id) or is_platform_admin());
create policy reviews_update on reviews for update using (can_manage(business_id)) with check (can_manage(business_id));
create policy reviews_delete on reviews for delete using (can_manage(business_id));

-- ---------------------------------------------------------------------
-- Funções auxiliares
-- ---------------------------------------------------------------------

-- Loja aberta agora, pelo horário de funcionamento (turnos podem virar a noite).
create function is_store_open(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  with n as (
    select extract(dow from (now() at time zone b.timezone))::int as wd,
           (now() at time zone b.timezone)::time as t
      from businesses b where b.id = bid)
  select exists (
    select 1 from store_hours h, n
     where h.business_id = bid and (
       (h.end_time > h.start_time and h.weekday = n.wd and n.t >= h.start_time and n.t < h.end_time)
       or (h.end_time < h.start_time and ((h.weekday = n.wd and n.t >= h.start_time)
                                          or ((h.weekday + 1) % 7 = n.wd and n.t < h.end_time)))))
$$;

create function _money(v numeric) returns text language sql immutable as $$
  select 'R$ ' || replace(to_char(v, 'FM999999990.00'), '.', ',')
$$;

-- Valida um cupom e calcula o desconto sobre o subtotal.
create function _coupon_lookup(p_business uuid, p_code text, p_subtotal numeric) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  c coupons;
  v_discount numeric;
begin
  if coalesce(trim(p_code), '') = '' then
    return jsonb_build_object('valid', false, 'message', 'Informe o cupom.');
  end if;
  if not has_feature(p_business, 'cupons') then
    return jsonb_build_object('valid', false, 'message', 'Cupom inválido.');
  end if;
  select * into c from coupons
   where business_id = p_business and upper(code) = upper(trim(p_code)) and active;
  if not found then
    return jsonb_build_object('valid', false, 'message', 'Cupom inválido.');
  end if;
  if c.valid_until is not null and c.valid_until < current_date then
    return jsonb_build_object('valid', false, 'message', 'Este cupom expirou.');
  end if;
  if c.max_uses is not null and c.uses >= c.max_uses then
    return jsonb_build_object('valid', false, 'message', 'Este cupom já foi totalmente usado.');
  end if;
  if p_subtotal < c.min_order then
    return jsonb_build_object('valid', false, 'message', 'Este cupom vale a partir de ' || _money(c.min_order) || '.');
  end if;
  v_discount := case when c.kind = 'percent' then round(p_subtotal * c.value / 100, 2)
                     else least(c.value, p_subtotal) end;
  return jsonb_build_object(
    'valid', true, 'coupon_id', c.id, 'code', upper(c.code), 'discount', v_discount,
    'message', case when c.kind = 'percent' then 'Cupom de ' || trim(to_char(c.value, 'FM990')) || '% aplicado!'
                    else 'Cupom de ' || _money(c.value) || ' aplicado!' end);
end $$;
revoke execute on function _coupon_lookup(uuid, text, numeric) from public, anon, authenticated;

create function check_coupon(p_business uuid, p_code text, p_subtotal numeric) returns jsonb
language sql stable security definer set search_path = public as $$
  select _coupon_lookup(p_business, p_code, p_subtotal) - 'coupon_id'
$$;

-- Fidelidade: carimbo automático quando um atendimento/pedido é concluído.
create function _add_loyalty_stamp(p_business uuid, p_phone text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
begin
  if length(v_phone) < 8 or not has_feature(p_business, 'fidelidade') then
    return;
  end if;
  if not exists (select 1 from loyalty_programs where business_id = p_business and active) then
    return;
  end if;
  insert into loyalty_cards (business_id, phone, name, stamps)
  values (p_business, v_phone, p_name, 1)
  on conflict (business_id, phone) do update
    set stamps = loyalty_cards.stamps + 1,
        name = coalesce(loyalty_cards.name, excluded.name),
        updated_at = now();
end $$;
revoke execute on function _add_loyalty_stamp(uuid, text, text) from public, anon, authenticated;

create function loyalty_on_appointment() returns trigger
language plpgsql security definer set search_path = public as $$
declare c customers;
begin
  if new.status = 'completed' and (tg_op = 'INSERT' or old.status is distinct from 'completed') then
    select * into c from customers where id = new.customer_id;
    perform _add_loyalty_stamp(new.business_id, c.phone, c.name);
  end if;
  return new;
end $$;
create trigger appointments_loyalty after insert or update of status on appointments
  for each row execute function loyalty_on_appointment();

create function loyalty_on_order() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'entregue' and (tg_op = 'INSERT' or old.status is distinct from 'entregue') then
    perform _add_loyalty_stamp(new.business_id, new.phone, new.customer_name);
  end if;
  return new;
end $$;
create trigger orders_loyalty after insert or update of status on orders
  for each row execute function loyalty_on_order();

revoke execute on function loyalty_on_appointment() from public, anon, authenticated;
revoke execute on function loyalty_on_order()       from public, anon, authenticated;

-- Cliente consulta o próprio cartão fidelidade pelo telefone.
create function check_loyalty(p_business uuid, p_phone text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  p loyalty_programs;
  v_stamps int;
begin
  select * into p from loyalty_programs where business_id = p_business and active;
  if not found or not has_feature(p_business, 'fidelidade') then
    return null;
  end if;
  select stamps into v_stamps from loyalty_cards
   where business_id = p_business and phone = regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  return jsonb_build_object('stamps', coalesce(v_stamps, 0), 'required', p.stamps_required, 'reward', p.reward);
end $$;

-- ---------------------------------------------------------------------
-- Avaliações (entram como "pendente" até o dono aprovar)
-- ---------------------------------------------------------------------

create function submit_review(p_business uuid, p_name text, p_rating int, p_comment text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from businesses where id = p_business and status = 'approved')
     or not has_feature(p_business, 'avaliacoes') then
    raise exception 'Avaliações indisponíveis para este estabelecimento.';
  end if;
  if p_rating not between 1 and 5 then
    raise exception 'Escolha de 1 a 5 estrelas.';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Informe seu nome.';
  end if;
  if (select count(*) from reviews where business_id = p_business and status = 'pending') >= 50 then
    raise exception 'Muitas avaliações aguardando aprovação. Tente novamente mais tarde.';
  end if;
  insert into reviews (business_id, author_name, rating, comment)
  values (p_business, left(trim(p_name), 60), p_rating, nullif(left(trim(coalesce(p_comment, '')), 500), ''));
end $$;

-- ---------------------------------------------------------------------
-- Catálogo: pedido salvo no painel (e enviado ao WhatsApp pelo site)
-- ---------------------------------------------------------------------

create function place_order(p_business uuid, p_items jsonb, p_name text, p_phone text, p_mode text,
                            p_address text default null, p_payment text default 'pix',
                            p_change numeric default null, p_notes text default null,
                            p_coupon text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b          businesses;
  v_line     record;
  v_subtotal numeric := 0;
  v_fee      numeric := 0;
  v_discount numeric := 0;
  v_coupon   jsonb;
  v_number   int;
  v_order    uuid;
  v_lines    jsonb := '[]'::jsonb;
begin
  select * into b from businesses where id = p_business;
  if not found or b.kind <> 'cardapio' or not business_is_live(p_business) then
    raise exception 'Esta loja não está recebendo pedidos online.';
  end if;
  if not b.accepting_orders or not is_store_open(p_business) then
    raise exception 'A loja está fechada no momento.';
  end if;
  if coalesce(trim(p_name), '') = '' or length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then
    raise exception 'Informe seu nome e WhatsApp.';
  end if;
  if p_mode = 'entrega' then
    if not b.delivery_enabled then raise exception 'Esta loja não faz entrega.'; end if;
    if coalesce(trim(p_address), '') = '' then raise exception 'Informe o endereço de entrega.'; end if;
    v_fee := b.delivery_fee;
  elsif p_mode = 'retirada' then
    if not b.pickup_enabled then raise exception 'Esta loja não tem retirada no local.'; end if;
  else
    raise exception 'Escolha retirada ou entrega.';
  end if;

  for v_line in
    select i.id, i.name, i.price, least(greatest((e->>'qty')::int, 1), 99) as qty
      from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
      join menu_items i on i.id = (e->>'id')::uuid and i.business_id = p_business and i.available
      join menu_categories c on c.id = i.category_id and c.active
  loop
    v_subtotal := v_subtotal + v_line.price * v_line.qty;
    v_lines := v_lines || jsonb_build_object('id', v_line.id, 'name', v_line.name, 'unit_price', v_line.price,
                                             'qty', v_line.qty, 'total', v_line.price * v_line.qty);
  end loop;
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'Sua sacola está vazia ou os itens não estão mais disponíveis.';
  end if;
  if v_subtotal < b.min_order then
    raise exception 'O pedido mínimo é %.', _money(b.min_order);
  end if;

  if coalesce(trim(p_coupon), '') <> '' then
    v_coupon := _coupon_lookup(p_business, p_coupon, v_subtotal);
    if not (v_coupon->>'valid')::boolean then
      raise exception '%', v_coupon->>'message';
    end if;
    v_discount := (v_coupon->>'discount')::numeric;
    update coupons set uses = uses + 1 where id = (v_coupon->>'coupon_id')::uuid;
  end if;

  perform pg_advisory_xact_lock(hashtext(p_business::text));
  select coalesce(max(number), 0) + 1 into v_number from orders where business_id = p_business;

  insert into orders (business_id, number, customer_name, phone, mode, address, payment, change_for, notes,
                      subtotal, delivery_fee, discount, total, coupon_code)
  values (p_business, v_number, left(trim(p_name), 80), left(trim(p_phone), 30), p_mode,
          nullif(left(trim(coalesce(p_address, '')), 300), ''), left(coalesce(p_payment, 'pix'), 40), p_change,
          nullif(left(trim(coalesce(p_notes, '')), 500), ''),
          v_subtotal, v_fee, v_discount, greatest(v_subtotal + v_fee - v_discount, 0), v_coupon->>'code')
  returning id into v_order;

  insert into order_items (order_id, business_id, item_id, name, unit_price, qty, total)
  select v_order, p_business, (l->>'id')::uuid, l->>'name', (l->>'unit_price')::numeric,
         (l->>'qty')::int, (l->>'total')::numeric
    from jsonb_array_elements(v_lines) l;

  return jsonb_build_object('id', v_order, 'number', v_number, 'items', v_lines,
                            'subtotal', v_subtotal, 'delivery_fee', v_fee, 'discount', v_discount,
                            'total', greatest(v_subtotal + v_fee - v_discount, 0), 'coupon', v_coupon->>'code');
end $$;

-- ---------------------------------------------------------------------
-- Orçamentos
-- ---------------------------------------------------------------------

create function submit_quote(p_business uuid, p_name text, p_phone text, p_description text,
                             p_district text default null, p_preferred_date date default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not exists (select 1 from businesses where id = p_business and kind = 'orcamento')
     or not business_is_live(p_business) then
    raise exception 'Este profissional não está recebendo pedidos de orçamento no momento.';
  end if;
  if coalesce(trim(p_name), '') = '' or length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then
    raise exception 'Informe seu nome e WhatsApp.';
  end if;
  if char_length(trim(coalesce(p_description, ''))) < 5 then
    raise exception 'Descreva o serviço que você precisa.';
  end if;
  if (select count(*) from quote_requests
       where business_id = p_business and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Muitos pedidos agora. Tente novamente em alguns minutos.';
  end if;
  insert into quote_requests (business_id, name, phone, description, district, preferred_date)
  values (p_business, left(trim(p_name), 80), left(trim(p_phone), 30), left(trim(p_description), 2000),
          nullif(left(trim(coalesce(p_district, '')), 80), ''), p_preferred_date)
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------

create function request_reservation(p_business uuid, p_name text, p_phone text, p_start date,
                                    p_end date default null, p_time time default null,
                                    p_party int default 1, p_unit uuid default null,
                                    p_email text default null, p_notes text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b      businesses;
  u      reservation_units;
  v_end  date;
  v_total numeric := 0;
  v_id   uuid;
  v_today date;
begin
  select * into b from businesses where id = p_business;
  if not found or b.kind <> 'reserva' or not business_is_live(p_business) then
    raise exception 'Este estabelecimento não está recebendo reservas no momento.';
  end if;
  v_today := (now() at time zone b.timezone)::date;
  if p_start is null or p_start < v_today or p_start > v_today + 365 then
    raise exception 'Escolha uma data a partir de hoje (até 1 ano).';
  end if;
  if coalesce(trim(p_name), '') = '' or length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then
    raise exception 'Informe seu nome e WhatsApp.';
  end if;

  if b.reservation_mode = 'horario' then
    if p_time is null then raise exception 'Escolha o horário.'; end if;
    if p_party < 1 or p_party > b.max_party then
      raise exception 'Reservas para até % pessoas. Para grupos maiores, fale com o estabelecimento.', b.max_party;
    end if;
    v_end := p_start + 1;
  else
    select * into u from reservation_units where id = p_unit and business_id = p_business and active;
    if not found then raise exception 'Escolha uma opção disponível.'; end if;
    v_end := p_end;
    if v_end is null or v_end <= p_start then raise exception 'A data de saída precisa ser depois da entrada.'; end if;
    if v_end - p_start > 60 then raise exception 'Reservas de até 60 diárias.'; end if;
    if p_party < 1 or p_party > u.capacity then
      raise exception 'Esta opção comporta até % pessoas.', u.capacity;
    end if;
    if exists (select 1 from reservations r
                where r.unit_id = u.id and r.status = 'confirmada'
                  and daterange(r.start_date, r.end_date) && daterange(p_start, v_end)) then
      raise exception 'Essas datas não estão disponíveis. Escolha outras.';
    end if;
    v_total := u.price * (v_end - p_start);
  end if;

  insert into reservations (business_id, unit_id, name, phone, email, party_size, start_date, end_date, at_time, notes, total)
  values (p_business, case when b.reservation_mode = 'diaria' then u.id end,
          left(trim(p_name), 80), left(trim(p_phone), 30), nullif(trim(coalesce(p_email, '')), ''),
          p_party, p_start, v_end, case when b.reservation_mode = 'horario' then p_time end,
          nullif(left(trim(coalesce(p_notes, '')), 500), ''), v_total)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'total', v_total, 'nights', v_end - p_start);
end $$;

-- Datas já confirmadas de uma unidade (para o calendário público).
create function get_unit_busy_dates(p_unit uuid) returns table (start_date date, end_date date)
language sql stable security definer set search_path = public as $$
  select r.start_date, r.end_date from reservations r
   where r.unit_id = p_unit and r.status = 'confirmada' and r.end_date >= current_date
   order by r.start_date
$$;

-- ---------------------------------------------------------------------
-- Eventos e turmas
-- ---------------------------------------------------------------------

create function register_event(p_event uuid, p_name text, p_phone text, p_quantity int default 1,
                               p_email text default null, p_coupon text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  e          events;
  v_taken    int;
  v_subtotal numeric;
  v_discount numeric := 0;
  v_coupon   jsonb;
  v_id       uuid;
begin
  select * into e from events where id = p_event and active for update;
  if not found or not business_is_live(e.business_id) then
    raise exception 'Inscrições indisponíveis para este evento.';
  end if;
  if e.starts_at <= now() then
    raise exception 'As inscrições deste evento já foram encerradas.';
  end if;
  if coalesce(trim(p_name), '') = '' or length(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g')) < 8 then
    raise exception 'Informe seu nome e WhatsApp.';
  end if;
  if p_quantity < 1 or p_quantity > 20 then
    raise exception 'Escolha de 1 a 20 vagas.';
  end if;
  if e.capacity is not null then
    select coalesce(sum(quantity), 0) into v_taken from event_registrations
     where event_id = e.id and status = 'confirmada';
    if v_taken + p_quantity > e.capacity then
      raise exception 'Restam apenas % vaga(s).', greatest(e.capacity - v_taken, 0);
    end if;
  end if;

  v_subtotal := e.price * p_quantity;
  if coalesce(trim(p_coupon), '') <> '' then
    v_coupon := _coupon_lookup(e.business_id, p_coupon, v_subtotal);
    if not (v_coupon->>'valid')::boolean then
      raise exception '%', v_coupon->>'message';
    end if;
    v_discount := (v_coupon->>'discount')::numeric;
    update coupons set uses = uses + 1 where id = (v_coupon->>'coupon_id')::uuid;
  end if;

  insert into event_registrations (business_id, event_id, name, phone, email, quantity, total, coupon_code)
  values (e.business_id, e.id, left(trim(p_name), 80), left(trim(p_phone), 30),
          nullif(trim(coalesce(p_email, '')), ''), p_quantity, greatest(v_subtotal - v_discount, 0), v_coupon->>'code')
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'total', greatest(v_subtotal - v_discount, 0), 'discount', v_discount);
end $$;

-- ---------------------------------------------------------------------
-- Agendamento com cupom
-- ---------------------------------------------------------------------

drop function book_appointment(uuid, uuid, uuid, timestamptz, text, text, text);

create function book_appointment(p_business uuid, p_service uuid, p_professional uuid,
                                 p_starts_at timestamptz, p_name text, p_phone text,
                                 p_notes text default null, p_coupon text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid      uuid := auth.uid();
  v_tz       text;
  v_duration int;
  v_price    numeric;
  v_coupon   jsonb;
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

  if coalesce(trim(p_coupon), '') <> '' then
    v_coupon := _coupon_lookup(p_business, p_coupon, v_price);
    if not (v_coupon->>'valid')::boolean then
      raise exception '%', v_coupon->>'message';
    end if;
    v_price := greatest(v_price - (v_coupon->>'discount')::numeric, 0);
    update coupons set uses = uses + 1 where id = (v_coupon->>'coupon_id')::uuid;
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
          p_starts_at, p_starts_at + make_interval(mins => v_duration), v_price,
          concat_ws(' · ', nullif(trim(coalesce(p_notes, '')), ''),
                    case when v_coupon is not null then 'Cupom ' || (v_coupon->>'code') end),
          v_uid)
  returning id into v_id;

  return v_id;
exception
  when exclusion_violation then
    raise exception 'Este horário acabou de ser reservado por outra pessoa. Escolha outro.';
end $$;

-- ---------------------------------------------------------------------
-- Página pública: tudo o que cada tipo de vitrine precisa
-- ---------------------------------------------------------------------

create or replace function get_public_business(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', b.id, 'slug', b.slug, 'kind', b.kind, 'name', b.name, 'category', b.category,
    'description', b.description, 'phone', b.phone, 'address', b.address,
    'logo_url', b.logo_url, 'primary_color', b.primary_color, 'timezone', b.timezone,
    'staff_label', b.staff_label,
    'live', business_is_live(b.id),
    'features', coalesce((select to_jsonb(p.features) from subscriptions s join plans p on p.id = s.plan_id
                           where s.business_id = b.id), '[]'::jsonb),

    'services', case when b.kind = 'agenda' then coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', s.id, 'name', s.name, 'description', s.description,
               'price', s.price, 'duration_min', s.duration_min) order by s.name)
        from services s where s.business_id = b.id and s.active), '[]'::jsonb) end,
    'professionals', case when b.kind = 'agenda' then coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', p.name, 'photo_url', p.photo_url,
               'service_ids', coalesce((select jsonb_agg(ps.service_id)
                                          from professional_services ps
                                         where ps.professional_id = p.id), '[]'::jsonb)) order by p.name)
        from professionals p where p.business_id = b.id and p.active), '[]'::jsonb) end,

    'menu', case when b.kind in ('cardapio', 'orcamento') then coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'name', c.name,
               'items', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', i.id, 'name', i.name, 'description', i.description,
                          'price', i.price, 'photo_url', i.photo_url, 'available', i.available)
                        order by i.sort_order, i.name)
                   from menu_items i where i.category_id = c.id), '[]'::jsonb))
             order by c.sort_order, c.name)
        from menu_categories c where c.business_id = b.id and c.active), '[]'::jsonb) end,

    'store', case when b.kind = 'cardapio' then jsonb_build_object(
      'accepting_orders', b.accepting_orders,
      'open_now',         is_store_open(b.id),
      'pickup_enabled',   b.pickup_enabled,
      'delivery_enabled', b.delivery_enabled,
      'delivery_fee',     b.delivery_fee,
      'min_order',        b.min_order,
      'delivery_area',    b.delivery_area,
      'hours', coalesce((
        select jsonb_agg(jsonb_build_object('weekday', h.weekday, 'start', h.start_time, 'end', h.end_time)
                         order by h.weekday, h.start_time)
          from store_hours h where h.business_id = b.id), '[]'::jsonb)) end,

    'reservation', case when b.kind = 'reserva' then jsonb_build_object(
      'mode', b.reservation_mode, 'max_party', b.max_party, 'notice', b.reservation_notice,
      'units', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', u.id, 'name', u.name, 'description', u.description, 'capacity', u.capacity,
                 'price', u.price, 'photo_url', u.photo_url) order by u.name)
          from reservation_units u where u.business_id = b.id and u.active), '[]'::jsonb)) end,

    'events', case when b.kind = 'evento' then coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'title', e.title, 'description', e.description, 'starts_at', e.starts_at,
               'ends_at', e.ends_at, 'location', e.location, 'price', e.price, 'photo_url', e.photo_url,
               'capacity', e.capacity,
               'spots_left', case when e.capacity is null then null else greatest(e.capacity - coalesce((
                  select sum(r.quantity) from event_registrations r
                   where r.event_id = e.id and r.status = 'confirmada'), 0), 0) end)
             order by e.starts_at)
        from events e where e.business_id = b.id and e.active and e.starts_at > now()), '[]'::jsonb) end,

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

-- Lista do admin: contagem de "itens" conforme o tipo.
drop function admin_list_businesses();

create function admin_list_businesses()
returns table (id uuid, slug text, kind text, name text, category text, phone text, status business_status,
               status_reason text, created_at timestamptz, owner_email text,
               plan_id text, plan_name text, base_price numeric, subscription_status subscription_status,
               custom_price numeric, discount_amount numeric, discount_until date, discount_note text,
               monthly_price numeric, current_period_end timestamptz,
               professionals_count bigint, customers_count bigint, appointments_count bigint,
               menu_items_count bigint, activity_count bigint)
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
         (select count(*) from menu_items x where x.business_id = b.id),
         case b.kind
           when 'agenda'    then (select count(*) from appointments x where x.business_id = b.id)
           when 'cardapio'  then (select count(*) from orders x where x.business_id = b.id)
           when 'orcamento' then (select count(*) from quote_requests x where x.business_id = b.id)
           when 'reserva'   then (select count(*) from reservations x where x.business_id = b.id)
           when 'evento'    then (select count(*) from event_registrations x where x.business_id = b.id)
           else (select count(*) from business_links x where x.business_id = b.id)
         end
    from businesses b
    left join auth.users u    on u.id = b.created_by
    left join subscriptions s on s.business_id = b.id
    left join plans p         on p.id = s.plan_id
   order by (b.status = 'pending') desc, b.created_at desc;
end $$;

-- Aceita os novos tipos no cadastro.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_meta jsonb := new.raw_user_meta_data;
  v_kind text  := case when new.raw_user_meta_data->>'business_kind'
                            in ('agenda', 'cardapio', 'cartao', 'orcamento', 'reserva', 'evento')
                       then new.raw_user_meta_data->>'business_kind' else 'agenda' end;
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
revoke execute on function handle_new_user() from public, anon, authenticated;
