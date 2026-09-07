-- Vier Meldungen, die bisher nicht ankamen oder nirgends hinfuehrten.
--
-- 1. NEUE BEITRITTSANFRAGE ERREICHTE DIE LEITUNG UEBERHAUPT NICHT
--    notify_new_join_request gibt es, sie hat aber seit einer
--    Aufraeum-Migration keinen Ausloeser mehr, und Ersatz kam nie. Der
--    Schalter "Beitrittsanfragen" verspricht beide Richtungen; angekommen ist
--    nur die Antwort an den Anfragenden (beitritt_melden), nie die Anfrage an
--    den Verein. Wer sich anmeldet, wartete also darauf, dass jemand zufaellig
--    in die Mitgliederverwaltung schaut.
--
-- 2. FUENF MELDUNGEN TRUGEN IHR ZIEL UNTER DEM FALSCHEN NAMEN
--    warteschlange_in_glocke liest ausschliesslich data->>'ziel_art' und
--    data->>'ziel_id'. Fahrgemeinschaft, Helfersuche und Strafen uebergaben
--    aber 'carpool_id', 'event_id' bzw. 'assignment_id'. Die Werte verfielen
--    still, die Zeilen blieben nicht anklickbar.
--
-- 3. DIE GERAETEMELDUNG WAR NOCH FEST AUF DEUTSCH
--    notify_new_device haengt aktiv an auth.sessions - ich hatte sie beim
--    Uebersetzen fuer toten Code gehalten. Sie ist die einzige Meldung, die
--    jemanden erreicht, der die App vielleicht gar nicht selbst geoeffnet hat;
--    ausgerechnet die stand nur auf Deutsch da.
--
-- 4. Die Warteschlange traegt ausserdem den notif_type als kind weiter. Fuer
--    'info' gibt es keinen Schalter - das bleibt so und ist richtig: 'info'
--    ist der Rueckfall, wenn gar keine Art mitkam, und den will man nicht
--    abbestellen koennen.

