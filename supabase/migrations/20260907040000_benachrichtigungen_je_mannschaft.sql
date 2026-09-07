-- Die Benachrichtigungsschalter tun endlich etwas - und es gibt sie je Mannschaft.
--
-- WAS BISHER PASSIERTE
-- Im Profil stehen 21 Schalter: "Neues Training", "Trainingsabsage",
-- "Vereins-News", "Chat" und so weiter. Sie liessen sich stellen, sie wurden
-- gespeichert - und dann las sie niemand. Nachgezaehlt: Von den zwoelf
-- Funktionen, die Benachrichtigungen schreiben, hat KEINE EINZIGE jemals
-- notification_master oder notification_preferences angesehen. Wer alles
-- abschaltete, bekam trotzdem alles.
--
-- WARUM DAS NIEMANDEM AUFFIEL
-- Weil es zwei Vokabulare gab, die nie zusammengefuehrt wurden. Die
-- Einstellung heisst training_created, verschickt wurde kind = 'training'.
-- Die Einstellung heisst tasks, verschickt wurde 'task'. results gegen
-- 'result'. Selbst wenn jemand die Pruefung eingebaut haette, waere sie ins
-- Leere gelaufen. Diese Migration fuehrt beide Woerterbuecher zusammen: Es
-- gibt ab jetzt genau einen Satz Schluessel, und kind IST der Schluessel.
--
-- Das ist gefahrlos, weil kind nirgends ausgewertet wird - weder die App noch
-- der Push-Versand verzweigen darauf, die Spalte wird nur mitgeschickt.
--
-- WAS NEU DAZUKOMMT: JE MANNSCHAFT
-- Bisher galt die Entscheidung fuer den ganzen Verein. Wer im Herren-1-Chat
-- ist, aber auch wissen will, wann die U15 spielt, hatte keine Handhabe. Ab
-- jetzt gibt es je Mitglied und Mannschaft vier Schalter: ueberhaupt,
-- Spiele, Trainings, Ergebnisse.
--
-- DER VOREINGESTELLTE ZUSTAND OHNE ZEILE
-- Fehlt eine Zeile, gilt: die eigene Mannschaft ja, jede andere nein. Genau
-- das erwartet man, und es heisst, dass niemand erst etwas einstellen muss.
-- Athletinnen, Trainer, Teammanager und Team-Staff stehen damit fuer ihre
-- Mannschaft automatisch auf ja, ohne dass dafuer Zeilen angelegt werden -
-- was auch der Grund ist, es zu RECHNEN und nicht zu speichern: Wer die
-- Mannschaft wechselt, nimmt sonst die alten Zeilen mit.
--
-- WAS SICH DAMIT AM EMPFAENGERKREIS AENDERT
-- Bisher bekam ein Mannschaftstermin nur, wer in der Mannschaft ist. Jetzt
-- zusaetzlich, wer sie ausdruecklich abonniert hat. Das ist der Punkt der
-- ganzen Uebung - vorher konnte man Fremdmannschaften gar nicht folgen.

-- --------------------------------------------------------------- Die Tabelle
create table if not exists public.team_benachrichtigungen (
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  team_id       uuid not null references public.teams(id)            on delete cascade,
  aktiv         boolean not null default true,
  spiele        boolean not null default true,
  trainings     boolean not null default true,
  ergebnisse    boolean not null default true,
  geaendert_am  timestamptz not null default now(),
  primary key (membership_id, team_id)
);

comment on table public.team_benachrichtigungen is
  'Welche Meldungen jemand zu einer bestimmten Mannschaft bekommen will. Fehlt die Zeile, gilt: eigene Mannschaft ja, fremde nein.';
comment on column public.team_benachrichtigungen.aktiv is
  'Hauptschalter fuer diese Mannschaft. Steht er auf nein, hilft auch spiele=true nichts.';

create index if not exists team_benachrichtigungen_team_idx
  on public.team_benachrichtigungen (team_id) where aktiv;

