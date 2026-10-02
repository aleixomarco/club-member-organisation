-- Ziel im Repo: supabase/migrations/20261002200000_fans_duerfen_eingeteilt_werden.sql
--
-- Ein Fan kann eingeteilt werden - uebernehmen kann er nichts.
--
-- WUNSCH DES BETREIBERS (02.10.2026): "fans koennen nur eingetragen werden,
-- sie koennen auch nur lesen. Uebernehmen koennen sie nicht. Die
-- Organisatoren oder Vereinsadmins koennen sie eintragen und loeschen.
-- auch an spieltagen gilt die gleiche logik."
--
-- Ein Fan ist jemand, der dem Verein folgt, ohne Mitglied zu sein - die
-- Schwiegermutter, die den Kuchenstand macht, der Nachbar, der den Grill
-- anwirft. Bisher sperrte ihn das System ueberall aus, auch dort, wo die
-- Leitung ihn ausdruecklich haben wollte.
--
-- DIE UNTERSCHEIDUNG, auf die es ankommt: NICHT ob ein Fan in der Liste steht,
-- sondern WER ihn hineingeschrieben hat. Traegt die Leitung ihn ein, ist das
-- eine Absprache - sie hat ihn gefragt. Traegt er sich selbst ein, waere es
-- eine Zusage, die ihm niemand abgenommen hat.
--
-- ------------------------------------------------------------------ 1
-- HELFERDIENSTE: der Riegel sass an der falschen Stelle
-- Zwei Schichten regeln das Eintragen:
--   Regel "mitglied traegt sich selbst ein"  prueft ist_nur_fan - richtig,
--     sie gilt nur fuer die Selbsteintragung (20260925220000).
--   Regel "leaders manage duties"            laesst die Leitung alles - auch
--     richtig.
--   Ausloeser helferdienst_eintrag_pruefen   warf fan_kein_helferdienst
--     UNABHAENGIG davon, wer eintraegt (20260926100000:223-228).
-- Der Ausloeser hat also die Leitung mit ausgesperrt. Jetzt fragt er zuerst,
-- ob der Eintragende die Dienste verwalten darf; nur wenn nicht, gilt die
-- Fan-Sperre weiter. Die uebrigen drei Pruefungen - Station bekannt, Platz
-- frei, Termin nicht abgesagt - bleiben fuer alle.
--
-- ------------------------------------------------------------------ 2
-- VEREINSAUFGABEN: dort fehlte der Riegel ganz
-- club_task_assignees ("leaders manage task assignees") traegt schon heute
-- jeden ein, auch einen Fan - das ist genau das Gewollte und bleibt.
-- club_task_signups dagegen ist die SELBSTzusage, und ihre Regel "club
-- members signup for tasks" prueft nur Mitgliedschaft und Status. Ein Fan
-- koennte sich selbst zusagen.
--
-- Das fiel bisher nicht auf, weil die App den Support-Reiter vor Fans
-- verbirgt - der Weg dorthin war zu. Mit dieser Auslieferung bekommen Fans
-- Lesezugriff, und damit waere er offen. Deshalb kommt der Riegel JETZT, in
-- derselben Migration wie die Oeffnung, und nicht spaeter: Eine Luecke, die
-- man beim Aufmachen der Tuer sieht, schliesst man beim Aufmachen.
--
-- Geprueft am 02.10.2026 (nur lesend, PROD): helferdienst_eintrag_pruefen
-- kennt can_manage_duty_task nicht; die INSERT-Regel auf club_task_signups
-- hat keinen ist_nur_fan-Riegel. 5 reine Fans, 3 Helferdienste, 1 Zusage -
-- keine davon von einem Fan, es ist nichts nachzutragen.
--
-- MUSS zusammen mit der App ausgeliefert werden.

create or replace function public.helferdienst_eintrag_pruefen()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_stationen text[];
  v_caps      jsonb;
  v_belegt    int;
