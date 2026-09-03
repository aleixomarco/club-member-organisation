-- Alle Vereine bis auf SV Musterstadt entfernen
--
-- Auftrag des Betreibers am 04.09.2026: "alle vereine und daten löschen bis
-- auf den muster verein".
--
-- Das betrifft ERG Iserlohn samt allem, was daran hängt. Die Fremdschlüssel
-- tragen "on delete cascade" auf club_id, deshalb gehen mit dem Verein auch:
--   Mannschaften und Zuordnungen, Termine (177), Kanäle und Nachrichten,
--   News, Umfragen, Protokolle, Aufgaben, Mitgliedschaften und deren Rollen,
--   Fahrgemeinschaften, Helfereinteilungen, Strafen, Fahrzeuge, Anzeigen.
--
-- NICHT gelöscht werden Anmeldekonten (auth.users). Wer dort ein Konto hat,
-- kann sich weiter anmelden - er steht danach nur in keinem Verein mehr und
-- landet in der Vereinsauswahl. Das ist Absicht: Ein Konto zu löschen ist
-- endgültig, aus einem Verein auszutreten nicht.
--
-- SV Musterstadt bleibt vollständig, mit Inhalten - der Apple-Prüfzugang
-- braucht einen Verein, in dem etwas zu sehen ist.

do $$
declare
  v_demo   uuid := 'd0000000-0000-4000-a000-000000000001';
  v_anzahl integer;
begin
  /* Sicherheitsnetz: Gibt es den Demo-Verein nicht, wäre nach dem Löschen
     KEIN Verein mehr da - dann lieber abbrechen. */
  if not exists (select 1 from public.clubs where id = v_demo) then
    raise exception 'SV Musterstadt (%) nicht gefunden - Abbruch, sonst bliebe kein Verein uebrig.', v_demo;
  end if;

  select count(*) into v_anzahl from public.clubs where id <> v_demo;
  raise notice 'Es werden % Verein(e) geloescht.', v_anzahl;

  delete from public.clubs where id <> v_demo;
end $$;

-- Kontrolle
select 'clubs' as tabelle, count(*) from public.clubs
union all select 'profiles', count(*) from public.profiles
union all select 'club_memberships', count(*) from public.club_memberships
union all select 'teams', count(*) from public.teams
union all select 'events', count(*) from public.events
union all select 'channels', count(*) from public.channels
union all select 'messages', count(*) from public.messages;
