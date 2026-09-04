-- Die fehlenden Ausloeser: Was passiert, soll auch ankommen.
--
-- AUSGANGSLAGE
-- Von den acht Ereignissen, ueber die der Verein Bescheid wissen will, loeste
-- bisher genau EINES etwas aus: Termine, ueber den Trigger
-- events_notify_audience. Beitrittsanfragen, Vereins-Events, Aufgaben, News und
-- Sponsoren schrieben nirgends eine Zeile - weder in der App noch in der
-- Datenbank. Die Glocke blieb dort fuer immer still.
--
-- Diese Migration legt die fehlenden Ausloeser an und raeumt zwei Fehler im
-- vorhandenen auf. Sie schreibt AUSSCHLIESSLICH Benachrichtigungen; kein
-- Bestandsdatensatz wird angefasst.
--
-- Zur Zustellung: Diese Zeilen fuellen die Glocke IN der App. Eine echte
-- Push-Mitteilung aufs Telefon entsteht daraus erst, wenn der Versender steht -
-- den gibt es noch nicht. Die Reihenfolge ist trotzdem richtig: Der Versender
-- liest spaeter genau diese Zeilen, es ist also keine Wegwerfarbeit.
--
-- public.notify(...) wird aufgerufen und NICHT neu definiert. Die Funktion
-- existiert nur in der Live-Datenbank und ist in keiner Migration festgehalten
-- (bekannte Luecke). Sie zu ueberschreiben, ohne ihren Rumpf lesen zu koennen,
-- wuerde die heute funktionierenden Meldungen gefaehrden.

/* ==========================================================================
   1. TERMINE - zwei Fehler im vorhandenen Ausloeser
   ==========================================================================

   FEHLER A: Der Trigger feuerte bei JEDEM Update auf public.events. Das
   Eintragen eines Spielergebnisses laeuft aber ueber record_event_result, und
   das schreibt home_score, away_score und updated_at nach public.events
   (20260802015000, Zeile 31). Jede Ergebniseingabe schickte deshalb der ganzen
   Mannschaft eine "Spielaenderung". Der Trigger hoert jetzt nur noch auf die
   Spalten, die den Termin wirklich betreffen.

   FEHLER B: Der Text war der blanke Titel des Termins, bei Absagen mit
   " wurde abgesagt" dahinter. Was passiert ist - angelegt, geaendert, abgesagt -
   und worum es sich handelt - Training, Spiel, Vereins-Event - stand nirgends.
   Vereins-Events fielen ausserdem in den else-Zweig und bekamen gar keine
   eigene Ansprache.
   ========================================================================== */

create or replace function public.notify_event_audience() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  notice_kind text;
  v_titel     text;
  v_text      text;
begin
  notice_kind := case
    when new.type = 'training' and new.status = 'cancelled' then 'training_cancelled'
    when new.type = 'training' then 'training_created'
    when new.type = 'spiel' and tg_op = 'UPDATE' then 'game_changed'
    when new.type = 'spiel' then 'game_created'
    else 'news' end;

  v_titel := case
    when new.type = 'training' and new.status = 'cancelled' then 'Das Training wurde abgesagt.'
    when new.type = 'training' and tg_op = 'INSERT'         then 'Das Training wurde angelegt.'
    when new.type = 'training'                              then 'Das Training wurde geändert.'
    when new.type = 'spiel'    and new.status = 'cancelled' then 'Das Spiel wurde abgesagt.'
    when new.type = 'spiel'    and tg_op = 'INSERT'         then 'Das Spiel wurde angelegt.'
    when new.type = 'spiel'                                 then 'Das Spiel wurde geändert.'
    when new.status = 'cancelled' then 'Das Event ' || new.title || ' wurde abgesagt.'
    when tg_op = 'INSERT'         then 'Das Event ' || new.title || ' wurde angelegt.'
    else 'Das Event ' || new.title || ' wurde geändert.'
  end;

  /* Der Titel sagt, WAS passiert ist; der Text sagt, WELCHER Termin gemeint
     ist. Ohne den zweiten Teil muesste man die App oeffnen, um ueberhaupt zu
     wissen, um welches Training es geht. Europe/Berlin, weil timestamptz sonst
     in UTC herauskommt und die Uhrzeit im Winter eine Stunde danebenlaege. */
  v_text := new.title
    || ' · ' || to_char(new.starts_at at time zone 'Europe/Berlin', 'DD.MM.YYYY, HH24:MI') || ' Uhr'
    || coalesce(' · ' || nullif(trim(new.location), ''), '');

  insert into public.user_notifications(profile_id, club_id, kind, title, body, source_event_id)
  select distinct audience.profile_id, new.club_id, notice_kind, v_titel, v_text, new.id
  from (
    select m.profile_id
    from public.club_memberships m left join public.team_members tm on tm.membership_id = m.id
    where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
      and (new.team_id is null or tm.team_id = new.team_id)
    union
    select parent.profile_id
    from public.family_links f
    join public.club_memberships child on child.id = f.second_membership_id
    join public.club_memberships parent on parent.id = f.first_membership_id
    left join public.team_members child_team on child_team.membership_id = child.id
    where f.club_id = new.club_id and f.first_to_second = 'eltern' and parent.profile_id is not null
      and (new.team_id is null or child_team.team_id = new.team_id)
    union
    select parent.profile_id
    from public.family_links f
    join public.club_memberships child on child.id = f.first_membership_id
    join public.club_memberships parent on parent.id = f.second_membership_id
    left join public.team_members child_team on child_team.membership_id = child.id
    where f.club_id = new.club_id and f.second_to_first = 'eltern' and parent.profile_id is not null
      and (new.team_id is null or child_team.team_id = new.team_id)
  ) audience
  join public.profiles p on p.id = audience.profile_id
  where p.notification_master
    and coalesce((p.notification_preferences ->> notice_kind)::boolean, true);
  return new;
