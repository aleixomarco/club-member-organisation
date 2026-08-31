-- Eine vereinbarte Zugangsgrenze je Verein.
--
-- club_account_limit kannte bisher nur vier Werte: 100, 350, 1000 oder 3. Ein
-- Verein mit 2.000 Mitgliedern liess sich damit gar nicht abbilden - die
-- Stufe "auf Anfrage" stand zwar in den Texten, hatte aber keine Entsprechung
-- in der Datenbank.
--
-- Seit der Umstellung auf Rechnung wird ohnehin je Verein verhandelt. Also
-- gehoert die vereinbarte Zahl an den Verein, nicht in eine feste Staffel.
--
-- Die Staffel bleibt als Voreinstellung bestehen: Wer keinen eigenen Wert
-- hinterlegt hat, bekommt weiterhin die Zahl seines Tarifs. Der eigene Wert
-- gilt nur zusaetzlich zu einem laufenden Abo - ohne Freischaltung bleibt es
-- bei der kostenlosen Stufe, sonst waere die Grenze ein Weg, sie zu umgehen.

alter table public.clubs
  add column if not exists vereinbarte_zugaenge integer
  check (vereinbarte_zugaenge is null or vereinbarte_zugaenge > 0);

comment on column public.clubs.vereinbarte_zugaenge is
  'Individuell vereinbarte Zahl der Zugaenge, gesetzt vom Betreiber nach Angebot. Null bedeutet: es gilt die Zahl des Tarifs.';

create or replace function public.club_account_limit(target_club uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select case
    -- Ohne Freischaltung bleibt es bei der kostenlosen Stufe, auch wenn eine
    -- Zahl vereinbart wurde. Sonst liesse sich die Grenze durch einen Eintrag
    -- aushebeln, den niemand bezahlt hat.
    when public.club_subscription_tier(target_club) = 'none' then 3
    else coalesce(
      (select c.vereinbarte_zugaenge from public.clubs c where c.id = target_club),
      case public.club_subscription_tier(target_club)
        when 'basic' then 100
        when 'plus'  then 350
        when 'pro'   then 1000
        else 3
      end
    )
  end;
$$;

grant execute on function public.club_account_limit(uuid) to authenticated;

-- Kontrolle: Kein Verein darf seine bisherige Grenze verlieren.
select c.name,
       public.club_subscription_tier(c.id) as tarif,
       c.vereinbarte_zugaenge,
       public.club_account_limit(c.id) as grenze
from public.clubs c
order by c.name;
