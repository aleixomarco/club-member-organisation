-- Ziel im Repo: supabase/migrations/20260925220000_austragen_nur_leitung.sql
--
-- Eintragen darf sich jedes Mitglied selbst. AUSTRAGEN kann nur noch die
-- Vereinsleitung - Vereinsadministration, Organisation, Systemverwaltung.
--
-- WARUM
-- Ein Helferdienst ist eine Zusage an den Verein, kein Kalendereintrag. Wer
-- sich zwei Tage vor dem Heimspiel selbst wieder austraegt, hinterlaesst eine
-- Luecke, die niemand bemerkt: Die Station steht dann wieder leer da, und
-- gesehen hat das nur, wer zufaellig hinschaut. Kann jemand doch nicht, sagt
-- er es der Organisation - die traegt ihn aus und kann gleich fuer Ersatz
-- sorgen. Betreiberentscheidung vom 25.09.2026.
--
-- BISHER: "members manage own duties" ALL to public
--   using/with check (exists (select 1 from events e
--                        join club_memberships m on m.club_id = e.club_id
--                       where e.id = duty_assignments.event_id
--                         and m.id = duty_assignments.membership_id
--                         and m.profile_id = (select auth.uid())
--                         and m.status = 'active'))
-- Das eine Wort "ALL" gab dem Mitglied insert, update UND delete auf die
-- eigene Zeile. Geblieben ist davon das Eintragen.
--
-- DER FAN kommt bei dieser Gelegenheit mit in die Regel. Die Oberflaeche
-- laesst ihn schon heute nicht eintragen (isFormalMember), die Datenbank aber
-- schon - und Vereinsarbeit geht einen reinen Fan nichts an, dieselbe Grenze
-- wie bei Aufgaben, Helferdiensten und Fuhrpark (20260914110100,
-- 20260925160000). Es verliert dadurch niemand eine Eintragung: In PROD steht
-- in duty_assignments am 25.09.2026 keine einzige Zeile (nur lesend geprueft).
--
-- UNVERAENDERT bleiben die beiden anderen Regeln: "members read duties"
-- (jedes Mitglied des Vereins sieht, wer eingeteilt ist) und "leaders manage
-- duties" (die Leitung darf alles, auch austragen).
--
-- MUSS zusammen mit der App ausgeliefert werden: Die Terminkarte zeigt dem
-- Mitglied ab sofort keinen Austragen-Knopf mehr, sondern einen Vermerk.

drop policy if exists "members manage own duties" on public.duty_assignments;

create policy "mitglied traegt sich selbst ein" on public.duty_assignments
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.events e
        join public.club_memberships m on m.club_id = e.club_id
       where e.id = duty_assignments.event_id
         and m.id = duty_assignments.membership_id
         and m.profile_id = (select auth.uid())
         and m.status = 'active'
         and not public.ist_nur_fan(e.club_id))
  );

comment on table public.duty_assignments is
  'Wer an einem Termin welche Helferstation uebernimmt. Eintragen kann sich jedes aktive Mitglied selbst (ausser einem reinen Fan); austragen kann nur die Vereinsleitung.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: eigene_regel = 'INSERT', kein_selbst_austragen = true,
-- fanriegel = true, leitungsregel_da = true.
select (select cmd from pg_policies
         where schemaname = 'public' and tablename = 'duty_assignments'
           and policyname = 'mitglied traegt sich selbst ein')                    as eigene_regel,
       (select count(*) = 0 from pg_policies
         where schemaname = 'public' and tablename = 'duty_assignments'
           and cmd in ('ALL','DELETE')
           and coalesce(qual, '') like '%auth.uid%'
           and policyname <> 'leaders manage duties')                             as kein_selbst_austragen,
       (select position('ist_nur_fan' in coalesce(with_check, '')) > 0 from pg_policies
         where schemaname = 'public' and tablename = 'duty_assignments'
           and policyname = 'mitglied traegt sich selbst ein')                     as fanriegel,
       (select count(*) = 1 from pg_policies
         where schemaname = 'public' and tablename = 'duty_assignments'
           and policyname = 'leaders manage duties')                               as leitungsregel_da;
