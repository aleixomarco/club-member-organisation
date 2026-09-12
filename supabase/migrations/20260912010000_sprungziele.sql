-- Jede Meldung weiss, wohin sie fuehrt.
--
-- WARUM
-- In der Glocke und auf dem Telefon standen Meldungen, die sich antippen
-- liessen und nichts taten - oder nur die App oeffneten. Stand 12.09.2026 in
-- der Produktion: chat, news, join_requests (Antwort an den Bewerber),
-- membership, vehicle und die Geraetemeldung trugen kein Ziel. Wer "Neue
-- Nachricht von Marco" antippt, will in diesen Kanal, nicht auf die
-- Startseite und von dort weitersuchen.
--
-- WAS SICH AENDERT
-- Nur das Ziel. Jede Funktion ist die JUENGSTE Fassung aus den Migrationen,
-- Wort fuer Wort uebernommen; dazu kommen ziel_art und ziel_id - bei den
-- Ausloesern ueber notify_uebersetzt als p_data (warteschlange_in_glocke
-- schreibt beides in die Glocke), bei den direkten Einfuegungen als Spalten.
--
--   Funktion (juengste Fassung)                     ziel_art      ziel_id
--   chatnachricht_melden        (20260910010000)    chat          Kanal
--   news_melden                 (20260911060000)    news          Beitrag
--   beitritt_melden, angenommen (20260907060000)    verein        Verein
--   aufnahme_leitung_melden     (20260911060000)    mitglied      neue Mitgliedschaft
--   notify_vehicle_booking_cancelled (20260907060000) fahrzeug    Fahrzeug
--   notify_new_device           (20260911070000)    sicherheit    -
--   notify_team_joined          (20260907060000)    mannschaft    Mannschaft
--   notify_family_link_created  (20260907060000)    familie       -
--   notify_penalty_removed      (20260907060000)    strafe        Mannschaft
--   run_duty_task_due_reminders (20260907060000)    helferdienst  Termin
--   run_birthday_reminders      (20260907060000)    geburtstag    Mitgliedschaft
--
-- WAS BLEIBT, WIE ES IST
--   * fahrzeuganfrage_melden (20260907100000) und entscheide_fahrzeug_anfrage
--     (20260907060000) tragen ihr Ziel 'fahrzeug' schon. Die zwei alten
--     vehicle-Zeilen ohne Ziel stammen aus der Zeit davor.
--   * beitritt_melden bei einer ABLEHNUNG: Es gibt nichts zu oeffnen - die
--     Mitgliedschaft ist nicht aktiv, der Verein laesst sich gar nicht waehlen.
--     Ein Ziel, das ins Leere fuehrt, waere schlechter als keines.
--   * aufnahme_leitung_melden fuehrte bisher auf 'beitritt', also zu den
--     offenen Antraegen. Dort steht die Aufnahme aber gerade NICHT mehr - sie
--     ist ja erledigt. 'mitglied' oeffnet stattdessen das neue Mitglied.
--     Die Anfrage selbst (beitrittsanfrage_melden) fuehrt weiter auf 'beitritt'.
--   * Betreibernachrichten (betreiber_nachricht_senden, anzeige_melden) bleiben
--     ohne Ziel: Sie sind eine Mitteilung, kein Hinweis auf eine Stelle.
--   * Kein Nachtrag fuer alte Zeilen. Sie bleiben, wie sie sind; die App zeigt
--     sie ohne Ziel als schlichte Notiz.
--
-- FEHLER DUERFEN NICHTS MITREISSEN
-- Diese Ausloeser haengen an Chatnachrichten, News, Anmeldungen. Keine
-- Umwandlung, die scheitern koennte: Die Kennungen sind schon uuid und wandern
-- unveraendert in jsonb_build_object; die Glocke prueft das Format selbst,
-- bevor sie ::uuid schreibt. Die Ausnahmebehandlung der Geraetemeldung bleibt
-- unveraendert.

-- ------------------------------------------------------------------- Chat
create or replace function public.chatnachricht_melden()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_club  uuid;
  v_team  uuid;
  v_wer   text;
  v_text  text;