alter table public.team_benachrichtigungen enable row level security;

/* Jeder pflegt nur seine eigenen Zeilen. Die Verknuepfung laeuft ueber die
   Mitgliedschaft, nicht ueber das Profil, weil ein Mensch in mehreren
   Vereinen mit getrennten Einstellungen sein kann. */
drop policy if exists "eigene teameinstellungen lesen"    on public.team_benachrichtigungen;
drop policy if exists "eigene teameinstellungen schreiben" on public.team_benachrichtigungen;

create policy "eigene teameinstellungen lesen" on public.team_benachrichtigungen
  for select to authenticated
  using (exists (select 1 from public.club_memberships m
                  where m.id = membership_id and m.profile_id = auth.uid()));

create policy "eigene teameinstellungen schreiben" on public.team_benachrichtigungen
  for all to authenticated
  using (exists (select 1 from public.club_memberships m
                  where m.id = membership_id and m.profile_id = auth.uid()))
  with check (exists (select 1 from public.club_memberships m
                       where m.id = membership_id and m.profile_id = auth.uid())
              and exists (select 1 from public.teams t
                           join public.club_memberships m2 on m2.id = membership_id
                          where t.id = team_id and t.club_id = m2.club_id));

-- ------------------------------------------------------- Die zwei Pruefungen
--
-- Beide sind security definer: Sie lesen fremde Profile und fremde
-- Mitgliedschaften, und zwar aus einem Ausloeser heraus, der im Namen
-- irgendeines Anwenders laeuft. Ohne definer wuerde die Pruefung an den
-- Zeilenregeln scheitern und - schlimmer - je nach Aufrufer verschieden
-- ausfallen.

create or replace function public.meldung_erlaubt(p_profile uuid, p_schluessel text)
returns boolean language sql stable security definer set search_path = 'public' as $$
  /* Unbekannter Schluessel gilt als ja. Das ist Absicht: Sonst verstummt eine
     neu eingefuehrte Meldungsart still bei allen, die ihre Einstellungen
     schon einmal gespeichert haben. Lieber eine Meldung zu viel, die man
     abschalten kann, als eine, die nie ankommt und die niemand vermisst. */
  select coalesce(
    (select coalesce(p.notification_master, true)
        and coalesce((p.notification_preferences ->> p_schluessel)::boolean, true)
     from public.profiles p where p.id = p_profile),
    true);
$$;

comment on function public.meldung_erlaubt(uuid, text) is
  'Will dieses Profil Meldungen dieser Art? Prueft Hauptschalter und Einzelschalter. Unbekannte Schluessel gelten als ja.';

create or replace function public.team_meldung_erlaubt(p_membership uuid, p_team uuid, p_art text)
returns boolean language sql stable security definer set search_path = 'public' as $$
  select case
    /* Ohne Mannschaft ist es eine Vereinsmeldung - die geht an alle, die sie
       nicht ueber den globalen Schalter abbestellt haben. */
    when p_team is null then true
    else coalesce(
      (select tb.aktiv and case p_art
                when 'spiele'     then tb.spiele
                when 'trainings'  then tb.trainings
                when 'ergebnisse' then tb.ergebnisse
                else true end
         from public.team_benachrichtigungen tb
        where tb.membership_id = p_membership and tb.team_id = p_team),
      /* Keine Zeile: eigene Mannschaft ja, fremde nein. */
      exists (select 1 from public.team_members tm
               where tm.membership_id = p_membership and tm.team_id = p_team))
  end;
$$;

comment on function public.team_meldung_erlaubt(uuid, uuid, text) is
  'Will diese Mitgliedschaft Meldungen dieser Art zu dieser Mannschaft? Ohne gespeicherte Zeile: eigene Mannschaft ja, fremde nein.';

grant execute on function public.meldung_erlaubt(uuid, text)              to authenticated, service_role;
grant execute on function public.team_meldung_erlaubt(uuid, uuid, text)   to authenticated, service_role;

