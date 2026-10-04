-- Ziel im Repo: supabase/migrations/20261004100000_fehlerberichte.sql
--
-- Der Betreiber erfaehrt, wenn die App abstuerzt.
--
-- WARUM
-- Bisher gab es dafuer genau einen Weg: Ein Mitglied tippt im Profil auf
-- "Fehler melden" und schreibt eine E-Mail. Wer die App stumm abstuerzen
-- sieht, tut das fast nie - er laedt neu und macht weiter. Der Betreiber
-- erfuhr also nur von den Fehlern, die jemandem wichtig genug fuer eine Mail
-- waren.
-- Dazu kommt die kurze Spur: Vercel haelt seine Protokolle rund eine Stunde,
-- die Push-Antworten sechs. Wer am Montag von einem Fehler vom Samstag hoert,
-- findet nichts mehr.
--
-- Ab jetzt meldet die App sich selbst - bei einem abgestuerzten Bereich, bei
-- einem unbehandelten Fehler im Fenster und bei einem abgelehnten Versprechen.
--
-- WARUM EINE EIGENE TABELLE UND KEIN FREMDER DIENST
-- Ein Dienst wie Sentry waere schneller eingebaut, aber er bekaeme Stapel mit
-- Vereins- und Personennamen darin - und zwar in den USA. Fuer eine App mit
-- Kinderkonten ist das eine Entscheidung mit Vertrag und Eintrag in der
-- Datenschutzerklaerung. Die eigene Tabelle bleibt dort, wo die uebrigen
-- Daten des Vereins ohnehin liegen.
--
-- WARUM NIEMAND DIESE TABELLE DIREKT BESCHREIBT
-- RLS ist an, und es gibt KEINE einzige Regel. Das ist Absicht: Geschrieben
-- wird ausschliesslich ueber fehler_melden(), gelesen ausschliesslich von der
-- Betreiber-Konsole, die serverseitig mit dem Dienstschluessel arbeitet
-- (app/api/betreiber/daten/route.ts). Ein Mitglied kann weder fremde Fehler
-- lesen noch eigene faelschen.
--
-- WAS NICHT GESPEICHERT WIRD
-- Keine Eingaben des Nutzers, kein Seiteninhalt, keine Kennwoerter. Nur die
-- Fehlermeldung selbst, der gekuerzte Stapel, der Bereich der App und was
-- fuer ein Geraet es war. Die Mitgliedschaft steht dabei, damit der Betreiber
-- zurueckfragen kann - sie faellt weg, sobald die Mitgliedschaft geloescht
-- wird.
--
-- Geprueft am 04.10.2026 (nur lesend, PROD): weder Tabelle noch Funktion
-- dieses Namens vorhanden.
--
-- MUSS zusammen mit der App ausgeliefert werden.

create table if not exists public.fehlerberichte (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid references public.clubs(id) on delete cascade,
  membership_id uuid references public.club_memberships(id) on delete set null,
  gemeldet_am   timestamptz not null default now(),
  art           text not null check (art in ('bereich', 'fenster', 'versprechen')),
  meldung       text not null,
  stapel        text,
  bereich       text,
  geraet        text,
  fassung       text,
  erledigt_am   timestamptz,
  erledigt_von  text
);

comment on table public.fehlerberichte is
  'Selbstmeldungen der App bei einem Absturz. Geschrieben nur ueber fehler_melden(), gelesen nur von der Betreiber-Konsole mit dem Dienstschluessel. RLS ist an und hat bewusst keine Regel.';
comment on column public.fehlerberichte.art is
  'bereich = ein Teil der Oberflaeche ist abgestuerzt (React-Fehlergrenze); fenster = unbehandelter Fehler im Fenster; versprechen = abgelehntes Promise ohne catch.';
comment on column public.fehlerberichte.bereich is
  'Wo in der App es passierte - der Reiter bzw. die Unteransicht. Kein Seiteninhalt, keine Eingaben.';
comment on column public.fehlerberichte.membership_id is
  'Damit der Betreiber zurueckfragen kann. set null beim Austritt: Der Bericht bleibt auswertbar, die Person verschwindet daraus.';
comment on column public.fehlerberichte.erledigt_von is
  'Freitext - abgehakt wird in der Betreiber-Konsole, und der Betreiber ist kein Vereinsmitglied, hat also keine membership_id.';

create index if not exists fehlerberichte_offen
  on public.fehlerberichte (gemeldet_am desc) where erledigt_am is null;

alter table public.fehlerberichte enable row level security;
-- Mit Absicht KEINE Regel: siehe Kopf.

-- ------------------------------------------------- Melden
create or replace function public.fehler_melden(
  p_art text, p_meldung text, p_stapel text default null,
  p_bereich text default null, p_geraet text default null, p_fassung text default null)
