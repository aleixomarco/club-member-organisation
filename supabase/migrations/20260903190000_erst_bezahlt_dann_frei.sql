-- Freigeschaltet wird erst, wenn bezahlt ist.
--
-- verein_freischalten() hakte offene Anfragen bisher einfach ab, egal in
-- welchem Zustand sie waren. Damit liess sich ein Verein freischalten, dessen
-- Rechnung noch nicht einmal geschrieben war — und weil das Abhaken still
-- passierte, fiel es hinterher nicht einmal auf.
--
-- Die Regel gehört hierher und nicht in die Oberfläche. Eine Regel, die nur im
-- Browser gilt, ist keine Regel: Der nächste Weg in die Datenbank (ein Skript,
-- ein zweiter Bildschirm, der SQL-Editor) kennt sie nicht.
--
-- Eine Verlängerung hat keine offene Anfrage und läuft deshalb weiterhin durch.

create or replace function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic',
  zugaenge integer default null,
  laufzeit interval default '1 year',
  belegnummer text default null,
  sponsoring boolean default null
)
returns table (verein text, tarif text, grenze integer, sponsoren boolean, laeuft_bis timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  plan_id uuid;
  plan_code text;
  beleg text;
  bisheriges_ende timestamptz;
  beginn timestamptz;
  offene record;
begin
  if not exists (select 1 from public.clubs where id = target_club) then
    raise exception 'Verein % existiert nicht', target_club;
  end if;

  /* Gibt es eine Anfrage, die noch nicht bezahlt ist? Dann ist hier Schluss. */
  select r.id, r.status into offene
    from public.club_access_requests r
   where r.club_id = target_club
     and r.status in ('offen', 'rechnung_erstellt', 'rechnung_versendet')
   order by r.created_at desc limit 1;

  if offene.id is not null then
    raise exception 'Der Verein hat eine offene Anfrage im Zustand "%". Freischalten geht erst nach "rechnung_bezahlt".', offene.status
      using errcode = 'P0001';
  end if;

  plan_code := 'club_' || lower(trim(stufe)) || '_yearly';
  select id into plan_id from public.subscription_plans where code = plan_code;
  if plan_id is null then
    raise exception 'Unbekannte Stufe "%" - erwartet basic, plus oder pro', stufe;
  end if;

  beleg := coalesce(
    nullif(trim(belegnummer), ''),
    -- Wenn eine bezahlte Anfrage dahintersteht, ist ihre Rechnungsnummer die
    -- richtige Zuordnung.
    (select nullif(trim(r.rechnungsnummer), '') from public.club_access_requests r
      where r.club_id = target_club and r.status = 'rechnung_bezahlt'
      order by r.created_at desc limit 1),
    'rechnung-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS') || '-' || left(target_club::text, 8)
  );

  select max(s.current_period_end) into bisheriges_ende
    from public.club_subscriptions s
   where s.club_id = target_club and s.status = 'active';
  beginn := greatest(now(), coalesce(bisheriges_ende, now()));

  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';

  insert into public.club_subscriptions
    (club_id, plan_id, provider, provider_subscription_id, status,
     current_period_start, current_period_end, last_payment_at)
  values
    (target_club, plan_id, 'manual', beleg,
     'active', now(), beginn + laufzeit, now());

  update public.clubs
     set vereinbarte_zugaenge = case
           when zugaenge is null then vereinbarte_zugaenge
           when zugaenge <= 0 then null
           else zugaenge
         end,
         sponsoring_freigeschaltet = coalesce(sponsoring, sponsoring_freigeschaltet)
   where id = target_club;

  update public.club_access_requests r
     set status = 'freigeschaltet', handled_at = now(), freigeschaltet_am = now()
   where r.status = 'rechnung_bezahlt'
     and (
       r.club_id = target_club
       or (r.club_id is null
           and lower(trim(r.club_name)) = (select lower(trim(c.name)) from public.clubs c where c.id = target_club))
     );

  return query
    select c.name,
           public.club_subscription_tier(c.id),
           public.club_account_limit(c.id),
           c.sponsoring_freigeschaltet,
           (select max(s.current_period_end) from public.club_subscriptions s
             where s.club_id = c.id and s.status = 'active')
      from public.clubs c where c.id = target_club;
end;
$$;

revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean) from public, anon, authenticated;

-- Die Uebersicht zeigt den ganzen Weg, nicht nur "offen".
drop view if exists public.offene_freischaltungen;
create view public.offene_freischaltungen with (security_invoker = true) as
select
  r.id, r.created_at, r.quelle,
  coalesce(c.name, r.club_name) as verein,
  r.club_id, r.contact_name, r.contact_email, r.contact_phone,
  r.expected_accounts, r.sponsoring_gewuenscht, r.note, r.status,
  r.rechnungsnummer, r.betrag, r.zahlweise,
  r.rechnung_erstellt_am, r.rechnung_versendet_am, r.bezahlt_am,
  r.freigeschaltet_am, r.bestaetigung_versendet_am, r.ablehnungsgrund,
  case when c.id is null then null else public.club_account_count(c.id) end as konten_jetzt,
  case when c.id is null then null else public.club_subscription_tier(c.id) end as tarif_jetzt,
  case when c.id is null then null else c.sponsoring_freigeschaltet end as sponsoren_jetzt
from public.club_access_requests r
left join public.clubs c on c.id = r.club_id
where r.status <> 'abgelehnt'
   or r.handled_at > now() - interval '30 days'
order by r.created_at;

revoke all on public.offene_freischaltungen from anon, authenticated;
grant select on public.offene_freischaltungen to service_role;
