-- Ziel im Repo: supabase/migrations/20260928060000_anzeige_knopftext.sql
--
-- Der Knopf einer Anzeige bekommt einen eigenen Text.
--
-- WUNSCH DES BETREIBERS (28.09.2026): "Dieser Button zur Website soll auch
-- anpassbar sein, standardmaessig auf 'Hier klicken' statt 'Website ansehen'."
--
-- WARUM DAS MEHR IST ALS EINE BESCHRIFTUNG
-- "Website ansehen" beschreibt, was technisch passiert. Ein Sponsor wirbt aber
-- nicht fuer seine Website, sondern fuer ein Angebot - "Platz sichern",
-- "Termin buchen", "Zum Angebot". Wer den Text nicht aendern kann, bekommt
-- unter jede Anzeige denselben faden Satz. Die Vorgabe lautet deshalb ab jetzt
-- "Hier klicken": kurz, neutral und ohne Behauptung darueber, was am anderen
-- Ende steht.
--
-- Der Text ist freiwillig. Bleibt er leer, setzt die App ihre uebersetzte
-- Vorgabe ein - deshalb steht hier KEIN default in der Spalte: Ein deutscher
-- Standardwert in der Datenbank waere fuer einen tuerkischen Verein falsch,
-- und er liesse sich hinterher nicht mehr von einer bewussten Eingabe
-- unterscheiden.
--
-- WARUM DIE BEIDEN FUNKTIONEN NEU GEBAUT WERDEN
-- anzeige_fuer_platz und anzeigen_fuer_verein geben feste Spaltenlisten
-- zurueck (RETURNS TABLE). Eine Spalte mehr aendert den Rueckgabetyp, und den
-- kann create or replace nicht anfassen - also drop und neu. Dabei gehen die
-- Rechte verloren; sie werden unten wieder gesetzt, genau wie sie am
-- 28.09.2026 waren (ausfuehrbar fuer public und authenticated).
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Ohne die erweiterten
-- Funktionen kommt der Text nie auf dem Geraet an.

alter table public.anzeigen
  add column if not exists ziel_knopf text;

comment on column public.anzeigen.ziel_knopf is
  'Beschriftung des Knopfes, der zur Zieladresse fuehrt - z. B. "Platz sichern" statt der Vorgabe. Leer heisst: Die App setzt ihren uebersetzten Standardtext ein ("Hier klicken"). Bewusst ohne default, damit ein deutscher Text nicht in fremdsprachigen Vereinen landet.';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'anzeigen_ziel_knopf_laenge') then
    alter table public.anzeigen add constraint anzeigen_ziel_knopf_laenge
      check (ziel_knopf is null or length(ziel_knopf) <= 40);
  end if;
end $$;

-- ------------------------------------------------- Die beiden Leser
drop function if exists public.anzeigen_fuer_verein(uuid);
drop function if exists public.anzeige_fuer_platz(uuid, text);

create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table(id uuid, herkunft text, titel text, text text, bild_pfad text, ziel_url text,
              ziel_knopf text, telefon text, email text, aktion_titel text, aktion_text text,
              aktion_url text, aktion_bis timestamp with time zone, laeuft_bis timestamp with time zone)
language sql stable security definer set search_path to '' as $function$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft,
           /* Die Aktion hat einen eigenen Zeitraum innerhalb der Laufzeit des
              Sponsors. Läuft sie nicht, kommen ihre Felder leer zurück - der
              Sponsor bleibt stehen, der Aktionsknopf verschwindet von selbst. */
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
         l.ziel_knopf, l.telefon, l.email,
         case when l.aktion_laeuft then l.aktion_titel end,
         case when l.aktion_laeuft then l.aktion_text end,
         case when l.aktion_laeuft then l.aktion_url end,
         case when l.aktion_laeuft then l.aktion_bis end,
         l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$function$;

create or replace function public.anzeigen_fuer_verein(target_club uuid)
returns table(platz text, id uuid, herkunft text, titel text, text text, bild_pfad text,
              ziel_url text, ziel_knopf text, telefon text, email text, aktion_titel text,
              aktion_text text, aktion_url text, aktion_bis timestamp with time zone,
              laeuft_bis timestamp with time zone)
language sql stable security definer set search_path to '' as $function$
  select p.platz, a.id, a.herkunft, a.titel, a.text, a.bild_pfad,
         a.ziel_url, a.ziel_knopf, a.telefon, a.email,
         a.aktion_titel, a.aktion_text, a.aktion_url,
         a.aktion_bis, a.laeuft_bis
    from (values ('dashboard_top'), ('dashboard_bottom'), ('events_header'), ('profile_bottom')) as p(platz)
    cross join lateral public.anzeige_fuer_platz(target_club, p.platz) a;
$function$;

/* Genau die Rechte von vorher - am 28.09.2026 abgelesen: ausfuehrbar fuer
   public UND authenticated. Nach einem drop sind sie weg; ohne diese Zeilen
   saehe niemand mehr eine Anzeige. */
grant execute on function public.anzeige_fuer_platz(uuid, text) to public, authenticated;
grant execute on function public.anzeigen_fuer_verein(uuid) to public, authenticated;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: spalte_da = 1, spalte_erklaert = 1, laengengrenze = 1,
-- platz_gibt_knopf = true, verein_gibt_knopf = true, beide_ausfuehrbar = true.
select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='anzeigen' and column_name='ziel_knopf') as spalte_da,
  (select count(*) from pg_description d join pg_class c on c.oid=d.objoid
     join pg_attribute a on a.attrelid=c.oid and a.attnum=d.objsubid
    where c.relname='anzeigen' and a.attname='ziel_knopf') as spalte_erklaert,
  (select count(*) from pg_constraint where conname='anzeigen_ziel_knopf_laenge') as laengengrenze,
  (select pg_get_function_result(p.oid) like '%ziel_knopf%'
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='anzeige_fuer_platz') as platz_gibt_knopf,
  (select pg_get_function_result(p.oid) like '%ziel_knopf%'
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='anzeigen_fuer_verein') as verein_gibt_knopf,
  (select bool_and(has_function_privilege('authenticated', p.oid, 'execute'))
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('anzeige_fuer_platz','anzeigen_fuer_verein')) as beide_ausfuehrbar;
