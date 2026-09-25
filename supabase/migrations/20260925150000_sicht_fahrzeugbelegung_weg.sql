-- Ziel im Repo: supabase/migrations/20260925150000_sicht_fahrzeugbelegung_weg.sql
--
-- Zweiter Schritt zu 20260925140000_fahrzeugbelegung_als_funktion.sql.
--
-- Die Sicht public.fahrzeugbelegung war der erste Anlauf und lief ohne
-- security_invoker an den Zeilenregeln vorbei - genau die Bauart, die
-- 20260906290000_sichten_umgehen_keine_regeln_mehr.sql abgeschafft hat. Ihren
-- Platz hat die Funktion fahrzeugbelegung_im_zeitraum eingenommen.
--
-- Eingespielt wird das erst, wenn die App live ist, die die Funktion ruft -
-- vorher wuerde der Fuhrparkkalender "Die Buchungen konnten nicht geladen
-- werden" melden. Dieselbe Reihenfolge wie bei
-- 20260914110800_nach_dem_deploy.sql.
--
-- Die Sicht hat nie einen anderen Lesweg geoeffnet als die Funktion heute:
-- Vereinszugehoerigkeit wurde in ihr selbst geprueft, Name, Freitext und
-- membership_id waren fuer alle ausser Leitung und Urheber maskiert.

drop view if exists public.fahrzeugbelegung;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
select (select count(*) from pg_views
         where schemaname = 'public' and viewname = 'fahrzeugbelegung')      as sicht_weg_soll_0,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'fahrzeugbelegung_im_zeitraum') as funktion_da,
       (select count(*) from pg_class c
         where c.relkind = 'v' and c.relnamespace = 'public'::regnamespace
           and coalesce(c.reloptions::text, '') not like '%security_invoker=on%')   as sichten_ohne_invoker_soll_0,
       (select string_agg(policyname, ' | ') from pg_policies
         where schemaname = 'public' and tablename = 'vehicle_bookings' and cmd = 'SELECT') as leseregel;
