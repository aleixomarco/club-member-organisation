-- Ziel im Repo: supabase/migrations/20260925180000_mitglied_aufgaben.sql
--
-- Aufgaben, die eine Person dauerhaft im Verein uebernimmt: "Ansprechpartner
-- Homepage", "Bewirtungsplan", "Platzwart". Dafuer gab es bisher keine Stelle.
--
-- WARUM EINE EIGENE TABELLE
-- Im Bestand heisst dreierlei "Aufgabe", und keines davon passt:
--   club_tasks + club_task_signups  Vereinsaufgabe mit Frist, Plaetzen und
--                                   Verantwortlichen ("Kuchenverkauf am 3.5.")
--   duty_tasks + duty_assignments   Helferstation an genau einem Termin
--   protocol_tasks                  To-do aus einem Sitzungsprotokoll
-- Alle drei haben Anfang und Ende: Faelligkeit, Erledigt-Zustand, danach sind
-- sie aus den Listen verschwunden. Eine Dauerzustaendigkeit ist das Gegenteil.
-- Sie in club_tasks zu legen haette zwei sichtbare Schaeden angerichtet: Die
-- Zeile stuende ohne erledigt_am fuer immer in offene_punkte_fuer_verein, und
-- aufgaben_erinnerung_senden haette am Vortag von nichts erinnert.
--
-- WARUM KEINE ROLLE
-- membership_roles traegt das Aufzaehlungsfeld public.club_role - einen festen
-- Satz, an dem Rechte, Kontingente und die Waechter rollensatz_bilden,
-- fan_exklusiv_pruefen und sync_club_role_entitlement haengen. Ein Freitext
-- wie "Homepage" gehoert dort nicht hinein. team_members.function ebenso
-- wenig: dort sind genau vier Mannschaftsfunktionen erlaubt.
--
-- WARUM EINE ZEILE JE AUFGABE UND KEINE SPALTE AN club_memberships
-- Eine Person kann fuer mehreres zustaendig sein. Dieselbe Begruendung wie in
-- 20260906140000_vereinsaufgaben_verantwortliche.sql: "Eine Spalte waere die
-- dritte Stelle, an der wir spaeter merken, dass eine nicht reicht."
--
-- RECHTE
-- Lesen: jedes aktive Mitglied des Vereins ausser einem reinen Fan. Wer im
-- Verein mitarbeitet, darf wissen, an wen er sich mit der Homepage wendet;
-- einen Fan geht die Vereinsarbeit nichts an (dieselbe Grenze wie beim
-- Fuhrpark, 20260925160000).
-- Pflegen: vereinsadmin, organisator, sysadmin - derselbe Satz, der auch die
-- Mitglieder selbst verwaltet (darfVereinVerwalten, app/page.tsx). Der
-- Organisator steht ausdruecklich mit dabei: Die alten Tabellenregeln
-- "admins manage memberships" kennen ihn nicht, und genau daraus entstand der
-- Fehler, den 20260911110000 fuer die Rollen beheben musste - die App zeigt
-- den Knopf, die Datenbank lehnt ab.
--
-- Fuer einen reinen Fan laesst sich keine Aufgabe hinterlegen. Sonst stuende
-- dort eine Zustaendigkeit, die die betroffene Person selbst nie zu sehen
-- bekaeme.
--
-- Geprueft am 25.09.2026 (nur lesend, PROD): Weder Tabelle noch Spalte dieses
-- Namens vorhanden; "ansprechpartner" gibt es bisher nur als Kontaktname bei
-- den Sponsoren und im Zugangsantrag an den Betreiber.
--
-- MUSS zusammen mit der App ausgeliefert werden.

create table if not exists public.mitglied_aufgaben (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  bezeichnung   text not null,
  erstellt_am   timestamptz not null default now(),
  /* Wer sie eingetragen hat. set null, damit ein Austritt die Aufgabe des
     anderen nicht mitnimmt - dieselbe Wahl wie in 20260830050000. */
  erstellt_von  uuid references public.club_memberships(id) on delete set null,
  constraint mitglied_aufgaben_bezeichnung_laenge
    check (char_length(btrim(bezeichnung)) between 1 and 80)
);

comment on table public.mitglied_aufgaben is
  'Dauerhafte Aufgaben einer Person im Verein, etwa "Ansprechpartner Homepage". Freitext, ohne Frist und ohne Erledigt-Zustand - im Unterschied zu club_tasks, duty_tasks und protocol_tasks.';
