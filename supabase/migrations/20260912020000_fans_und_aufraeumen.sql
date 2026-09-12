-- Fans sehen keine Trainings, Fans werden still aufgenommen - und Aufraeumen.
--
-- Entscheidungen des Product Owners vom 12.09.2026.
--
-- WAS SICH AENDERT
--   1. notify_event_audience (juengste Fassung: 20260909040000_reihe_absagen)
--      meldet Trainings nicht mehr an Mitgliedschaften, deren einzige Rolle
--      'fan' ist. Die App zeigt einem Fan keine Trainings mehr - eine Meldung
--      "Neues Training" fuehrte ihn also auf etwas, das er gar nicht sieht.
--      Spiele und Vereinstermine melden weiter an Fans.
--   2. willkommens_news (juengste Fassung: 20260911060000_aufnahme_nur_leitung)
--      legt fuer einen Fan keinen oeffentlichen Willkommensbeitrag mehr an.
--      "Willkommen im Verein, ...! Unter Termine findest du Training ..." ist
--      fuer einen Fan doppelt falsch.
--   3. aufnahme_leitung_melden (juengste Fassung: 20260912010000_sprungziele,
--      das Ziel 'mitglied' bleibt) meldet der Vereinsleitung einen Fan mit
--      eigenen Texten: "Neu dabei" / "{wer} ist jetzt dabei!". "Neues
--      Mitglied" stimmte fuer einen Fan nicht.
--   4. set_membership_role verliert EXECUTE fuer authenticated (und anon).
--      Die App ruft sie nicht auf, Rollen laufen seit 20260911110000 ueber
--      mitgliedsrollen_setzen. Der Fan-Waechter schuetzt sie zwar ohnehin -
--      aber eine Tuer, die niemand braucht, muss nicht offen stehen.
--
-- WOHER DIE AUFNAHME-AUSLOESER DIE ROLLE KENNEN
-- beitritt_entscheiden (20260911110000) schreibt die Rollen VOR dem
-- Status-UPDATE. Wenn willkommens_news und aufnahme_leitung_melden beim
-- Wechsel auf 'active' feuern, steht 'fan' also schon in membership_roles.
-- Der einzige Weg, auf dem eine Mitgliedschaft schon beim INSERT aktiv ist,
-- ist das erste Mitglied eines Vereins (register_for_club) - und das ist nie
-- ein Fan, sondern bekommt vereinsadmin und sysadmin.
--
-- WEITERE TRAININGS-ERINNERUNGEN GIBT ES NICHT
-- Durchgesehen (jeweils die juengste Fassung): ergebnis_erinnerung_senden,
-- spielergebnis_melden und ergebnis_melden betreffen nur Spiele,
-- run_carpool_gap_check ebenso (e.type = 'spiel'), run_duty_gap_check und
-- die Helferdienst-Meldungen gehen nur an Eingeteilte - ein Fan steht in
-- keinem Dienst. Die Push-Funktion verschickt nur, was in user_notifications
-- steht. Bleibt notify_event_audience.
--
-- WAS BLEIBT, WIE ES IST
--   * anzeige_zaehlen bleibt stehen - aeltere App-Staende rufen sie noch.
--     Geplant ist das Entfernen um den 17.09.2026, nicht hier.
--   * Leitungen, die Termine bearbeiten, sind nicht betroffen: Ein Fan hat
--     nie eine weitere Rolle.
--
-- FEHLER DUERFEN NICHTS MITREISSEN
-- Alle drei Funktionen haengen als Ausloeser an events bzw. club_memberships.
-- Ein Fehler beim Melden darf weder das Anlegen eines Termins noch eine
-- Aufnahme scheitern lassen. Jede bekommt deshalb einen Ausnahmeblock, der
-- warnt und die Zeile unveraendert durchlaesst. Der Block rollt nur seine
-- eigene Arbeit zurueck - bei willkommens_news also auch die Markierung
-- cmo.news_still, die in ihm gesetzt wurde.

