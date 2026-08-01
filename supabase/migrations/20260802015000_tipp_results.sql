-- Tippspiel: Endergebnisse durch Vereins-Admin und automatische Punkte

alter table public.events
  add column if not exists home_score integer check (home_score >= 0),
  add column if not exists away_score integer check (away_score >= 0),
  add column if not exists result_entered_at timestamptz,
  add column if not exists result_entered_by uuid references public.profiles(id) on delete set null;

alter table public.predictions
  add column if not exists points integer not null default 0 check (points in (0, 1, 3));

create or replace function public.record_event_result(
  target_event uuid,
  final_home_score integer,
  final_away_score integer
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  target_club uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if final_home_score < 0 or final_away_score < 0 then raise exception 'Invalid result'; end if;

  select club_id into target_club from public.events where id = target_event for update;
  if target_club is null then raise exception 'Event not found'; end if;
  if not public.has_club_role(target_club, array['vereinsadmin','sysadmin']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;

  update public.events
  set home_score = final_home_score,
      away_score = final_away_score,
      result_entered_at = now(),
      result_entered_by = auth.uid(),
      updated_at = now()
  where id = target_event;

  update public.predictions p
  set points = case
    when p.home_score = final_home_score and p.away_score = final_away_score then 3
    when sign(p.home_score - p.away_score) = sign(final_home_score - final_away_score) then 1
    else 0
  end,
  updated_at = now()
  where p.event_id = target_event;
end;
$$;

grant execute on function public.record_event_result(uuid, integer, integer) to authenticated;

