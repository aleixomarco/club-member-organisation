-- Ziel im Repo: supabase/migrations/20260925140000_fahrzeugbelegung_als_funktion.sql
--
-- Nachtrag zu 20260925120000_fahrzeugbuchung_ohne_namen.sql: Dieselbe Sache,
-- aber im Muster dieses Projekts.
--
-- WAS DARAN FALSCH WAR
-- Die Belegung kam bisher aus der Sicht public.fahrzeugbelegung. Damit sie
-- allen Mitgliedern die fremden Buchungen zeigen konnte, obwohl die neue
-- Zeilenregel auf vehicle_bookings nur noch eigene Buchungen durchlaesst,
-- lief sie ohne security_invoker - also mit den Rechten ihres Eigentuemers
-- und an der Zeilenregel vorbei. Sie pruefte die Vereinszugehoerigkeit selbst
-- und war dadurch dicht; geprueft wurde das am Livestand fuer ein
-- gewoehnliches Mitglied.
--
-- Trotzdem ist es das falsche Mittel: 20260906290000_sichten_umgehen_keine_-
-- regeln_mehr.sql hat genau diese Bauart fuer beide damals vorhandenen
-- Sichten abgestellt ("Sichten duerfen die Zeilenregeln nicht mehr umgehen")
-- und ihnen security_invoker = on gegeben. Eine neue Sicht ohne
-- security_invoker nimmt diese Entscheidung zurueck, und der Supabase-Pruefer
-- meldet sie als "security definer view". Wer die Sichten das naechste Mal
-- durchgeht, muesste sich die Begruendung erneut erarbeiten.
--
-- WAS STATTDESSEN
-- Dasselbe Muster wie kontaktdaten_im_verein (rollen-03) und saisonwahl_stand
-- (U5): eine SECURITY-DEFINER-Funktion, die je nach Rolle mehr oder weniger
-- herausgibt. Die App ruft sie wie die anderen mit supabase.rpc auf.
--
-- Unveraendert bleiben aus 20260925120000: die enge Leseregel
-- "eigene buchung oder leitung liest" auf vehicle_bookings und die
-- eingeschraenkte get_booking_contact_phone. Nur der Lesweg fuer die
-- Belegung wechselt von der Sicht zur Funktion.
--
-- IN ZWEI SCHRITTEN, wie 20260914110800_nach_dem_deploy.sql: Die gerade live
-- laufende App liest noch die Sicht. Diese Migration legt deshalb nur die
-- Funktion an und laesst die Sicht stehen; weg raeumt sie
-- 20260925150000_sicht_fahrzeugbelegung_weg.sql, sobald die neue App live
-- ist. So sieht niemand zwischendurch "Die Buchungen konnten nicht geladen
-- werden".

-- Die Belegung eines Vereins in einem Zeitraum. Fahrzeug, Mannschaft,
-- Zeitraum und Status fuer jedes Mitglied; Name, persoenlicher Freitext und
-- membership_id nur fuer die Vereinsleitung (can_manage_fleet) und fuer die
-- buchende Person selbst. darf_namen_sehen sagt der App, welcher Fall vorliegt,
-- damit sie den Namensblock gar nicht erst aufbaut.
create or replace function public.fahrzeugbelegung_im_zeitraum(
  target_club uuid, von timestamptz, bis timestamptz)
returns table (id uuid, vehicle_id uuid, fahrzeug text, team_id uuid, mannschaft text,
               membership_id uuid, private_label text, gebucht_von text,
               darf_namen_sehen boolean, starts_at timestamptz, ends_at timestamptz,
               status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select vb.id,
         vb.vehicle_id,
         v.label,
         vb.team_id,
         t.name,
         case when darf.ja then vb.membership_id end,
         case when darf.ja then vb.private_label end,
         case when darf.ja then m.display_name end,
         darf.ja,
         vb.starts_at,
         vb.ends_at,
         vb.status,
         vb.created_at
    from public.vehicle_bookings vb
    join public.club_vehicles v on v.id = vb.vehicle_id
    left join public.teams t on t.id = vb.team_id
    left join public.club_memberships m on m.id = vb.membership_id
    cross join lateral (
      select public.can_manage_fleet(vb.club_id)
             or exists (select 1 from public.club_memberships eigen
                         where eigen.id = vb.membership_id
                           and eigen.profile_id = (select auth.uid())) as ja
    ) darf
   where vb.club_id = target_club
     and public.is_club_member(target_club)
     and vb.starts_at < bis
     and vb.ends_at > von
   order by vb.starts_at;
$$;

revoke all on function public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz) to authenticated, service_role;

comment on function public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz) is
  'Belegung der Vereinsfahrzeuge in einem Zeitraum. Fahrzeug, Mannschaft, Zeitraum und Status fuer jedes Mitglied des Vereins; Name, Freitext und membership_id nur fuer Vereinsleitung (can_manage_fleet) und buchende Person.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
select (select count(*) from pg_views
         where schemaname = 'public' and viewname = 'fahrzeugbelegung')     as sicht_noch_da,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'fahrzeugbelegung_im_zeitraum') as funktion_da,
       (select has_function_privilege('authenticated',
                 'public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz)'::regprocedure, 'EXECUTE')) as authenticated_darf,
       (select has_function_privilege('anon',
                 'public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz)'::regprocedure, 'EXECUTE')) as anon_darf_nicht,
       (select string_agg(policyname, ' | ') from pg_policies
         where schemaname = 'public' and tablename = 'vehicle_bookings' and cmd = 'SELECT') as leseregel,
       (select count(*) from pg_class c
         where c.relkind = 'v' and c.relnamespace = 'public'::regnamespace
           and coalesce(c.reloptions::text, '') not like '%security_invoker=on%')            as sichten_ohne_invoker;
