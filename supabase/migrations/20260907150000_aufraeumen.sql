-- Aufraeumen: was es gibt, das aber nichts mehr benutzt.
--
-- WARUM DAS NICHT KOSMETIK IST
-- Genau solche Leichen haben die zwei Vokabulare erzeugt, an denen die
-- Benachrichtigungsschalter monatelang wirkungslos waren: Es lagen zwei
-- Saetze Funktionen fuer dieselbe Sache herum, einer lebendig, einer tot, und
-- niemand konnte mehr sagen, welcher welcher war. Wer heute die
-- Meldungsverkabelung liest, stolpert ueber fuenf notify_*-Funktionen, die
-- nach Absendern aussehen und keine sind.
--
-- VOR JEDEM DROP GEPRUEFT
--   * kein Ausloeser, kein cron-Auftrag
--   * kein Aufruf aus einer anderen Datenbankfunktion
--   * kein rpc(...) in app/, lib/, supabase/functions/, worker/
--   * keine Sicht, kein Fremdschluessel von aussen
--   * Tabellen: 0 Zeilen
--
-- WAS AUSDRUECKLICH BLEIBT
--   notify_new_device - haengt aktiv am Ausloeser on_new_session_check_device
--     auf auth.sessions und meldet neue Geraete. Ich hatte sie in meiner
--     eigenen Liste als tot gefuehrt; die Pruefung hat mich korrigiert. Waere
--     sie mitgegangen, waere die Sicherheitsmeldung stillschweigend weg.
--   club_subscriptions (4 Zeilen) und payment_events (4 Zeilen) - die
--     Abrechnung des Vereins bei uns. Klingt aehnlich wie das tote
--     user_subscriptions, ist aber etwas voellig anderes.
--   anzeigen (1 Zeile) - das lebende Sponsoring.

-- --------------------------------- 1. Fuenf Meldungsfunktionen ohne Ausloeser
--
-- Alle fuenf geben trigger zurueck, haengen aber an nichts. Sie wurden von
-- 20260905200000_meldungen_vereinheitlichen.sql abgeloest.
-- notify_new_join_request ist seit heute endgueltig ersetzt: Ihre Aufgabe -
-- die Vereinsleitung ueber eine neue Anfrage zu unterrichten - hat
-- beitrittsanfrage_melden uebernommen, uebersetzt und mit Ziel.
drop function if exists public.notify_event_created();
drop function if exists public.notify_event_updated();
drop function if exists public.notify_news_posted();
drop function if exists public.notify_new_join_request();
drop function if exists public.notify_join_request_decided();

-- ------------------------------------- 2. Rest der alten Push-Kette
--
-- 20260905220000_alten_pushaufruf_entfernen.sql hat den Ausloeser
-- on_notification_queued entfernt, die Funktion aber stehenlassen. Der
-- Versand laeuft heute ueber warteschlange_in_glocke und push_anstossen.
drop function if exists public.trigger_send_push();

-- ------------------------------- 3. Sponsoring: die abgeloeste Tabelle
--
-- Das Sponsoring laeuft seit 20260831150000_sponsoren_und_anzeigen.sql ueber
-- "anzeigen". sponsors und sponsor_placements haben beide 0 Zeilen.
--
-- ACHTUNG, DAS WAERE FAST STILL VERSCHWUNDEN: An sponsors hing der Ausloeser
-- fuer "Ein neuer Sponsor präsentiert sich". Mit der Tabelle waere die
-- Meldung weg gewesen - nur hat sie ohnehin nie ausgeloest, weil seit dem
-- Umbau niemand mehr nach sponsors schreibt. Sie zieht deshalb mit um: nach
-- anzeigen, wo das Sponsoring heute wirklich entsteht.
create or replace function public.anzeige_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_mitglied record;
begin
  if new.aktiv is not true then return new; end if;

  for v_mitglied in
    select m.id from public.club_memberships m
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
  loop
    /* Der Name der Anzeige ist ein Eigenname und bleibt; uebersetzt wird nur
       die Ueberschrift. */
    perform public.notify(v_mitglied.id, 'news'::text,
      public.meldungstext('sponsor.titel', public.sprache_der_mitgliedschaft(v_mitglied.id)),
      coalesce(new.titel, '')::text);
  end loop;
  return new;
end;
$$;

drop trigger if exists anzeigen_melden on public.anzeigen;
create trigger anzeigen_melden after insert on public.anzeigen
  for each row execute function public.anzeige_melden();

drop table if exists public.sponsor_placements cascade;
drop table if exists public.sponsors cascade;
drop function if exists public.sponsor_melden();

-- ------------------------- 4. Toter Abo- und Testzeitraum-Bereich
--
-- Der Testzeitraum ist zum 31.08.2026 ersatzlos entfallen, der In-App-Kauf
-- mit ihm. Es gibt im ganzen Projekt keinen Zahlungs-Webhook mehr - weder zu
-- RevenueCat noch zu PayPal -, der user_subscriptions je wieder fuellen
-- wuerde; die Tabelle hat 0 Zeilen und keinen eingehenden Fremdschluessel.
-- Die acht Funktionen rufen sich nur noch gegenseitig auf.
drop function if exists public.has_active_subscription(uuid);
drop function if exists public.has_active_subscription();
drop function if exists public.member_plan_active(uuid);
drop function if exists public.member_access_info(uuid);
drop function if exists public.member_trial_active(uuid);
drop function if exists public.member_trial_info(uuid);
drop function if exists public.club_trial_info(uuid);
drop function if exists public.club_has_active_subscription(uuid);

/* Falls die Signaturen abweichen: alles wegnehmen, was so heisst. Ein drop
   mit falscher Signatur laeuft sonst ohne Wirkung durch. */
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure::text as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('has_active_subscription','member_plan_active','member_access_info',
                        'member_trial_active','member_trial_info','club_trial_info',
                        'club_has_active_subscription')
  loop
    execute format('drop function if exists %s', r.sig);
  end loop;
end $$;

drop table if exists public.user_subscriptions cascade;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in
      ('notify_event_created','notify_event_updated','notify_news_posted','notify_new_join_request',
       'notify_join_request_decided','trigger_send_push','sponsor_melden','has_active_subscription',
       'member_plan_active','member_access_info','member_trial_active','member_trial_info',
       'club_trial_info','club_has_active_subscription')) as tote_funktionen_uebrig,
  (select count(*) from information_schema.tables where table_schema='public'
    and table_name in ('sponsors','sponsor_placements','user_subscriptions')) as tote_tabellen_uebrig,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname='notify_new_device') as geraetemeldung_noch_da,
  (select count(*) from public.club_subscriptions) as abos_unangetastet,
  (select count(*) from public.payment_events) as zahlungen_unangetastet,
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='anzeigen' and t.tgname='anzeigen_melden') as sponsormeldung_umgezogen;
