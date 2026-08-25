-- Kalender-Abo: Auswahl der Mannschaften
--
-- Bisher lieferte der Feed die Termine der Mannschaften aus, in denen man
-- selbst steht - dazu die vereinsweiten Termine. Das genügt nicht:
--
--   Ein Elternteil möchte die Mannschaft des Kindes im eigenen Kalender haben.
--   Ein Vorstandsmitglied möchte einer bestimmten Mannschaft folgen.
--   Ein Spieler in zwei Mannschaften möchte nur eine davon abonnieren.
--
-- Wie bei den Terminarten gehört die Auswahl an das Abonnement und nicht in
-- die URL: Der Gerätekalender ruft die Adresse dauerhaft unverändert ab.
-- Stünde die Auswahl als Parameter darin, müsste bei jeder Änderung das Abo im
-- Gerät neu eingerichtet werden.

-- Leeres Feld bedeutet "meine Mannschaften" - also das bisherige Verhalten.
-- Bestehende Abos behalten damit genau das, was sie heute liefern.
alter table public.calendar_subscriptions
  add column if not exists team_ids uuid[] not null default '{}';

-- Die alte Fassung muss weichen: Mit einem zusätzlichen Vorgabewert wären
-- beide Fassungen für einen Aufruf mit drei Argumenten gültig, und Postgres
-- lehnt ihn als mehrdeutig ab.
drop function if exists public.configure_calendar_subscription(uuid, text, text[]);

create or replace function public.configure_calendar_subscription(
  target_club uuid,
  requested_interval text,
  requested_types text[] default null,
  requested_teams uuid[] default null
)
returns table(token uuid, last_synced_at timestamptz, next_sync_at timestamptz, event_types text[], team_ids uuid[])
language plpgsql security definer set search_path = '' as $$
declare
  next_run timestamptz;
  chosen_types text[];
  chosen_teams uuid[];
  fremde integer;
begin
  if not public.is_club_member(target_club) then raise exception 'Membership required'; end if;
  if requested_interval not in ('never','daily','weekly','monthly') then raise exception 'Invalid interval'; end if;

  chosen_types := coalesce(nullif(requested_types, '{}'::text[]), array['training','spiel','event']);
  if not (chosen_types <@ array['training','spiel','event']) then
    raise exception 'Invalid event type';
  end if;

  -- Leer heißt "meine Mannschaften". Sonst muss jede gewählte Mannschaft zu
  -- diesem Verein gehören - sonst könnte man über eine untergeschobene Kennung
  -- die Termine eines fremden Vereins mitlesen.
  chosen_teams := coalesce(requested_teams, '{}'::uuid[]);
  if cardinality(chosen_teams) > 0 then
    select count(*) into fremde
    from unnest(chosen_teams) as gewaehlt(id)
    where not exists (
      select 1 from public.teams t where t.id = gewaehlt.id and t.club_id = target_club
    );
    if fremde > 0 then raise exception 'Team does not belong to this club'; end if;
  end if;

  next_run := case requested_interval
    when 'daily' then now() + interval '1 day'
    when 'weekly' then date_trunc('week', now()) + interval '6 days 20 hours'
    when 'monthly' then date_trunc('month', now()) + interval '1 month'
    else null end;

  return query
    insert into public.calendar_subscriptions(profile_id, club_id, sync_interval, event_types, team_ids, last_synced_at, next_sync_at)
    values(auth.uid(), target_club, requested_interval, chosen_types, chosen_teams, now(), next_run)
    on conflict(profile_id, club_id) do update set
      sync_interval = excluded.sync_interval,
      event_types = excluded.event_types,
      team_ids = excluded.team_ids,
      last_synced_at = now(),
      next_sync_at = excluded.next_sync_at,
      updated_at = now()
    returning calendar_subscriptions.token,
              calendar_subscriptions.last_synced_at,
              calendar_subscriptions.next_sync_at,
              calendar_subscriptions.event_types,
              calendar_subscriptions.team_ids;
end;
$$;

create or replace function public.my_calendar_subscription(target_club uuid)
returns table(token uuid, sync_interval text, event_types text[], team_ids uuid[], enabled boolean)
language sql security definer set search_path = '' as $$
  select s.token, s.sync_interval, s.event_types, s.team_ids, s.enabled
  from public.calendar_subscriptions s
  where s.profile_id = auth.uid() and s.club_id = target_club;
$$;

grant execute on function public.configure_calendar_subscription(uuid, text, text[], uuid[]) to authenticated;
grant execute on function public.my_calendar_subscription(uuid) to authenticated;

-- Kontrolle
select column_name, data_type
from information_schema.columns
where table_name = 'calendar_subscriptions' and column_name in ('event_types','team_ids');