-- ------------------------------------------------------------ Textbausteine
insert into public.meldungstexte (schluessel, sprache, text) values
  ('beitritt.anfrage.titel','de','Neue Beitrittsanfrage'),
  ('beitritt.anfrage.titel','en','New join request'),
  ('beitritt.anfrage.titel','es','Nueva solicitud de ingreso'),
  ('beitritt.anfrage.titel','pt','Novo pedido de adesão'),
  ('beitritt.anfrage.titel','it','Nuova richiesta di iscrizione'),
  ('beitritt.anfrage.titel','tr','Yeni üyelik başvurusu'),
  ('beitritt.anfrage.titel','fr','Nouvelle demande d''adhésion'),

  ('beitritt.anfrage.text','de','{wer} möchte dem Verein beitreten. Jetzt annehmen oder ablehnen.'),
  ('beitritt.anfrage.text','en','{wer} would like to join the club. Accept or decline now.'),
  ('beitritt.anfrage.text','es','{wer} quiere unirse al club. Acéptalo o recházalo ahora.'),
  ('beitritt.anfrage.text','pt','{wer} quer juntar-se ao clube. Aceita ou recusa agora.'),
  ('beitritt.anfrage.text','it','{wer} vuole iscriversi alla società. Accetta o rifiuta ora.'),
  ('beitritt.anfrage.text','tr','{wer} kulübe katılmak istiyor. Şimdi kabul et ya da reddet.'),
  ('beitritt.anfrage.text','fr','{wer} souhaite rejoindre le club. Accepte ou refuse maintenant.'),

  /* Eigener Satz statt eingesetztem Wort, weil der Name am Satzanfang steht. */
  ('beitritt.anfrage.textOhneName','de','Jemand möchte dem Verein beitreten. Jetzt annehmen oder ablehnen.'),
  ('beitritt.anfrage.textOhneName','en','Someone would like to join the club. Accept or decline now.'),
  ('beitritt.anfrage.textOhneName','es','Alguien quiere unirse al club. Acéptalo o recházalo ahora.'),
  ('beitritt.anfrage.textOhneName','pt','Alguém quer juntar-se ao clube. Aceita ou recusa agora.'),
  ('beitritt.anfrage.textOhneName','it','Qualcuno vuole iscriversi alla società. Accetta o rifiuta ora.'),
  ('beitritt.anfrage.textOhneName','tr','Biri kulübe katılmak istiyor. Şimdi kabul et ya da reddet.'),
  ('beitritt.anfrage.textOhneName','fr','Quelqu''un souhaite rejoindre le club. Accepte ou refuse maintenant.'),

  ('geraet.neu.titel','de','Neues Gerät angemeldet'),
  ('geraet.neu.titel','en','New device signed in'),
  ('geraet.neu.titel','es','Nuevo dispositivo con sesión iniciada'),
  ('geraet.neu.titel','pt','Novo dispositivo com sessão iniciada'),
  ('geraet.neu.titel','it','Nuovo dispositivo collegato'),
  ('geraet.neu.titel','tr','Yeni cihaz giriş yaptı'),
  ('geraet.neu.titel','fr','Nouvel appareil connecté'),

  ('geraet.neu.text','de','Dein Konto wurde soeben von einem neuen Gerät aus angemeldet. Warst du das nicht, ändere umgehend dein Passwort.'),
  ('geraet.neu.text','en','Your account was just signed in from a new device. If that was not you, change your password right away.'),
  ('geraet.neu.text','es','Se acaba de iniciar sesión en tu cuenta desde un dispositivo nuevo. Si no has sido tú, cambia la contraseña de inmediato.'),
  ('geraet.neu.text','pt','A tua conta acabou de iniciar sessão num dispositivo novo. Se não foste tu, muda já a palavra-passe.'),
  ('geraet.neu.text','it','Il tuo account ha appena effettuato l''accesso da un nuovo dispositivo. Se non sei stato tu, cambia subito la password.'),
  ('geraet.neu.text','tr','Hesabına az önce yeni bir cihazdan giriş yapıldı. Bu sen değilsen şifreni hemen değiştir.'),
  ('geraet.neu.text','fr','Ton compte vient d''être connecté depuis un nouvel appareil. Si ce n''était pas toi, change ton mot de passe immédiatement.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- -------------------------------------------------- 1. Beitrittsanfrage
--
-- Neu geschrieben statt die alte Funktion wiederzubeleben: Die alte schickte
-- fertige deutsche Saetze und traf 'vorstand' mit, der aber gar nicht ueber
-- Anfragen entscheiden kann. Entscheiden duerfen vereinsadmin, sysadmin und
-- organisator - genau die bekommen die Meldung.
create or replace function public.beitrittsanfrage_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_wer text;
begin
  if new.status <> 'pending' then return new; end if;
  /* Nur beim UEBERGANG nach pending, nicht bei jeder Aenderung an einer
     bereits wartenden Zeile - sonst meldet jeder Tippfehler im Namen erneut. */
  if tg_op = 'UPDATE' and old.status = 'pending' then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldungstext('beitritt.anfrage.titel', p.language),
         case when v_wer is null
              then public.meldungstext('beitritt.anfrage.textOhneName', p.language)
              else public.meldungstext('beitritt.anfrage.text', p.language,
                     jsonb_build_object('wer', v_wer)) end,
         'beitritt', new.id
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and m.id is distinct from new.id
    and public.meldung_erlaubt(m.profile_id, 'join_requests');

  return new;
end;
$$;

drop trigger if exists club_memberships_anfrage_melden on public.club_memberships;
create trigger club_memberships_anfrage_melden
  after insert or update of status on public.club_memberships
  for each row execute function public.beitrittsanfrage_melden();

-- ---------------------------------------------- 2. Ziele richtig benennen
create or replace function public.notify_carpool_joined()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  driver_id uuid;
  passenger_name text;
  v_event uuid;
  v_sprache text;
begin
  select driver_membership_id, event_id into driver_id, v_event
    from public.carpools where id = new.carpool_id;
  select display_name into passenger_name from public.club_memberships where id = new.membership_id;
  if driver_id is not null and driver_id <> new.membership_id then
    v_sprache := public.sprache_der_mitgliedschaft(driver_id);
    /* Eine Fahrgemeinschaft gehoert zu einem Termin - dorthin fuehrt die
       Meldung. Vorher stand hier 'carpool_id', ein Name, den die Glocke gar
       nicht liest. */
    perform public.notify_uebersetzt(driver_id, 'carpool',
      'fahrgemeinschaft.neu.titel', 'fahrgemeinschaft.neu.text',
      jsonb_build_object('wer', coalesce(passenger_name, public.meldungstext('allg.jemand', v_sprache))),
      case when v_event is null then '{}'::jsonb
           else jsonb_build_object('ziel_art', 'termin', 'ziel_id', v_event) end);
  end if;
  return new;
end;
$$;

create or replace function public.run_carpool_gap_check()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled'
      and e.type = 'spiel'
      and coalesce(e.home_away, 'auswaerts') <> 'heim'
      and e.starts_at::date = current_date + interval '3 days'
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', to_char(ev.starts_at, 'DD.MM.')),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$$;

create or replace function public.run_duty_gap_check()
returns void language plpgsql security definer set search_path = 'public' as $$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and e.starts_at::date = current_date + interval '3 days'
      and exists (select 1 from public.duty_tasks dt where dt.event_id = e.id and dt.assignee_membership_id is null and dt.done = false)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', to_char(ev.starts_at, 'DD.MM.')),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$$;

create or replace function public.notify_penalty_assigned()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text; v_team uuid;
begin
  select title, team_id into rule_title, v_team from public.team_penalty_rules where id = new.rule_id;
  perform public.notify_uebersetzt(new.membership_id, 'penalties',
    'strafe.neu.titel',
    case when rule_title is null then 'strafe.neu.textOhneRegel' else 'strafe.neu.text' end,
    jsonb_build_object('regel', coalesce(rule_title, '')),
    case when v_team is null then '{}'::jsonb
         else jsonb_build_object('ziel_art', 'strafe', 'ziel_id', v_team) end);
  return new;
end;
$$;

create or replace function public.notify_penalty_paid()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare rule_title text; v_team uuid;
begin
  if old.paid_at is null and new.paid_at is not null then
    select title, team_id into rule_title, v_team from public.team_penalty_rules where id = new.rule_id;
    perform public.notify_uebersetzt(new.membership_id, 'penalties',
      'strafe.bezahlt.titel',
      case when rule_title is null then 'strafe.bezahlt.textOhneRegel' else 'strafe.bezahlt.text' end,
      jsonb_build_object('regel', coalesce(rule_title, '')),
      case when v_team is null then '{}'::jsonb
           else jsonb_build_object('ziel_art', 'strafe', 'ziel_id', v_team) end);
  end if;
  return new;
end;
$$;

-- ----------------------------------------- 3. Geraetemeldung uebersetzen
create or replace function public.notify_new_device()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  computed_hash text;
  is_new boolean;
  member record;
begin
  computed_hash := md5(coalesce(new.user_agent, '') || '|' || coalesce(host(new.ip), ''));
  select not exists (
    select 1 from public.known_devices where profile_id = new.user_id and device_hash = computed_hash
  ) into is_new;
  insert into public.known_devices (profile_id, device_hash, user_agent, last_seen_at)
  values (new.user_id, computed_hash, new.user_agent, now())
  on conflict (profile_id, device_hash) do update set last_seen_at = now();
  if is_new then
    for member in select id from public.club_memberships where profile_id = new.user_id and status = 'active' loop
      perform public.notify_uebersetzt(member.id, 'security', 'geraet.neu.titel', 'geraet.neu.text');
    end loop;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_proc p on p.oid=t.tgfoid
    where c.relname='club_memberships' and p.proname='beitrittsanfrage_melden') as anfrage_ausloeser,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosrc ~ 'jsonb_build_object\(''(carpool_id|assignment_id|event_id|membership_id|news_id)''' 
      and p.prosrc like '%notify%'
      and p.proname not like 'notify_event_%' and p.proname <> 'notify_news_posted'
      and p.proname <> 'notify_new_join_request') as falsche_zielnamen_uebrig,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname='notify_new_device' and prosrc like '%geraet.neu.titel%') as geraet_uebersetzt;
