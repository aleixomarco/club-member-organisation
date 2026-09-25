-- Ziel im Repo: supabase/migrations/20260925160000_fans_ohne_fuhrpark.sql
--
-- Fans sehen den Fuhrpark nicht mehr - weder die Fahrzeuge noch die Belegung,
-- und buchen koennen sie auch nicht.
--
-- Warum: Ein reiner Fan folgt dem Verein, mehr nicht. Bei Aufgaben und
-- Helferdiensten ist er deshalb schon ausgesperrt (20260914110100, Kacheln in
-- app/page.tsx), beim Fuhrpark war er es als einziger Stelle nicht: Er sah
-- jedes Fahrzeug und jede Buchung. Seit 20260925120000 immerhin ohne Namen -
-- aber auch die Belegung selbst geht ihn nichts an.
--
-- Dieselbe Pruefung wie ueberall sonst: public.ist_nur_fan(target_club)
-- (20260914110100) - Rolle 'fan' und keine andere ausser 'mitglied'. Wer
-- zusaetzlich Athlet, Trainer, Helfer oder Vorstand ist, ist kein Fan im
-- Sinne dieser Regel und behaelt den Fuhrpark.
--
-- Geprueft am 25.09.2026 (nur lesend, PROD): Keine der beiden vorhandenen
-- Buchungen gehoert einem reinen Fan - es verliert also niemand den Zugriff
-- auf eine eigene Buchung.

-- ------------------------------------------------------------ Fahrzeuge
-- Bisher: "club members read vehicles" SELECT to public
--   using (exists (club_memberships m where m.club_id = club_vehicles.club_id
--                  and m.profile_id = auth.uid() and m.status = 'active'))
drop policy if exists "club members read vehicles" on public.club_vehicles;
drop policy if exists "members read vehicles" on public.club_vehicles;

create policy "mitglieder ohne fans lesen fahrzeuge" on public.club_vehicles
  for select to authenticated
  using (public.is_club_member(club_id) and not public.ist_nur_fan(club_id));

-- ------------------------------------------------------------- Buchungen
-- Bisher (20260925120000): can_manage_fleet(club_id) oder eigene Buchung.
drop policy if exists "eigene buchung oder leitung liest" on public.vehicle_bookings;

create policy "eigene buchung oder leitung liest" on public.vehicle_bookings
  for select to authenticated
  using (
    not public.ist_nur_fan(club_id)
    and (
      public.can_manage_fleet(club_id)
      or exists (
        select 1 from public.club_memberships m
         where m.id = vehicle_bookings.membership_id
           and m.profile_id = (select auth.uid())
           and m.club_id = vehicle_bookings.club_id))
  );

-- Anlegen: bisher jedes aktive Mitglied des Vereins, Fans eingeschlossen.
-- Die uebrigen Bedingungen (Fahrzeug und Mannschaft gehoeren zum Verein,
-- membership_id ist die eigene) bleiben Wort fuer Wort wie in
-- 20260914110000_verein_als_blase.sql.
drop policy if exists "members request bookings" on public.vehicle_bookings;

create policy "members request bookings" on public.vehicle_bookings
  for insert to authenticated
  with check (
    not public.ist_nur_fan(vehicle_bookings.club_id)
    and exists (select 1 from public.club_memberships m
                 where m.id = vehicle_bookings.membership_id
                   and m.profile_id = (select auth.uid())
                   and m.club_id = vehicle_bookings.club_id
                   and m.status = 'active')
    and exists (select 1 from public.club_vehicles v
                 where v.id = vehicle_bookings.vehicle_id and v.club_id = vehicle_bookings.club_id)
    and (vehicle_bookings.team_id is null
         or exists (select 1 from public.teams t
                     where t.id = vehicle_bookings.team_id and t.club_id = vehicle_bookings.club_id)));

-- -------------------------------------------------------------- Belegung
-- Dieselbe Grenze in der Funktion, die die Belegung ausgibt: Fuer einen
-- reinen Fan bleibt die Liste leer, ohne Fehlermeldung - wie bei einem
-- Verein, der den Fuhrpark gar nicht eingeschaltet hat.
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
     and not public.ist_nur_fan(target_club)
     and vb.starts_at < bis
     and vb.ends_at > von
   order by vb.starts_at;
$$;

-- Telefonnummern: derselbe Riegel, damit die Regel ueberall gleich lautet.
create or replace function public.get_booking_contact_phone(target_booking uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  select p.contact_phones
    from public.vehicle_bookings vb
    join public.club_memberships m on m.id = vb.membership_id
    join public.profiles p on p.id = m.profile_id
   where vb.id = target_booking
     and not public.ist_nur_fan(vb.club_id)
     and (public.can_manage_fleet(vb.club_id) or m.profile_id = auth.uid());
$$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
select (select string_agg(policyname, ' | ' order by policyname) from pg_policies
         where schemaname='public' and tablename='club_vehicles' and cmd='SELECT')      as fahrzeuge_leseregel,
       (select string_agg(policyname, ' | ' order by policyname) from pg_policies
         where schemaname='public' and tablename='vehicle_bookings' and cmd='SELECT')   as buchungen_leseregel,
       (select position('ist_nur_fan' in coalesce(qual, '')) > 0 from pg_policies
         where schemaname='public' and tablename='club_vehicles' and cmd='SELECT')      as fahrzeuge_mit_fanriegel,
       (select position('ist_nur_fan' in coalesce(with_check, '')) > 0 from pg_policies
         where schemaname='public' and tablename='vehicle_bookings' and cmd='INSERT')   as anlegen_mit_fanriegel,
       (select position('ist_nur_fan' in pg_get_functiondef(
                 'public.fahrzeugbelegung_im_zeitraum(uuid, timestamptz, timestamptz)'::regprocedure)) > 0) as belegung_mit_fanriegel,
       (select position('ist_nur_fan' in pg_get_functiondef(
                 'public.get_booking_contact_phone(uuid)'::regprocedure)) > 0)          as telefon_mit_fanriegel;
