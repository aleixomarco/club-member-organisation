-- Die Datenbank ruft den Versender selbst.
--
-- WAS HIER FEHLTE
-- Der Versender (Edge Function push-versenden) steht seit heute, aber niemand
-- ruft ihn. Eine Zeile in user_notifications fuellt die Glocke in der App -
-- und bleibt sonst liegen.
--
-- WARUM NICHT UEBER DAS DASHBOARD
-- Supabase kann so einen Webhook in der Oberflaeche anlegen. Dabei traegt man
-- den Dienstschluessel als Kopfzeile ein. Das haette bedeutet: Der Schluessel
-- muss durch Menschenhaende, und der ganze Aufbau steht nirgends im Projekt -
-- wer die Datenbank aus diesen Dateien neu aufbaut, bekommt eine stumme App
-- und merkt es nicht.
--
-- Deshalb hier, in einer Migration. Und mit einem Geheimnis, das die Datenbank
-- SELBST erzeugt: Es steht in keiner Datei, in keinem Protokoll und in keinem
-- Chatverlauf. Der Versender holt es sich ueber eine Funktion ab, die nur der
-- Dienstschluessel ausfuehren darf, und vergleicht es mit dem, was in der
-- Kopfzeile ankommt. Beide Seiten kennen es, niemand sonst.

create extension if not exists pg_net;

/* Ein eigenes Schema, das ausdruecklich niemandem gehoert ausser dem
   Dienstschluessel. "private" ist in Postgres kein Schluesselwort, aber
   "intern" liest sich fuer die naechste Person eindeutiger. */
create schema if not exists intern;
revoke all on schema intern from public, anon, authenticated;

create table if not exists intern.push_zustellung (
  -- Genau eine Zeile: Der Primaerschluessel kann nur "true" sein.
  id         boolean primary key default true check (id),
  geheimnis  text    not null default encode(extensions.gen_random_bytes(32), 'hex'),
  ziel_url   text    not null,
  aktiv      boolean not null default true,
  angelegt   timestamptz not null default now()
);
revoke all on table intern.push_zustellung from public, anon, authenticated;

insert into intern.push_zustellung (id, ziel_url)
values (true, 'https://kymokcqebfruhlvcyqnw.supabase.co/functions/v1/push-versenden')
on conflict (id) do update set ziel_url = excluded.ziel_url;

/* Der Versender braucht das Geheimnis, kommt aber nicht an das Schema intern -
   PostgREST sieht nur public. Diese Funktion ist die einzige Tuer, und sie
   steht nur dem Dienstschluessel offen. */
create or replace function public.push_geheimnis()
returns text language sql security definer set search_path = '' as $$
  select geheimnis from intern.push_zustellung where id;
$$;
revoke all on function public.push_geheimnis() from public, anon, authenticated;
grant execute on function public.push_geheimnis() to service_role;

/* --------------------------------------------------------------------------
   Der Ausloeser.

   net.http_post arbeitet asynchron: Es legt die Anfrage in eine Warteschlange
   und kehrt sofort zurueck. Das Anlegen eines Termins wartet also nicht darauf,
   dass Apple die Mitteilung entgegennimmt.

   Der ganze Aufruf steckt trotzdem in einem exception-Block. Faellt der
   Versand aus - Netz weg, Funktion nicht erreichbar, Erweiterung fehlt -, darf
   das NIEMALS das Schreiben der Benachrichtigung verhindern. Die Glocke in der
   App muss auch dann funktionieren, wenn Push gerade nicht geht. Ein
   Trigger, der eine Ausnahme durchreicht, wuerde die ganze Einfuegung
   zuruecknehmen und damit den Termin gleich mit.
   -------------------------------------------------------------------------- */

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
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- Bewusst verschluckt, aber nicht verschwiegen: Die Meldung steht im
  -- Postgres-Protokoll, die Benachrichtigung selbst bleibt erhalten.
  raise warning 'Push konnte nicht angestossen werden: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists user_notifications_push on public.user_notifications;
create trigger user_notifications_push
after insert on public.user_notifications
for each row execute function public.push_anstossen();

-- Kontrolle: Erweiterung, Ausloeser und Tuer muessen stehen.
select
  (select count(*) from pg_extension where extname = 'pg_net')                     as pg_net,
  (select count(*) from pg_trigger where tgname = 'user_notifications_push')       as ausloeser,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'push_geheimnis')                   as tuer,
  (select length(geheimnis) from intern.push_zustellung where id)                   as geheimnis_laenge;