begin
  select c.club_id, c.team_id into v_club, v_team from public.channels c where c.id = new.channel_id;
  if v_club is null then return new; end if;

  /* Ueber profile_id UND club_id: Dieselbe Person kann in mehreren Vereinen
     Mitglied sein, und der Name soll der aus DIESEM Verein sein. */
  select m.display_name into v_wer
    from public.club_memberships m
   where m.profile_id = new.author_id and m.club_id = v_club
   order by (m.status = 'active') desc
   limit 1;

  v_text := case when length(new.body) > 90 then left(new.body, 90) || ' …' else new.body end;

  /* Ziel ist der Kanal: Die Meldung oeffnet genau das Gespraech, aus dem sie
     kommt. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, v_club, 'chat',
         coalesce(v_wer, public.meldungstext('chat.titel', p.language)),
         coalesce(v_wer, public.meldungstext('allg.jemand', p.language)) || ': ' || v_text,
         'chat', new.channel_id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = v_team
  where m.club_id = v_club and m.status = 'active' and m.profile_id is not null
    /* Der Absender bekommt seine eigene Nachricht nicht gemeldet. Verglichen
       wird jetzt Profil mit Profil - vorher stand hier m.id, eine
       Mitgliedschaftskennung, und der Vergleich ging immer aus. */
    and m.profile_id is distinct from new.author_id
    and (v_team is null or tm.membership_id is not null)
    and public.team_meldung_erlaubt(m.id, v_team, 'chat')
    and public.meldung_erlaubt(m.profile_id, 'chat');
  return new;
end;
$function$;

-- ------------------------------------------------------------------- News
create or replace function public.news_melden()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  /* Der Willkommensbeitrag bei einer Aufnahme meldet nicht an alle - die
     Aufnahme melden wir der Vereinsleitung eigens (aufnahme_leitung_melden). */
  if coalesce(current_setting('cmo.news_still', true), '') = 'an' then
    return new;
  end if;
  /* Ziel ist der Beitrag selbst: Die App rollt ihn auf der Startseite heran
     oder oeffnet ihn einzeln, wenn er dort nicht mehr steht. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select m.profile_id, new.club_id, 'news',
         public.meldungstext('news.titel', p.language),
         public.meldungstext('news.text', p.language),
         'news', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'news');
  return new;
end;
$function$;

-- --------------------------------------------------- Beitritt (Bewerber)
create or replace function public.beitritt_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_verein  text;
  v_sprache text;
begin
  if tg_op <> 'UPDATE' or old.status <> 'pending' or new.status = 'pending' then
    return new;
  end if;
  if new.profile_id is null then return new; end if;

  select c.name into v_verein from public.clubs c where c.id = new.club_id;
  v_sprache := public.sprache_der_mitgliedschaft(new.id);

  if new.status = 'active' then
    /* Angenommen: Die Meldung oeffnet den Verein, in den man gerade
       aufgenommen wurde - auch wenn in der App noch ein anderer offen ist. */
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.angenommen.titel', 'beitritt.angenommen.text',
      jsonb_build_object('verein', coalesce(v_verein, public.meldungstext('allg.deinVerein', v_sprache))),
      jsonb_build_object('ziel_art', 'verein', 'ziel_id', new.club_id));
  else
    /* Abgelehnt: bewusst ohne Ziel - siehe Kopf dieser Datei. */
    perform public.notify_uebersetzt(new.id, 'join_requests',
      'beitritt.abgelehnt.titel', 'beitritt.abgelehnt.text',
      jsonb_build_object('verein', coalesce(v_verein, public.meldungstext('allg.deinVerein', v_sprache))));
  end if;
  return new;
end;
$$;

-- ------------------------------------------- Aufnahme (Vereinsleitung)
create or replace function public.aufnahme_leitung_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wer text;
begin
  if new.status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  if new.profile_id is null or new.is_managed_profile then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  /* 'mitglied' statt 'beitritt': Die Aufnahme ist erledigt, bei den offenen
     Antraegen steht sie nicht mehr. Die Leitung will das neue Mitglied sehen. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldungstext('beitritt.aufgenommen.titel', p.language),
         case when v_wer is null
              then public.meldungstext('beitritt.aufgenommen.textOhneName', p.language)
              else public.meldungstext('beitritt.aufgenommen.text', p.language, jsonb_build_object('wer', v_wer)) end,
         'mitglied', new.id
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and m.id <> new.id
    and m.profile_id is distinct from new.profile_id
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'join_requests');
  return new;
end;
$$;

-- ------------------------------------------------ Fahrzeug storniert
/* Wer selbst storniert, braucht keine Meldung darueber.
   Ziel ist das FAHRZEUG, nicht die Buchung: Die Buchung gibt es nach dem
   Stornieren nicht mehr, das Fahrzeug schon. */
