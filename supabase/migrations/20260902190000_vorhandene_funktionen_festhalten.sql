-- Dreizehn Funktionen, die es nur in der Produktivdatenbank gab.
--
-- Derselbe Befund wie bei den Tabellen und Spalten: Die App ruft sie, sie
-- laufen, aber sie stehen in keiner Migration. Auf einer frisch aufgebauten
-- Datenbank waeren dreizehn Funktionen der App tot - Helferaufgaben,
-- Terminserien, Beitrittsentscheidungen, Saisonabschluss, Benachrichtigungen.
--
-- Die Definitionen sind woertlich aus der laufenden Datenbank ausgelesen
-- (pg_get_functiondef) und hier unveraendert festgehalten. Auf ihr sind sie
-- wirkungslos; ihr Zweck ist, dass sich das Schema wieder herstellen laesst.

CREATE OR REPLACE FUNCTION public.notify_club(target_club uuid, p_notif_type text, p_title text, p_body text, exclude_profile uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  member record;
begin
  for member in
    select m.id from public.club_memberships m
    where m.club_id = target_club and m.status = 'active'
      and (exclude_profile is null or m.profile_id is distinct from exclude_profile)
  loop
    perform public.notify(member.id, p_notif_type, p_title, p_body);
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.notify_many(target_memberships uuid[], p_notif_type text, p_title text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  mid uuid;
begin
  foreach mid in array coalesce(target_memberships, array[]::uuid[]) loop
    perform public.notify(mid, p_notif_type, p_title, p_body);
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_duty_template(target_event uuid, target_template uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev_club uuid;
  item record;
  acting_membership uuid;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;
  select club_id into ev_club from public.events where id = target_event;
  select id into acting_membership from public.club_memberships where profile_id = auth.uid() and club_id = ev_club;
  for item in select title from public.duty_task_template_items where template_id = target_template order by sort_order loop
    insert into public.duty_tasks (event_id, club_id, title, created_by)
    values (target_event, ev_club, item.title, acting_membership);
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_duty_task(target_event uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev_team uuid;
  ev_club uuid;
begin
  select team_id, club_id into ev_team, ev_club from public.events where id = target_event;
  if ev_club is null then return false; end if;
  if public.can_manage_duty_templates(ev_club) then return true; end if;
  if ev_team is not null and public.can_manage_team(ev_team) then return true; end if;
  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.check_task_reminder_threshold(target_club uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  total_active integer;
  signed_up integer;
  already_triggered boolean;
  member record;
begin
  select count(*) into total_active from public.club_memberships where club_id = target_club and status = 'active';
  if total_active = 0 then return false; end if;
  select count(distinct s.membership_id) into signed_up
  from public.club_task_signups s
  join public.club_memberships m on m.id = s.membership_id
  where m.club_id = target_club and m.status = 'active';
  select exists(select 1 from public.club_task_reminders where club_id = target_club) into already_triggered;
  if already_triggered then return false; end if;
  if (signed_up::numeric / total_active::numeric) >= 0.7 then
    insert into public.club_task_reminders (club_id) values (target_club) on conflict do nothing;
    for member in
      select m.id from public.club_memberships m
      where m.club_id = target_club and m.status = 'active'
        and m.id not in (select s.membership_id from public.club_task_signups s)
    loop
      perform public.notify(member.id, 'tasks', 'Der Verein braucht Unterstützung',
        'Schon 70% der Mitglieder haben sich für Aufgaben eingetragen. Hilfst du auch mit?');
    end loop;
    return true;
  end if;
  return false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_duty_task(target_task uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  acting_membership uuid;
  current_assignee uuid;
  task_club uuid;
begin
  select dt.assignee_membership_id, dt.club_id into current_assignee, task_club
  from public.duty_tasks dt where dt.id = target_task;
  if task_club is null then
    raise exception 'Task not found';
  end if;

  select id into acting_membership from public.club_memberships
  where profile_id = auth.uid() and club_id = task_club and status = 'active';
  if acting_membership is null then
    raise exception 'Not authorized';
  end if;

  if current_assignee is null then
    update public.duty_tasks set assignee_membership_id = acting_membership where id = target_task;
  elsif current_assignee = acting_membership then
    update public.duty_tasks set assignee_membership_id = null where id = target_task;
  else
    raise exception 'Task already assigned to someone else';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_recurring_events(target_club uuid, target_team uuid, event_type event_type, event_title text, event_description text, event_location text, weekdays integer[], start_time time without time zone, end_time time without time zone, range_start date, range_end date)
 RETURNS SETOF uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_series uuid := gen_random_uuid();
  v_creator uuid := auth.uid();
  v_title text := nullif(trim(event_title), '');
begin
  if v_creator is null then raise exception 'Authentication required'; end if;
  if v_title is null then raise exception 'Title required'; end if;
  if range_start is null or range_end is null then raise exception 'Date range required'; end if;
  if range_end < range_start then raise exception 'End date must be after start date'; end if;
  if range_end - range_start > 366 then raise exception 'Date range too long (max one year)'; end if;
  if weekdays is null or cardinality(weekdays) = 0 then raise exception 'At least one weekday required'; end if;
  if end_time <= start_time then raise exception 'End time must be after start time'; end if;

  if not (
    public.can_manage_team(target_team)
    or public.has_club_role(target_club, array['sysadmin','vereinsadmin']::public.club_role[])
  ) then raise exception 'Not authorized to create events for this team'; end if;

  return query
    insert into public.events (club_id, team_id, type, status, title, description, starts_at, ends_at, location, created_by, series_id)
    select
      target_club,
      target_team,
      event_type,
      'scheduled',
      v_title,
      nullif(trim(event_description), ''),
      (d + start_time)::timestamptz,
      (d + end_time)::timestamptz,
      nullif(trim(event_location), ''),
      v_creator,
      v_series
    from generate_series(range_start, range_end, interval '1 day') as d
    where extract(isodow from d)::int = any(weekdays)
    returning id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.delete_event_series(target_series uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.events
  where series_id = target_series
    and (
      public.has_club_role(club_id, array['sysadmin','vereinsadmin']::public.club_role[])
      or (team_id is not null and public.can_manage_team(team_id))
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_booking_contact_phone(target_booking uuid)
 RETURNS text[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.contact_phones
  from public.vehicle_bookings vb
  join public.club_memberships m on m.id = vb.membership_id
  join public.profiles p on p.id = m.profile_id
  where vb.id = target_booking
    and exists (
      select 1 from public.club_memberships viewer
      where viewer.club_id = vb.club_id and viewer.profile_id = auth.uid() and viewer.status = 'active'
    );
$function$;

CREATE OR REPLACE FUNCTION public.get_task_signup_ratio(target_club uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when count(distinct m.id) = 0 then 0 else
    (select count(distinct s.membership_id)::numeric from public.club_task_signups s join public.club_memberships m2 on m2.id = s.membership_id where m2.club_id = target_club and m2.status = 'active')
    / count(distinct m.id)::numeric
  end
  from public.club_memberships m where m.club_id = target_club and m.status = 'active';
$function$;

CREATE OR REPLACE FUNCTION public.mark_penalty_paid(target_assignment uuid, mark_paid boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  assignment_team uuid;
  acting_membership uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select team_id into assignment_team from public.team_penalty_assignments where id = target_assignment;
  if assignment_team is null then raise exception 'Penalty assignment not found'; end if;
  if not public.can_manage_team(assignment_team) then
    raise exception 'Only trainer, captain or team manager of this team may change payment status';
  end if;
  select id into acting_membership from public.club_memberships where profile_id = auth.uid() and status = 'active';
  update public.team_penalty_assignments
  set paid_at = case when mark_paid then now() else null end,
      paid_by = case when mark_paid then acting_membership else null end
  where id = target_assignment and archived_season is null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.respond_to_join_request(target_membership uuid, approve boolean, granted_role club_role DEFAULT NULL::club_role)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_club uuid;
  v_current_status public.membership_status;
  v_rejections integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select club_id, status, rejection_count into v_club, v_current_status, v_rejections
  from public.club_memberships where id = target_membership;
  if v_club is null then raise exception 'Membership request not found'; end if;
  if v_current_status <> 'pending' then raise exception 'This request has already been handled'; end if;

  if not public.has_club_role(v_club, array['sysadmin','vereinsadmin','vorstand']::public.club_role[]) then
    raise exception 'Not authorized to review join requests';
  end if;

  if approve then
    update public.club_memberships set status = 'active', rejection_count = 0, blocked_until = null, updated_at = now()
    where id = target_membership;
    if granted_role is not null and granted_role <> 'mitglied' then
      insert into public.membership_roles (membership_id, role, granted_by)
      values (target_membership, granted_role, auth.uid()) on conflict do nothing;
    end if;
  else
    v_rejections := coalesce(v_rejections, 0) + 1;
    update public.club_memberships set
      status = 'rejected',
      rejection_count = v_rejections,
      blocked_until = case when v_rejections >= 3 then now() + interval '7 days' else null end,
      updated_at = now()
    where id = target_membership;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.run_season_reset(target_club uuid, season_label text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  affected integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['vorstand','finanzmanager','sysadmin','vereinsadmin']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;
  update public.team_penalty_assignments a
  set archived_season = season_label, archived_at = now()
  from public.teams t
  where a.team_id = t.id and t.club_id = target_club
    and a.paid_at is not null and a.archived_season is null;
  get diagnostics affected = row_count;
  return affected;
end;
$function$;
