-- Sichten duerfen die Zeilenregeln nicht mehr umgehen.
--
-- DER FUND
-- Beim Abriegeln der neuen Aktivitaetssicht habe ich alle Sichten im Schema
-- durchgesehen. team_penalty_totals hat dasselbe Problem, und zwar laenger:
--
--   SELECT team_id, membership_id, display_name, count(*), sum(amount)
--   FROM team_penalty_assignments JOIN team_penalty_rules JOIN club_memberships
--
-- Die Sicht ist fuer jedes angemeldete Konto lesbar. Eine Sicht laeuft
-- standardmaessig mit den Rechten ihres EIGENTUEMERS - die Regeln auf
-- team_penalty_assignments, team_penalty_rules und club_memberships greifen
-- dabei nicht. Ein Mitglied aus Verein A konnte also lesen, wer in Verein B
-- wie viele Strafen hat und wie viel Geld offen ist. Mit Klarnamen.
--
-- Die App benutzt die Sicht nirgends - weder in app/ noch in lib/ kommt sie
-- vor. Aufgefallen waere es also niemandem.
--
-- DIE BEHEBUNG
-- security_invoker = on. Danach laeuft die Sicht mit den Rechten dessen, der
-- sie liest, und die vorhandenen Regeln ("adult team participants read
-- penalty assignments") entscheiden wieder. Das Leserecht bleibt bestehen:
-- Wer die Sicht kuenftig benutzt, bekommt genau die Zeilen, die er auch
-- direkt aus den Tabellen lesen duerfte.

alter view public.team_penalty_totals set (security_invoker = on);

-- ZURUECKGENOMMEN: die geaenderte Voreinstellung.
--
-- In der Migration davor hatte ich zusaetzlich das Standard-Leserecht im
-- Schema entzogen, damit die naechste Sicht nicht wieder offen steht. Das
-- war zu grob. Die Voreinstellung gilt fuer TABELLEN genauso, und Supabase
-- baut darauf auf: Eine neue Tabelle bekommt das Leserecht automatisch, die
-- Zeilenregeln entscheiden dann, wer welche Zeile sieht.
--
-- Ohne dieses Recht laeuft jede kuenftige Migration in "permission denied",
-- obwohl die Regeln richtig aussehen - und wer den Fehler sucht, sucht ihn
-- in den Regeln, nicht in einer Voreinstellung, die vor Monaten geaendert
-- wurde. Das Problem waren nie die Tabellen, sondern die Sichten. Fuer die
-- gibt es security_invoker, und beide betroffenen Sichten haben es jetzt.
alter default privileges for role postgres in schema public
  grant select on tables to anon, authenticated;

select c.relname as sicht,
       (c.reloptions::text like '%security_invoker=on%') as laeuft_mit_leserechten,
       has_table_privilege('authenticated', c.oid, 'SELECT') as auth_darf_lesen
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
order by 1;
