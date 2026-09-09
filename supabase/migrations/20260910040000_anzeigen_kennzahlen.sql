-- Kennzahlen für Anzeigen und Sponsoren.
--
-- Bisher trug jede Anzeige genau zwei Zahlen: impressionen und klicks. Als
-- Nachweis gegenüber jemandem, der für den Platz bezahlt, reicht das nicht.
-- Ein Sponsor fragt drei Dinge, und keines davon steht in einer Gesamtsumme:
--
--   "Wie lief es im letzten Monat?"   -> braucht eine Zeitachse
--   "Was haben die Leute angetippt?"  -> braucht eine Aufschlüsselung
--   "In welchen Vereinen lief das?"   -> braucht die Herkunft
--
-- Deshalb kommt neben die Gesamtsumme eine Tagesstatistik. Bewusst als
-- TAGESSUMME und nicht als Einzelereignis: Wer jeden Antipp mit Zeitstempel
-- und Mitglied speichert, legt eine Bewegungsaufzeichnung über die Mitglieder
-- an - für eine Auswertung, die niemand auf dieser Ebene braucht. Eine Zeile
-- pro Anzeige, Verein, Tag und Element sagt alles, was ein Sponsorenbericht
-- aussagen soll, und über die einzelne Person nichts.
--
-- Der Verein ist mitgespeichert, weil eine Betreiberanzeige (club_id null) in
-- jedem Verein läuft. Ohne diese Spalte wüsste man die Gesamtzahl, aber nicht,
-- welcher Verein sie trägt - und genau das ist die Zahl, die man beim Verkauf
-- eines Werbeplatzes braucht.

/* Zwei weitere Kontaktwege im Inserat. Der Sponsor will nicht nur eine
   Webseite verlinken, sondern auch erreichbar sein - und genau diese
   Antipper sind es, die er hinterher gezählt haben will. */
alter table public.anzeigen
  add column if not exists telefon text
    check (telefon is null or char_length(trim(telefon)) between 3 and 40),
  add column if not exists email text
    check (email is null or char_length(trim(email)) between 5 and 160);

comment on column public.anzeigen.telefon is
  'Rufnummer des Sponsors. Erscheint als eigener Knopf im Inserat und wird getrennt gezählt.';
comment on column public.anzeigen.email is
  'E-Mail-Adresse des Sponsors. Erscheint als eigener Knopf im Inserat und wird getrennt gezählt.';

create table if not exists public.anzeigen_statistik (
  anzeige_id uuid not null references public.anzeigen(id) on delete cascade,
  -- In welchem Verein der Kontakt entstand. Bei einer Vereinsanzeige immer
  -- deren eigener; bei einer Betreiberanzeige der Verein, in dem sie stand.
  club_id uuid not null references public.clubs(id) on delete cascade,
  tag date not null,
  element text not null check (element in ('anzeige', 'aktion', 'website', 'telefon', 'email')),
  impressionen bigint not null default 0,
  klicks bigint not null default 0,
  primary key (anzeige_id, club_id, tag, element)
);

comment on table public.anzeigen_statistik is
  'Tagessummen je Anzeige, Verein und Element. Keine Einzelereignisse, kein Personenbezug.';

/* Für den Verlauf einer Anzeige über die Zeit - der häufigste Zugriff. Der
   Primärschlüssel beginnt mit anzeige_id, deckt diesen Fall also mit ab; der
   Index hier hilft der umgekehrten Frage "was lief in diesem Verein". */
create index if not exists anzeigen_statistik_verein_idx
  on public.anzeigen_statistik(club_id, tag);

alter table public.anzeigen_statistik enable row level security;

/* Absichtlich ohne Richtlinie für authenticated: Gelesen wird ausschließlich
   über anzeigen_kennzahlen() weiter unten, geschrieben ausschließlich über
   anzeige_ereignis(). Beide prüfen selbst, wer fragen darf. Eine offene
   Leserichtlinie hier wäre ein zweiter Weg an derselben Prüfung vorbei. */
grant select, insert, update on public.anzeigen_statistik to service_role;

/* Ein Kontakt mit einer Anzeige.
 *
 * Tritt neben anzeige_zaehlen(), ersetzt es aber nicht per "create or
 * replace" mit zusätzlichen Parametern: Eine Funktion mit Vorgabewerten neben
 * der alten ergibt zwei Kandidaten für denselben Aufruf, und PostgREST bricht
 * dann mit "function is not unique" ab - im laufenden Betrieb. Ein eigener
 * Name kann das nicht. Die alte Funktion bleibt, solange noch eine ältere
 * App-Fassung unterwegs sein kann, und wird danach entfernt.
 *
 * Der Tag ist deutsche Ortszeit, nicht UTC. Sonst fällt ein Antipp um 01:00
 * in Iserlohn auf den Vortag, und der Sponsorenbericht widerspricht dem
 * Kalender des Sponsors. */
