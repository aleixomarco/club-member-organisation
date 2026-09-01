-- Fünf Testvereine und die zugehörigen Testzugänge entfernen.
--
-- Anlass: Die Vereinssuche ist der zweite Bildschirm, den ein Apple-Prüfer
-- sieht - er landet dort, sobald er ohne Verein registriert, und genau diesen
-- Weg geht er, um die Kontolöschung nach 5.1.1(v) zu prüfen. Dort standen
-- zweimal "Borussia Dortmund" (einer davon mit dem Wappen der ERG Iserlohn),
-- dazu "ERGI TEST", "Ringen Iserlohn" und "Schwimmen Iserlohn". Das liest sich
-- als unfertig, und ein Bundesligaverein als Testdatensatz mit fremdem Wappen
-- ist unabhängig davon nichts, was stehenbleiben sollte.
--
-- ABSICHTLICH NICHT GELÖSCHT - beides ausdrücklich geprüft, bevor hier etwas
-- entfernt wurde:
--
--   SV Musterstadt (d0000000-...-0001)
--     22 Mitgliedschaften, aber nur 2 eigenständige Profile: 20 davon sind
--     angelegte Mitgliedsdatensätze ohne eigenen Zugang. Dazu 63 Termine und
--     4 Mannschaften. Das ist der Verein des Prüfzugangs und soll genau so
--     bleiben.
--
--   ERG Iserlohn (00000000-...-0001)
--     25 Mitgliedschaften, alle eigenständig, 25 verschiedene Profile, dazu
--     114 Termine und 5 Mannschaften. Das sind keine Testdaten, sondern ein
--     Verein, den Menschen benutzen. Er wird hier nicht angefasst.
--
-- Die fünf entfernten Vereine hatten zusammen 7 Mitgliedschaften und keinen
-- einzigen Termin.
--
-- Am Verein hängen 33 Tabellen mit "on delete cascade"; das Löschen räumt
-- Mitgliedschaften, Termine, Mannschaften, Kanäle, Einstellungen und alles
-- Übrige mit ab. Das Betreiberprotokoll behält seine Zeilen (dort steht
-- "on delete set null"), der Nachweis über frühere Freischaltungen bleibt also
-- erhalten.

do $$
declare
  zu_loeschen uuid[] := array[
    'ad001452-2140-4b6e-b90a-ec97dc308be8',  -- ERGI TEST
    '01a28b2f-7fa5-40b5-b6ff-667bb3b952bb',  -- Schwimmen Iserlohn
    'c077ba5b-bf70-4e57-b273-7f6d781f2898',  -- Ringen Iserlohn
    'a4d49bbb-176e-4497-b581-defbcc16d84a',  -- Borussia Dortmund (mit ERGI-Wappen)
    '2055c9e1-209a-4a6d-acf0-9cf38ca108af'   -- Borussia Dortmund (ohne Logo)
  ]::uuid[];
  betroffene uuid[];
  anzahl_vereine int;
  anzahl_konten int;
begin
  /* Sicherheitsnetz: Sollte eine der IDs versehentlich auf einen der beiden
     zu erhaltenden Vereine zeigen, bricht das hier ab, statt sie zu löschen. */
  if zu_loeschen && array[
       'd0000000-0000-4000-a000-000000000001',
       '00000000-0000-4000-8000-000000000001']::uuid[] then
    raise exception 'Die Liste enthaelt SV Musterstadt oder ERG Iserlohn - abgebrochen.';
  end if;

  /* Erst merken, wer in diesen Vereinen war - nach dem Löschen der Vereine
     sind die Mitgliedschaften weg und die Zuordnung nicht mehr feststellbar. */
  select coalesce(array_agg(distinct m.profile_id), '{}')
    into betroffene
    from public.club_memberships m
   where m.club_id = any(zu_loeschen)
     and m.profile_id is not null;

  delete from public.clubs where id = any(zu_loeschen);
  get diagnostics anzahl_vereine = row_count;

  /* Konten nur dann entfernen, wenn danach keine Mitgliedschaft mehr übrig
     ist. Wer auch in einem der erhaltenen Vereine steht, behält seinen Zugang.
     Die beiden Betreiberadressen bleiben in jedem Fall: Das Prüfkonto steht so
     in App Store Connect, und das eigene Konto abzuräumen wäre ein
     Eigentor. */
  delete from auth.users u
   where u.id = any(betroffene)
     and not exists (select 1 from public.club_memberships m where m.profile_id = u.id)
     and u.email is distinct from 'demo@idbranding.de'
     and u.email is distinct from 'aleixo.marco@idbranding.de';
  get diagnostics anzahl_konten = row_count;

  raise notice 'Entfernt: % Vereine, % verwaiste Konten.', anzahl_vereine, anzahl_konten;
end $$;