end;
$$;

drop trigger if exists events_notify_audience on public.events;
create trigger events_notify_audience
after insert or update of status, starts_at, ends_at, location, title, team_id, type
on public.events
for each row execute function public.notify_event_audience();

/* ==========================================================================
   2. BEITRITTSANFRAGE angenommen oder abgelehnt
   ==========================================================================
   Die Vereinsleitung entscheidet in der App ueber offene Antraege: annehmen
   setzt den Status auf 'active', ablehnen auf 'inactive'. Der Antragsteller
   erfuhr davon bisher nichts - er musste selbst nachsehen.
   Es gibt keinen Status 'rejected'; 'inactive' nach 'pending' IST die Ablehnung.
   ========================================================================== */

create or replace function public.beitritt_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_verein text;
begin
  -- Nur der Uebergang aus einem offenen Antrag heraus.
  if tg_op <> 'UPDATE' or old.status <> 'pending' or new.status = 'pending' then
    return new;
  end if;
  if new.profile_id is null then return new; end if;

  select c.name into v_verein from public.clubs c where c.id = new.club_id;

  if new.status = 'active' then
    perform public.notify(new.id, 'join_requests'::text,
      'Deine Beitrittsanfrage wurde angenommen.'::text,
      ('Willkommen bei ' || coalesce(v_verein, 'deinem Verein') || '.')::text);
  else
    perform public.notify(new.id, 'join_requests'::text,
      'Deine Beitrittsanfrage wurde abgelehnt.'::text,
      ('Wende dich an die Leitung von ' || coalesce(v_verein, 'deinem Verein') || ', wenn du Fragen hast.')::text);
  end if;
  return new;
end;
$$;

drop trigger if exists club_memberships_beitritt_melden on public.club_memberships;
create trigger club_memberships_beitritt_melden
after update of status on public.club_memberships
for each row execute function public.beitritt_melden();

/* ==========================================================================
   3. NEUE AUFGABE
   ==========================================================================
   club_tasks kann einer Mannschaft zugeordnet sein (team_id). Ist sie das,
   geht die Meldung nur an diese Mannschaft; sonst an den ganzen Verein.
   Nur auf INSERT: Das Bearbeiten einer Aufgabe laeuft in der App durch
   dieselbe Funktion und soll nicht jedes Mal erneut melden.
   ========================================================================== */

create or replace function public.aufgabe_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_mitglied record;
  v_text     text;
begin
  v_text := new.title
    || coalesce(' · bis ' || to_char(new.due_date, 'DD.MM.YYYY'), '');

  for v_mitglied in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and (new.team_id is null
            or exists (select 1 from public.team_members tm
                        where tm.membership_id = m.id and tm.team_id = new.team_id))
  loop
    perform public.notify(v_mitglied.id, 'tasks'::text,
      'Eine neue Aufgabe wurde erstellt.'::text, v_text::text);
  end loop;
  return new;
end;
$$;

drop trigger if exists club_tasks_melden on public.club_tasks;
create trigger club_tasks_melden after insert on public.club_tasks
for each row execute function public.aufgabe_melden();