-- ============================================================================
-- Ab hier: die zwoelf Schreiber lesen die Einstellungen.
-- ============================================================================

-- ------------------------------------------------------- Termine
--
-- Drei Aenderungen auf einmal:
--
-- 1. kind ist jetzt genau der Einstellungsschluessel, also
--    training_created / training_cancelled / training_changed und
--    game_created / game_cancelled / game_changed. Bisher stand dort
--    'training' bzw. 'match' - ein Wort, das in keiner Einstellung vorkommt.
--    Vereinstermine ohne Mannschaft bekommen 'events'.
--
-- 2. Ein reiner Ergebniseintrag loest keine "Spiel geaendert"-Meldung mehr
--    aus. Bisher bekam der halbe Verein "Das Spiel wurde geaendert", sobald
--    jemand 3:2 eintrug - und gleich darauf die Ergebnismeldung hinterher.
--    Der Vergleich laeuft ueber to_jsonb minus der Ergebnisspalten: Was sonst
--    gleich blieb, war eben nur das Ergebnis.
--
-- 3. Der Empfaengerkreis ist offen fuer Abonnenten fremder Mannschaften.
create or replace function public.notify_event_audience()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_titel      text;
  v_text       text;
  v_art        text;   -- Training | Spiel | Event, fuer den Fliesstext
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null, fuer die Mannschaftsschalter
begin
  v_art := case new.type when 'training' then 'Training' when 'spiel' then 'Spiel' else 'Event' end;
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

  if tg_op = 'UPDATE'
     and to_jsonb(old) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
       = to_jsonb(new) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
  then
    return new;  -- nur das Ergebnis; dafuer gibt es spielergebnis_melden
  end if;

  if tg_op = 'INSERT' then
    v_titel := v_art || ' angelegt';
    v_text  := 'Das ' || v_art || ' wurde angelegt.';
    v_schluessel := case new.type when 'training' then 'training_created'
                                  when 'spiel'    then 'game_created'
                                  else 'events' end;
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_titel := v_art || ' abgesagt';
    v_text  := 'Das ' || v_art || ' wurde abgesagt.'
               || coalesce(' Grund: ' || nullif(trim(new.cancel_reason), ''), '');
    v_schluessel := case new.type when 'training' then 'training_cancelled'
                                  when 'spiel'    then 'game_cancelled'
                                  else 'events' end;
  elsif tg_op = 'UPDATE' then
    v_titel := v_art || ' geändert';
    v_text  := 'Das ' || v_art || ' wurde geändert.';
    v_schluessel := case new.type when 'training' then 'training_changed'
                                  when 'spiel'    then 'game_changed'
                                  else 'events' end;
  else
    return new;
  end if;

  v_text := v_text || ' ' || coalesce(new.title, '')
            || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
            || coalesce(' · ' || new.location, '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, v_schluessel, v_titel, v_text, 'termin', new.id
  from public.club_memberships m
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null            -- Vereinstermin: alle
         or tm.membership_id is not null -- in der Mannschaft
         or tb.aktiv)                    -- oder ausdruecklich abonniert
    and public.team_meldung_erlaubt(m.id, new.team_id, v_teamart)
    and public.meldung_erlaubt(m.profile_id, v_schluessel);

  return new;
end;
$function$;

-- ------------------------------------------------------- Spielergebnisse
--
-- Diese Meldung gab es bisher gar nicht. Es gab nur die ERINNERUNG an den
-- Trainer, das Ergebnis nachzutragen - wer wissen wollte, wie es ausging,
-- musste selbst nachsehen. Die Einstellung "Spielergebnisse" stand also im
-- Profil, ohne dass je etwas darunter verschickt wurde.
create or replace function public.spielergebnis_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_text text;
begin
  if new.home_score is null or new.away_score is null then return new; end if;
  if old.home_score is not distinct from new.home_score
     and old.away_score is not distinct from new.away_score then return new; end if;

  v_text := coalesce(new.title, 'Spiel') || ': ' || new.home_score || ':' || new.away_score;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'results', 'Ergebnis', v_text, 'termin', new.id
  from public.club_memberships m
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$function$;

