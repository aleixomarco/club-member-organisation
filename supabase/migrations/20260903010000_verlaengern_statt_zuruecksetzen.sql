-- Verlängern heißt anhängen, nicht neu anfangen.
--
-- verein_freischalten() setzte das Laufzeitende bisher immer auf
-- `now() + laufzeit`. Für eine Neu-Freischaltung ist das richtig. Für eine
-- Verlängerung ist es ein Fehler, den niemand bemerkt: Zahlt ein Verein seine
-- Jahresrechnung drei Monate vor Ablauf, verschenkt er diese drei Monate. Der
-- Aufruf sieht erfolgreich aus, die Rückgabe nennt ein plausibles Datum, und
-- der Verlust fällt erst im Folgejahr auf — wenn überhaupt.
--
-- Die Oberfläche legt genau diesen Weg nahe; ihr Hinweistext spricht
-- ausdrücklich von Verlängerungen.
--
-- Jetzt wird ab dem späteren der beiden Zeitpunkte gerechnet: ab heute, wenn
-- nichts mehr läuft, sonst ab dem bisherigen Ende. Wer eine abgelaufene
-- Freischaltung erneuert, bekommt dieselbe Rechnung wie vorher.

create or replace function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic',
  zugaenge integer default null,           -- null = unverändert, 0 = zurücksetzen
  laufzeit interval default '1 year',
  belegnummer text default null,
  sponsoring boolean default null          -- null = unverändert
)
returns table (verein text, tarif text, grenze integer, sponsoren boolean, laeuft_bis timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  plan_id uuid;
  plan_code text;
  beleg text;
  bisheriges_ende timestamptz;
  beginn timestamptz;
begin
  if not exists (select 1 from public.clubs where id = target_club) then
    raise exception 'Verein % existiert nicht', target_club;
  end if;

  plan_code := 'club_' || lower(trim(stufe)) || '_yearly';
  select id into plan_id from public.subscription_plans where code = plan_code;
  if plan_id is null then
    raise exception 'Unbekannte Stufe "%" - erwartet basic, plus oder pro', stufe;
  end if;

  beleg := coalesce(
    nullif(trim(belegnummer), ''),
    'rechnung-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS') || '-' || left(target_club::text, 8)
  );

  /* Der Anschlusspunkt. Läuft noch etwas, wird daran angehängt; ist es
     abgelaufen oder gab es nie eines, beginnt die Laufzeit heute. */
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
     set status = 'freigeschaltet', handled_at = now()
   where r.status in ('offen', 'berechnet')
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