/* ==========================================================================
   4. NEUE VEREINS-NEWS
   ==========================================================================
   ACHTUNG: willkommens_news() (20260903050000) schreibt bei jeder Aufnahme
   eines Mitglieds selbst eine Zeile nach news_posts. Ohne Ausnahme wuerde
   jede Aufnahme zusaetzlich eine News-Meldung an den ganzen Verein ausloesen.
   Diese automatischen Beitraege sind daran zu erkennen, dass sie keinen Autor
   haben (author_id is null, author_name 'Verein') - echte News schreibt immer
   ein Mensch.
   ========================================================================== */

create or replace function public.news_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_verein   text;
  v_mitglied record;
begin
  if new.author_id is null then return new; end if;

  select c.name into v_verein from public.clubs c where c.id = new.club_id;

  for v_mitglied in
    select m.id from public.club_memberships m
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
       and m.profile_id is distinct from new.author_id
  loop
    perform public.notify(v_mitglied.id, 'news'::text,
      (coalesce(v_verein, 'Verein') || ': Neue News!')::text, new.title::text);
  end loop;
  return new;
end;
$$;

drop trigger if exists news_posts_melden on public.news_posts;
create trigger news_posts_melden after insert on public.news_posts
for each row execute function public.news_melden();

/* ==========================================================================
   5. NEUER SPONSOR
   ==========================================================================
   Nur aktive Sponsoren. Einen abgeschalteten anzukuendigen ergibt keinen Sinn.
   ========================================================================== */

create or replace function public.sponsor_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_mitglied record;
begin
  if new.active is not true then return new; end if;

  for v_mitglied in
    select m.id from public.club_memberships m
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
  loop
    perform public.notify(v_mitglied.id, 'news'::text,
      'Ein neuer Sponsor präsentiert sich'::text, new.name::text);
  end loop;
  return new;
end;
$$;

drop trigger if exists sponsors_melden on public.sponsors;
create trigger sponsors_melden after insert on public.sponsors
for each row execute function public.sponsor_melden();

/* ==========================================================================
   6. NEUE ERGEBNISSE - fuer das Tippspiel
   ==========================================================================
   ergebnis_melden gibt es seit 20260905070000; sie benachrichtigt bisher nur
   diejenigen, die diese Mannschaft als ihre Ansicht gespeichert haben (die
   Lieblingsmannschaft). Wer getippt hat, erfaehrt aber nichts davon, dass das
   Ergebnis feststeht und seine Punkte berechnet sind.

   Empfaenger sind hier genau die, die auf DIESE Begegnung getippt haben -
   nicht der ganze Verein. Wer nicht mitspielt, will davon nichts wissen.
   Die Lieblingsmannschafts-Meldung bleibt unveraendert daneben bestehen; wer
   beides ist, bekommt zwei Zeilen mit unterschiedlichem Inhalt - einmal das
   Ergebnis, einmal der Hinweis auf die Punkte.
   ========================================================================== */

create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_spielart    text;
  v_titel       text;
  v_empfaenger  record;
  v_tipper      record;
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* --- Wer getippt hat: Punkte stehen fest --------------------------------
     Steht VOR dem Mannschafts-Block, denn der kehrt ohne Mannschaft frueh
     zurueck - und ein Tippspiel gibt es auch fuer Begegnungen ohne
     hinterlegte Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    perform public.notify(v_tipper.id, 'tipp'::text,
      'Das Ergebnis steht fest - deine Punkte sind berechnet.'::text,
      (coalesce(v_event.title, 'Begegnung') || ' · ' || new.heim || ':' || new.auswaerts)::text);
  end loop;

  if v_mannschaft is null then return new; end if;

  v_spielart := case when v_event.home_away = 'heim' then 'Heimspiel' else 'Auswärtsspiel' end;

  v_titel := case
    when new.heim > new.auswaerts then
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' haben wir mit ' || new.heim || ':' || new.auswaerts || ' gewonnen!'
    when new.heim = new.auswaerts then
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' geht mit einem ' || new.heim || ':' || new.auswaerts || ' unentschieden aus!'
    else
      coalesce(v_vereinsname, 'Verein') || ': Das ' || v_spielart || ' der ' || v_mannschaft
        || ' haben wir mit ' || new.auswaerts || ':' || new.heim || ' verloren!'
  end;

  for v_empfaenger in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and m.team_filter = v_mannschaft
  loop
    perform public.notify(v_empfaenger.id, 'results'::text, v_titel::text, null::text);
  end loop;

  return new;
end;
$$;

-- Kontrolle: Alle neuen Ausloeser muessen stehen.
select c.relname as tabelle, t.tgname as ausloeser
from pg_trigger t join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not t.tgisinternal
  and t.tgname in ('events_notify_audience', 'club_memberships_beitritt_melden',
                   'club_tasks_melden', 'news_posts_melden', 'sponsors_melden',
                   'event_results_melden')
order by c.relname, t.tgname;
