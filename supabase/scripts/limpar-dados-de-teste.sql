-- =====================================================================
-- GG Vitrine — apagar vitrines de teste antes do lançamento
--
-- NÃO é uma migração: rode só quando for limpar, no SQL Editor.
-- Apagar uma vitrine remove junto tudo dela: assinatura, pagamentos,
-- serviços, profissionais, clientes, agendamentos, pedidos, reservas,
-- avaliações, cupons etc. A conta de login do dono NÃO é apagada.
-- =====================================================================

-- 1) Confira o que existe hoje:
select slug, name, kind, status, created_at from businesses order by created_at;

-- 2) Coloque na lista os links (slug) das vitrines de teste e rode:
--    (tire o "--" do início das linhas abaixo)
-- delete from businesses
--  where slug in (
--    'gabi-cortes'
--  );

-- 3) Opcional: apagar contas de login de teste que não são donas de nenhuma
--    vitrine e não são administradoras (ex.: e-mails usados como "cliente").
--    Confira a lista antes:
-- select u.email, u.created_at
--   from auth.users u
--  where not exists (select 1 from business_members m where m.user_id = u.id)
--    and not exists (select 1 from platform_admins a where a.user_id = u.id)
--  order by u.created_at;
--
--    E, se estiver tudo certo, apague só as que forem de teste:
-- delete from auth.users where email in ('teste@exemplo.com');
