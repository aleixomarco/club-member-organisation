-- Alle Benachrichtigungen auf einen Weg bringen - und vier neue dazu.
--
-- WAS VORGEFUNDEN WURDE: ZWEI SYSTEME NEBENEINANDER
--
--   alt:  notify_*  ->  notification_queue  ->  trigger_send_push
--   neu:  *_melden  ->  user_notifications  ->  push_anstossen
--
-- Beide liefen. Aber nur das neue speist die Glocke in der App - die alten
-- Meldungen landeten in einer Tabelle, die niemand anzeigt. 260 Eintraege
-- liegen dort, 222 allein aus den letzten sieben Tagen: Strafen, Fahrgemein-
-- schaften, Familienverknuepfungen, Mannschaftszugaenge. Nichts davon hat je
-- ein Mitglied gesehen.
--
-- Schlimmer: Bei Terminen, News und Mitgliedsantraegen feuerten BEIDE Systeme.
-- Sobald ein Geraet angemeldet ist, kaeme jede dieser Meldungen doppelt.
--
-- WAS DIESE MIGRATION TUT
--
-- 1. Vereinsname einheitlich voranstellen - an EINER Stelle, nicht in
--    fuenfzehn Funktionen. Ein Ausloeser auf user_notifications setzt ihn vor
--    jeden Text, der ihn noch nicht traegt. Damit gilt das Format
--    "{Verein}: ..." auch fuer alles, was spaeter dazukommt.
--
-- 2. Doppelte alte Ausloeser entfernen (Termine, News, Mitgliedsantraege).
--
-- 3. Den Rest der alten Warteschlange ueberbruecken: Was noch in
--    notification_queue geschrieben wird, landet ab jetzt auch in
--    user_notifications - also in der Glocke und im Push.
--
-- 4. Vier neue Meldungen: Aufgabe zugewiesen, Erinnerung am Vortag,
--    News-Text angepasst, Chatnachricht.

/* ------------------------------------------------------------------ */
/* 1. Vereinsname voranstellen - zentral                              */
/* ------------------------------------------------------------------ */
create or replace function public.meldung_vereinsname_voranstellen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_name text;
begin
  if new.club_id is null or new.body is null then return new; end if;
  select name into v_name from public.clubs where id = new.club_id;
  /* Nur voranstellen, wenn er nicht schon dasteht - sonst entsteht
     "SV Muster: SV Muster: ..." bei jeder Meldung, die ihn selbst setzt. */
  if v_name is not null and v_name <> '' and position(v_name || ':' in new.body) <> 1 then
    new.body := v_name || ': ' || new.body;
  end if;
  return new;
end;
$$;

drop trigger if exists user_notifications_vereinsname on public.user_notifications;
create trigger user_notifications_vereinsname
  before insert on public.user_notifications
  for each row execute function public.meldung_vereinsname_voranstellen();

/* ------------------------------------------------------------------ */
/* 2. Doppelte alte Ausloeser entfernen                               */
/* ------------------------------------------------------------------ */
drop trigger if exists notify_event_created on public.events;
drop trigger if exists notify_event_updated on public.events;
drop trigger if exists notify_news_posted on public.news_posts;
drop trigger if exists notify_new_join_request on public.club_memberships;
drop trigger if exists notify_join_request_decided on public.club_memberships;

/* ------------------------------------------------------------------ */
/* 3. Alte Warteschlange ueberbruecken                                */
/* ------------------------------------------------------------------ */
/* Strafen, Fahrgemeinschaften, Familienverknuepfungen, Mannschafts-
   zugaenge und stornierte Fahrzeugbuchungen schreiben weiter in
   notification_queue. Statt fuenf Funktionen umzubauen - jede eine
   Gelegenheit, sich zu vertun - wird die Warteschlange abgegriffen. */
create or replace function public.warteschlange_in_glocke()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_profil uuid;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, new.club_id, coalesce(new.notif_type, 'info'),
          coalesce(new.title, 'Vereinsmeldung'), coalesce(new.body, ''));
  return new;
end;
$$;

drop trigger if exists notification_queue_in_glocke on public.notification_queue;
create trigger notification_queue_in_glocke
  after insert on public.notification_queue
  for each row execute function public.warteschlange_in_glocke();

/* Der alte Push-Aufruf auf der Warteschlange faellt weg: Er ruft den Versender
   mit dem oeffentlichen Schluessel auf, den dieser seit der Absicherung
   ablehnt - und ueber die Bruecke oben laeuft der Versand jetzt ohnehin auf
   dem geprueften Weg. Zwei Aufrufe pro Meldung waeren nur doppelte Last. */
drop trigger if exists trigger_send_push on public.notification_queue;