comment on column public.mitglied_aufgaben.bezeichnung is
  'Wofuer die Person zustaendig ist, in ihren eigenen Worten: "Homepage", "Bewirtungsplan", "Platzwart".';

/* Dieselbe Aufgabe zweimal bei derselben Person ist immer ein Versehen -
   meist ein zweiter Tipp auf "Hinzufuegen". Gross- und Kleinschreibung sowie
   Leerzeichen am Rand zaehlen dabei nicht. */
create unique index if not exists mitglied_aufgaben_je_person_eindeutig
  on public.mitglied_aufgaben (membership_id, lower(btrim(bezeichnung)));

/* Die Liste wird immer je Person gelesen, die Vereinsuebersicht je Verein. */
create index if not exists mitglied_aufgaben_verein_idx
  on public.mitglied_aufgaben (club_id, membership_id);

alter table public.mitglied_aufgaben enable row level security;

-- ----------------------------------------------------------------- Lesen
drop policy if exists "mitglieder ohne fans lesen aufgaben" on public.mitglied_aufgaben;
create policy "mitglieder ohne fans lesen aufgaben" on public.mitglied_aufgaben
  for select to authenticated
  using (public.is_club_member(club_id) and not public.ist_nur_fan(club_id));

-- ---------------------------------------------------------------- Pflegen
/* with check bindet die fremde membership_id ueber
   public.mitgliedschaft_im_verein an den Verein der Zeile. Ohne das koennte
   eine Leitung eine Aufgabe an eine Person eines anderen Vereins haengen -
   die Vereinsblase aus 20260914110000. Die Pruefung steht im with check und
   nicht nur im using, sonst verschoebe ein update die Zeile nachtraeglich. */
drop policy if exists "leitung pflegt mitglied aufgaben" on public.mitglied_aufgaben;
create policy "leitung pflegt mitglied aufgaben" on public.mitglied_aufgaben
  for all to authenticated
  using (
    public.has_club_role(club_id, array['vereinsadmin','organisator','sysadmin']::public.club_role[])
  )
  with check (
    public.has_club_role(club_id, array['vereinsadmin','organisator','sysadmin']::public.club_role[])
    and public.mitgliedschaft_im_verein(membership_id, club_id)
    and not public.mitgliedschaft_ist_fan(membership_id)
  );

/* Supabase vergibt neuen Tabellen in public die Rechte fuer anon und
   authenticated von selbst, service_role dagegen nicht. Beides hier
   ausdruecklich, damit die Regeln nicht an fehlenden Grants scheitern und
   nicht angemeldete Besucher gar nicht erst anklopfen. */
revoke all on table public.mitglied_aufgaben from public, anon;
grant select, insert, update, delete on table public.mitglied_aufgaben to authenticated;
grant all on table public.mitglied_aufgaben to service_role;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: tabelle = 1, zeilenregeln_an = true, leseregel und pflegeregel
-- gesetzt, vereinsgrenze_im_check = true, fanriegel_im_check = true,
-- authenticated_darf = true, anon_darf_nicht = false.
select (select count(*) from information_schema.tables
         where table_schema = 'public' and table_name = 'mitglied_aufgaben')            as tabelle,
       (select relrowsecurity from pg_class where oid = 'public.mitglied_aufgaben'::regclass) as zeilenregeln_an,
       (select string_agg(policyname, ' | ' order by policyname) from pg_policies
         where schemaname = 'public' and tablename = 'mitglied_aufgaben')               as regeln,
       (select position('mitgliedschaft_im_verein' in coalesce(with_check, '')) > 0 from pg_policies
         where schemaname = 'public' and tablename = 'mitglied_aufgaben' and cmd = 'ALL') as vereinsgrenze_im_check,
       (select position('mitgliedschaft_ist_fan' in coalesce(with_check, '')) > 0 from pg_policies
         where schemaname = 'public' and tablename = 'mitglied_aufgaben' and cmd = 'ALL') as fanriegel_im_check,
       (select has_table_privilege('authenticated', 'public.mitglied_aufgaben', 'INSERT')) as authenticated_darf,
       (select has_table_privilege('anon', 'public.mitglied_aufgaben', 'SELECT'))         as anon_darf_nicht;
