-- Was nur der Betreiber setzen darf, darf der Verein nicht überschreiben.
--
-- Auf clubs liegt seit den Vereinslogos die Regel "club admins update club
-- profile": Vereinsadmin und Sysadmin dürfen die ganze Zeile ändern. Das war
-- richtig, solange dort nur Name, Farben und Logo standen. Inzwischen stehen
-- dort drei Felder, über die der Betreiber entscheidet:
--
--   vereinbarte_zugaenge        die verhandelte Zahl der Zugänge
--   sponsoring_freigeschaltet   der Zusatz für eigene Sponsoren
--   referral_credit_months      gutgeschriebene Monate
--
-- Ein Vereinsadmin konnte bisher
--   update clubs set vereinbarte_zugaenge = 100000 where id = <sein Verein>
-- ausführen und sich damit von der Stufe basic (100 Zugänge, 239,99 €) auf
-- beliebig viele setzen. enforce_club_account_limit hätte die Konten
-- anschliessend anstandslos durchgelassen. Dasselbe galt für den
-- Sponsorenzusatz.
--
-- Spaltenweise Rechte helfen hier nicht: Sie greifen nicht, wenn eine
-- Policy den Zugriff auf die ganze Zeile erlaubt. Ein Trigger ist die
-- verlässliche Stelle — er sieht alten und neuen Wert und gilt für jeden Weg
-- in die Tabelle, auch für den, den es heute noch nicht gibt.

create or replace function public.betreiberfelder_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Der Dienstschlüssel des Betreibers darf alles. Er ist der einzige Weg,
  -- auf dem diese Felder überhaupt gesetzt werden sollen.
  if auth.role() = 'service_role' or auth.uid() is null then
    return new;
  end if;

  if new.vereinbarte_zugaenge is distinct from old.vereinbarte_zugaenge then
    raise exception 'Die Zahl der Zugaenge wird vom Betreiber vereinbart.' using errcode = 'P0001';
  end if;
  if new.sponsoring_freigeschaltet is distinct from old.sponsoring_freigeschaltet then
    raise exception 'Der Sponsorenzusatz wird vom Betreiber freigeschaltet.' using errcode = 'P0001';
  end if;
  if new.referral_credit_months is distinct from old.referral_credit_months then
    raise exception 'Gutgeschriebene Monate setzt der Betreiber.' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists clubs_betreiberfelder on public.clubs;
create trigger clubs_betreiberfelder before update on public.clubs
for each row execute function public.betreiberfelder_schuetzen();

/* Freischalten, ohne die Vereinbarung zu verlieren.
 *
 * zugaenge hat den Vorgabewert null, und null wurde bisher bedingungslos in
 * clubs.vereinbarte_zugaenge geschrieben. Der Normalfall - eine Verlängerung
 * mit verein_freischalten(verein, 'pro') - setzte damit eine vereinbarte Zahl
 * von 2.000 stillschweigend auf die Staffelzahl 1.000 zurück. Der Verein
 * konnte danach kein einziges Mitglied mehr aufnehmen.
 *
 * Jetzt gilt: Ein übergebener Wert wird gesetzt, kein übergebener Wert lässt
 * die Vereinbarung stehen. Zum Zurücksetzen gibt es zugaenge => 0. */
create or replace function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic',
  zugaenge integer default null,           -- null = unverändert lassen, 0 = zurücksetzen
  laufzeit interval default '1 year',
  belegnummer text default null,
  sponsoring boolean default null          -- null = unverändert lassen
)
returns table (verein text, tarif text, grenze integer, sponsoren boolean, laeuft_bis timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  plan_id uuid;
  plan_code text;
  beleg text;
begin
  if not exists (select 1 from public.clubs where id = target_club) then
    raise exception 'Verein % existiert nicht', target_club;
  end if;

  plan_code := 'club_' || lower(trim(stufe)) || '_yearly';
  select id into plan_id from public.subscription_plans where code = plan_code;
  if plan_id is null then
    raise exception 'Unbekannte Stufe "%" - erwartet basic, plus oder pro', stufe;
  end if;

  /* Die Belegnummer ist Teil eines eindeutigen Index (provider,
     provider_subscription_id). now() hat Sekundenauflösung und ist über die
     ganze Transaktion konstant - zwei Freischaltungen in einem Rutsch
     bekamen dieselbe Nummer und die zweite brach ab. Mit der Vereinskennung
     im Ersatzwert kann das nicht mehr passieren. */
  beleg := coalesce(
    nullif(trim(belegnummer), ''),
    'rechnung-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS') || '-' || left(target_club::text, 8)
  );

  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';

  insert into public.club_subscriptions
    (club_id, plan_id, provider, provider_subscription_id, status,
     current_period_start, current_period_end, last_payment_at)
  values
    (target_club, plan_id, 'manual', beleg,
     'active', now(), now() + laufzeit, now());

  update public.clubs
     set vereinbarte_zugaenge = case
           when zugaenge is null then vereinbarte_zugaenge
           when zugaenge <= 0 then null
           else zugaenge
         end,
         sponsoring_freigeschaltet = coalesce(sponsoring, sponsoring_freigeschaltet)
   where id = target_club;

  /* Auch die Anfragen von der Website abhaken. Die kommen ohne club_id an,
     wenn es den Verein damals noch nicht gab - genau der übliche Ablauf.
     Ohne diesen zweiten Vergleich blieben sie für immer offen und die
     Übersicht füllte sich mit Erledigtem. */
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

revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean) from public, authenticated, anon;