create or replace function public.notify_vehicle_booking_cancelled()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  acting_profile uuid;
begin
  select profile_id into acting_profile from public.club_memberships where id = old.membership_id;
  if acting_profile is distinct from auth.uid() then
    perform public.notify_uebersetzt(old.membership_id, 'carpool',
      'fahrzeug.storniert.titel', 'fahrzeug.storniert.text',
      '{}'::jsonb,
      jsonb_build_object('ziel_art', 'fahrzeug', 'ziel_id', old.vehicle_id));
  end if;
  return old;
end;
$$;

-- ------------------------------------------------------ Neues Geraet
-- Der Ausloeser haengt an auth.sessions: Ein Fehler hier wuerde die Anmeldung
-- selbst scheitern lassen. Der eigene Block um das Melden bleibt deshalb
-- genau so, wie er war. Neu sind nur die zwei Spalten mit dem Ziel - reine
-- Textwerte, nichts, was scheitern koennte.
create or replace function public.notify_new_device()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  computed_hash text;
  is_new boolean;
  v_sprache text;
begin
  computed_hash := md5(coalesce(new.user_agent, '') || '|' || coalesce(host(new.ip), ''));
  select not exists (
    select 1 from public.known_devices where profile_id = new.user_id and device_hash = computed_hash
  ) into is_new;
  insert into public.known_devices (profile_id, device_hash, user_agent, last_seen_at)
  values (new.user_id, computed_hash, new.user_agent, now())
  on conflict (profile_id, device_hash) do update set last_seen_at = now();

  if is_new then
    begin
      if exists (select 1 from public.club_memberships where profile_id = new.user_id and status = 'active')
         and public.meldung_erlaubt(new.user_id, 'security') then
        select coalesce(p.language, 'de') into v_sprache from public.profiles p where p.id = new.user_id;
        v_sprache := coalesce(v_sprache, 'de');
        /* 'sicherheit' ohne Kennung: Die App oeffnet Profil > Konto &
           Sicherheit - dort meldet man fremde Geraete ab. */
        insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
        values (new.user_id, null, 'security',
                public.meldungstext('geraet.neu.titel', v_sprache),
                public.meldungstext('geraet.neu.text', v_sprache),
                'sicherheit', null);
      end if;
    exception when others then
      -- Auch meldung_erlaubt gehoert in diesen Block: Es wandelt die
      -- gespeicherte Einstellung per ::boolean um - ein kaputter Wert wuerde
      -- sonst die Anmeldung selbst abbrechen.
      raise warning 'Geraetemeldung fehlgeschlagen: %', sqlerrm;
    end;
  end if;
  return new;
end;
$$;

-- ------------------------------------------------ Mannschaft beigetreten
create or replace function public.notify_team_joined()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare team_name text;
begin
  select name into team_name from public.teams where id = new.team_id;
  perform public.notify_uebersetzt(new.membership_id, 'membership',
    'team.willkommen.titel', 'team.willkommen.text',
    jsonb_build_object('team', coalesce(team_name, '')),
    jsonb_build_object('ziel_art', 'mannschaft', 'ziel_id', new.team_id));
  return new;
end;
$$;

-- ------------------------------------------------------------- Familie
/* Ohne Kennung: Die Verknuepfungen stehen gesammelt unter Profil > Familie,
   eine einzelne gibt es dort nicht zu oeffnen. */
