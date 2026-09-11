-- Helferplanung: Ist ein Mitglied 16 oder aelter? - ohne das Geburtsdatum
-- herauszugeben.
--
-- Heimspiel-Stationen (Theke, Kasse, Grill ...) sind erst ab 16. Die App hat
-- das bisher am Geburtsdatum im Mitgliederdatensatz geprueft. Nur: profiles
-- hat genau eine Lese-Regel, "users read own profile" - die Vereinsleitung
-- sieht das Geburtsdatum der ANDEREN nie. Fuer sie hatten alle ausser ihr
-- selbst "kein Geburtsdatum", und "Helfer einteilen" bot bei Heimspielen nur
-- eine einzige Person an.
--
-- Diese Funktion gibt der Leitung je Mitgliedschaft nur die Antwort:
--   true  = nachweislich 16 oder aelter
--   false = nachweislich juenger ODER ein Profil ohne eigenes Konto
--           (Kinder aus "Familie", Spieler ohne Konto - dort gibt es kein
--           Geburtsdatum, und im Zweifel sind das Kinder)
--   null  = kein Geburtsdatum hinterlegt - die App zeigt "Alter unbekannt",
--           die Leitung entscheidet
-- Aufrufen darf sie, wer auch Helfer einteilen darf (dieselben Rollen wie die
-- Regel "leaders manage duties" auf duty_assignments).

create or replace function public.helfer_altersstatus(target_club uuid)
returns table (membership_id uuid, ab16 boolean)
language sql stable security definer set search_path = '' as $$
  select m.id,
         case
           when m.profile_id is null or coalesce(m.is_managed_profile, false) then false
           when p.birthdate is null then null
           else p.birthdate <= (current_date - interval '16 years')::date
         end
    from public.club_memberships m
    left join public.profiles p on p.id = m.profile_id
   where m.club_id = target_club
     and m.status = 'active'
     and public.has_club_role(target_club, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]);
$$;

revoke all on function public.helfer_altersstatus(uuid) from public, anon;
grant execute on function public.helfer_altersstatus(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'helfer_altersstatus') as funktion_da,
  has_function_privilege('anon', 'public.helfer_altersstatus(uuid)', 'EXECUTE') as anon_darf,
  has_function_privilege('authenticated', 'public.helfer_altersstatus(uuid)', 'EXECUTE') as angemeldete_duerfen;
