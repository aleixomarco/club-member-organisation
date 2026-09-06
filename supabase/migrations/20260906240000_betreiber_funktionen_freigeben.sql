-- Die Betreiber-Konsole durfte ihre eigenen Funktionen nicht aufrufen.
--
-- "Die Vereinsansicht konnte nicht geladen werden." - dahinter stand
-- permission denied for function mitglieder_eines_vereins (SQLSTATE 42501).
--
-- Die drei Funktionen hatten NUR das Recht fuer postgres:
--   proacl = postgres=X/postgres
-- Die Konsole arbeitet aber ueber die API mit der Rolle service_role. Ihr
-- fehlte das Ausfuehrungsrecht - seit dem Tag, an dem die Funktionen angelegt
-- wurden. Die Ansicht war also nie benutzbar; aufgefallen ist es erst jetzt,
-- weil bis vor Kurzem niemand einen Verein in der Konsole geoeffnet hat.
--
-- Bewusst NUR service_role, nicht authenticated: Diese Funktionen liefern alle
-- Mitglieder eines Vereins samt Kontaktdaten. Das gehoert dem Betreiber der
-- Plattform, nicht jedem angemeldeten Nutzer. Der Weg dorthin fuehrt
-- ausschliesslich ueber die Konsole, und die prueft ihre eigene Anmeldung.

grant execute on function public.mitglieder_eines_vereins(uuid) to service_role;
grant execute on function public.zielgruppe_eines_vereins(uuid) to service_role;
grant execute on function public.sponsoren_eines_vereins(uuid)  to service_role;

select p.proname, array_to_string(p.proacl, ' | ') as rechte
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('mitglieder_eines_vereins','zielgruppe_eines_vereins','sponsoren_eines_vereins');
