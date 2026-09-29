-- =====================================================================
-- GG Vitrine — 0004: lembretes automáticos de agendamento
--
-- Como aplicar: Supabase > SQL Editor > cole este arquivo inteiro > Run.
-- (Precisa que 0001, 0002 e 0003 já tenham sido aplicados.)
--
-- Como funciona:
--   * Cada estabelecimento escolhe quando lembrar o cliente e o profissional:
--     30 min, 45 min, 1 h, 1 h 30 ou 2 h antes (pode marcar vários).
--   * A cada 5 minutos o banco procura lembretes vencidos e envia por e-mail
--     (via Resend). Cada lembrete é enviado uma única vez (reminder_log).
--   * O envio só começa depois de cadastrar a chave do Resend no Vault
--     (instruções no final deste arquivo). Sem a chave, nada é enviado.
-- =====================================================================

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------------
-- Configuração
-- ---------------------------------------------------------------------

alter table businesses
  add column remind_client_offsets int[] not null default '{60}',
  add column remind_staff_offsets  int[] not null default '{}',
  add constraint businesses_remind_offsets_check check (
    remind_client_offsets <@ array[30, 45, 60, 90, 120] and remind_staff_offsets <@ array[30, 45, 60, 90, 120]);

grant update (remind_client_offsets, remind_staff_offsets) on businesses to authenticated;

-- Contato do profissional, para ele também receber os lembretes.
alter table professionals
  add column phone text check (char_length(phone) <= 30),
  add column email text check (char_length(email) <= 120);

-- ---------------------------------------------------------------------
-- Registro dos lembretes (garante que cada um sai uma vez só)
-- ---------------------------------------------------------------------

create table reminder_log (
  id             uuid primary key default gen_random_uuid(),
  business_id    uuid not null references businesses (id) on delete cascade,
  appointment_id uuid not null references appointments (id) on delete cascade,
  target         text not null check (target in ('cliente', 'profissional')),
  offset_min     int  not null,
  channel        text not null default 'email',
  status         text not null check (status in ('enviado', 'sem_contato', 'erro')),
  sent_to        text,
  created_at     timestamptz not null default now(),
  unique (appointment_id, target, offset_min)
);
create index on reminder_log (business_id, created_at desc);

alter table reminder_log enable row level security;
create policy reminder_log_read on reminder_log for select
  using (is_member(business_id) or is_platform_admin());
revoke insert, update, delete on reminder_log from anon, authenticated;

-- ---------------------------------------------------------------------
-- Lembretes vencidos
-- ---------------------------------------------------------------------

-- Um lembrete "vence" quando faltam N minutos ou menos para o horário.
-- Lembretes atrasados mais de 20 minutos são ignorados (ex.: agendamento
-- feito em cima da hora ou configuração ligada depois).
create function due_reminders(p_limit int default 200)
returns table (business_id uuid, appointment_id uuid, target text, offset_min int,
               to_email text, to_phone text, to_name text, business_name text, business_address text,
               service_name text, staff_name text, customer_name text, starts_at timestamptz, timezone text)
language sql stable security definer set search_path = public as $$
  with cfg as (
    select b.id, b.name, b.address, b.timezone, 'cliente'::text as target, unnest(b.remind_client_offsets) as offset_min
      from businesses b where b.status = 'approved' and has_feature(b.id, 'lembretes')
    union all
    select b.id, b.name, b.address, b.timezone, 'profissional', unnest(b.remind_staff_offsets)
      from businesses b where b.status = 'approved' and has_feature(b.id, 'lembretes')
  )
  select a.business_id, a.id, cfg.target, cfg.offset_min,
         case when cfg.target = 'cliente' then c.email else p.email end,
         case when cfg.target = 'cliente' then c.phone else p.phone end,
         case when cfg.target = 'cliente' then c.name else p.name end,
         cfg.name, cfg.address, s.name, p.name, c.name, a.starts_at, cfg.timezone
    from cfg
    join appointments a  on a.business_id = cfg.id and a.status in ('scheduled', 'confirmed')
    join customers c     on c.id = a.customer_id
    join services s      on s.id = a.service_id
    join professionals p on p.id = a.professional_id
   where a.starts_at > now()
     and a.starts_at - make_interval(mins => cfg.offset_min) <= now()
     and a.starts_at - make_interval(mins => cfg.offset_min) > now() - interval '20 minutes'
     and business_is_live(a.business_id)
     and not exists (select 1 from reminder_log l
                      where l.appointment_id = a.id and l.target = cfg.target and l.offset_min = cfg.offset_min)
   order by a.starts_at
   limit p_limit
