-- Spielergebnisse: wer sie eintragen darf und was die Datenbank annimmt.
--
-- Betreiberentscheidung vom 13.09.2026, Punkt 3: Neben Vereinsadministration
-- und Sysadmin tragen die Organisation (vereinsweit) sowie Trainer, Kapitaen
-- und Teammanager einer Mannschaft (nur deren Spiele) Ergebnisse ein. Dieselbe
-- Regel wie beim Anlegen und Aendern von Terminen
-- (20260906310000_wer_darf_termine_anlegen.sql:28-50). Die Mannschaftsfunktion
-- zaehlt nur mit einer Zeile in team_members, wie in can_manage_team
-- (20260801160000_initial_schema.sql:308-316); die Vereinsrolle allein reicht nicht.
--
-- Die Speicherung bleibt wir : Gegner (20260905070000:27-30). Angezeigt und
-- eingegeben wird Heim : Gast, umgerechnet ausschliesslich in lib/ergebnis.mjs
-- (App) und public.ergebnis_meldewerte (Meldungen, 20260914100100).
--
-- Rueckwaertsvertraeglich mit der laufenden App: Admins behalten ihre Rechte.
-- Neu abgelehnt wird nur, was ohnehin falsch war: Spiele in der Zukunft,
-- abgesagte Spiele, Nicht-Spiele, Spiele ohne Spielort, fremde Vereine.
-- Bis zum Merge bietet die alte App noch kuenftige Spiele an: Deren Eingabe
-- scheitert jetzt, die Zahl steht bis zum Neuladen trotzdem da. Deshalb den
-- Merge gleich nach den Proben (Freigabeplan, Schritt 6).

