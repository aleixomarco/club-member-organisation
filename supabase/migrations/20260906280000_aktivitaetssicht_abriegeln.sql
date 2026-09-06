-- Die Aktivitaetssicht gehoert dem Betreiber, sonst niemandem.
--
-- WAS PASSIERT WAERE
-- Im Schema public stehen Standardrechte: Wer dort eine Sicht anlegt,
-- schenkt authenticated automatisch das Leserecht. Genau das ist bei
-- vereins_aktivitaet passiert - die Sicht war eine Minute alt und schon
-- fuer jedes angemeldete Mitglied lesbar.
--
-- Das ist schlimmer als es klingt. Eine Sicht laeuft standardmaessig mit
-- den Rechten ihres Eigentuemers, nicht mit denen des Lesers. Die
-- Zeilenregeln auf messages, events und event_attendance greifen dabei
-- NICHT. Ein Mitglied aus Verein A haette also gesehen, wer in Verein B
-- wann eine Nachricht geschrieben oder zu einem Termin zugesagt hat.
--
-- ZWEI RIEGEL STATT EINEM
-- 1. Das Leserecht wird entzogen - anon und authenticated kommen nicht mehr
--    heran, und kuenftige Sichten in diesem Schema bekommen es erst gar
--    nicht mehr geschenkt.
-- 2. security_invoker wird eingeschaltet. Sollte jemand das Leserecht
--    spaeter versehentlich wieder vergeben, laeuft die Sicht dann mit den
--    Rechten des Lesers - und die Zeilenregeln der Tabellen greifen doch.
--    Ein zweites Schloss an derselben Tuer, weil das erste von einer
--    Voreinstellung aufgesperrt wurde.
--
-- Der Betreiber liest ueber service_role und ist davon nicht betroffen.

revoke all on public.vereins_aktivitaet from anon, authenticated;
alter view public.vereins_aktivitaet set (security_invoker = on);

/* Und die Voreinstellung selbst, damit die naechste Sicht nicht wieder
   offen steht. Betrifft nur, was postgres kuenftig anlegt. */
alter default privileges for role postgres in schema public
  revoke select on tables from anon, authenticated;

select
  (select count(*) from information_schema.role_table_grants
    where table_schema='public' and table_name='vereins_aktivitaet'
      and grantee in ('anon','authenticated') and privilege_type='SELECT') as darf_lesen,
  (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='vereins_aktivitaet'
      and c.reloptions::text like '%security_invoker=on%') as invoker_an;
