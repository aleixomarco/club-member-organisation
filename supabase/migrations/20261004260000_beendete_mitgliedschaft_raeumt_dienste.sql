-- Ziel im Repo: supabase/migrations/20261004260000_beendete_mitgliedschaft_raeumt_dienste.sql
--
-- Wer nicht mehr Mitglied ist, blockiert keine Helferstation mehr.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026.
-- "Mitgliedschaft beenden" setzt club_memberships.status auf 'inactive'
-- (app/page.tsx:14876-14891) und raeumt nichts auf.
-- duty_assignments.membership_id haengt nur per ON DELETE CASCADE am
-- endgueltigen ENTFERNEN (duty_assignments_membership_id_fkey, nachgesehen),
-- und auf club_memberships gibt es keinen Ausloeser, der beim Statuswechsel
-- Dienste anfasst - nachgesehen am 04.10.2026 (nur lesend, PROD): acht
-- Ausloeser (account_limit, anfrage_melden, aufnahme_melden, beitritt_melden,
-- eigene_zeile, letzter_admin, willkommen, touch), keiner raeumt Dienste.
--
-- WAS MAN DANN SIEHT
-- Mitglied A steht an "Kasse" (1 Platz), die Leitung beendet seine
-- Mitgliedschaft. Die App laedt nur aktive Mitglieder, personName findet die
-- Kennung nicht mehr und gibt Leerstring zurueck. Jedes andere Mitglied liest
-- "Kasse - niemand · 1/1", der Knopf steht auf "Voll" und ist ausgegraut; der
-- Leitung zeigt die Zeile "Unbekannt". Der taegliche Waechter
-- run_duty_gap_check zaehlt die Zeile als besetzt
-- (20260926110000:118-122) - es geht kein "Helfer gesucht" hinaus. Die Tafel
-- "offene Punkte" der Leitung zaehlt genauso (20260928120000:407-422) und
-- schweigt ebenfalls. Und run_bewirtung_erinnerung schickte dem
-- Ausgetretenen am Vorabend noch "Du hast morgen Dienst"; notify prueft den
-- Mitgliedsstatus nicht. Am Spieltag steht niemand an der Kasse, und niemand
-- hat davon erfahren.
--
-- WARUM LOESCHEN UND NICHT "ehemaliges Mitglied" ANZEIGEN
-- Die ehrlichere Anzeige loest das Problem nicht: Der Platz bliebe belegt,
-- der Waechter bliebe still, die Erinnerung ginge weiter hinaus. Damit die
-- Station den Eintrag als vergangen BEHANDELN kann, braeuchte
-- duty_assignments eine zusaetzliche Spalte, die JEDE Zaehlstelle kennen
-- muss - App, Waechter, offene Punkte, Platzpruefung. Eine vergessene Stelle
-- zaehlt dann still falsch, und genau dieser Fehler ist hier schon einmal
-- passiert (20260928120000:399-404).
--
-- WARUM NUR KUENFTIGE TERMINE
-- Das Beenden ist umkehrbar gedacht: Dieselbe Zeile geht wieder auf 'active',
-- der Knopf heisst dann "Reaktivieren". Deshalb wird so wenig geloescht wie
-- moeglich. Vergangene Dienste sind Geschichte und bleiben stehen - sie
-- werden gebraucht, wenn jemand fragt, wer damals an der Theke stand.
-- Kuenftige muessen weg, weil sonst ein Platz fuer jemanden reserviert
-- bleibt, der nicht kommt; nach einer Reaktivierung teilt die Leitung erneut
-- ein - ein Schritt gegen eine leere Station am Spieltag.
--
-- GREIFT AUCH BEIM SPERREN ('blocked'): Wer gesperrt ist, kommt nicht an die
-- Theke - derselbe Schaden, dieselbe Behandlung. Beim Entsperren zurueck auf
-- 'inactive' ist ohnehin nichts mehr da.
--
-- WARUM KEINE MELDUNG AN DIE LEITUNG
-- Die frei gewordene Station steht ab sofort wieder auf der Tafel "offene
-- Punkte" (20260928120000:407) und meldet sich drei Tage vorher von selbst
-- (run_duty_gap_check). Dazu erfaehrt die Leitung vom Beenden ohnehin:
-- toggleMemberActive ruft notifyClubAdmins mit 'mitglied.beendet'
-- (app/page.tsx:14887). Eine zusaetzliche Push waere die vierte Stelle, die
-- dasselbe sagt - in dem Moment, in dem die Leitung ohnehin in der App ist.
--
-- Geprueft am 04.10.2026 (nur lesend, PROD): 35 Mitgliedschaften, alle
-- 'active'; 3 Helfereintraege (1 Mitglied, 2 Gastnamen). Der Fall ist noch
-- nicht eingetreten, es ist nichts nachzutragen - der Ausloeser faengt den
-- naechsten.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Die App ruft nichts
-- davon auf.

create or replace function public.beendete_mitgliedschaft_dienste_freigeben()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  /* Nur kuenftige Termine - die vergangenen sind Geschichte und werden
     gebraucht, wenn jemand fragt, wer damals an der Theke stand. */
  delete from public.duty_assignments d
   using public.events e
   where d.membership_id = new.id
     and e.id = d.event_id
     and e.starts_at > now();
  return new;
end;
$$;

comment on function public.beendete_mitgliedschaft_dienste_freigeben() is
  'Gibt die Helferstationen kuenftiger Termine frei, sobald eine Mitgliedschaft nicht mehr aktiv ist. Vergangene Dienste bleiben als Geschichte stehen.';

drop trigger if exists club_memberships_dienste_freigeben on public.club_memberships;

create trigger club_memberships_dienste_freigeben
  after update of status on public.club_memberships
  for each row
  when (old.status = 'active' and new.status is distinct from 'active')
  execute function public.beendete_mitgliedschaft_dienste_freigeben();

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: ausloeser_haengt = true, nur_bei_statuswechsel = true,
--           nur_kuenftige = true, blockierte_stationen = 0,
--           vergangene_dienste_zahl unveraendert gegenueber dem Stand VOR
--           dem Einspielen (heute 0).
select
  exists (select 1 from pg_trigger
           where tgrelid = 'public.club_memberships'::regclass
             and tgfoid  = 'public.beendete_mitgliedschaft_dienste_freigeben()'::regprocedure
             and not tgisinternal)                                   as ausloeser_haengt,
  (select pg_get_triggerdef(oid) like '%AFTER UPDATE OF status%'
     from pg_trigger
    where tgname = 'club_memberships_dienste_freigeben')             as nur_bei_statuswechsel,
  pg_get_functiondef('public.beendete_mitgliedschaft_dienste_freigeben()'::regprocedure)
    like '%e.starts_at > now()%'                                     as nur_kuenftige,
  (select count(*) from public.duty_assignments d
     join public.events e on e.id = d.event_id
     join public.club_memberships m on m.id = d.membership_id
    where m.status is distinct from 'active'
      and e.starts_at > now())                                       as blockierte_stationen,
  (select count(*) from public.duty_assignments d
     join public.events e on e.id = d.event_id
    where e.starts_at <= now())                                      as vergangene_dienste_zahl;
