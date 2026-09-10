-- Die "Klickrate" konnte über 100 % liegen.
--
-- fenster.klicks summierte die Klicks ALLER fünf Elemente (anzeige, website,
-- telefon, email, aktion), fenster.impressionen zählt aber nur Einblendungen -
-- und die entstehen ausschließlich am Element "anzeige". Wer ein Inserat
-- öffnet, die Webseite aufruft, anruft und schreibt, erzeugt vier "Klicks" bei
-- einer Einblendung. Die Oberfläche machte daraus 400 %.
--
-- Eine Quote über 100 % ist in einem Nachweis an einen zahlenden Sponsor
-- schlimmer als gar keine: Sie fällt auf, und danach glaubt niemand mehr die
-- übrigen Zahlen.
--
-- Statt an drei Stellen zu rechnen, liefert die Datenbank die beiden Zahlen
-- jetzt fertig. Damit ist ausgeschlossen, dass App, Konsole und Excel
-- auseinanderlaufen - sie hatten dieselbe Überschrift und zwei verschiedene
-- Grundmengen.
--
--   Einblendungen  wie oft das Inserat auf dem Platz stand
--   Öffnungen      wie oft es angetippt und aufgeklappt wurde   (element = anzeige)
--   Kontakte       wie oft danach ein Weg nach draußen genommen wurde
--                  (website, telefon, email, aktion)
--
-- Das ist ein Trichter: Jede Stufe ist eine Teilmenge der vorigen, und die
-- Öffnungsrate ist Öffnungen geteilt durch Einblendungen. Sie kann nicht mehr
-- über 100 % steigen.

create or replace function public.anzeigen_kennzahlen(ziel uuid, tage integer default 30)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  a public.anzeigen%rowtype;
  betreiber boolean := auth.role() = 'service_role';
  von date;
  bis date;
  ergebnis jsonb;
begin
  select * into a from public.anzeigen where id = ziel;
  if not found then
    raise exception 'Diese Anzeige gibt es nicht';
  end if;

  if a.club_id is null then
    if not betreiber then
      raise exception 'Die Zahlen einer Betreiberanzeige sieht nur der Betreiber';
    end if;
  elsif not betreiber
    and not public.has_club_role(a.club_id,
      array['sponsorenmanager','vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[]) then
    raise exception 'Keine Berechtigung für die Zahlen dieser Anzeige';
  end if;

  tage := greatest(1, least(coalesce(tage, 30), 730));
  bis := (now() at time zone 'Europe/Berlin')::date;
  von := bis - (tage - 1);

  select jsonb_build_object(
    'stand', now(),
    'anzeige', jsonb_build_object(
      'id', a.id,
      'titel', a.titel,
      'platz', a.platz,
      'herkunft', case when a.club_id is null then 'betreiber' else 'verein' end,
      'club_id', a.club_id,
      'aktiv', a.aktiv,
      'laeuft_von', a.laeuft_von,
      'laeuft_bis', a.laeuft_bis,
      'laeuft_gerade', a.aktiv and a.laeuft_von <= now() and (a.laeuft_bis is null or a.laeuft_bis > now()),
      'aktion_titel', a.aktion_titel,
      'ziel_url', a.ziel_url,
      'telefon', a.telefon,
      'email', a.email
    ),
    'zeitraum', jsonb_build_object('von', von, 'bis', bis, 'tage', tage),
    'gesamt', jsonb_build_object('impressionen', a.impressionen, 'klicks', a.klicks),
    'fenster', (
      select jsonb_build_object(
        'impressionen', coalesce(sum(s.impressionen), 0),
        'klicks', coalesce(sum(s.klicks), 0),
        /* Die beiden Stufen des Trichters, getrennt gerechnet. Wer die Quote
           bildet, nimmt oeffnungen - niemals klicks. */
        'oeffnungen', coalesce(sum(s.klicks) filter (where s.element = 'anzeige'), 0),
        'kontakte', coalesce(sum(s.klicks) filter (where s.element <> 'anzeige'), 0),
        'tage_mit_kontakt', count(distinct s.tag) filter (where s.klicks > 0 or s.impressionen > 0)
      )
      from public.anzeigen_statistik s
      where s.anzeige_id = ziel and s.tag between von and bis
    ),
    'verlauf', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'tag', d.tag, 'impressionen', coalesce(w.i, 0), 'klicks', coalesce(w.k, 0)
             ) order by d.tag), '[]'::jsonb)
      from generate_series(von::timestamp, bis::timestamp, interval '1 day') g(zeit)
      cross join lateral (select g.zeit::date as tag) d
      left join lateral (
        select sum(s.impressionen) as i, sum(s.klicks) as k
          from public.anzeigen_statistik s
         where s.anzeige_id = ziel and s.tag = d.tag
      ) w on true
    ),
    'elemente', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'element', e.element, 'klicks', e.klicks
             ) order by e.klicks desc, e.element), '[]'::jsonb)
      from (
        select s.element, sum(s.klicks) as klicks
          from public.anzeigen_statistik s
         where s.anzeige_id = ziel and s.tag between von and bis
         group by s.element
        having sum(s.klicks) > 0
      ) e
    ),
    'vereine', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'verein', v.name, 'club_id', v.id,
               'impressionen', v.impressionen, 'klicks', v.klicks
             ) order by v.klicks desc, v.impressionen desc), '[]'::jsonb)
      from (
        select c.id, c.name,
               sum(s.impressionen) as impressionen, sum(s.klicks) as klicks
          from public.anzeigen_statistik s
          join public.clubs c on c.id = s.club_id
         where s.anzeige_id = ziel and s.tag between von and bis
         group by c.id, c.name
      ) v
    ),
    'reichweite', (
      select count(*)
        from public.club_memberships m
       where m.status = 'active'
         and (a.club_id is null or m.club_id = a.club_id)
    )
  ) into ergebnis;

  return ergebnis;
end;
$$;

grant execute on function public.anzeigen_kennzahlen(uuid, integer) to authenticated;
grant execute on function public.anzeigen_kennzahlen(uuid, integer) to service_role;