drop trigger if exists events_ergebnis_melden on public.events;
create trigger events_ergebnis_melden after update on public.events
  for each row execute function public.spielergebnis_melden();

-- ------------------------------------------------------- Chat
--
-- Hier wird der Empfaengerkreis BEWUSST NICHT geoeffnet. Wer eine fremde
-- Mannschaft abonniert, will wissen, wann sie spielt - nicht mitlesen, was
-- die Mannschaft sich schreibt. Der Mannschaftsschalter wirkt deshalb nur
-- abschaltend: aktiv = false macht still, aktiv = true oeffnet keine Tuer.
create or replace function public.chatnachricht_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_club  uuid;
  v_team  uuid;
  v_wer   text;
  v_text  text;
begin
  select c.club_id, c.team_id into v_club, v_team from public.channels c where c.id = new.channel_id;
  if v_club is null then return new; end if;

  select display_name into v_wer from public.club_memberships where id = new.author_id;

  /* Lange Nachrichten kuerzen: Auf dem Sperrbildschirm ist nach etwa hundert
     Zeichen ohnehin Schluss, und eine abgeschnittene Meldung ohne Zeichen
     dafuer sieht aus wie ein Fehler. */
  v_text := case when length(new.body) > 90 then left(new.body, 90) || ' …' else new.body end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, v_club, 'chat',
         coalesce(v_wer, 'Neue Nachricht'),
         coalesce(v_wer, 'Jemand') || ': ' || v_text
  from public.club_memberships m
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = v_team
  where m.club_id = v_club and m.status = 'active' and m.profile_id is not null
    and m.id is distinct from new.author_id
    and (v_team is null or tm.membership_id is not null)
    and public.team_meldung_erlaubt(m.id, v_team, 'chat')
    and public.meldung_erlaubt(m.profile_id, 'chat');
  return new;
end;
$function$;

-- ------------------------------------------------------- Vereins-News
create or replace function public.news_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
begin
  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select m.profile_id, new.club_id, 'news', 'Neue Vereins-News', 'Neue News. Jetzt lesen!'
  from public.club_memberships m
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'news');
  return new;
end;
$function$;

-- ------------------------------------------------------- Umfragen
create or replace function public.umfrage_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  if not new.active then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select m.profile_id, new.club_id, 'polls',
         public.meldungstext('umfrage.titel', p.language),
         public.meldungstext('umfrage.text', p.language),
         'umfrage', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and public.meldung_erlaubt(m.profile_id, 'polls');

  return new;
end;
$$;

-- ------------------------------------------------------- Aufgaben
--
-- kind war 'task', die Einstellung heisst 'tasks'. Ein einziger Buchstabe,
-- und die Pruefung haette nie gegriffen.
create or replace function public.vereinsaufgabe_zuweisung_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_profil uuid; v_club uuid; v_titel text; v_wer text;
begin
  select t.club_id, t.title into v_club, v_titel from public.club_tasks t where t.id = new.task_id;
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'tasks') then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = v_club limit 1;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, v_club, 'tasks', 'Neue Aufgabe',
          coalesce(v_wer, 'Die Vereinsleitung') || ' hat dir eine Aufgabe zugewiesen: ' || coalesce(v_titel, ''),
          'aufgabe', new.task_id);
  return new;
end;
$function$;

create or replace function public.aufgabe_zugewiesen_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_profil uuid;
  v_wer    text;
begin
  if new.assignee_membership_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.assignee_membership_id is not distinct from old.assignee_membership_id then
    return new;
  end if;

  select profile_id into v_profil from public.club_memberships where id = new.assignee_membership_id;
  if v_profil is null then return new; end if;
  /* Wer sich selbst eine Aufgabe nimmt, braucht darueber keine Meldung. */
  if v_profil = auth.uid() then return new; end if;
  /* Helferdienste sind Aufgaben aus duty_tasks - dafuer gibt es den eigenen
     Schalter "Helferdienst". */
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, new.club_id, 'duty', 'Neue Aufgabe',
          coalesce(v_wer, 'Die Vereinsleitung') || ' hat dir eine Aufgabe zugewiesen.');
  return new;
