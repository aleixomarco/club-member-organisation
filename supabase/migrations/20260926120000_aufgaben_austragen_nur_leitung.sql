-- Ziel im Repo: supabase/migrations/20260926120000_aufgaben_austragen_nur_leitung.sql
--
-- Bei den Vereinsaufgaben dieselbe Regel wie seit gestern beim Helferdienst
-- (20260925220000): Eintragen kann sich jedes Mitglied selbst, AUSTRAGEN kann
-- nur die Vereinsleitung - Vereinsadministration, Organisation,
-- Systemverwaltung.
--
-- WARUM
-- Eine Eintragung ist eine Zusage an den Verein. Wer sich zwei Tage vor dem
-- Termin selbst wieder streicht, hinterlaesst eine Luecke, die niemand
-- bemerkt: Die Aufgabe steht wieder auf "Platz frei", und gesehen hat das nur,
-- wer zufaellig hinschaut. Kann jemand doch nicht, sagt er es der Organisation
-- - die traegt ihn aus und kann gleich fuer Ersatz sorgen.
--
-- BISHER: "club members withdraw own signup" DELETE
--   using (membership_id in (select m.id from club_memberships m
--                             where m.profile_id = auth.uid()))
-- Jedes Mitglied durfte die eigene Eintragung loeschen - und sonst niemand.
-- Das ist die zweite Haelfte des Fehlers: Die Leitung konnte eine fremde
-- Eintragung gar nicht entfernen. Wer sich vertippt hatte oder ausfiel, blieb
-- in der Liste stehen, bis jemand die ganze Aufgabe loeschte.
--
-- JETZT: Loeschen darf, wer den Verein verwaltet, und zwar jede Eintragung
-- der Aufgaben seines Vereins. Die Vereinsgrenze kommt ueber club_tasks:
-- has_club_role prueft gegen den Verein der Aufgabe, zu der die Eintragung
-- gehoert.
--
-- Die beiden anderen Regeln bleiben Wort fuer Wort: "club members signup for
-- tasks" (eintragen) und "club members read task signups" (sehen, wer sich
-- eingetragen hat).
--
-- Was beim Loeschen einer ganzen Aufgabe passiert, aendert sich nicht: Die
-- Eintragungen haengen per Fremdschluessel daran und gehen mit.
--
-- Geprueft am 26.09.2026 (nur lesend, PROD): drei Regeln auf
-- club_task_signups, keine davon laesst die Leitung an eine fremde
-- Eintragung.
--
-- MUSS zusammen mit der App ausgeliefert werden: Die Aufgabenkarte zeigt dem
-- Mitglied ab sofort keinen Austragen-Knopf mehr, sondern einen Vermerk, und
-- die Leitung bekommt neben jedem Namen ein Kreuz.

drop policy if exists "club members withdraw own signup" on public.club_task_signups;

create policy "leitung traegt aus vereinsaufgaben" on public.club_task_signups
  for delete to authenticated
  using (
    exists (select 1 from public.club_tasks t
             where t.id = club_task_signups.task_id
               and public.has_club_role(t.club_id,
                     array['vereinsadmin','organisator','sysadmin']::public.club_role[]))
  );

comment on table public.club_task_signups is
  'Wer sich freiwillig fuer eine Vereinsaufgabe eingetragen hat. Eintragen kann sich jedes Mitglied selbst; austragen kann nur die Vereinsleitung (vereinsadmin, organisator, sysadmin) - auch fremde Eintragungen.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: loeschregel = 'leitung traegt aus vereinsaufgaben',
-- kein_selbst_austragen = true, eintragen_unveraendert = true,
-- lesen_unveraendert = true.
select (select string_agg(policyname, ' | ' order by policyname) from pg_policies
         where schemaname='public' and tablename='club_task_signups' and cmd='DELETE')   as loeschregel,
       (select count(*) = 0 from pg_policies
         where schemaname='public' and tablename='club_task_signups' and cmd='DELETE'
           and coalesce(qual,'') like '%auth.uid%'
           and coalesce(qual,'') not like '%has_club_role%')                             as kein_selbst_austragen,
       (select count(*) = 1 from pg_policies
         where schemaname='public' and tablename='club_task_signups'
           and policyname='club members signup for tasks')                               as eintragen_unveraendert,
       (select count(*) = 1 from pg_policies
         where schemaname='public' and tablename='club_task_signups'
           and policyname='club members read task signups')                              as lesen_unveraendert;