-- ------------------------------------------------------------------- Texte
insert into public.meldungstexte (schluessel, sprache, text) values
  ('beitritt.aufgenommenFan.titel', 'de', 'Neu dabei'),
  ('beitritt.aufgenommenFan.titel', 'en', 'New here'),
  ('beitritt.aufgenommenFan.titel', 'es', 'Nuevo por aquí'),
  ('beitritt.aufgenommenFan.titel', 'pt', 'Novo por aqui'),
  ('beitritt.aufgenommenFan.titel', 'it', 'Nuovo arrivo'),
  ('beitritt.aufgenommenFan.titel', 'tr', 'Yeni katılım'),
  ('beitritt.aufgenommenFan.titel', 'fr', 'Nouvelle arrivée'),
  ('beitritt.aufgenommenFan.text', 'de', '{wer} ist jetzt dabei!'),
  ('beitritt.aufgenommenFan.text', 'en', '{wer} is now on board!'),
  ('beitritt.aufgenommenFan.text', 'es', '¡{wer} ya está con nosotros!'),
  ('beitritt.aufgenommenFan.text', 'pt', '{wer} já está connosco!'),
  ('beitritt.aufgenommenFan.text', 'it', '{wer} ora è dei nostri!'),
  ('beitritt.aufgenommenFan.text', 'tr', '{wer} artık aramızda!'),
  ('beitritt.aufgenommenFan.text', 'fr', '{wer} est désormais parmi nous !'),
  ('beitritt.aufgenommenFan.textOhneName', 'de', 'Jemand Neues ist jetzt dabei!'),
  ('beitritt.aufgenommenFan.textOhneName', 'en', 'Someone new is now on board!'),
  ('beitritt.aufgenommenFan.textOhneName', 'es', '¡Alguien nuevo ya está con nosotros!'),
  ('beitritt.aufgenommenFan.textOhneName', 'pt', 'Alguém novo já está connosco!'),
  ('beitritt.aufgenommenFan.textOhneName', 'it', 'Qualcuno di nuovo ora è dei nostri!'),
  ('beitritt.aufgenommenFan.textOhneName', 'tr', 'Aramıza yeni biri katıldı!'),
  ('beitritt.aufgenommenFan.textOhneName', 'fr', 'Une nouvelle personne est désormais parmi nous !')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ----------------------------------------------------------------- Termine
-- Juengste Fassung aus 20260909040000_reihe_absagen, Wort fuer Wort. Neu:
-- die Fan-Bedingung in der Empfaengerauswahl und der Ausnahmeblock am Ende.
CREATE OR REPLACE FUNCTION public.notify_event_audience()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_situation  text;   -- angelegt | abgesagt | geaendert
  v_basis      text;   -- z. B. termin.spiel.abgesagt
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null
  v_grund      text;
begin
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

  /* Ein reiner Ergebniseintrag ist keine Aenderung des Termins - dafuer gibt
     es spielergebnis_melden. Sonst bekaeme der halbe Verein "Das Spiel wurde
     geaendert", sobald jemand 3:2 eintraegt. */
  if tg_op = 'UPDATE'
     and to_jsonb(old) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
       = to_jsonb(new) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
  then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_situation := 'angelegt';
    v_schluessel := case new.type when 'training' then 'training_created'
                                  when 'spiel'    then 'game_created'
                                  else 'events' end;

    /* Eine Serie meldet EINMAL, nicht je Termin.
       create_recurring_events legt alle Termine in einer einzigen
       INSERT-...-SELECT-Anweisung an. Dieser Ausloeser haengt aber an FOR EACH
       ROW - bisher entstand also je Termin und je Empfaenger eine Meldung und
       damit eine Push-Nachricht. In den Daten steht der Beleg: eine Serie mit
       drei Terminen erzeugte neun Meldungen. Die groesste vorhandene Serie hat
       85 Termine.
       Weil alle Zeilen derselben Anweisung dieselbe created_at tragen - now()
       ist innerhalb einer Transaktion konstant -, entscheidet die Kennung den
       Gleichstand. Genau eine Zeile findet keine aeltere vor sich und meldet;
       alle uebrigen steigen hier aus.
       Wird der Serie spaeter ein Termin hinzugefuegt, hat er eine juengere
       created_at und schweigt ebenfalls - richtig so: angekuendigt wurde die
       Serie bereits. */
    if new.series_id is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and (e.created_at, e.id) < (new.created_at, new.id)
      ) then
        return new;
      end if;
      v_situation := 'serie_angelegt';
    end if;
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_situation := 'abgesagt';
    v_schluessel := case new.type when 'training' then 'training_cancelled'
                                  when 'spiel'    then 'game_cancelled'
                                  else 'events' end;

    /* Dieselbe Ueberlegung wie beim Anlegen, nur umgekehrt: Wer eine ganze
       Reihe absagt, soll EINE Nachricht ausloesen, nicht zwanzig.
       Unterschieden wird an cancelled_at. absage_serie setzt alle Termine in
       EINER Anweisung ab, und now() ist innerhalb einer Transaktion konstant -
       alle abgesagten Zeilen der Reihe tragen deshalb denselben Zeitpunkt auf
       die Mikrosekunde. Findet eine Zeile eine Schwester mit GENAU derselben
       cancelled_at und kleinerer Kennung, war es eine Reihenabsage und sie
       schweigt.
       Wird dagegen ein EINZELNER Termin einer Reihe abgesagt, gibt es keine
       solche Schwester - er meldet ganz normal mit "abgesagt". Genau das
       braucht die Auswahl "nur dieser Termin". */
    if new.series_id is not null and new.cancelled_at is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
           and e.id < new.id
      ) then
        return new;
      end if;
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
      ) then
        v_situation := 'serie_abgesagt';
      end if;
    end if;
  elsif tg_op = 'UPDATE' then
    v_situation := 'geaendert';
    v_schluessel := case new.type when 'training' then 'training_changed'
                                  when 'spiel'    then 'game_changed'
                                  else 'events' end;
  else
    return new;
  end if;

  /* Ganze Saetze je Terminart, nicht "Das {art} wurde …" zusammengesetzt:
     Artikel und Geschlecht haengen in den meisten Sprachen am Wort. */
  v_basis := 'termin.' || case new.type when 'training' then 'training'
                                        when 'spiel'    then 'spiel'
                                        else 'event' end
             || '.' || v_situation;

  v_grund := nullif(trim(new.cancel_reason), '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, v_schluessel,
         public.meldungstext(v_basis || '.titel', p.language),
         /* Der Grund steht am ENDE, nicht direkt hinter dem Satz. Vorher las
            sich eine Absage als "Das Spiel wurde abgesagt. Grund: Glatteis
            Herren 1 gegen Herringen · 12.09. · Hemberghalle" - der Grund
            klebte am Spieltitel und man wusste nicht, wo er aufhoert. */
         public.meldungstext(v_basis || '.text', p.language)
           || ' ' || coalesce(new.title, '')
           || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
           || coalesce(' · ' || new.location, '')
           || case when v_situation = 'abgesagt' and v_grund is not null
                   then ' ·' || public.meldungstext('termin.grund', p.language, jsonb_build_object('grund', v_grund))
                   else '' end,
         'termin', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, v_teamart)
    and public.meldung_erlaubt(m.profile_id, v_schluessel)
    /* Fans sehen keine Trainings (12.09.2026) - also auch keine Meldung
       darueber. Ein Fan ist in keiner Mannschaft, konnte einer aber ueber
       team_benachrichtigungen folgen, und vereinsweite Trainings erreichten
       ohnehin jeden. "Nur Fan" heisst: 'fan' und keine andere Rolle. Seit
       20260911110000 laesst die Datenbank neben 'fan' nichts mehr zu; die
       zweite Bedingung haelt trotzdem fest, was gemeint ist. */
    and not (
      new.type = 'training'
      and exists (select 1 from public.membership_roles r
                   where r.membership_id = m.id and r.role = 'fan')
      and not exists (select 1 from public.membership_roles r
                       where r.membership_id = m.id and r.role <> 'fan')
    );

  return new;