$$;
revoke execute on function due_reminders(int) from public, anon, authenticated;

create function _reminder_when(p_offset int) returns text language sql immutable as $$
  select case p_offset when 30 then '30 minutos' when 45 then '45 minutos' when 60 then '1 hora'
                       when 90 then '1 hora e meia' when 120 then '2 horas' else p_offset || ' minutos' end
$$;

-- Envia os lembretes vencidos por e-mail (Resend) e registra cada um.
create function send_due_reminders() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_key  text;
  v_from text;
  r      record;
  v_time text;
  v_subject text;
  v_html text;
  v_sent int := 0;
begin
  select decrypted_secret into v_key  from vault.decrypted_secrets where name = 'resend_api_key';
  select decrypted_secret into v_from from vault.decrypted_secrets where name = 'reminder_from_email';
  if v_key is null or v_from is null then
    return 0;   -- envio automático ainda não configurado
  end if;

  for r in select * from due_reminders() loop
    if coalesce(trim(r.to_email), '') = '' then
      insert into reminder_log (business_id, appointment_id, target, offset_min, status)
      values (r.business_id, r.appointment_id, r.target, r.offset_min, 'sem_contato')
      on conflict do nothing;
      continue;
    end if;

    v_time := to_char(r.starts_at at time zone r.timezone, 'HH24:MI');
    if r.target = 'cliente' then
      v_subject := 'Lembrete: ' || r.service_name || ' às ' || v_time || ' em ' || r.business_name;
      v_html := '<p>Olá, ' || r.to_name || '!</p>'
             || '<p>Passando para lembrar: seu horário em <strong>' || r.business_name || '</strong> é daqui a '
             || _reminder_when(r.offset_min) || ', às <strong>' || v_time || '</strong>.</p>'
             || '<p>Serviço: ' || r.service_name || '<br>Com: ' || r.staff_name
             || coalesce('<br>Endereço: ' || r.business_address, '') || '</p>'
             || '<p>Se não puder ir, cancele ou remarque pelo mesmo link em que agendou.</p>';
    else
      v_subject := 'Próximo atendimento às ' || v_time || ': ' || r.customer_name;
      v_html := '<p>Olá, ' || r.to_name || '!</p>'
             || '<p>Seu próximo atendimento é daqui a ' || _reminder_when(r.offset_min) || ', às <strong>' || v_time
             || '</strong>.</p><p>Cliente: ' || r.customer_name || '<br>Serviço: ' || r.service_name || '</p>';
    end if;

    perform net.http_post(
      url     := 'https://api.resend.com/emails',
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
      body    := jsonb_build_object('from', v_from, 'to', jsonb_build_array(r.to_email),
                                    'subject', v_subject, 'html', v_html || '<p style="color:#888">Enviado por GG Vitrine</p>'));

    insert into reminder_log (business_id, appointment_id, target, offset_min, status, sent_to)
    values (r.business_id, r.appointment_id, r.target, r.offset_min, 'enviado', r.to_email)
    on conflict do nothing;
    v_sent := v_sent + 1;
  end loop;
  return v_sent;
end $$;
revoke execute on function send_due_reminders() from public, anon, authenticated;

-- Roda a cada 5 minutos.
select cron.schedule('gg-vitrine-lembretes', '*/5 * * * *', $$select public.send_due_reminders()$$);

-- ---------------------------------------------------------------------
-- Correção de texto: plural no limite de profissionais
-- ---------------------------------------------------------------------

create or replace function enforce_plan_limits() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_max   int;
  v_count int;
begin
  if tg_table_name = 'professionals' then
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
        raise exception '%', case when v_max = 1
          then 'Seu plano permite 1 profissional ativo. Faça upgrade para adicionar mais.'
          else 'Seu plano permite até ' || v_max || ' profissionais ativos. Faça upgrade para adicionar mais.' end;
      end if;
    end if;

  elsif tg_table_name = 'customers' then
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
revoke execute on function enforce_plan_limits() from public, anon, authenticated;

-- =====================================================================
-- PARA LIGAR O ENVIO AUTOMÁTICO (fazer uma vez, quando tiver o domínio):
--   1. Crie uma conta grátis em https://resend.com e verifique o domínio
--      ggvitrine.com.br (eles mostram os registros DNS para colar na Hostnet/Hostinger).
--   2. Gere uma API Key no Resend.
--   3. Rode no SQL Editor (trocando os valores):
--        select vault.create_secret('re_SUA_CHAVE_AQUI', 'resend_api_key');
--        select vault.create_secret('GG Vitrine <lembretes@ggvitrine.com.br>', 'reminder_from_email');
-- =====================================================================