end;
$function$;

create or replace function public.aufgaben_erinnerung_senden()
 returns integer language plpgsql security definer set search_path to ''
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select t.id, t.club_id, t.title, m.profile_id
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select f.profile_id, f.club_id, 'duty', 'Erinnerung', 'Erinnerung für morgen: ' || f.title
    from faellig f
    where public.meldung_erlaubt(f.profile_id, 'duty')
    returning 1
  )
  update public.duty_tasks set reminded_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title,
           exists (select 1 from public.club_task_assignees a where a.task_id = t.id) as hat_verantwortliche
    from public.club_tasks t
    where t.due_date = (current_date + 1) and t.reminded_at is null
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'tasks', 'Erinnerung', 'Erinnerung für morgen: ' || f.title,
           'aufgabe', f.id
    from faellig2 f
    join public.club_memberships m on m.club_id = f.club_id and m.status = 'active'
    left join public.team_members tm on tm.membership_id = m.id and tm.team_id = f.team_id
    left join public.club_task_assignees a on a.task_id = f.id and a.membership_id = m.id
    where m.profile_id is not null
      and (case when f.hat_verantwortliche then a.membership_id is not null
                when f.team_id is not null  then tm.membership_id is not null
                else true end)
      and public.team_meldung_erlaubt(m.id, f.team_id, 'aufgaben')
      and public.meldung_erlaubt(m.profile_id, 'tasks')
    returning 1
  )
  update public.club_tasks set reminded_at = now() where id in (select id from faellig2);

  return v_anzahl;
end;
$function$;

-- ------------------------------------------------------- Ergebnis-Erinnerung
--
-- Das ist die Erinnerung AN DIE VEREINSLEITUNG, ein fehlendes Ergebnis
-- nachzutragen - nicht die Ergebnismeldung an die Mannschaft. Sie haengt
-- trotzdem am selben Schalter "Spielergebnisse": Wer mit Ergebnissen nichts
-- zu tun haben will, will auch nicht ans Nachtragen erinnert werden, und ein
-- eigener Schalter fuer eine Meldung, die nur drei Menschen im Verein
-- betrifft, macht die Liste laenger als noetig.
create or replace function public.ergebnis_erinnerung_senden()
 returns integer language plpgsql security definer set search_path to 'public'
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select e.id, e.club_id, e.title
    from public.events e
    left join public.event_results r on r.event_id = e.id
    where e.type = 'spiel'
      and e.status is distinct from 'cancelled'
      and e.starts_at < now() - interval '3 hours'
      and e.starts_at > now() - interval '7 days'
      and r.event_id is null
      and e.ergebnis_erinnert_at is null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'results', 'Ergebnis fehlt',
           'Bitte das Ergebnis vom Spiel ' || f.title || ' eintragen.', 'termin', f.id
    from faellig f
    join public.membership_roles ro on true
    join public.club_memberships m on m.id = ro.membership_id
    where m.club_id = f.club_id and m.status = 'active' and m.profile_id is not null
      and ro.role in ('vereinsadmin','sysadmin','organisator')
      and public.meldung_erlaubt(m.profile_id, 'results')
    returning 1
  )
  update public.events set ergebnis_erinnert_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$;

-- ------------------------------------------------------- Vereinsfahrzeug
create or replace function public.fahrzeuganfrage_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_name text;
begin
  if new.status <> 'angefragt' then return new; end if;

  select display_name into v_name from public.club_memberships where id = new.membership_id;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, new.club_id, 'vehicle',
         'Neue Vereinsfahrzeug Buchungsanfrage',
         'Neue Vereinsfahrzeug Buchungsanfrage von ' || coalesce(v_name, 'einem Mitglied') || '.'
  from public.membership_roles r
  join public.club_memberships m on m.id = r.membership_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and public.meldung_erlaubt(m.profile_id, 'vehicle');

  return new;