exception when others then
  /* Ein Termin ist wichtiger als die Meldung darueber: Er wird angelegt,
     auch wenn das Melden scheitert. Die Warnung steht im Protokoll. */
  raise warning 'Terminmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$;

-- ------------------------------------------------------- Willkommensbeitrag
-- Juengste Fassung aus 20260911060000_aufnahme_nur_leitung, Wort fuer Wort.
-- Neu: Ein Fan bekommt keinen Beitrag, und der Ausnahmeblock am Ende.
create or replace function public.willkommens_news()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  angeschaltet boolean;
begin
  -- Nur beim Übergang auf 'active'. Ein erneutes Speichern derselben Zeile
  -- soll nicht jedes Mal grüßen.
  if new.status <> 'active' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;

  -- Kein oeffentlicher Willkommensbeitrag fuer einen Fan (12.09.2026). Die
  -- Rolle steht schon da: beitritt_entscheiden schreibt sie vor dem Status.
  -- Die Vereinsleitung erfaehrt es trotzdem - ueber aufnahme_leitung_melden.
  if exists (select 1 from public.membership_roles r
              where r.membership_id = new.id and r.role = 'fan') then
    return new;
  end if;

  select coalesce(s.welcome_automation, true) into angeschaltet
    from public.club_settings s where s.club_id = new.club_id;
  if angeschaltet is false then return new; end if;

  -- Still: news_melden überspringt diesen einen Beitrag. Die Markierung gilt
  -- nur in dieser Transaktion und wird gleich danach wieder gelöscht.
  perform set_config('cmo.news_still', 'an', true);
  insert into public.news_posts (club_id, title, body, author_id, author_name)
  values (
    new.club_id,
    'Willkommen im Verein, ' || split_part(trim(new.display_name), ' ', 1) || '!',
    'Schön, dass du da bist. Unter „Termine" findest du Training und Spiele, im Chat erreichst du deine Mannschaft.',
    null,
    'Verein'
  );
  perform set_config('cmo.news_still', '', true);

  return new;
