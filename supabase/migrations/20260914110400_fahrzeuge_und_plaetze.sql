-- Fahrzeuge, Mitfahrten und Helferplaetze: was die Oberflaeche verspricht,
-- haelt jetzt die Datenbank.
--
-- rollen-08  Fahrzeug bearbeiten speicherte nie (keine UPDATE-Regel), die App
--            schloss das Formular trotzdem.
-- M3         Eine abgelehnte Anfrage blockierte den Zeitraum weiter.
-- M4         Die Freigabe liess sich per UPDATE umgehen (Bearbeiten einer
--            bestaetigten Buchung, API-PATCH auf status).
-- M5         Freie Plaetze in Fahrgemeinschaften und die Grenze von zwei
--            Personen je Helferstation standen nur in der Oberflaeche; Fans
--            konnten sich per API zu Helferdiensten eintragen.
--
-- Live-Definitionen von PROD (14.09.2026, nur lesend). Keine Datenreparatur:
-- PROD hat 2 Buchungen, beide bestaetigt (M2 bleibt reine Code-Korrektur).

-- ================================================================ rollen-08
-- Nur auf PROD, in keiner Migration:
--   can_manage_fleet(target_club uuid) returns boolean, sql stable security definer,
--     search_path public: exists (membership_roles r join club_memberships m ...
--     where m.club_id = target_club and m.profile_id = auth.uid()
--       and m.status = 'active' and r.role in ('vorstand','vereinsadmin','geschaeftsfuehrung'))
--   club_vehicles: "club members read vehicles" SELECT (aktive Mitglieder),
--     "fleet admins manage vehicles" INSERT with check (can_manage_fleet(club_id)),
--     "fleet admins delete vehicles" DELETE using (can_manage_fleet(club_id)).
-- Den Rollensatz von can_manage_fleet angleichen ist rollen-12.
drop policy if exists "fleet admins update vehicles" on public.club_vehicles;
create policy "fleet admins update vehicles" on public.club_vehicles
  for update to authenticated
  using (public.can_manage_fleet(club_id))
  with check (public.can_manage_fleet(club_id));

