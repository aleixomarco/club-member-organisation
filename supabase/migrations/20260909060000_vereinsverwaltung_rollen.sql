/* Wer den Verein verwaltet: Vereinsadministration und Organisation.

 * Die Oberflaeche zeigt Benutzerverwaltung und Beitrittsanfragen jetzt genau
 * diesen beiden Rollen (plus sysadmin, den register_new_club dem Gruender
 * ohnehin zusammen mit vereinsadmin gibt). Ohne diese Migration waere das
 * Kosmetik: Die Datenbank entscheidet, wer etwas darf, nicht die Kachel.
 *
 * ZWEI ANGLEICHUNGEN
 * 1. respond_to_join_request liess 'vorstand' zu. Die Rolle ist seit
 *    20260905180000 abgeschafft, alle Traeger wurden auf vereinsadmin
 *    umgestellt und ein Ausloeser lehnt sie seitdem ab - in der Datenbank
 *    steht sie bei null Mitgliedschaften. Der Zweig war also tot; an seine
 *    Stelle tritt 'organisator'.
 * 2. sysadmin_update_member_profile verlangte ausschliesslich sysadmin. Damit
 *    kam ein Vereinsadministrator an die Stammdaten seiner eigenen Mitglieder
 *    nicht heran - die Kachel war nur fuer den Gruender da. Jetzt gilt
 *    dieselbe Menge wie in der Oberflaeche.
 *    Die beiden Meldungen darin nennen deshalb nicht mehr "sysadmin"; sie
 *    waeren sonst falsch, sobald ein Organisator sie liest.
 *
 * Der Rumpf stammt im Uebrigen unveraendert aus der Datenbank.
 */

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

  if not public.has_club_role(v_club, array['sysadmin','vereinsadmin','organisator']::public.club_role[]) then
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

CREATE OR REPLACE FUNCTION public.sysadmin_update_member_profile(target_membership uuid, new_display_name text, new_contact_email text, new_birthdate date, new_member_since integer, new_status membership_status)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  target_club uuid;
  target_profile uuid;
  acting_membership uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if nullif(trim(new_display_name), '') is null then raise exception 'Display name required'; end if;
  if new_member_since is not null and (new_member_since < 1800 or new_member_since > 2200) then
    raise exception 'Invalid membership year';
  end if;

  select club_id, profile_id into target_club, target_profile
  from public.club_memberships where id = target_membership;
  if target_club is null then raise exception 'Membership not found'; end if;

  select membership.id into acting_membership
  from public.club_memberships membership
  join public.membership_roles role
    on role.membership_id = membership.id
   and role.role in ('sysadmin', 'vereinsadmin', 'organisator')
  where membership.club_id = target_club
    and membership.profile_id = auth.uid()
    and membership.status = 'active';
  if acting_membership is null then raise exception 'Not authorized to manage members'; end if;
  if acting_membership = target_membership and new_status <> 'active' then
    raise exception 'Cannot deactivate own active membership';
  end if;

  update public.club_memberships
  set display_name = trim(new_display_name),
      email = nullif(trim(new_contact_email), ''),
      member_since = new_member_since,
      status = new_status
  where id = target_membership;

  if target_profile is not null then
    update public.profiles
    set full_name = trim(new_display_name), birthdate = new_birthdate
    where id = target_profile;
  end if;
end;
$function$;
