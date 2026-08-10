-- Kalender-Abo: Auswahl der Terminarten
--
-- Bisher lieferte der Feed immer alle Termine aus. Jetzt entscheidet jede
-- Person selbst, welche der drei Arten (training, spiel, event) in ihrem
-- privaten Gerätekalender landen sollen.
--
-- Die Auswahl gehört an das Abonnement und nicht in die URL: Der Gerätekalender
-- ruft die Adresse dauerhaft und unverändert ab. Stünde die Auswahl als
-- Parameter darin, müsste bei jeder Änderung das Abo im Gerät neu eingerichtet
-- werden. So genügt ein Speichern in der App und der nächste Abruf liefert
-- automatisch die neue Auswahl.

alter table public.calendar_subscriptions
  add column if not exists event_types text[] not null default array['training','spiel','event'];

alter table public.calendar_subscriptions
  drop constraint if exists calendar_subscriptions_event_types_check;

-- Leere Auswahl wäre ein leerer Kalender ohne erkennbaren Grund — deshalb
-- mindestens eine Art, und nur die drei bekannten.
--
-- cardinality statt array_length: array_length('{}', 1) liefert NULL, und eine
-- CHECK-Bedingung gilt bei NULL als erfüllt. Ein leeres Feld wäre also genau
-- durch die Prüfung geschlüpft, die es verhindern soll.
alter table public.calendar_subscriptions
  add constraint calendar_subscriptions_event_types_check
  check (
    cardinality(event_types) >= 1
    and event_types <@ array['training','spiel','event']
  );

-- Die alte Fassung muss weichen: Mit einem zusätzlichen Vorgabewert wären
-- beide Fassungen für einen Aufruf mit zwei Argumenten gültig und Postgres
-- lehnt ihn als mehrdeutig ab.
drop function if exists public.configure_calendar_subscription(uuid, text);

create or replace function public.configure_calendar_subscription(
  target_club uuid,
  requested_interval text,
  requested_types text[] default null
)
returns table(token uuid, last_synced_at timestamptz, next_sync_at timestamptz, event_types text[])
language plpgsql security definer set search_path = '' as $$
declare
  next_run timestamptz;
  chosen_types text[];
begin
  if not public.is_club_member(target_club) then raise exception 'Membership required'; end if;
  if requested_interval not in ('never','daily','weekly','monthly') then raise exception 'Invalid interval'; end if;

  -- Leeres Feld wie „nicht angegeben" behandeln und auf alles zurückfallen,
  -- statt ein Abonnement anzulegen, das nie etwas ausliefert.
  chosen_types := coalesce(nullif(requested_types, '{}'::text[]), array['training','spiel','event']);
  if not (chosen_types <@ array['training','spiel','event']) then
    raise exception 'Invalid event type';
  end if;

  next_run := case requested_interval
    when 'daily' then now() + interval '1 day'
    when 'weekly' then date_trunc('week', now()) + interval '6 days 20 hours'
    when 'monthly' then date_trunc('month', now()) + interval '1 month'
    else null end;

  return query
    insert into public.calendar_subscriptions(profile_id, club_id, sync_interval, event_types, last_synced_at, next_sync_at)
    values(auth.uid(), target_club, requested_interval, chosen_types, now(), next_run)
    on conflict(profile_id, club_id) do update set
      sync_interval = excluded.sync_interval,
      event_types = excluded.event_types,
      last_synced_at = now(),
      next_sync_at = excluded.next_sync_at,
      updated_at = now()
    returning calendar_subscriptions.token,
              calendar_subscriptions.last_synced_at,
              calendar_subscriptions.next_sync_at,
              calendar_subscriptions.event_types;
end;
$$;

-- Damit die App die zuletzt gespeicherte Auswahl anzeigen kann, ohne dass ein
-- erneutes Speichern nötig wäre.
create or replace function public.my_calendar_subscription(target_club uuid)
returns table(token uuid, sync_interval text, event_types text[], enabled boolean)
language sql security definer set search_path = '' as $$
  select s.token, s.sync_interval, s.event_types, s.enabled
  from public.calendar_subscriptions s
  where s.profile_id = auth.uid() and s.club_id = target_club;
$$;

grant execute on function public.configure_calendar_subscription(uuid, text, text[]) to authenticated;
grant execute on function public.my_calendar_subscription(uuid) to authenticated;
