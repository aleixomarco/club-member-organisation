-- Das Prüfkonto von Apple und die Zwei-Geräte-Grenze.
--
-- Ein Konto darf auf höchstens zwei Geräten angemeldet sein; ein drittes
-- verdrängt das älteste. Apple prüft aber regelmäßig in mehreren Anläufen, teils
-- von zwei Personen. Der dritte Anlauf bekäme statt der App den Satz „Dieses
-- Gerät wurde abgemeldet, weil dein Konto inzwischen auf zwei anderen Geräten
-- angemeldet ist" — was wie ein Fehler aussieht und eine Ablehnung nach 2.1
-- nach sich zöge.
--
-- Zwei Dinge dagegen:
--
-- 1. Die vorhandenen Geräteeinträge des Prüfkontos werden geleert, damit die
--    Prüfung mit zwei freien Plätzen beginnt.
-- 2. Ein Konto lässt sich von der Grenze ausnehmen. Das ist ausdrücklich kein
--    Schlupfloch für jedermann: Der Schalter sitzt am Profil, ist nur mit dem
--    Dienstschlüssel setzbar und für die App unsichtbar.

alter table public.profiles
  add column if not exists geraetegrenze_aus boolean not null default false;

comment on column public.profiles.geraetegrenze_aus is
  'Nimmt dieses Konto von der Zwei-Geraete-Grenze aus. Nur fuer Pruefkonten (App Store). Setzt der Betreiber.';

create or replace function public.geraet_anmelden(kennung text, bezeichnung text default null)
returns table (erlaubt boolean, geraete integer)
language plpgsql security definer set search_path = '' as $$
declare
  grenze constant integer := 2;
  wer uuid := auth.uid();
  ausgenommen boolean;
begin
  if wer is null then raise exception 'Authentication required'; end if;
  if nullif(trim(kennung), '') is null then raise exception 'Geraetekennung fehlt'; end if;

  insert into public.user_devices (profile_id, device_id, device_name)
  values (wer, trim(kennung), nullif(trim(bezeichnung), ''))
  on conflict (profile_id, device_id) do update
    set last_seen = now(),
        device_name = coalesce(excluded.device_name, public.user_devices.device_name);

  select coalesce(p.geraetegrenze_aus, false) into ausgenommen
    from public.profiles p where p.id = wer;

  if not ausgenommen then
    delete from public.user_devices d
     where d.profile_id = wer
       and d.id not in (
         select d2.id from public.user_devices d2
          where d2.profile_id = wer
          order by d2.last_seen desc
          limit grenze
       );
  end if;

  return query
    select exists (
      select 1 from public.user_devices d
       where d.profile_id = wer and d.device_id = trim(kennung)
    ),
    (select count(*)::integer from public.user_devices d where d.profile_id = wer);
end;
$$;

grant execute on function public.geraet_anmelden(text, text) to authenticated;

-- Das Pruefkonto ausnehmen und seine bisherigen Geraete entfernen.
update public.profiles p
   set geraetegrenze_aus = true
 where p.id in (select u.id from auth.users u where u.email = 'demo@idbranding.de');

delete from public.user_devices d
 where d.profile_id in (select u.id from auth.users u where u.email = 'demo@idbranding.de');
