-- Einen Verein freischalten — in einem Aufruf.
--
-- Bisher hätte der Betreiber das von Hand zusammenschreiben müssen: Zeile in
-- club_subscriptions anlegen, Plan-Kennung heraussuchen, Laufzeitende setzen,
-- die vereinbarte Zugangszahl am Verein eintragen und die Anfrage abhaken. Fünf
-- Schritte, bei denen sich einer vergessen lässt — und dann steht ein Verein
-- da, der bezahlt hat und nichts sehen kann.
--
-- Diese Funktion macht alles zusammen oder gar nichts.

create or replace function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic',              -- basic, plus oder pro
  zugaenge integer default null,           -- abweichend vereinbarte Zahl; null = die des Tarifs
  laufzeit interval default '1 year',      -- ab jetzt
  belegnummer text default null            -- Rechnungsnummer, zur Zuordnung
)
returns table (verein text, tarif text, grenze integer, laeuft_bis timestamptz)
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

  -- Vorhandene Freischaltungen desselben Vereins beenden, damit nicht zwei
  -- nebeneinander laufen und club_subscription_tier die höhere nimmt.
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

  -- Die vereinbarte Zahl geht der Staffel vor; null setzt sie zurück auf die
  -- Zahl des Tarifs.
  update public.clubs set vereinbarte_zugaenge = zugaenge where id = target_club;

  -- Offene Anfragen dieses Vereins sind damit erledigt.
  update public.club_access_requests
     set status = 'freigeschaltet', handled_at = now()
   where club_id = target_club and status in ('offen', 'berechnet');

  return query
    select c.name,
           public.club_subscription_tier(c.id),
           public.club_account_limit(c.id),
           (select max(s.current_period_end) from public.club_subscriptions s
             where s.club_id = c.id and s.status = 'active')
      from public.clubs c where c.id = target_club;
end;
$$;

-- Ausdrücklich NICHT an authenticated. Freischalten darf nur der Betreiber,
-- und der arbeitet mit dem Dienstschlüssel. Ohne diese Einschränkung könnte
-- sich jeder Vereinsadmin selbst freischalten.
revoke all on function public.verein_freischalten(uuid, text, integer, interval, text) from public, authenticated, anon;

-- Das Gegenstück: eine Freischaltung beenden.
create or replace function public.verein_sperren(target_club uuid)
returns table (verein text, tarif text, grenze integer)
language plpgsql security definer set search_path = '' as $$
begin
  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';
  update public.clubs set vereinbarte_zugaenge = null where id = target_club;

  return query
    select c.name, public.club_subscription_tier(c.id), public.club_account_limit(c.id)
      from public.clubs c where c.id = target_club;
end;
$$;

revoke all on function public.verein_sperren(uuid) from public, authenticated, anon;
