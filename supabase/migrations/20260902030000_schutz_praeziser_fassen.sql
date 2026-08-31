-- Der Schutz der eigenen Mitgliedschaft, enger gefasst.
--
-- Die erste Fassung sperrte auch display_name und membership_number. Beides
-- darf ein Mitglied aber längst selbst setzen — update_own_profile() tut genau
-- das, und das ist die reguläre Profilbearbeitung, die jeder benutzt. Der
-- Schutz hätte sie abgebrochen.
--
-- Worum es wirklich geht, sind drei Felder:
--
--   status       wer ihn selbst setzen kann, gibt sich die Aufnahme selbst
--                frei und hebt jede Sperre auf
--   club_id      verschiebt die eigene Mitgliedschaft in einen fremden Verein
--   profile_id   übernimmt die Mitgliedschaft eines anderen
--
-- Alles andere an der eigenen Zeile ist Selbstverwaltung und geht niemanden
-- sonst etwas an.

create or replace function public.eigene_mitgliedschaft_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null
     or auth.role() = 'service_role'
     or coalesce(current_setting('app.mitgliedschaft_pflege', true), '') = 'ja'
     or public.has_club_role(new.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
  then
    return new;
  end if;

  if new.profile_id = auth.uid()
     and (new.status is distinct from old.status
          or new.club_id is distinct from old.club_id
          or new.profile_id is distinct from old.profile_id)
  then
    raise exception 'Aufnahmestatus und Vereinszugehoerigkeit setzt die Vereinsleitung.' using errcode = 'P0001';
  end if;

  return new;
end;
$$;
