-- sync_club_role_entitlement darf nur noch fuer den eigenen Verein laufen.
--
-- DIE LUECKE
-- Die Funktion ist SECURITY DEFINER, fuer authenticated ausfuehrbar und
-- prueft den Aufrufer nicht. Der Verein kommt als Parameter herein. Ergibt
-- club_subscription_tier(target_club) den Wert 'none', loescht sie ALLE
-- Eintraege aus membership_roles ausser 'mitglied' - fuer saemtliche
-- Mitgliedschaften dieses Vereins.
--
-- Damit konnte jeder Angemeldete einem beliebigen fremden Verein ohne
-- laufendes Abo in einem Aufruf die komplette Rollenstruktur loeschen:
-- Vereinsadmin, Trainer, Organisator, Teammanager, Kapitaen. Wer danach
-- wieder ein Abo abschliesst, bekommt die Rollen NICHT automatisch zurueck -
-- das steht so in der Funktion und ist Absicht. Der Schaden waere also
-- bleibend und muesste von Hand repariert werden.
--
-- DIE APP BRAUCHT DIE FUNKTION WEITER
-- useClubEntitlement ruft sie nach dem Anmelden fuer den EIGENEN Verein auf,
-- wenn kein Tarif laeuft. Genau das bleibt erlaubt. Nur der Griff nach einem
-- fremden Verein ist zu.
--
-- Rueckgabewert und Verhalten fuer den erlaubten Fall sind unveraendert.
create or replace function public.sync_club_role_entitlement(target_club uuid)
returns text language plpgsql security definer set search_path = 'public' as $$
declare
  v_tier text;
begin
  v_tier := public.club_subscription_tier(target_club);

  /* Nur im eigenen Verein aufraeumen. Der Tarif darf jeder erfragen - das
     verraet nichts, was nicht ohnehin sichtbar waere -, aber loeschen nur,
     wer dazugehoert. */
  if v_tier = 'none' and public.is_club_member(target_club) then
    delete from public.membership_roles
    where role <> 'mitglied'
      and membership_id in (select id from public.club_memberships where club_id = target_club);
  end if;
  return v_tier;
end;
$$;

select (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and proname='sync_club_role_entitlement'
    and prosrc like '%is_club_member%') as waechter_gesetzt;
