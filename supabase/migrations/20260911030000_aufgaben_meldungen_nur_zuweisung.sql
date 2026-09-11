-- Aufgaben: Mitteilungen nur noch an die, denen eine Aufgabe zugewiesen wird
--
-- Wunsch des Betreibers (11.09.2026): "Es sollen keine Benachrichtigungen
-- versendet werden, wenn eine neue Aufgabe angelegt wird im Verein. Man soll
-- nur benachrichtigt werden, wenn man der Aufgabe zugewiesen wurde."
--
-- 1. WEG: die Rundmeldung bei jeder neuen Vereinsaufgabe an alle Mitglieder
--    (bei Mannschaftsaufgaben an die ganze Mannschaft) - Trigger
--    club_tasks_melden mit aufgabe_melden(). Nichts sonst ruft sie auf.
-- 2. BLEIBT: Zuweisung einer Vereinsaufgabe (club_task_assignees ->
--    vereinsaufgabe_zuweisung_melden), unverändert.
-- 3. ERGÄNZT: Wer eine Station (duty_tasks) übernehmen soll, bekam schon eine
--    Mitteilung - aber ohne Ziel, die Glocke führte nirgendwohin, und ohne zu
--    sagen, welche Station. Jetzt mit Titel und ziel_art 'helferdienst'.
-- 4. NEU: Einteilung in der Helferplanung (duty_assignments) meldete bisher
--    gar nichts. Jetzt eine Mitteilung an die eingeteilte Person.
-- 5. NEU: Protokollaufgaben mit zugewiesener Person (protocol_tasks) ebenso.
--
-- Wer sich selbst einträgt oder zuweist, bekommt keine Mitteilung - er weiß
-- es schon. Jede Mitteilung fragt meldung_erlaubt(), die Einstellungen im
-- Profil gelten also weiter ("Helferdienst" bzw. "Aufgaben").
-- Texte: die vorhandenen Bausteine aufgabe.zugewiesen.titel und
-- aufgabe.zugewiesen.textMitTitel, beide in allen sieben Sprachen.
-- club_id setzen bei duty_assignments und protocol_tasks BEFORE-Trigger
-- (club_id_aus_elternteil); die Mitteilungen hier laufen AFTER und sehen sie.

-- 1.
drop trigger if exists club_tasks_melden on public.club_tasks;
drop function if exists public.aufgabe_melden();

-- 3.
create or replace function public.aufgabe_zugewiesen_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;
  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null then return new; end if;
  if v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.assignee_membership_id);
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, 'duty',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.textMitTitel', v_sprache,
            jsonb_build_object(
              'wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)),
              'titel', coalesce(new.title, ''))),
          'helferdienst', new.event_id);
  return new;
end;
$$;

-- 4.
create or replace function public.helferdienst_einteilung_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
  v_termin  text;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;
  select nullif(trim(coalesce(e.title, '') || coalesce(' · ' || to_char(e.starts_at at time zone 'Europe/Berlin', 'DD.MM.'), '')), '')
    into v_termin from public.events e where e.id = new.event_id;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, 'duty',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.textMitTitel', v_sprache,
            jsonb_build_object(
              'wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)),
              'titel', new.station || coalesce(' – ' || v_termin, ''))),
          'helferdienst', new.event_id);
  return new;
end;
$$;

drop trigger if exists duty_assignments_melden on public.duty_assignments;
create trigger duty_assignments_melden
  after insert on public.duty_assignments
  for each row execute function public.helferdienst_einteilung_melden();

-- 5.
create or replace function public.protokollaufgabe_zuweisung_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;
  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'tasks') then return new; end if;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  v_sprache := public.sprache_der_mitgliedschaft(new.assignee_membership_id);
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, 'tasks',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.textMitTitel', v_sprache,
            jsonb_build_object(
              'wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)),
              'titel', left(coalesce(new.text, ''), 120))),
          'protokollaufgabe', new.id);
  return new;
end;
$$;

drop trigger if exists protocol_tasks_zuweisung_melden on public.protocol_tasks;
create trigger protocol_tasks_zuweisung_melden
  after insert or update of assignee_membership_id on public.protocol_tasks
  for each row execute function public.protokollaufgabe_zuweisung_melden();

-- Triggerfunktionen ruft niemand direkt auf; Supabase gäbe sie sonst
-- anon und authenticated frei.
revoke all on function public.aufgabe_zugewiesen_melden() from public, anon, authenticated;
revoke all on function public.helferdienst_einteilung_melden() from public, anon, authenticated;
revoke all on function public.protokollaufgabe_zuweisung_melden() from public, anon, authenticated;
