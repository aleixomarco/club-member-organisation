-- Vereinsfahrzeug: Buchungsanfragen mit Freigabe.
--
-- BISHER
-- Buchen durfte nur ein enger Kreis (can_book_vehicles: Vorstand,
-- Vereinsadmin, Geschaeftsfuehrung, Trainer, Teammanager, Kapitaen,
-- Finanzmanager), und jede Buchung galt sofort. Ein normales Mitglied kam gar
-- nicht an das Fahrzeug - es musste jemanden bitten, fuer es zu buchen.
--
-- JETZT
-- Jedes aktive Mitglied darf ANFRAGEN. Ob daraus sofort eine Buchung wird oder
-- erst eine Anfrage, entscheidet nicht die App, sondern die Datenbank:
--
--   Vereinsadmin, Sysadmin, Organisator  ->  sofort bestaetigt
--   alle anderen                         ->  angefragt
--
-- WARUM DIE DATENBANK DAS ENTSCHEIDET UND NICHT DIE APP
-- Wenn die App den Status mitschickt, kann sie ihn auch faelschen - ein
-- praeparierter Aufruf setzt "bestaetigt" und umgeht die Freigabe komplett.
-- Der Ausloeser unten ueberschreibt den Status daher IMMER, unabhaengig davon,
-- was hereinkommt.
--
-- BENACHRICHTIGUNGEN
-- Beide Richtungen laufen ueber user_notifications und damit ueber dieselbe
-- Kette, die seit heute Push aufs Telefon bringt:
--   Anfrage gestellt   -> an alle Entscheider
--   entschieden        -> an die anfragende Person
--
-- BESTAND
-- Alle vorhandenen Buchungen bekommen 'bestaetigt'. Sie stammen aus der Zeit,
-- in der nur Berechtigte buchen konnten - sie nachtraeglich zu Anfragen zu
-- machen, wuerde bestehende Fahrten in Frage stellen.

alter table public.vehicle_bookings
  add column if not exists status text not null default 'bestaetigt',
  add column if not exists decided_by uuid references public.club_memberships(id) on delete set null,
  add column if not exists decided_at timestamptz;

do $$ begin
  alter table public.vehicle_bookings
    add constraint vehicle_bookings_status_check
    check (status in ('angefragt', 'bestaetigt', 'abgelehnt'));
exception when duplicate_object then null; end $$;

create index if not exists vehicle_bookings_status_idx
  on public.vehicle_bookings (club_id, status);

/* Wer ueber Anfragen entscheidet. Bewusst enger als can_manage_fleet, das noch
   Vorstand und Geschaeftsfuehrung kennt - beide Rollen sind abgeschafft. */
create or replace function public.darf_fahrzeug_entscheiden(target_club uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membership_roles r
    join public.club_memberships m on m.id = r.membership_id
    where m.club_id = target_club and m.profile_id = auth.uid()
      and m.status = 'active'
      and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
  );
$$;

/* Status festlegen - unabhaengig davon, was die App schickt. */
create or replace function public.fahrzeugbuchung_status_setzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if public.darf_fahrzeug_entscheiden(new.club_id) then
    new.status := 'bestaetigt';
    new.decided_by := new.membership_id;
    new.decided_at := now();
  else
    new.status := 'angefragt';
    new.decided_by := null;
    new.decided_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists vehicle_bookings_status on public.vehicle_bookings;
create trigger vehicle_bookings_status
  before insert on public.vehicle_bookings
  for each row execute function public.fahrzeugbuchung_status_setzen();

/* Anfrage melden - an jede Person, die entscheiden darf. */
create or replace function public.fahrzeuganfrage_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_name text;
begin
  if new.status <> 'angefragt' then return new; end if;

  select display_name into v_name from public.club_memberships where id = new.membership_id;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, new.club_id, 'vehicle',
         'Neue Vereinsfahrzeug Buchungsanfrage',
         'Neue Vereinsfahrzeug Buchungsanfrage von ' || coalesce(v_name, 'einem Mitglied') || '.'
  from public.membership_roles r
  join public.club_memberships m on m.id = r.membership_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator');

  return new;
end;
$$;

drop trigger if exists vehicle_bookings_anfrage_melden on public.vehicle_bookings;
create trigger vehicle_bookings_anfrage_melden
  after insert on public.vehicle_bookings
  for each row execute function public.fahrzeuganfrage_melden();

/* Entscheiden. Liefert den neuen Status zurueck, damit die App nicht raten muss. */
create or replace function public.entscheide_fahrzeug_anfrage(target_booking uuid, annehmen boolean)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_club uuid;
  v_anfrager uuid;
  v_profil uuid;
  v_status text;
  v_mein uuid;
begin
  select club_id, membership_id, status into v_club, v_anfrager, v_status
  from public.vehicle_bookings where id = target_booking;
  if v_club is null then raise exception 'Booking not found'; end if;
  if not public.darf_fahrzeug_entscheiden(v_club) then raise exception 'Not authorized'; end if;
  if v_status <> 'angefragt' then return v_status; end if;

  select id into v_mein from public.club_memberships
   where club_id = v_club and profile_id = auth.uid() and status = 'active' limit 1;

  update public.vehicle_bookings
     set status = case when annehmen then 'bestaetigt' else 'abgelehnt' end,
         decided_by = v_mein, decided_at = now()
   where id = target_booking;

  select profile_id into v_profil from public.club_memberships where id = v_anfrager;
  if v_profil is not null then
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    values (v_profil, v_club, 'vehicle',
            'Vereinsfahrzeug',
            'Deine Anfrage zur Vereinsfahrzeug Buchung wurde ' ||
            case when annehmen then 'angenommen' else 'abgelehnt' end || '.');
  end if;

  return case when annehmen then 'bestaetigt' else 'abgelehnt' end;
end;
$$;

grant execute on function public.darf_fahrzeug_entscheiden(uuid) to authenticated, service_role;
grant execute on function public.entscheide_fahrzeug_anfrage(uuid, boolean) to authenticated, service_role;
revoke all on function public.entscheide_fahrzeug_anfrage(uuid, boolean) from public, anon;

/* Anfragen darf jedes aktive Mitglied - die Beschraenkung auf einzelne Rollen
   faellt weg. Wer nicht entscheiden darf, erzeugt durch den Ausloeser oben
   ohnehin nur eine Anfrage. */
drop policy if exists "authorized members create bookings" on public.vehicle_bookings;
create policy "members request bookings" on public.vehicle_bookings
  for insert with check (
    membership_id in (
      select id from public.club_memberships
      where profile_id = auth.uid() and club_id = vehicle_bookings.club_id and status = 'active'
    )
  );

select
  (select count(*) from public.vehicle_bookings where status = 'bestaetigt') as bestaetigt,
  (select count(*) from public.vehicle_bookings where status = 'angefragt') as angefragt,
  (select count(*) from pg_trigger where tgname in ('vehicle_bookings_status','vehicle_bookings_anfrage_melden')) as ausloeser;
