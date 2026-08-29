-- Welchen Tabellen fehlen die Zugriffsrechte?
--
-- Hintergrund: Der Kalender-Feed antwortete mit PostgreSQL-Code 42501
-- (insufficient_privilege) auf ein einfaches SELECT. In allen Migrationen gibt
-- es genau eine Rechtevergabe auf eine Tabelle - team_penalty_rules - und
-- keine Zeile, die Standardrechte setzt. Jemand ist also schon einmal in
-- dasselbe Problem gelaufen und hat es an einer Stelle geflickt.
--
-- Diese Abfrage zeigt, wo es sonst noch fehlt. In PROD ausführen, ändert nichts.

select
  t.tablename                                                   as tabelle,
  bool_or(g.grantee = 'authenticated' and g.privilege_type = 'SELECT')  as auth_lesen,
  bool_or(g.grantee = 'authenticated' and g.privilege_type = 'INSERT')  as auth_schreiben,
  bool_or(g.grantee = 'service_role'  and g.privilege_type = 'SELECT')  as dienst_lesen,
  case
    when not bool_or(g.grantee = 'service_role' and g.privilege_type = 'SELECT')
      then 'SERVER KOMMT NICHT DRAN'
    when not bool_or(g.grantee = 'authenticated' and g.privilege_type = 'SELECT')
      then 'APP KOMMT NICHT DRAN'
    else ''
  end                                                           as befund
from pg_tables t
left join information_schema.role_table_grants g
  on g.table_schema = t.schemaname
 and g.table_name = t.tablename
 and g.grantee in ('authenticated', 'service_role')
where t.schemaname = 'public'
group by t.tablename
order by befund desc, t.tablename;