-- ------------------------------------------------------------------ Recht
-- Mit ausdruecklichem Profil: lesend pruefbar und von der Erinnerung
-- (20260914100200) wiederverwendet - wer erinnert wird, darf auch eintragen.
create or replace function public.darf_ergebnis_eintragen_fuer(p_profile uuid, p_club uuid, p_event uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_profile is not null and exists (
    select 1
      from public.events e
      join public.club_memberships m
        on m.club_id = e.club_id and m.profile_id = p_profile and m.status = 'active'
     where e.id = p_event
       and e.club_id = p_club
       and (
         exists (select 1 from public.membership_roles r
                  where r.membership_id = m.id
                    and r.role in ('vereinsadmin', 'sysadmin', 'organisator'))
         or (e.team_id is not null and exists (
               select 1 from public.team_members tm
                where tm.membership_id = m.id
                  and tm.team_id = e.team_id
                  and tm.function in ('trainer', 'kapitaen', 'teammanager')))
       )
  );
$$;
revoke all on function public.darf_ergebnis_eintragen_fuer(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.darf_ergebnis_eintragen_fuer(uuid, uuid, uuid) to service_role;

-- Die Regeln rufen diese Form auf. Sie MUSS fuer authenticated ausfuehrbar
-- bleiben - eine spaetere Aufraeumrunde wie 20260907110000 darf sie nicht treffen.
create or replace function public.darf_ergebnis_eintragen(p_club uuid, p_event uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.darf_ergebnis_eintragen_fuer(auth.uid(), p_club, p_event);
$$;
revoke all on function public.darf_ergebnis_eintragen(uuid, uuid) from public, anon;
grant execute on function public.darf_ergebnis_eintragen(uuid, uuid) to authenticated, service_role;

comment on function public.darf_ergebnis_eintragen(uuid, uuid) is
  'Darf der angemeldete Nutzer das Ergebnis dieses Spiels eintragen, korrigieren oder entfernen? Vereinsadmin, Sysadmin und Organisator vereinsweit; Trainer, Kapitaen und Teammanager (Zeile in team_members) fuer die Spiele ihrer Mannschaft. Von den Regeln auf event_results benutzt - muss fuer authenticated ausfuehrbar bleiben.';

-- --------------------------------------------------------------- Regeln
-- Die App schreibt per upsert onConflict club_id,event_id (app/page.tsx, ergebnisSpeichern):
-- INSERT ... ON CONFLICT DO UPDATE braucht INSERT, UPDATE und SELECT - alle drei
-- sind abgedeckt. SELECT bleibt bei "ergebnisse lesbar" (is_club_member), damit
-- Fans alle Ergebnisse sehen.
drop policy if exists "ergebnisse pflegen"     on public.event_results;
drop policy if exists "ergebnisse eintragen"   on public.event_results;
drop policy if exists "ergebnisse korrigieren" on public.event_results;
drop policy if exists "ergebnisse entfernen"   on public.event_results;

create policy "ergebnisse eintragen" on public.event_results for insert to authenticated
  with check (public.darf_ergebnis_eintragen(club_id, event_id));

create policy "ergebnisse korrigieren" on public.event_results for update to authenticated
  using (public.darf_ergebnis_eintragen(club_id, event_id))
  with check (public.darf_ergebnis_eintragen(club_id, event_id));

create policy "ergebnisse entfernen" on public.event_results for delete to authenticated
  using (public.darf_ergebnis_eintragen(club_id, event_id));

-- ------------------------------------------------------------ Pruefung
-- Der Grund als reine Funktion: lesend auf PROD pruefbar. null = in Ordnung.
-- Die Werte sind App-Schluessel (lib/sprachen.ts) und kommen als HINT an.
create or replace function public.ergebnis_pruefgrund(p_club uuid, p_event uuid, p_wir integer, p_gegner integer)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when e.id is null                      then 'erg.fehler.fehlt'
    when e.club_id is distinct from p_club then 'erg.fehler.fremderVerein'
    when e.type is distinct from 'spiel'   then 'erg.fehler.keinSpiel'
    when e.status = 'cancelled'            then 'erg.fehler.abgesagt'
    when e.starts_at > now()               then 'erg.fehler.zukunft'
    when e.home_away is null               then 'erg.fehler.ortFehlt'
    when p_wir is null or p_gegner is null
      or p_wir not between 0 and 99
      or p_gegner not between 0 and 99     then 'erg.fehler.bereich'
  end
  from (select 1) as eins
  left join public.events e on e.id = p_event;
$$;
revoke all on function public.ergebnis_pruefgrund(uuid, uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.ergebnis_pruefgrund(uuid, uuid, integer, integer) to service_role;

-- BEFORE-Ausloeser: laeuft vor den CHECKs tipp_results_heim_check und
-- tipp_results_auswaerts_check, damit der lesbare Hinweis gewinnt, und vor
-- tipp_results_touch (Reihenfolge nach Namen). DELETE bleibt bewusst ungeprueft:
-- das verwaiste Ergebnis am abgesagten Spiel laesst sich weiter entfernen.
create or replace function public.ergebnis_pruefen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_grund    text;
  v_mitglied uuid;
begin
  if tg_op = 'UPDATE'
     and (new.club_id is distinct from old.club_id or new.event_id is distinct from old.event_id) then
    raise exception using
      message = 'Ein Ergebnis bleibt an seinem Spiel.',
      errcode = 'check_violation',
      hint    = 'erg.fehler.verschoben';
  end if;

  -- Der Fremdschluessel erfasst_von -> club_memberships (on delete set null,
  -- 20260901130000:35) leert die Spalte, wenn ein Mitglied entfernt, ein Konto
  -- geloescht (app/api/account/delete) oder ein Verein aufgeloest wird
  -- (konto_loeschung_abschliessen). Das ist kein neues Ergebnis: weder pruefen
  -- noch umschreiben. Sonst scheiterte das Loeschen am Ergebnis eines inzwischen
  -- abgesagten Spiels (auf PROD gibt es eines), und beim Entfernen durch einen
  -- Admin stuende danach dessen Mitgliedschaft als Erfasser da.
  -- pg_trigger_depth() > 1: nur wenn ein anderer Ausloeser - hier die
  -- Fremdschluesselaktion - die Zeile aendert. Ein direktes UPDATE aus der App
  -- kommt so nicht an der Pruefung vorbei.
  if tg_op = 'UPDATE'
     and pg_trigger_depth() > 1
     and old.erfasst_von is not null and new.erfasst_von is null
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  v_grund := public.ergebnis_pruefgrund(new.club_id, new.event_id, new.heim, new.auswaerts);
  if v_grund is not null then
    raise exception using
      message = 'Ergebnis abgelehnt: ' || v_grund,
      errcode = 'check_violation',
      hint    = v_grund;
  end if;

  -- erfasst_von heisst ab jetzt: wer zuletzt eingetragen oder korrigiert hat.
  -- Aufrufe ohne Anmeldung (service_role, SQL) behalten, was sie mitgeben.
  if auth.uid() is not null then
    select m.id into v_mitglied
      from public.club_memberships m
     where m.club_id = new.club_id and m.profile_id = auth.uid() and m.status = 'active'
     limit 1;
    new.erfasst_von := v_mitglied;
  end if;

  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;
revoke all on function public.ergebnis_pruefen() from public, anon, authenticated;

drop trigger if exists event_results_pruefen on public.event_results;
create trigger event_results_pruefen
  before insert or update on public.event_results
  for each row execute function public.ergebnis_pruefen();

-- ------------------------------------------------------- Bedeutung festhalten
comment on column public.event_results.heim is
  'Tore UNSERER Mannschaft, unabhaengig vom Spielort - NICHT die Tore der Heimmannschaft. Angezeigt und eingegeben wird Heim:Gast; umgerechnet ausschliesslich in lib/ergebnis.mjs (App) und public.ergebnis_meldewerte (Meldungen) anhand von events.home_away.';
comment on column public.event_results.auswaerts is
  'Tore des GEGNERS, unabhaengig vom Spielort - NICHT die Tore der Gastmannschaft. Siehe event_results.heim.';
comment on column public.predictions.home_score is
  'Getippte Tore UNSERER Mannschaft - dieselbe Bedeutung wie event_results.heim, nicht Heimmannschaft.';
comment on column public.predictions.away_score is
  'Getippte Tore des GEGNERS - dieselbe Bedeutung wie event_results.auswaerts.';

-- Erwartet: regeln = ergebnisse entfernen:DELETE, ergebnisse eintragen:INSERT,
-- ergebnisse lesbar:SELECT, ergebnisse korrigieren:UPDATE; pruefung_aktiv = 1;
-- regelhelfer_ausfuehrbar = true; innerer_helfer_offen = false.
select
  (select string_agg(policyname || ':' || cmd, ', ' order by cmd, policyname)
     from pg_policies where schemaname = 'public' and tablename = 'event_results') as regeln,
  (select count(*) from pg_trigger
    where tgrelid = 'public.event_results'::regclass
      and tgname = 'event_results_pruefen' and tgenabled <> 'D') as pruefung_aktiv,
  has_function_privilege('authenticated', 'public.darf_ergebnis_eintragen(uuid, uuid)', 'execute') as regelhelfer_ausfuehrbar,
  has_function_privilege('authenticated', 'public.darf_ergebnis_eintragen_fuer(uuid, uuid, uuid)', 'execute') as innerer_helfer_offen;
