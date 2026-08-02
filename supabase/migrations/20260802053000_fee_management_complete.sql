-- Dauerhafte und atomare Beitragsverwaltung für Geschäftsführung und Finanzmanagement.

create or replace function public.save_fee_record(
  target_club uuid,
  target_membership uuid,
  fee_year integer,
  fee_kind public.fee_type,
  fee_amount numeric,
  fee_status public.payment_status,
  fee_invoice_number text,
  fee_person_count integer,
  linked_memberships uuid[],
  manual_people text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  result_id uuid;
  related_id uuid;
  person_name text;
begin
  if auth.uid() is null or not public.has_club_role(target_club, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;
  if not exists (select 1 from public.club_memberships where id = target_membership and club_id = target_club) then
    raise exception 'Membership not found';
  end if;
  if fee_year not between 2000 and 2200 or fee_amount < 0 or fee_person_count < 1 then
    raise exception 'Invalid fee record';
  end if;

  insert into public.fee_records (
    club_id, membership_id, year, type, amount, payment_status,
    invoice_number, person_count, created_by
  ) values (
    target_club, target_membership, fee_year, fee_kind, fee_amount, fee_status,
    nullif(trim(fee_invoice_number), ''),
    case when fee_kind = 'Familienbeitrag' then fee_person_count else 1 end,
    auth.uid()
  ) returning id into result_id;

  if fee_kind = 'Familienbeitrag' then
    foreach related_id in array coalesce(linked_memberships, array[]::uuid[]) loop
      if related_id <> target_membership and exists (
        select 1 from public.club_memberships where id = related_id and club_id = target_club
      ) and not exists (
        select 1 from public.fee_people where fee_record_id = result_id and membership_id = related_id
      ) then
        insert into public.fee_people (fee_record_id, membership_id) values (result_id, related_id);
      end if;
    end loop;
    foreach person_name in array coalesce(manual_people, array[]::text[]) loop
      if nullif(trim(person_name), '') is not null then
        insert into public.fee_people (fee_record_id, manual_name) values (result_id, trim(person_name));
      end if;
    end loop;
  end if;

  return result_id;
end;
$$;

create or replace function public.set_fee_payment_status(target_fee uuid, new_status public.payment_status)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  fee_club uuid;
begin
  select club_id into fee_club from public.fee_records where id = target_fee;
  if fee_club is null or auth.uid() is null or not public.has_club_role(fee_club, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;
  update public.fee_records set payment_status = new_status where id = target_fee;
end;
$$;

create or replace function public.delete_fee_record(target_fee uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  fee_club uuid;
begin
  select club_id into fee_club from public.fee_records where id = target_fee;
  if fee_club is null or auth.uid() is null or not public.has_club_role(fee_club, array['finanzmanager','geschaeftsfuehrung']::public.club_role[]) then
    raise exception 'Not authorized';
  end if;
  delete from public.fee_records where id = target_fee;
end;
$$;

revoke all on function public.save_fee_record(uuid, uuid, integer, public.fee_type, numeric, public.payment_status, text, integer, uuid[], text[]) from public;
revoke all on function public.set_fee_payment_status(uuid, public.payment_status) from public;
revoke all on function public.delete_fee_record(uuid) from public;
grant execute on function public.save_fee_record(uuid, uuid, integer, public.fee_type, numeric, public.payment_status, text, integer, uuid[], text[]) to authenticated;
grant execute on function public.set_fee_payment_status(uuid, public.payment_status) to authenticated;
grant execute on function public.delete_fee_record(uuid) to authenticated;
