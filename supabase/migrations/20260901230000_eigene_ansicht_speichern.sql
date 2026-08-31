-- Die eigene Standardansicht darf man selbst speichern.
--
-- club_memberships ließ bisher nur die Vereinsleitung schreiben ("admins manage
-- memberships"). Für Rollen, Status und Mitgliedsnummer ist das richtig — ein
-- Mitglied soll sich nicht selbst zum Vorstand machen. Die gespeicherte
-- Mannschaftsansicht ist aber eine Vorliebe, keine Berechtigung, und sie lag
-- deshalb bisher im Gerätespeicher: weg nach der Neuinstallation, ungültig auf
-- dem zweiten Gerät.
--
-- Diese Regel erlaubt nur die eigene Zeile. Dass sie nur team_filter betreffen
-- darf, sichert der Trigger darunter — eine Policy kann keine einzelnen Spalten
-- freigeben, und ohne diese Ergänzung wäre die Regel ein Freibrief auf die
-- eigene Rolle.

drop policy if exists "own membership view preference" on public.club_memberships;
create policy "own membership view preference" on public.club_memberships
for update to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create or replace function public.eigene_mitgliedschaft_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Die Vereinsleitung und der Dienstschlüssel dürfen alles.
  if auth.uid() is null
     or auth.role() = 'service_role'
     or public.has_club_role(new.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
  then
    return new;
  end if;

  -- Für alle anderen gilt an der eigenen Zeile: nur die Ansicht.
  if new.profile_id = auth.uid() then
    if new.status is distinct from old.status
       or new.club_id is distinct from old.club_id
       or new.profile_id is distinct from old.profile_id
       or new.membership_number is distinct from old.membership_number
       or new.display_name is distinct from old.display_name
       or new.email is distinct from old.email
       or new.member_since is distinct from old.member_since
    then
      raise exception 'An der eigenen Mitgliedschaft laesst sich nur die gespeicherte Ansicht aendern.' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists club_memberships_eigene_zeile on public.club_memberships;
create trigger club_memberships_eigene_zeile before update on public.club_memberships
for each row execute function public.eigene_mitgliedschaft_schuetzen();
