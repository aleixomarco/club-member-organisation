-- Ziel im Repo: supabase/migrations/20260925120000_fahrzeugbuchung_ohne_namen.sql
--
-- Wer ein Vereinsfahrzeug gebucht hat, ist ab hier eine Angabe fuer die
-- Vereinsleitung (can_manage_fleet: vereinsadmin, sysadmin, organisator) und
-- fuer die buchende Person selbst. Alle anderen Mitglieder sehen weiterhin,
-- DASS und WANN ein Fahrzeug belegt ist - ohne Namen, ohne persoenlichen
-- Freitext, ohne Telefonnummer.
--
-- Warum ueberhaupt: heute erlaubt die Regel "club members read bookings" jedem
-- aktiven Mitglied das Lesen aller Buchungen des Vereins samt membership_id;
-- die App holt dazu display_name der buchenden Person ueber den
-- Fremdschluessel mit. Der Name steht damit im Browser jedes Mitglieds -
-- unabhaengig davon, was die Oberflaeche anzeigt. Ein blosses Ausblenden in
-- der Anzeige waere Kosmetik: ueber die REST-Schnittstelle bleibt jede
-- Buchung mitsamt Person abrufbar, und die Komponente <Erstellt> loest die
-- membership_id ohnehin aus dem lokalen Mitgliederverzeichnis auf.
--
-- Schwerer als der Name wiegt get_booking_contact_phone: Diese SECURITY-
-- DEFINER-Funktion gibt zu einer beliebigen Buchungs-ID die Telefonnummern
-- der buchenden Person heraus und prueft dabei nur, ob der Aufrufer
-- irgendein aktives Mitglied desselben Vereins ist. profiles ist sonst nur
-- fuer die eigene Person lesbar; das ist die einzige Ausnahme.
--
-- Drei Teile:
--   1. Die Tabelle liest nur noch, wer die Buchung selbst angelegt hat, und
--      die Vereinsleitung.
--   2. Die neue View public.fahrzeugbelegung zeigt allen Mitgliedern die
--      Belegung - Fahrzeug, Mannschaft, Zeitraum, Status - und gibt Name,
--      Freitext und membership_id nur an Leitung und Urheber heraus.
--   3. get_booking_contact_phone gibt die Nummern nur noch an Leitung und
--      Urheber.
--
-- Der Mannschaftsname bleibt fuer alle sichtbar: Er benennt keine Person,
-- sondern den Zweck der Fahrt, und ohne ihn liesse sich im Verein nicht mehr
-- planen. Der persoenliche Freitext (private_label) verschwindet dagegen -
-- in ihm steht regelmaessig ein Name, das Eingabefeld fragt ausdruecklich
-- danach.
--
-- Die Schreibwege bleiben unberuehrt: "members request bookings" (INSERT),
-- "owner or fleet admin updates booking" (UPDATE) und "owner or fleet admin
-- deletes booking" (DELETE) haengen nicht an der Leseregel. Die
-- Ueberschneidungssperre ist der Ausschluss-Constraint
-- vehicle_bookings_vehicle_id_tstzrange_excl und arbeitet unabhaengig von
-- Zeilenregeln weiter; die Ausloeser rund um Status, Anfrage und Meldung sind
-- SECURITY DEFINER und sehen daher weiterhin alle Zeilen.

-- ----------------------------------------------------------------- 1. Lesen
-- In PROD heisst die Regel "club members read bookings", im Repo stand sie als
-- "members read vehicle bookings" (20260816140000). Beide Namen fallen, damit
-- am Ende genau eine Leseregel steht.
drop policy if exists "club members read bookings" on public.vehicle_bookings;
drop policy if exists "members read vehicle bookings" on public.vehicle_bookings;

create policy "eigene buchung oder leitung liest" on public.vehicle_bookings
  for select to authenticated
  using (
    public.can_manage_fleet(club_id)
    or exists (
      select 1 from public.club_memberships m
       where m.id = vehicle_bookings.membership_id
         and m.profile_id = (select auth.uid())
         and m.club_id = vehicle_bookings.club_id)
  );

-- -------------------------------------------------------------- 2. Belegung
-- Die View gehoert postgres und laeuft ohne security_invoker an der Zeilenregel
-- der Tabelle vorbei - sie muss die Vereinszugehoerigkeit deshalb selbst
-- pruefen (is_club_member). security_barrier verhindert, dass eine vom Aufrufer
-- mitgegebene Bedingung vor dieser Pruefung ausgewertet wird.
--
-- Fahrzeug- und Mannschaftsname stehen fest in der View: Ueber eine View kann
-- PostgREST keine Fremdschluessel einbetten, die App holt sie also nicht mehr
-- per club_vehicles(label) / teams(name) dazu.
drop view if exists public.fahrzeugbelegung;

create view public.fahrzeugbelegung with (security_barrier = true) as
select vb.id,
       vb.club_id,
       vb.vehicle_id,
       v.label                                          as fahrzeug,
       vb.team_id,
       t.name                                           as mannschaft,
       vb.starts_at,
       vb.ends_at,
       vb.status,
       vb.created_at,
       darf.ja                                          as darf_namen_sehen,
       case when darf.ja then vb.membership_id end      as membership_id,
       case when darf.ja then vb.private_label end      as private_label,
       case when darf.ja then m.display_name end        as gebucht_von
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
 where public.is_club_member(vb.club_id);

revoke all on public.fahrzeugbelegung from public;
grant select on public.fahrzeugbelegung to authenticated, service_role;

comment on view public.fahrzeugbelegung is
  'Belegung der Vereinsfahrzeuge fuer alle Mitglieder. Name, Freitext und membership_id nur fuer Vereinsleitung und buchende Person.';

-- --------------------------------------------------------------- 3. Telefon
-- Vorher: jedes aktive Mitglied des Vereins bekam die Nummern zu jeder
-- Buchungs-ID. Jetzt dieselbe Grenze wie bei der Anzeige.
create or replace function public.get_booking_contact_phone(target_booking uuid)
returns text[] language sql stable security definer set search_path = '' as $$
  select p.contact_phones
    from public.vehicle_bookings vb
    join public.club_memberships m on m.id = vb.membership_id
    join public.profiles p on p.id = m.profile_id
   where vb.id = target_booking
     and (public.can_manage_fleet(vb.club_id) or m.profile_id = auth.uid());
$$;

grant execute on function public.get_booking_contact_phone(uuid) to authenticated, service_role;

-- PostgREST soll die neue View sofort kennen.
notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
select (select count(*) from pg_policies
         where schemaname = 'public' and tablename = 'vehicle_bookings'
           and policyname = 'eigene buchung oder leitung liest')            as leseregel_neu,
       (select count(*) from pg_policies
         where schemaname = 'public' and tablename = 'vehicle_bookings'
           and cmd = 'SELECT')                                              as leseregeln_gesamt,
       (select count(*) from pg_views
         where schemaname = 'public' and viewname = 'fahrzeugbelegung')     as view_da,
       (select count(*) from information_schema.role_table_grants
         where table_schema = 'public' and table_name = 'fahrzeugbelegung'
           and grantee = 'authenticated' and privilege_type = 'SELECT')     as view_lesbar,
       (select position('can_manage_fleet' in pg_get_functiondef(
                 'public.get_booking_contact_phone(uuid)'::regprocedure)) > 0)
                                                                            as telefon_eng;