begin
  select coalesce(e.helper_slots, '{}'::text[]), coalesce(e.helper_caps, '{}'::jsonb)
    into v_stationen, v_caps
    from public.events e where e.id = new.event_id;

  if not (new.station = any(coalesce(v_stationen, '{}'::text[]))) then
    raise exception 'station_unbekannt' using errcode = 'P0001';
  end if;

  select count(*) into v_belegt
    from public.duty_assignments d
   where d.event_id = new.event_id and d.station = new.station;
  if v_belegt >= public.helferstation_plaetze(coalesce(v_caps, '{}'::jsonb), new.station) then
    raise exception 'voll' using errcode = 'P0001';
  end if;

  /* Die Fan-Sperre gilt nur fuer die SELBSTeintragung.
     Traegt die Leitung ein, ist es eine Absprache - sie hat den Fan gefragt.
     Traegt er sich selbst ein, waere es eine Zusage, die ihm niemand
     abgenommen hat. can_manage_duty_task deckt Vereinsleitung, Organisation
     und die Mannschaftsfuehrung am eigenen Termin ab (20260902190000).
     new.membership_id kann null sein - dann steht ein Gastname in der Zeile
     (20260928010000), und es gibt keine Rolle zu pruefen. */
  if new.membership_id is not null
     and not public.can_manage_duty_task(new.event_id)
     and exists (select 1 from public.membership_roles r
                  where r.membership_id = new.membership_id and r.role = 'fan')
     and not exists (select 1 from public.membership_roles r
                      where r.membership_id = new.membership_id and r.role <> 'fan') then
    raise exception 'fan_kein_helferdienst' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

comment on table public.duty_assignments is
  'Wer an einem Termin welche Helferstation uebernimmt. Eintragen kann sich jedes aktive Mitglied selbst (ausser einem reinen Fan); einen Fan kann nur die Vereinsleitung eintragen. Austragen kann in jedem Fall nur die Vereinsleitung.';

-- ------------------------------------------------- Vereinsaufgaben
drop policy if exists "club members signup for tasks" on public.club_task_signups;

create policy "club members signup for tasks" on public.club_task_signups
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.club_tasks t
        join public.club_memberships m on m.club_id = t.club_id
       where t.id = club_task_signups.task_id
         and m.id = club_task_signups.membership_id
         and m.profile_id = (select auth.uid())
         and m.status = 'active'
         /* Neu: Ein reiner Fan sagt nicht selbst zu. Eintragen kann ihn die
            Leitung ueber club_task_assignees - dort ist er willkommen. */
         and not public.ist_nur_fan(t.club_id))
  );

comment on table public.club_task_signups is
  'Freiwillige Zusagen zu einer Vereinsaufgabe. Zusagen kann jedes aktive Mitglied ausser einem reinen Fan; einen Fan traegt die Leitung ueber club_task_assignees ein. Austragen ist Sache der Vereinsleitung.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: trigger_fragt_leitung = true, trigger_prueft_gast_nicht = true,
--           aufgaben_fanriegel = true, selbsteintrag_riegel_bleibt = true,
--           leitungsregel_bleibt = 1, zuweisung_ohne_riegel = 1.
-- Der Nachweis, dass es WIRKT, ist das Nachspielen gegen PROD: Fan als
-- Leitung eintragen (geht), Fan traegt sich selbst ein (geht nicht).
select
  (select pg_get_functiondef(p.oid) like '%can_manage_duty_task%'
     from pg_proc p where p.proname = 'helferdienst_eintrag_pruefen') as trigger_fragt_leitung,
  (select pg_get_functiondef(p.oid) like '%new.membership_id is not null%'
     from pg_proc p where p.proname = 'helferdienst_eintrag_pruefen') as trigger_prueft_gast_nicht,
  (select position('ist_nur_fan' in coalesce(with_check,'')) > 0 from pg_policies
    where tablename = 'club_task_signups' and cmd = 'INSERT') as aufgaben_fanriegel,
  /* Die Selbsteintragung bei den Diensten behaelt ihren eigenen Riegel. */
  (select position('ist_nur_fan' in coalesce(with_check,'')) > 0 from pg_policies
    where tablename = 'duty_assignments' and policyname = 'mitglied traegt sich selbst ein') as selbsteintrag_riegel_bleibt,
  (select count(*) from pg_policies
    where tablename = 'duty_assignments' and policyname = 'leaders manage duties') as leitungsregel_bleibt,
  /* Die Zuweisung durch die Leitung bleibt ohne Fan-Riegel - genau so gewollt. */
  (select count(*) from pg_policies
    where tablename = 'club_task_assignees' and policyname = 'leaders manage task assignees') as zuweisung_ohne_riegel;
