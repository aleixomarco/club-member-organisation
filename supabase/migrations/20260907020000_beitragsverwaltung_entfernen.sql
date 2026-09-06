-- Die Beitragsverwaltung wird entfernt.
--
-- WARUM SIE GEHT
-- Sie stand seit Wochen auf BEITRAGSVERWALTUNG_SICHTBAR = false, war also
-- fuer keinen Verein sichtbar. Was niemand sieht, pflegt auch niemand: Der
-- Code lag als toter Ballast in der App, die Tabellen als leere Huellen in
-- der Datenbank, und beides musste bei jeder Aenderung mitbedacht werden.
--
-- WAS VERLOREN GEHT: NICHTS
-- Vor dem Loeschen nachgezaehlt:
--   fee_records    0 Zeilen
--   fee_people     0 Zeilen
--   fee_reminders  0 Zeilen
-- Kein Verein hat je einen Beitrag darueber erfasst.
--
-- WAS BLEIBT: payment_events
-- Die Tabelle klingt aehnlich, meint aber etwas voellig anderes - die
-- Zahlungsmeldungen des Anbieters fuer das ABO DES VEREINS bei uns. Sie
-- haengt an club_subscriptions, hat vier Zeilen und wird gebraucht. Wer sie
-- mit den Mitgliedsbeitraegen verwechselt, loescht die Abrechnung.

/* Der woechentliche Auftrag fuer Zahlungserinnerungen. Zuerst weg, sonst
   ruft er montags eine Funktion, die es nicht mehr gibt. */
select cron.unschedule('fee-reminders')
 where exists (select 1 from cron.job where jobname = 'fee-reminders');

drop function if exists public.run_fee_reminders();
drop function if exists public.save_fee_record(uuid, uuid, text, text, numeric, text, text, integer, uuid[], text[]);
drop function if exists public.delete_fee_record(uuid);
drop function if exists public.set_fee_payment_status(uuid, text);

/* Falls die Signaturen abweichen: alles wegnehmen, was so heisst. Ein
   drop mit falscher Signatur laeuft sonst ohne Wirkung durch, und die
   Funktion bleibt stehen, obwohl ihre Tabelle verschwindet. */
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure::text as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('run_fee_reminders','save_fee_record','delete_fee_record','set_fee_payment_status')
  loop
    execute format('drop function if exists %s', r.sig);
  end loop;
end $$;

/* fee_people zeigt auf fee_records - Reihenfolge oder cascade, sonst
   verweigert Postgres. */
drop table if exists public.fee_people cascade;
drop table if exists public.fee_reminders cascade;
drop table if exists public.fee_records cascade;

select
  (select count(*) from information_schema.tables
    where table_schema='public' and table_name in ('fee_records','fee_people','fee_reminders')) as tabellen_uebrig,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('run_fee_reminders','save_fee_record','delete_fee_record','set_fee_payment_status')) as funktionen_uebrig,
  (select count(*) from cron.job where jobname='fee-reminders') as auftrag_uebrig,
  (select count(*) from public.payment_events) as payment_events_unangetastet;
