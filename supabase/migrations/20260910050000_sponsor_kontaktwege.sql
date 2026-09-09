-- Telefon und E-Mail bis in die Anzeige durchreichen.
--
-- Die beiden Spalten gibt es seit der letzten Migration, aber die App liest
-- eine Anzeige nicht aus der Tabelle, sondern über anzeigen_fuer_verein().
-- Deren Rückgabetyp kennt die neuen Felder nicht - also käme im Inserat kein
-- Telefonknopf an, und gezählt werden könnte er erst recht nicht.
--
-- Ein Rückgabetyp lässt sich nicht per "create or replace" erweitern; die
-- Funktionen müssen fallen und neu entstehen. Beides passiert hier in einer
-- Transaktion und in dieser Reihenfolge, damit zu keinem Zeitpunkt eine
-- Funktion auf eine fehlende zeigt.

drop function if exists public.anzeigen_fuer_verein(uuid);
drop function if exists public.anzeige_fuer_platz(uuid, text);

create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table (
  id uuid, herkunft text, titel text, text text, bild_pfad text, ziel_url text,
  telefon text, email text,
  aktion_titel text, aktion_text text, aktion_url text, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft
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
         l.telefon, l.email,
         l.aktion_titel, l.aktion_text, l.aktion_url, l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$$;

grant execute on function public.anzeige_fuer_platz(uuid, text) to authenticated;

create or replace function public.anzeigen_fuer_verein(target_club uuid)
returns table (
  platz text, id uuid, herkunft text, titel text, text text, bild_pfad text,
  ziel_url text, telefon text, email text,
  aktion_titel text, aktion_text text, aktion_url text, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.platz, a.id, a.herkunft, a.titel, a.text, a.bild_pfad,
         a.ziel_url, a.telefon, a.email,
         a.aktion_titel, a.aktion_text, a.aktion_url, a.laeuft_bis
    from (values ('dashboard_top'), ('dashboard_bottom'), ('events_header'), ('profile_bottom')) as p(platz)
    cross join lateral public.anzeige_fuer_platz(target_club, p.platz) a;
$$;

grant execute on function public.anzeigen_fuer_verein(uuid) to authenticated;