returns void
language plpgsql security definer set search_path to 'public' as $function$
declare
  v_mitglied uuid;
  v_club uuid;
  v_meldung text := left(btrim(coalesce(p_meldung, '')), 500);
begin
  if auth.uid() is null then return; end if;
  if p_art is null or p_art not in ('bereich', 'fenster', 'versprechen') then return; end if;
  if v_meldung = '' then return; end if;

  /* Die aktive Mitgliedschaft des Anrufers. Gibt es mehrere (eine Person kann
     in zwei Vereinen sein), nimmt die zuletzt angelegte - genauer geht es
     nicht, ohne dass die App den Verein mitschickt, und das waere eine
     Angabe, die der Anrufer faelschen koennte. */
  select m.id, m.club_id into v_mitglied, v_club
    from public.club_memberships m
   where m.profile_id = auth.uid() and m.status = 'active'
   order by m.created_at desc nulls last limit 1;

  /* Gegen die Flut. Ein kaputter Bildschirm wirft denselben Fehler bei jedem
     Antippen neu; ohne diese Sperre stuenden in einer Minute hundert gleiche
     Zeilen, und der eine ANDERE Fehler ginge darin unter. Zehn Minuten je
     Person und Meldung reichen: Wer den Fehler zweimal am Tag trifft, soll
     beide Male zaehlen. */
  if exists (select 1 from public.fehlerberichte f
              where f.membership_id is not distinct from v_mitglied
                and f.meldung = v_meldung
                and f.gemeldet_am > now() - interval '10 minutes') then
    return;
  end if;

  insert into public.fehlerberichte
    (club_id, membership_id, art, meldung, stapel, bereich, geraet, fassung)
  values (v_club, v_mitglied, p_art, v_meldung,
          left(btrim(coalesce(p_stapel, '')), 4000),
          left(btrim(coalesce(p_bereich, '')), 60),
          left(btrim(coalesce(p_geraet, '')), 120),
          left(btrim(coalesce(p_fassung, '')), 60));
end;
$function$;

revoke all on function public.fehler_melden(text, text, text, text, text, text) from public, anon;
grant execute on function public.fehler_melden(text, text, text, text, text, text) to authenticated;

-- ------------------------------------------------- Aufraeumen
/* Angehaengt an den woechentlichen Lauf, der schon die Glocke und die
   Warteschlange raeumt (20260903110000). Ein eigener Auftrag waere der
   neunte in cron.job fuer eine Zeile Arbeit.
   Ein Jahr fuer erledigte, zwei Jahre fuer alle: Wer im Herbst wissen will,
   ob ein Fehler schon im Fruehjahr auftrat, soll ihn noch finden. */
create or replace function public.run_fehlerberichte_aufraeumen()
returns integer
language sql security definer set search_path to '' as $function$
  with weg as (
    delete from public.fehlerberichte
     where (erledigt_am is not null and erledigt_am < now() - interval '365 days')
        or gemeldet_am < now() - interval '730 days'
    returning 1
  )
  select count(*)::int from weg;
$function$;

revoke execute on function public.run_fehlerberichte_aufraeumen() from public, anon, authenticated;

select cron.unschedule('fehlerberichte-aufraeumen')
 where exists (select 1 from cron.job where jobname = 'fehlerberichte-aufraeumen');
select cron.schedule('fehlerberichte-aufraeumen', '45 4 * * 0',
  $$select public.run_fehlerberichte_aufraeumen();$$);

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: tabelle_da = true, rls_an = true, regeln = 0, melden_da = true,
--           melden_fuer_angemeldete = true, aufraeumen_nur_cron = true,
--           auftrag_da = 1, art_eingeschraenkt = true.
select
  (select count(*) = 1 from pg_tables
    where schemaname = 'public' and tablename = 'fehlerberichte') as tabelle_da,
  (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'fehlerberichte') as rls_an,
  /* Keine Regel ist hier das Ziel, nicht ein Versehen. */
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'fehlerberichte') as regeln,
  (select count(*) = 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fehler_melden') as melden_da,
  has_function_privilege('authenticated',
    'public.fehler_melden(text,text,text,text,text,text)', 'execute') as melden_fuer_angemeldete,
  not has_function_privilege('authenticated',
    'public.run_fehlerberichte_aufraeumen()', 'execute') as aufraeumen_nur_cron,
  (select count(*) from cron.job where jobname = 'fehlerberichte-aufraeumen') as auftrag_da,
  (select count(*) = 1 from pg_constraint
    where conrelid = 'public.fehlerberichte'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) like '%bereich%') as art_eingeschraenkt;