-- ================================================================ M3
-- Bisher (nur auf PROD): vehicle_bookings_vehicle_id_tstzrange_excl
--   EXCLUDE USING gist (vehicle_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
-- Neu: abgelehnte Buchungen zaehlen nicht mit. Sie bleiben stehen, damit der
-- Anfragende die Ablehnung sieht. btree_gist liegt auf PROD in public.
alter table public.vehicle_bookings drop constraint if exists vehicle_bookings_vehicle_id_tstzrange_excl;
alter table public.vehicle_bookings add constraint vehicle_bookings_vehicle_id_tstzrange_excl
  exclude using gist (vehicle_id with =, tstzrange(starts_at, ends_at, '[)') with &&)
  where (status <> 'abgelehnt');

-- ================================================================ M4
-- vehicle_bookings_status (fahrzeugbuchung_status_setzen) wirkt nur beim
-- Einfuegen. Beim Aendern durfte der Buchende status, decided_by und
-- decided_at selbst setzen - oder eine bestaetigte Buchung auf einen anderen
-- Zeitraum oder ein anderes Fahrzeug schieben, ohne dass jemand gefragt wurde.
-- Neu fuer alle, die nicht entscheiden duerfen (darf_fahrzeug_entscheiden):
-- Status, Entscheidung, Verein und Mitgliedschaft bleiben; eine Aenderung von
-- Zeitraum oder Fahrzeug an einer bestaetigten (oder abgelehnten) Buchung
-- macht daraus wieder eine Anfrage. entscheide_fahrzeug_anfrage laeuft als
-- Entscheider und ist nicht betroffen.
create or replace function public.fahrzeugbuchung_aenderung_pruefen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then return new; end if;
  if public.darf_fahrzeug_entscheiden(old.club_id) then return new; end if;

  new.status        := old.status;
  new.decided_by    := old.decided_by;
  new.decided_at    := old.decided_at;
  new.club_id       := old.club_id;
  new.membership_id := old.membership_id;

  if old.status in ('bestaetigt', 'abgelehnt')
     and (new.starts_at  is distinct from old.starts_at
       or new.ends_at    is distinct from old.ends_at
       or new.vehicle_id is distinct from old.vehicle_id) then
    new.status     := 'angefragt';
    new.decided_by := null;
    new.decided_at := null;
  end if;
  return new;
end;
$$;
revoke all on function public.fahrzeugbuchung_aenderung_pruefen() from public, anon, authenticated;

drop trigger if exists vehicle_bookings_aenderung_pruefen on public.vehicle_bookings;
create trigger vehicle_bookings_aenderung_pruefen
  before update on public.vehicle_bookings
  for each row execute function public.fahrzeugbuchung_aenderung_pruefen();

-- Die erneute Anfrage meldet sich wie eine neue (fahrzeuganfrage_melden liest
-- nur new und prueft selbst auf 'angefragt'). Bewusst ohne "OF status": Den
-- Status setzt der Ausloeser oben, nicht die Anweisung - eine Spaltenliste
-- sieht nur die Anweisung.
drop trigger if exists vehicle_bookings_anfrage_erneut_melden on public.vehicle_bookings;
create trigger vehicle_bookings_anfrage_erneut_melden
  after update on public.vehicle_bookings
  for each row
  when (new.status = 'angefragt' and old.status is distinct from 'angefragt')
  execute function public.fahrzeuganfrage_melden();

-- ================================================================ M5: Mitfahrten
-- Die Fahrgemeinschaft wird gesperrt, bevor gezaehlt wird - zwei
-- gleichzeitige Zusteiger koennen den letzten Platz nicht doppelt belegen.
-- Die App zeigt bei jedem Fehler schon "voll" (help.eintragenNichtMoeglichVoll).
create or replace function public.mitfahrt_platz_pruefen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_plaetze integer;
  v_belegt  integer;
begin
  select c.seats_available into v_plaetze
    from public.carpools c where c.id = new.carpool_id for update;
  if not found then return new; end if;
  select count(*) into v_belegt
    from public.carpool_passengers p
   where p.carpool_id = new.carpool_id and p.membership_id <> new.membership_id;
  if v_belegt >= v_plaetze then
    raise exception 'voll' using errcode = 'P0001', hint = 'Die Fahrgemeinschaft ist voll.';
  end if;
  return new;
end;
$$;
revoke all on function public.mitfahrt_platz_pruefen() from public, anon, authenticated;

drop trigger if exists carpool_passengers_platz on public.carpool_passengers;
create trigger carpool_passengers_platz
  before insert on public.carpool_passengers
  for each row execute function public.mitfahrt_platz_pruefen();

-- ================================================================ M5: Helferdienste
-- Fuer Selbsteintragungen (Aufrufer ohne Leitungsrolle der Regel
-- "leaders manage duties"): Die Station muss am Termin stehen
-- (events.helper_slots), hoechstens zwei Personen je Station (STATION_CAP in
-- app/page.tsx), und ein Fan traegt sich nicht ein. Der Termin wird vorher
-- gesperrt.
create or replace function public.helferdienst_eintrag_pruefen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_club      uuid;
  v_stationen text[];
  v_belegt    integer;
begin
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then return new; end if;

  select e.club_id, e.helper_slots into v_club, v_stationen
    from public.events e where e.id = new.event_id for update;
  if v_club is null then return new; end if;

  if public.has_club_role(v_club, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]) then
    return new;
  end if;

  if not (new.station = any(coalesce(v_stationen, '{}'::text[]))) then
    raise exception 'station_unbekannt' using errcode = 'P0001';
  end if;
  select count(*) into v_belegt
    from public.duty_assignments d
   where d.event_id = new.event_id and d.station = new.station;
  if v_belegt >= 2 then
    raise exception 'voll' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.membership_roles r
              where r.membership_id = new.membership_id and r.role = 'fan')
     and not exists (select 1 from public.membership_roles r
                      where r.membership_id = new.membership_id and r.role <> 'fan') then
    raise exception 'fan_kein_helferdienst' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.helferdienst_eintrag_pruefen() from public, anon, authenticated;

drop trigger if exists duty_assignments_platz_pruefen on public.duty_assignments;
create trigger duty_assignments_platz_pruefen
  before insert on public.duty_assignments
  for each row execute function public.helferdienst_eintrag_pruefen();

-- Erwartet: fahrzeug_aendern = 1, sperre_ohne_abgelehnte = true,
-- ausloeser = 4, bestand_passt = 0 (keine Ueberschneidung im Bestand).
select
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'club_vehicles' and cmd = 'UPDATE') as fahrzeug_aendern,
  (select pg_get_constraintdef(oid) like '%abgelehnt%' from pg_constraint
    where conrelid = 'public.vehicle_bookings'::regclass
      and conname = 'vehicle_bookings_vehicle_id_tstzrange_excl') as sperre_ohne_abgelehnte,
  (select count(*) from pg_trigger
    where tgname in ('vehicle_bookings_aenderung_pruefen', 'vehicle_bookings_anfrage_erneut_melden',
                     'carpool_passengers_platz', 'duty_assignments_platz_pruefen')) as ausloeser,
  (select count(*) from public.carpools c
    where (select count(*) from public.carpool_passengers p where p.carpool_id = c.id) > c.seats_available) as bestand_passt;
