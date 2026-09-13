-- Der Ausloeser wartet 30 statt 5 Sekunden auf den Versender.
--
-- WAS PASSIERT IST
-- Am 13.09.2026 um 11:15:00 UTC schrieb die Ergebnis-Erinnerung sechs Zeilen
-- in user_notifications. pg_net schickte die sechs Aufrufe gleichzeitig los
-- (ein Stapel, eine gemeinsame created-Zeit). Einer kam mit
-- {"zugestellt":1} zurueck, fuenf brachen nach 5000 ms ab: timed_out, kein
-- Status, kein Inhalt.
--
-- WARUM 5 SEKUNDEN ZU KNAPP SIND
-- Der Versender lief vorher 39 Stunden nicht; alle sechs Aufrufe starteten
-- kalt, jeder mit eigenem Geheimnis-Abruf und eigenem Google-Tausch. Das
-- dauert unter Gleichzeitigkeit laenger als 5 Sekunden - selbst der Aufruf
-- ohne Geraet, der Firebase gar nicht anfasst, lief ueber die Grenze.
-- timeout_milliseconds ist in pg_net die GESAMTZEIT eines Aufrufs
-- (CURLOPT_TIMEOUT_MS), nicht nur der Verbindungsaufbau.
--
-- WAS DER ABBRUCH BEDEUTET
-- Die Edge Runtime bricht den Versender nicht ab, wenn pg_net auflegt - sie
-- wartet auf seine Antwort und wirft sie dann weg (supabase/edge-runtime,
-- server.rs). Die Mitteilung geht also sehr wahrscheinlich trotzdem raus.
-- Verloren ist die Antwort: In net._http_response steht dann nur
-- "timed_out" statt "zugestellt: 1" oder des Ablehnungsgrunds - genau der
-- Kanal, aus dem wir den Versand ueberwachen.
--
-- WARUM 30 SEKUNDEN
-- Die Aufrufe eines Stapels laufen in pg_net parallel; ein langsamer haelt
-- die anderen desselben Stapels nicht auf. Er haelt nur den NAECHSTEN Stapel
-- zurueck, bis er fertig ist (Arbeiter wartet auf alle Aufrufe, dann 1 s
-- Pause). Schlimmstenfalls kommt eine spaetere Mitteilung also 31 Sekunden
-- spaeter an. Der Versender selbst darf 150 Sekunden laufen; 30 lassen einem
-- kalten Start reichlich Luft und melden trotzdem, wenn wirklich etwas haengt.
--
-- Sonst bleibt alles wie in 20260905130000_push_zustellung.sql: security
-- definer, leerer search_path, und der exception-Block, der die Glocke auch
-- dann schreibt, wenn Push gerade nicht geht. "create or replace" behaelt
-- die bestehenden Rechte und den Ausloeser.

create or replace function public.push_anstossen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_zeile intern.push_zustellung%rowtype;
begin
  select * into v_zeile from intern.push_zustellung where id;
  if not found or not v_zeile.aktiv then return new; end if;

  perform net.http_post(
    url := v_zeile.ziel_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cmo-signatur', v_zeile.geheimnis
    ),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'user_notifications',
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 30000
  );
  return new;
exception when others then
  -- Bewusst verschluckt, aber nicht verschwiegen: Die Meldung steht im
  -- Postgres-Protokoll, die Benachrichtigung selbst bleibt erhalten.
  raise warning 'Push konnte nicht angestossen werden: %', sqlerrm;
  return new;
end;
$$;

-- Kontrolle: Der Ausloeser steht noch und die Funktion traegt das neue Limit.
select
  (select count(*) from pg_trigger where tgname = 'user_notifications_push')  as ausloeser,
  (select pg_get_functiondef('public.push_anstossen()'::regprocedure)
     like '%timeout_milliseconds := 30000%')                                   as neues_limit;
