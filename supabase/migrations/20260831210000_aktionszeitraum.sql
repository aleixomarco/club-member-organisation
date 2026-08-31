-- Zwei Zeiträume statt einem.
--
-- Bisher hatte die Anzeige nur eine Laufzeit, und weil eine Aktion ein Ende
-- braucht, hing beides daran. Das hatte eine Folge, die niemand wollte: Endete
-- die Rabattaktion, verschwand der Sponsor gleich mit — und der Werbeplatz
-- fiel an den Betreiber zurück, obwohl der Verein den Platz für die Saison
-- vergeben hatte.
--
-- Es sind zwei Dinge:
--
--   laeuft_von/laeuft_bis   Wie lange der Sponsor auf dem Platz steht. Ohne
--                           Ende: bis der Verein ihn entfernt.
--   aktion_von/aktion_bis   Wie lange die Aktion beworben wird. Immer mit
--                           Ende — eine Aktion, die niemand zurücknimmt, ist
--                           irgendwann eine Lüge.
--
-- Danach passiert genau das Erwartete: Am 1. November ist der Oktoberrabatt
-- weg, das Sponsorenlogo steht weiter.

alter table public.anzeigen
  add column if not exists aktion_von timestamptz,
  add column if not exists aktion_bis timestamptz;

-- Was es schon gibt, behält sein bisheriges Verhalten: Aktionszeitraum gleich
-- Anzeigenzeitraum.
update public.anzeigen
   set aktion_von = coalesce(aktion_von, laeuft_von),
       aktion_bis = coalesce(aktion_bis, laeuft_bis)
 where aktion_titel is not null;

alter table public.anzeigen drop constraint if exists anzeigen_aktion_hat_ende;
alter table public.anzeigen drop constraint if exists anzeigen_aktion_ende_nach_beginn;
alter table public.anzeigen
  add constraint anzeigen_aktion_hat_ende
  check (aktion_titel is null or aktion_bis is not null);
alter table public.anzeigen
  add constraint anzeigen_aktion_ende_nach_beginn
  check (aktion_bis is null or aktion_von is null or aktion_bis > aktion_von);

/* Was auf einem Platz gerade zu sehen ist.
 *
 * Rangfolge unverändert: eigener, laufender Sponsor des Vereins vor der Werbung
 * des Betreibers, sonst bleibt der Platz frei.
 *
 * Neu ist, dass die Aktion getrennt geprüft wird. Läuft sie nicht (noch nicht,
 * nicht mehr, oder gibt es gar keine), kommen die Aktionsfelder leer zurück -
 * die Oberfläche muss dann nichts entscheiden und kann auch nichts falsch
 * machen. Der Sponsor selbst bleibt stehen. */
-- Die Spaltenliste aendert sich, und "create or replace" darf das nicht. Erst
-- die abhaengige Funktion weg, dann diese.
drop function if exists public.anzeigen_fuer_verein(uuid);
drop function if exists public.anzeige_fuer_platz(uuid, text);
create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table (
  id uuid, herkunft text, titel text, text text, bild_pfad text, ziel_url text,
  aktion_titel text, aktion_text text, aktion_url text, aktion_bis timestamptz,
  laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft,
           (a.aktion_titel is not null
            and coalesce(a.aktion_von, a.laeuft_von) <= now()
            and a.aktion_bis > now()) as aktion_laeuft
      from public.anzeigen a
     where a.platz = ziel_platz
       and a.aktiv
       and a.laeuft_von <= now()
       and (a.laeuft_bis is null or a.laeuft_bis > now())
       and (
         a.club_id is null
         or (a.club_id = target_club
             and exists (select 1 from public.clubs c
                          where c.id = target_club and c.sponsoring_freigeschaltet))
       )
  )
  select l.id, l.herkunft, l.titel, l.text, l.bild_pfad, l.ziel_url,
         case when l.aktion_laeuft then l.aktion_titel end,
         case when l.aktion_laeuft then l.aktion_text end,
         case when l.aktion_laeuft then l.aktion_url end,
         case when l.aktion_laeuft then l.aktion_bis end,
         l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$$;

grant execute on function public.anzeige_fuer_platz(uuid, text) to authenticated;

create or replace function public.anzeigen_fuer_verein(target_club uuid)
returns table (
  platz text, id uuid, herkunft text, titel text, text text, bild_pfad text,
  ziel_url text, aktion_titel text, aktion_text text, aktion_url text,
  aktion_bis timestamptz, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.platz, a.id, a.herkunft, a.titel, a.text, a.bild_pfad,
         a.ziel_url, a.aktion_titel, a.aktion_text, a.aktion_url,
         a.aktion_bis, a.laeuft_bis
    from (values ('dashboard_top'), ('dashboard_bottom'), ('events_header'), ('profile_bottom')) as p(platz)
    cross join lateral public.anzeige_fuer_platz(target_club, p.platz) a;
$$;

grant execute on function public.anzeigen_fuer_verein(uuid) to authenticated;
