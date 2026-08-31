-- Sponsoring mit freischalten.
--
-- Der Zusatz kostet fünf Euro im Monat über dem Tarif und wird wie alles
-- andere in Rechnung gestellt. Er gehört deshalb in denselben Aufruf: Wer
-- freischaltet, hat die Rechnung vor sich und weiß, ob der Zusatz gebucht ist.
-- Ein zweites, leicht zu vergessendes Update von Hand wäre genau die Sorte
-- Schritt, die diese Funktion abschaffen sollte.

create or replace function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic',              -- basic, plus oder pro
  zugaenge integer default null,           -- abweichend vereinbarte Zahl; null = die des Tarifs
  laufzeit interval default '1 year',      -- ab jetzt
  belegnummer text default null,           -- Rechnungsnummer, zur Zuordnung
  sponsoring boolean default false         -- eigene Sponsoren, +5 €/Monat
)
returns table (verein text, tarif text, grenze integer, sponsoren boolean, laeuft_bis timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  plan_id uuid;
  plan_code text;
begin
  if not exists (select 1 from public.clubs where id = target_club) then
    raise exception 'Verein % existiert nicht', target_club;
  end if;

  plan_code := 'club_' || lower(trim(stufe)) || '_yearly';
  select id into plan_id from public.subscription_plans where code = plan_code;
  if plan_id is null then
    raise exception 'Unbekannte Stufe "%" - erwartet basic, plus oder pro', stufe;
  end if;

  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';

  insert into public.club_subscriptions
    (club_id, plan_id, provider, provider_subscription_id, status,
     current_period_start, current_period_end, last_payment_at)
  values
    (target_club, plan_id, 'manual',
     coalesce(nullif(trim(belegnummer), ''), 'rechnung-' || to_char(now(), 'YYYYMMDD-HH24MISS')),
     'active', now(), now() + laufzeit, now());

  update public.clubs
     set vereinbarte_zugaenge = zugaenge,
         sponsoring_freigeschaltet = sponsoring
   where id = target_club;

  update public.club_access_requests
     set status = 'freigeschaltet', handled_at = now()
   where club_id = target_club and status in ('offen', 'berechnet');

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

revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean) from public, authenticated, anon;

-- Die alte Signatur ohne den Zusatz würde sonst danebenstehen und beim Aufruf
-- ohne benannte Argumente mehrdeutig werden.
drop function if exists public.verein_freischalten(uuid, text, integer, interval, text);

-- Beim Sperren fällt der Zusatz mit weg. Ein Verein ohne Freischaltung, der
-- weiter eigene Sponsoren zeigt, wäre eine unbezahlte Leistung.
create or replace function public.verein_sperren(target_club uuid)
returns table (verein text, tarif text, grenze integer)
language plpgsql security definer set search_path = '' as $$
begin
  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';
  update public.clubs
     set vereinbarte_zugaenge = null, sponsoring_freigeschaltet = false
   where id = target_club;

  return query
    select c.name, public.club_subscription_tier(c.id), public.club_account_limit(c.id)
      from public.clubs c where c.id = target_club;
end;
$$;

revoke all on function public.verein_sperren(uuid) from public, authenticated, anon;
