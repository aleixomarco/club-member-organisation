-- Ziel im Repo: supabase/migrations/20260928010000_helfername_ohne_mitgliedschaft.sql
--
-- Ein Name an der Zuteilung - ohne Mitgliedschaft dahinter.
--
-- WUNSCH DES BETREIBERS (27.09.2026, KEHRTWENDE gegenueber 20260927190000):
-- "Die Personen, die bei den Aufgaben angelegt werden, aber keinen User haben,
-- sollen nicht fest als User hinterlegt werden, sondern nur fuer die eine
-- spezifische Aufgabe angelegt werden und nirgendwo weiter gespeichert.
-- Bitte daher 'Thorsten' und 'Michael Lyczuk' aus dem System loeschen, aber in
-- der Aufgabe drin lassen."
--
-- WAS SICH DAMIT UMKEHRT
-- Heute frueh bekam eine solche Person eine verwaltete Mitgliedschaft
-- (person_ohne_konto_anlegen). Das hatte den Vorteil, dass jede Zaehlung und
-- jede Liste sie wie jedes Mitglied behandelte. Der Preis war aber genau das,
-- was der Betreiber nicht will: Sie blieb im Verein stehen. Jetzt haengt der
-- Name an der Zuteilung und verschwindet mit ihr.
-- Die Kehrseite, bewusst in Kauf genommen: Derselbe Name laesst sich nicht
-- wiederverwenden. Wer beim naechsten Heimspiel wieder am Kuchenstand steht,
-- wird erneut eingetippt.
--
-- WAS DABEI NICHT BRICHT (27.09.2026 lesend gegen PROD geprueft)
-- Erstaunlich viel kommt mit einer Zeile ohne Mitgliedschaft von allein
-- zurecht, weil es Zeilen je Station zaehlt und nicht Mitgliedschaften:
--   helferdienst_eintrag_pruefen  Platzgrenze - zaehlt count(*) je Station
--   run_duty_gap_check            "Helfer gesucht" - dito, der Gast besetzt
--   offene_punkte_fuer_verein     dito
--   punkte_je_mitglied            zaehlt je Mitgliedschaft; ein Gast hat keine
--                                 und bekommt folgerichtig keine Punkte
--   helferdienst_einteilung_melden findet kein Profil und meldet nichts - auch
--                                 richtig, ein Gast hat kein Geraet
--   club_id_aus_elternteil        liest nur event_id
-- Kein einziger Fremdschluessel zeigt auf duty_assignments oder
-- club_task_assignees. In ganz PROD steht EINE Zuteilung. Ein Schluesselumbau
-- ist deshalb jetzt praktisch kostenlos - und nie wieder so guenstig.
--
-- WARUM EIN ERSATZSCHLUESSEL
-- membership_id steht heute im Primaerschluessel, und Schluesselspalten
-- duerfen nicht null sein. Statt des zusammengesetzten Schluessels also eine
-- eigene id - und die Eindeutigkeit ueber zwei TEILWEISE Indizes. Teilweise,
-- weil null in einem gewoehnlichen eindeutigen Index als verschieden gilt:
-- Ohne die Einschraenkung passte derselbe Gastname beliebig oft an dieselbe
-- Station, und niemand merkte es.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN.

-- ------------------------------------------------- Helferstationen
alter table public.duty_assignments
  add column if not exists gast_name text;

comment on column public.duty_assignments.gast_name is
  'Name einer Person ohne App-Konto, die nur fuer diesen einen Dienst eingetragen ist. Entweder membership_id ODER gast_name ist gesetzt, nie beides. Der Name wird nirgends sonst gespeichert und verschwindet mit der Zuteilung.';

do $$
begin
  if exists (select 1 from pg_constraint where conname = 'duty_assignments_pkey') then
    alter table public.duty_assignments drop constraint duty_assignments_pkey;
  end if;
end $$;

