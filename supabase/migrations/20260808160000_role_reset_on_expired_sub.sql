-- Rollen jenseits der Basisrolle "mitglied" sind an ein aktives Vereinsabo geknüpft
-- (die Zuweisung selbst ist bereits über das Premium-Erfordernis der Verwaltungs-UI
-- gesperrt, siehe LockedFeature um AdminView). Läuft das Abo ab/endet es, werden alle
-- Rollen außer "mitglied" automatisch entfernt. Wird der Verein später wieder aktiv
-- abonniert, werden Rollen NICHT automatisch wiederhergestellt — der Verein muss
-- Mitglieder aktiv erneut befördern (siehe Rollen-Panel).
create or replace function public.sync_club_role_entitlement(target_club uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_tier text;
begin
  v_tier := public.club_subscription_tier(target_club);
  if v_tier = 'none' then
    delete from public.membership_roles
    where role <> 'mitglied'
      and membership_id in (select id from public.club_memberships where club_id = target_club);
  end if;
  return v_tier;
end;
$$;

grant execute on function public.sync_club_role_entitlement(uuid) to authenticated;