create or replace function public.notify_family_link_created()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  perform public.notify_uebersetzt(new.first_membership_id,  'family', 'familie.titel', 'familie.text',
    '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
  perform public.notify_uebersetzt(new.second_membership_id, 'family', 'familie.titel', 'familie.text',
    '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
  return new;
end;
$$;

-- ------------------------------------------------------ Strafe entfernt
/* Wie bei zugewiesen und bezahlt (20260907140000): ziel_id ist die
   Mannschaft, denn die Zuweisung selbst ist hier gerade geloescht worden.
   Die Zeile traegt team_id selbst - kein Nachschlagen noetig. */
create or replace function public.notify_penalty_removed()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text;
begin
  if old.archived_season is null then
    select title into rule_title from public.team_penalty_rules where id = old.rule_id;
    perform public.notify_uebersetzt(old.membership_id, 'penalties',
      'strafe.zurueck.titel',
      case when rule_title is null then 'strafe.zurueck.textOhneRegel' else 'strafe.zurueck.text' end,
      jsonb_build_object('regel', coalesce(rule_title, '')),
      jsonb_build_object('ziel_art', 'strafe', 'ziel_id', old.team_id));
  end if;
  return old;
end;
$$;

-- --------------------------------------------------------- Geburtstage
/* Das Geburtstagskind bekommt keine Meldung ueber sich selbst - daher
   id <> bday.membership_id.
   Ziel 'geburtstag': Die Startseite zeigt die Geburtstage des Tages. */
create or replace function public.run_birthday_reminders()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  bday record;
  member record;
begin
  for bday in
    select m.id as membership_id, m.club_id, m.display_name
    from public.club_memberships m
    join public.profiles p on p.id = m.profile_id
    where m.status = 'active' and p.show_birthday = true
      and extract(month from p.birthdate) = extract(month from current_date)
      and extract(day from p.birthdate) = extract(day from current_date)
  loop
    for member in
      select id from public.club_memberships
      where club_id = bday.club_id and status = 'active' and id <> bday.membership_id
    loop
      perform public.notify_uebersetzt(member.id, 'birthdays',
        'geburtstag.titel', 'geburtstag.text',
        jsonb_build_object('wer', bday.display_name),
        jsonb_build_object('ziel_art', 'geburtstag', 'ziel_id', bday.membership_id));
    end loop;
  end loop;
end;
$$;

-- ------------------------------------------ Helferdienst morgen faellig
/* reminded_at ist die Sperre gegen taegliche Wiederholung. Ohne sie erinnert
   der naechtliche Auftrag jeden Tag aufs Neue an dieselbe Aufgabe.
   Ziel ist der TERMIN, wie bei den uebrigen Helferdienst-Meldungen
   (20260911030000, 20260911050000): Dort stehen Helferplan und Stationen
   beieinander. Haengt der Dienst an keinem Termin, bleibt ziel_id leer - die
   App oeffnet dann die Helferdienste im Support-Reiter. */
create or replace function public.run_duty_task_due_reminders()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  t record;
begin
  for t in
    select id, assignee_membership_id, title, event_id from public.duty_tasks
    where due_date = current_date + 1 and assignee_membership_id is not null and not done and reminded_at is null
  loop
    perform public.notify_uebersetzt(t.assignee_membership_id, 'duty',
      'helfer.faellig.titel', 'helfer.faellig.text',
      jsonb_build_object('titel', t.title),
      jsonb_build_object('ziel_art', 'helferdienst', 'ziel_id', t.event_id));
    update public.duty_tasks set reminded_at = now() where id = t.id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------- Nachweis
-- Nur lesend. Erwartet: melder_mit_ziel = 13, die uebrigen je 1.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('chatnachricht_melden', 'news_melden', 'beitritt_melden', 'aufnahme_leitung_melden',
                        'notify_vehicle_booking_cancelled', 'notify_new_device', 'notify_team_joined',
                        'notify_family_link_created', 'notify_penalty_removed', 'run_birthday_reminders',
                        'run_duty_task_due_reminders', 'fahrzeuganfrage_melden', 'entscheide_fahrzeug_anfrage')
      and p.prosrc like '%ziel_art%') as melder_mit_ziel,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'notify_new_device'
      and p.prosrc like '%''sicherheit''%' and p.prosrc like '%exception when others%') as geraetemeldung_abgesichert,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'aufnahme_leitung_melden'
      and p.prosrc like '%''mitglied''%') as aufnahme_zeigt_aufs_mitglied,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'news_melden'
      and p.prosrc like '%cmo.news_still%') as willkommen_bleibt_still;