alter table public.duty_assignments
  alter column membership_id drop not null,
  add column if not exists id uuid not null default gen_random_uuid();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'duty_assignments_pkey') then
    alter table public.duty_assignments add constraint duty_assignments_pkey primary key (id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'duty_assignments_person_oder_gast') then
    alter table public.duty_assignments add constraint duty_assignments_person_oder_gast
      check ((membership_id is not null) <> (nullif(btrim(coalesce(gast_name, '')), '') is not null));
  end if;
end $$;

/* Ein Mitglied einmal je Station - wie der alte Primaerschluessel es hielt. */
create unique index if not exists duty_assignments_mitglied_je_station
  on public.duty_assignments (event_id, station, membership_id)
  where membership_id is not null;

/* Und ein Gastname einmal je Station, ohne Ruecksicht auf Gross- und
   Kleinschreibung: "Oma Meier" und "oma meier" sind dieselbe Person, und zwei
   gleiche Namen nebeneinander liest niemand als Versehen. */
create unique index if not exists duty_assignments_gast_je_station
  on public.duty_assignments (event_id, station, lower(btrim(gast_name)))
  where gast_name is not null;

-- ------------------------------------------------- Vereinsaufgaben
alter table public.club_task_assignees
  add column if not exists gast_name text;

comment on column public.club_task_assignees.gast_name is
  'Name einer Person ohne App-Konto, die nur fuer diese eine Aufgabe eingetragen ist. Entweder membership_id ODER gast_name ist gesetzt, nie beides.';

do $$
begin
  if exists (select 1 from pg_constraint where conname = 'club_task_assignees_pkey') then
    alter table public.club_task_assignees drop constraint club_task_assignees_pkey;
  end if;
end $$;

alter table public.club_task_assignees
  alter column membership_id drop not null,
  add column if not exists id uuid not null default gen_random_uuid();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'club_task_assignees_pkey') then
    alter table public.club_task_assignees add constraint club_task_assignees_pkey primary key (id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'club_task_assignees_person_oder_gast') then
    alter table public.club_task_assignees add constraint club_task_assignees_person_oder_gast
      check ((membership_id is not null) <> (nullif(btrim(coalesce(gast_name, '')), '') is not null));
  end if;
end $$;

create unique index if not exists club_task_assignees_mitglied_je_aufgabe
  on public.club_task_assignees (task_id, membership_id)
  where membership_id is not null;

create unique index if not exists club_task_assignees_gast_je_aufgabe
  on public.club_task_assignees (task_id, lower(btrim(gast_name)))
  where gast_name is not null;

-- ------------------------------------------------- Die Schreibregeln
/* Beide Regeln pruefen heute mitgliedschaft_im_verein(membership_id, ...), und
   das liefert bei null false - die Gastzeile waere abgewiesen, und zwar genau
   fuer die Rollen, die sie eintragen sollen. Der Rollensatz bleibt derselbe;
   nur der Gastfall kommt dazu.
   Die Regel "mitglied traegt sich selbst ein" bleibt unangetastet: Sie
   verlangt m.id = membership_id und passt fuer eine Gastzeile nie. Damit kann
   kein gewoehnliches Mitglied fremde Namen eintragen - genau so gewollt. */
drop policy if exists "leaders manage duties" on public.duty_assignments;
create policy "leaders manage duties" on public.duty_assignments
  for all using (
    exists (select 1 from public.events e
             where e.id = duty_assignments.event_id
               and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]))
  ) with check (
    exists (select 1 from public.events e
             where e.id = duty_assignments.event_id
               and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[])
               and (duty_assignments.membership_id is null
                    or public.mitgliedschaft_im_verein(duty_assignments.membership_id, e.club_id)))
  );