create or replace function public.anzeige_ereignis(ziel uuid, art text, teil text, verein uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  gehoert_zu uuid;
  gefunden boolean;
begin
  if auth.uid() is null then return; end if;
  if art not in ('impression', 'klick') then
    raise exception 'Unbekannte Art "%"', art;
  end if;
  if teil not in ('anzeige', 'aktion', 'website', 'telefon', 'email') then
    raise exception 'Unbekanntes Element "%"', teil;
  end if;

  /* Gezählt wird nur an Anzeigen, die der Aufrufer auch sehen darf - sonst
     ließe sich die Zahl eines fremden Sponsors von außen hochtreiben. */
  select a.club_id, true into gehoert_zu, gefunden
    from public.anzeigen a
   where a.id = ziel
     and (a.club_id is null or public.is_club_member(a.club_id));
  if not coalesce(gefunden, false) then return; end if;

  /* Der genannte Verein muss einer sein, in dem der Aufrufer Mitglied ist -
     und bei einer Vereinsanzeige genau der, dem sie gehört. Ohne diese
     Prüfung könnte jedes Mitglied Kontakte einem beliebigen Verein
     zuschreiben und damit fremde Berichte verfälschen. */
  if verein is null or not public.is_club_member(verein) then return; end if;
  if gehoert_zu is not null and gehoert_zu <> verein then return; end if;

  update public.anzeigen a
     set impressionen = a.impressionen + case when art = 'impression' then 1 else 0 end,
         klicks       = a.klicks       + case when art = 'klick'      then 1 else 0 end
   where a.id = ziel;

  insert into public.anzeigen_statistik (anzeige_id, club_id, tag, element, impressionen, klicks)
  values (ziel, verein, (now() at time zone 'Europe/Berlin')::date, teil,
          case when art = 'impression' then 1 else 0 end,
          case when art = 'klick' then 1 else 0 end)
  on conflict (anzeige_id, club_id, tag, element) do update
     set impressionen = public.anzeigen_statistik.impressionen + excluded.impressionen,
         klicks       = public.anzeigen_statistik.klicks       + excluded.klicks;
end;
$$;

grant execute on function public.anzeige_ereignis(uuid, text, text, uuid) to authenticated;

/* Die Zahlen einer Anzeige - alles, was ein Bericht braucht, in einer Antwort.
 *
 * Ein einziger Aufruf statt vier, weil die Oberfläche sie zusammen zeigt und
 * vier Abfragen vier Ladezustände bedeuten, die nacheinander eintrudeln.
 *
 * Wer fragen darf:
 *   Vereinsanzeige    Sponsorenmanager und Vereinsleitung dieses Vereins.
 *   Betreiberanzeige  Nur der Dienstschlüssel. Kein Verein soll sehen, wie
 *                     die Werbung in anderen Vereinen läuft.
 */
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

  /* Ein unsinniger Zeitraum wird zurechtgebogen statt abgelehnt: Die Zahl
     kommt aus einer Auswahlliste, ein Fehler dort ist kein Grund, dem
     Sponsorenmanager eine Fehlermeldung zu zeigen. */
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
    /* Die Gesamtsumme über die ganze Laufzeit. Sie steht neben dem Zeitraum
       und nicht statt seiner: Wer im dritten Monat fragt, will beides. */
    'gesamt', jsonb_build_object('impressionen', a.impressionen, 'klicks', a.klicks),
    'fenster', (
      select jsonb_build_object(
        'impressionen', coalesce(sum(s.impressionen), 0),
        'klicks', coalesce(sum(s.klicks), 0),
        'tage_mit_kontakt', count(distinct s.tag) filter (where s.klicks > 0 or s.impressionen > 0)
      )
      from public.anzeigen_statistik s
      where s.anzeige_id = ziel and s.tag between von and bis
    ),
    /* Jeder Tag des Zeitraums, auch die leeren. Eine Kurve, die nur die Tage
       mit Kontakten zeigt, sieht gleichmäßig aus, wo eine Lücke war. */
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
    /* Mögliche Reichweite - keine gemessene Zahl, sondern wie viele Menschen
       die Anzeige überhaupt sehen können. Sie gehört dazu, weil ein Sponsor
       sonst 200 Einblendungen ohne Maßstab liest. */
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