/* ------------------------------------------------------------------ */
/* 4a. Aufgabe zugewiesen                                             */
/* ------------------------------------------------------------------ */
create or replace function public.aufgabe_zugewiesen_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
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

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  values (v_profil, new.club_id, 'task', 'Neue Aufgabe',
          coalesce(v_wer, 'Die Vereinsleitung') || ' hat dir eine Aufgabe zugewiesen.');
  return new;
end;
$$;

drop trigger if exists duty_tasks_zuweisung_melden on public.duty_tasks;
create trigger duty_tasks_zuweisung_melden
  after insert or update of assignee_membership_id on public.duty_tasks
  for each row execute function public.aufgabe_zugewiesen_melden();

/* ------------------------------------------------------------------ */
/* 4b. Erinnerung am Vortag                                           */
/* ------------------------------------------------------------------ */
/* duty_tasks hatte die Spalte reminded_at schon - offenbar war die
   Erinnerung geplant und nie gebaut worden. club_tasks bekommt sie jetzt
   auch, damit beide Aufgabenarten gleich behandelt werden. */
alter table public.club_tasks add column if not exists reminded_at timestamptz;

create or replace function public.aufgaben_erinnerung_senden()
returns integer language plpgsql security definer set search_path = '' as $$
declare v_anzahl integer := 0;
begin
  /* Zugewiesene Aufgaben an einem Termin */
  with faellig as (
    select t.id, t.club_id, t.title, m.profile_id
    from public.duty_tasks t
    join public.club_memberships m on m.id = t.assignee_membership_id
    where t.due_date = (current_date + 1)
      and t.reminded_at is null and t.done is not true
      and m.profile_id is not null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select f.profile_id, f.club_id, 'task', 'Erinnerung',
           'Erinnerung für morgen: ' || f.title
    from faellig f
    returning 1
  )
  update public.duty_tasks set reminded_at = now()
   where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;

  /* Vereinsaufgaben ohne feste Zuweisung - an die ganze Mannschaft, sonst
     an den Verein. Wer die Aufgabe nicht sieht, bekommt auch keine
     Erinnerung: notify_club_or_team beruecksichtigt team_id. */
  with faellig2 as (
    select t.id, t.club_id, t.team_id, t.title
    from public.club_tasks t
    where t.due_date = (current_date + 1) and t.reminded_at is null
  ), empfaenger as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select distinct m.profile_id, f.club_id, 'task', 'Erinnerung',
           'Erinnerung für morgen: ' || f.title
    from faellig2 f
    join public.club_memberships m on m.club_id = f.club_id and m.status = 'active'
    left join public.team_members tm on tm.membership_id = m.id and tm.team_id = f.team_id
    where m.profile_id is not null and (f.team_id is null or tm.membership_id is not null)
    returning 1
  )
  update public.club_tasks set reminded_at = now()
   where id in (select id from faellig2);

  return v_anzahl;
end;
$$;

/* Einmal taeglich um 18 Uhr - frueh genug, um am Abend vorher noch zu
   reagieren, spaet genug, um nicht im Morgentrubel unterzugehen. */
select cron.unschedule('aufgaben-erinnerung')
 where exists (select 1 from cron.job where jobname = 'aufgaben-erinnerung');
select cron.schedule('aufgaben-erinnerung', '0 18 * * *',
  $$select public.aufgaben_erinnerung_senden();$$);

/* ------------------------------------------------------------------ */
/* 4c. News-Text                                                      */
/* ------------------------------------------------------------------ */
/* Der Vereinsname kommt jetzt vom Ausloeser oben, der Text sagt, was zu tun
   ist. Vorher stand der Vereinsname im Text selbst - das haette nach der
   Umstellung doppelt gewirkt. */
create or replace function public.news_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select m.profile_id, new.club_id, 'news', 'Neue Vereins-News', 'Neue News. Jetzt lesen!'
  from public.club_memberships m
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid();
  return new;
end;
$$;

/* ------------------------------------------------------------------ */
/* 4d. Chatnachricht                                                  */
/* ------------------------------------------------------------------ */
create or replace function public.chatnachricht_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
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
    and (v_team is null or tm.membership_id is not null);
  return new;
end;
$$;

drop trigger if exists messages_melden on public.messages;
create trigger messages_melden
  after insert on public.messages
  for each row execute function public.chatnachricht_melden();

/* Kontrolle */
select
  (select count(*) from pg_trigger where tgname = 'user_notifications_vereinsname') as vereinsname,
  (select count(*) from pg_trigger where tgname in
     ('notify_event_created','notify_event_updated','notify_news_posted',
      'notify_new_join_request','notify_join_request_decided','trigger_send_push')) as alte_uebrig,
  (select count(*) from pg_trigger where tgname in
     ('notification_queue_in_glocke','duty_tasks_zuweisung_melden','messages_melden')) as neue,
  (select count(*) from cron.job where jobname = 'aufgaben-erinnerung') as erinnerung;