drop policy if exists "leaders manage task assignees" on public.club_task_assignees;
create policy "leaders manage task assignees" on public.club_task_assignees
  for all using (
    exists (select 1 from public.club_tasks t
             where t.id = club_task_assignees.task_id
               and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[]))
  ) with check (
    exists (select 1 from public.club_tasks t
             where t.id = club_task_assignees.task_id
               and public.has_club_role(t.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
               and (club_task_assignees.membership_id is null
                    or public.mitgliedschaft_im_verein(club_task_assignees.membership_id, t.club_id)))
  );

-- ------------------------------------------------- Die beiden Personen
/* ZUERST den Namen an die Zuteilung schreiben, DANN die Mitgliedschaft
   loeschen. Andersherum nimmt die Kaskade auf club_memberships die Zuteilung
   mit, und Michael Lyczuk waere aus der Station verschwunden - genau das
   Gegenteil dessen, was der Betreiber verlangt hat. */
update public.duty_assignments d
   set gast_name = m.display_name, membership_id = null
  from public.club_memberships m
 where m.id = d.membership_id and m.is_managed_profile and m.profile_id is null;

update public.club_task_assignees a
   set gast_name = m.display_name, membership_id = null
  from public.club_memberships m
 where m.id = a.membership_id and m.is_managed_profile and m.profile_id is null;

/* Erst jetzt weg. Getroffen werden genau die verwalteten Profile ohne Konto -
   am 27.09.2026 waren das "Thorsten" (nirgends eingetragen) und
   "Michael Lyczuk" (Station "Zeitnahme", Heimspiel am 11.10.2026). Betreute
   Kinderprofile aus der Familienfunktion traegen dasselbe Kennzeichen; in PROD
   gibt es davon null, und die Bedingung is_managed_profile and profile_id is
   null trifft sie gleichermassen - deshalb steht hier zusaetzlich die
   Einschraenkung auf solche ohne jede Familienverknuepfung. */
delete from public.club_memberships m
 where m.is_managed_profile
   and m.profile_id is null
   and not exists (select 1 from public.family_links f
                    where f.first_membership_id = m.id or f.second_membership_id = m.id);

-- ------------------------------------------------- Die Funktionen von heute frueh
/* person_ohne_konto_anlegen legte genau die Mitgliedschaft an, die jetzt nicht
   mehr entstehen soll. Bliebe sie stehen, koennte ein aelterer App-Stand
   weiter Karteileichen erzeugen. create_team_player bleibt: Eine Athletin ohne
   eigenes Handy gehoert sehr wohl in den Kader - das ist ein anderer Fall. */
drop function if exists public.person_ohne_konto_anlegen(uuid, text);
drop function if exists public.person_ohne_konto_entfernen(uuid);

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: gast_spalte_helfer = 1, gast_spalte_aufgaben = 1,
-- mitgliedschaft_darf_leer = 2, entweder_oder = 2, teilindizes = 4,
-- alte_funktionen_weg = 0, verwaltete_profile_weg = 0,
-- michael_steht_noch = 1.
select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='duty_assignments' and column_name='gast_name') as gast_spalte_helfer,
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='club_task_assignees' and column_name='gast_name') as gast_spalte_aufgaben,
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name in ('duty_assignments','club_task_assignees')
      and column_name='membership_id' and is_nullable='YES') as mitgliedschaft_darf_leer,
  (select count(*) from pg_constraint
    where conname in ('duty_assignments_person_oder_gast','club_task_assignees_person_oder_gast')) as entweder_oder,
  (select count(*) from pg_indexes where schemaname='public'
     and indexname in ('duty_assignments_mitglied_je_station','duty_assignments_gast_je_station',
                       'club_task_assignees_mitglied_je_aufgabe','club_task_assignees_gast_je_aufgabe')) as teilindizes,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('person_ohne_konto_anlegen','person_ohne_konto_entfernen')) as alte_funktionen_weg,
  (select count(*) from public.club_memberships
    where is_managed_profile and profile_id is null) as verwaltete_profile_weg,
  (select count(*) from public.duty_assignments
    where gast_name = 'Michael Lyczuk' and station = 'Zeitnahme') as michael_steht_noch;
