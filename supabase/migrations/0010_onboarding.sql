-- =====================================================================
-- MarqueAí — 0010: flag de onboarding completo
--
-- Como aplicar: Supabase > SQL Editor > cole e Run. Idempotente.
--
-- Quando a vitrine é criada, começa com onboarding_done = false. O painel
-- redireciona o dono pra tela de /painel/comecar na primeira vez, onde ele
-- escolhe um template (barbearia, salão, clínica...) e já cai com serviços e
-- horários pré-preenchidos. Depois marca done = true e cai no painel normal.
-- =====================================================================

alter table businesses add column if not exists onboarding_done boolean not null default false;

-- Pra quem já tem serviço cadastrado, considera o onboarding feito.
update businesses b set onboarding_done = true
 where exists (select 1 from services s where s.business_id = b.id);