end;
$function$;

create or replace function public.entscheide_fahrzeug_anfrage(target_booking uuid, annehmen boolean)
 returns text language plpgsql security definer set search_path to ''
as $function$
declare
  v_club uuid;
  v_anfrager uuid;
  v_profil uuid;
  v_status text;
  v_mein uuid;
begin
  select club_id, membership_id, status into v_club, v_anfrager, v_status
  from public.vehicle_bookings where id = target_booking;
  if v_club is null then raise exception 'Booking not found'; end if;
  if not public.darf_fahrzeug_entscheiden(v_club) then raise exception 'Not authorized'; end if;
  if v_status <> 'angefragt' then return v_status; end if;

  select id into v_mein from public.club_memberships
   where club_id = v_club and profile_id = auth.uid() and status = 'active' limit 1;

  update public.vehicle_bookings
     set status = case when annehmen then 'bestaetigt' else 'abgelehnt' end,
         decided_by = v_mein, decided_at = now()
   where id = target_booking;

  select profile_id into v_profil from public.club_memberships where id = v_anfrager;
  if v_profil is not null and public.meldung_erlaubt(v_profil, 'vehicle') then
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    values (v_profil, v_club, 'vehicle',
            'Vereinsfahrzeug',
            'Deine Anfrage zur Vereinsfahrzeug Buchung wurde ' ||
            case when annehmen then 'angenommen' else 'abgelehnt' end || '.',
            'fahrzeug', target_booking);
  end if;

  return case when annehmen then 'bestaetigt' else 'abgelehnt' end;
end;
$function$;

-- ------------------------------------------------------- Betreiber und Rest
--
-- Betreibermeldungen sind kein Thema, das man einzeln abbestellt - es sind
-- Nachrichten von uns an den Verein, oft zu Abo und Freischaltung. Sie
-- gehorchen deshalb nur dem Hauptschalter. meldung_erlaubt leistet genau
-- das: 'betreiber' steht in keiner Einstellungsliste, gilt damit als ja, und
-- uebrig bleibt notification_master.
create or replace function public.betreiber_nachricht_senden(target_club uuid, p_titel text, p_text text, p_nur_leitung boolean default true)
 returns integer language plpgsql security definer set search_path to 'public'
as $function$
declare v_anzahl integer := 0;
begin
  if coalesce(btrim(p_titel), '') = '' or coalesce(btrim(p_text), '') = '' then
    raise exception 'Titel und Text duerfen nicht leer sein';
  end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, target_club, 'betreiber', btrim(p_titel), btrim(p_text)
  from public.club_memberships m
  where m.club_id = target_club and m.status = 'active' and m.profile_id is not null
    and public.meldung_erlaubt(m.profile_id, 'betreiber')
    and (
      not p_nur_leitung
      or exists (select 1 from public.membership_roles r
                  where r.membership_id = m.id
                    and r.role in ('vereinsadmin', 'sysadmin'))
    );
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$;

/* Die Warteschlange traegt ihre Art selbst mit - notif_type ist derselbe
   Schluessel, den auch die Einstellung benutzt. */
create or replace function public.warteschlange_in_glocke()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_profil uuid;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null then return new; end if;
  if not public.meldung_erlaubt(v_profil, coalesce(new.notif_type, 'info')) then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, new.club_id, coalesce(new.notif_type, 'info'),
          coalesce(new.title, 'Vereinsmeldung'), coalesce(new.body, ''));
  return new;
end;
$function$;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from information_schema.tables
    where table_schema='public' and table_name='team_benachrichtigungen') as tabelle,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosrc like '%insert into public.user_notifications%'
      and p.prosrc not like '%meldung_erlaubt%') as schreiber_ohne_pruefung,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosrc like '%insert into public.user_notifications%') as schreiber_gesamt;
