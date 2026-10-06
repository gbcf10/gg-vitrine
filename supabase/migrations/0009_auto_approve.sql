-- =====================================================================
-- MarqueAí — 0009: cadastro cai aprovado automaticamente
--
-- Como aplicar: Supabase > SQL Editor > cole e Run. Idempotente.
--
-- Antes: toda vitrine nova entrava com status 'pending' e precisava de
-- aprovação manual do admin pra o dono conseguir montar.
--
-- Depois: cadastro novo já entra 'approved'. A barreira pra usar fica no
-- plano/assinatura (business_is_live exige subscription ativa). Admin
-- continua podendo bloquear casos ruins.
-- =====================================================================

alter table businesses alter column status set default 'approved';
update businesses set status = 'approved', approved_at = coalesce(approved_at, now())
 where status = 'pending';
