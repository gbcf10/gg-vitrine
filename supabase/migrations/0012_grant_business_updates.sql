-- =====================================================================
-- MarqueAí — 0012: dono pode atualizar staff_label e onboarding_done
--
-- Como aplicar: Supabase > SQL Editor > cole e Run. Idempotente.
--
-- O grant original de UPDATE em businesses enumera as colunas que o dono
-- pode mexer. staff_label (que o dono define no Profile e no Onboarding) e
-- onboarding_done (criado em 0010) não estavam na lista.
-- =====================================================================

grant update (
  name, category, description, phone, address, logo_url, primary_color,
  slot_interval_min, staff_label, onboarding_done
) on businesses to authenticated;
