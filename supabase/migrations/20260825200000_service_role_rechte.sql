-- Zugriffsrechte des Dienstkontos wiederherstellen
--
-- Der Kalender-Feed antwortete mit PostgreSQL-Code 42501 auf ein einfaches
-- SELECT. Der Grund: service_role hatte auf calendar_subscriptions nur
-- REFERENCES, TRIGGER und TRUNCATE - kein SELECT.
--
-- Das ist nicht der Normalzustand. In einem frischen Supabase-Projekt hat
-- service_role volle Rechte auf alle Tabellen im Schema public; das ist der
-- Sinn dieses Schluessels. Er wird ausschliesslich serverseitig verwendet und
-- umgeht RLS bewusst - fuer Vorgaenge ohne angemeldeten Nutzer, etwa den
-- Kalender-Feed, den ein Geraetekalender anonym abruft.
--
-- Die App selbst war nie betroffen: Sie arbeitet als authenticated, und dort
-- sind die Rechte vorhanden. Deshalb ist es so lange niemandem aufgefallen.
--
-- Dass in 31 Migrationen genau eine einzige Rechtevergabe steht
-- (team_penalty_rules), zeigt: Jemand ist schon einmal in dasselbe Problem
-- gelaufen und hat es an einer Stelle geflickt. Diese Migration behebt die
-- Ursache.

-- 1. Alle bestehenden Tabellen
grant select, insert, update, delete on all tables in schema public to service_role;

-- 2. Sequenzen, sonst schlagen Einfuegungen mit Zaehlern fehl
grant usage, select on all sequences in schema public to service_role;

-- 3. Kuenftige Tabellen erben die Rechte automatisch. Ohne diesen Teil taucht
--    dasselbe Problem bei der naechsten neuen Tabelle wieder auf.
alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges in schema public
  grant usage, select on sequences to service_role;

-- Kontrolle: Tabellen, bei denen service_role weiterhin nicht lesen darf.
-- Erwartet wird eine leere Liste.
select t.tablename
from pg_tables t
where t.schemaname = 'public'
  and not exists (
    select 1 from information_schema.role_table_grants g
    where g.table_schema = 'public'
      and g.table_name = t.tablename
      and g.grantee = 'service_role'
      and g.privilege_type = 'SELECT'
  )
order by t.tablename;