exception when others then
  -- Die Aufnahme ist wichtiger als der Gruss: Sie gilt, auch wenn der
  -- Beitrag nicht entsteht. Die Markierung faellt mit dem Block zurueck.
  raise warning 'Willkommensbeitrag fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$;

-- ------------------------------------------- Aufnahme (Vereinsleitung)
-- Juengste Fassung aus 20260912010000_sprungziele, Wort fuer Wort - Ziel
-- 'mitglied' bleibt. Neu: eigene Texte fuer einen Fan und der Ausnahmeblock.
create or replace function public.aufnahme_leitung_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wer text;
  v_fan boolean;
  v_texte text;
begin
  if new.status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  if new.profile_id is null or new.is_managed_profile then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  /* Ein Fan ist kein "Neues Mitglied". Die Rolle steht schon da:
     beitritt_entscheiden schreibt die Rollen vor dem Status. */
  v_fan := exists (select 1 from public.membership_roles r
                    where r.membership_id = new.id and r.role = 'fan');
  v_texte := case when v_fan then 'beitritt.aufgenommenFan' else 'beitritt.aufgenommen' end;

  /* 'mitglied' statt 'beitritt': Die Aufnahme ist erledigt, bei den offenen
     Antraegen steht sie nicht mehr. Die Leitung will das neue Mitglied sehen. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldungstext(v_texte || '.titel', p.language),
         case when v_wer is null
              then public.meldungstext(v_texte || '.textOhneName', p.language)
              else public.meldungstext(v_texte || '.text', p.language, jsonb_build_object('wer', v_wer)) end,
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
exception when others then
  -- Die Aufnahme gilt, auch wenn die Meldung an die Leitung scheitert.
  raise warning 'Aufnahmemeldung an die Vereinsleitung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$$;

revoke all on function public.aufnahme_leitung_melden() from public, anon, authenticated;

-- ------------------------------------------------------ set_membership_role
-- Seit 20260802063000 fuer authenticated freigegeben, von der App nicht mehr
-- benutzt. anon steht mit dabei: Supabase vergibt EXECUTE auf neue
-- Funktionen im Schema public standardmaessig auch an anon, das damalige
-- "revoke ... from public" hat das nicht erfasst. service_role behaelt sie.
-- set_membership_role gibt es in PROD gar nicht: 20260802063000 wurde am 29.08.
-- per "migration repair" nur als eingespielt vermerkt, die Funktion nie
-- angelegt. Ein unbedingtes REVOKE braeche die ganze Migration ab (42883) -
-- deshalb nur, wenn es sie gibt.
do $$
begin
  if to_regprocedure('public.set_membership_role(uuid, public.club_role, boolean)') is not null then
    execute 'revoke execute on function public.set_membership_role(uuid, public.club_role, boolean) from public, anon, authenticated';
  end if;
end $$;

-- ---------------------------------------------------------------- Nachweis
-- Nur lesend. Erwartet: die ersten fuenf je 1, fan_texte = 21,
-- set_membership_role_authenticated und _anon = false, anzeige_zaehlen_bleibt >= 1.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'notify_event_audience'
      and p.prosrc like '%r.role <> ''fan''%'
      and p.prosrc like '%serie_abgesagt%'
      and p.prosrc like '%exception when others%') as terminmeldung_ohne_fan_trainings,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'willkommens_news'
      and p.prosrc like '%r.role = ''fan''%'
      and p.prosrc like '%cmo.news_still%') as willkommen_ohne_fans,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'aufnahme_leitung_melden'
      and p.prosrc like '%beitritt.aufgenommenFan%'
      and p.prosrc like '%''mitglied''%') as aufnahme_fan_texte_mit_ziel,
  (select count(*) from pg_trigger t
    where t.tgrelid = 'public.club_memberships'::regclass and not t.tgisinternal
      and t.tgfoid = 'public.aufnahme_leitung_melden()'::regprocedure) as aufnahme_ausloeser,
  (select count(*) from pg_trigger t
    where t.tgrelid = 'public.events'::regclass and not t.tgisinternal
      and t.tgfoid = 'public.notify_event_audience()'::regprocedure) as termin_ausloeser,
  (select count(*) from public.meldungstexte
    where schluessel like 'beitritt.aufgenommenFan.%') as fan_texte,
  (case when to_regprocedure('public.set_membership_role(uuid, public.club_role, boolean)') is null then false else has_function_privilege('authenticated',
    'public.set_membership_role(uuid, public.club_role, boolean)', 'EXECUTE') end) as set_membership_role_authenticated,
  (case when to_regprocedure('public.set_membership_role(uuid, public.club_role, boolean)') is null then false else has_function_privilege('anon',
    'public.set_membership_role(uuid, public.club_role, boolean)', 'EXECUTE') end) as set_membership_role_anon,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'anzeige_zaehlen') as anzeige_zaehlen_bleibt;
