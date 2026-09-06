-- Absagen brauchen einen Grund.
--
-- Bisher verschwand ein Training oder Spiel mit einem Klick und ohne Erklaerung.
-- Die Mannschaft sah nur "wurde abgesagt" - und fragte im Chat nach, warum.
-- Genau diese Frage soll die Absage selbst beantworten.
--
-- Der Grund geht auch in die Benachrichtigung: notify_event_audience meldet
-- die Absage ohnehin, und "Training abgesagt - Halle gesperrt" spart der
-- Vereinsleitung fuenf Rueckfragen.

alter table public.events add column if not exists cancel_reason text;

/* Die Meldung um den Grund ergaenzen, wenn einer dasteht. */
create or replace function public.notify_event_audience()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  v_titel text;
  v_text  text;
  v_art   text;
begin
  v_art := case new.type when 'training' then 'Training' when 'spiel' then 'Spiel' else 'Event' end;

  if tg_op = 'INSERT' then
    v_titel := v_art || ' angelegt';
    v_text  := 'Das ' || v_art || ' wurde angelegt.';
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_titel := v_art || ' abgesagt';
    v_text  := 'Das ' || v_art || ' wurde abgesagt.'
               || coalesce(' Grund: ' || nullif(trim(new.cancel_reason), ''), '');
  elsif tg_op = 'UPDATE' then
    v_titel := v_art || ' geändert';
    v_text  := 'Das ' || v_art || ' wurde geändert.';
  else
    return new;
  end if;

  v_text := v_text || ' ' || coalesce(new.title, '')
            || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
            || coalesce(' · ' || new.location, '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, new.club_id,
         case new.type when 'training' then 'training' when 'spiel' then 'match' else 'event' end,
         v_titel, v_text
  from public.club_memberships m
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null);

  return new;
end;
$$;

select column_name from information_schema.columns
 where table_schema='public' and table_name='events' and column_name='cancel_reason';
