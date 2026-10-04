-- Ziel im Repo: supabase/migrations/20261004230000_protokollaufgabe_nur_abhaken.sql
--
-- Wer eine Protokollaufgabe zugewiesen bekommt, darf sie abhaken - und sonst
-- nichts daran aendern.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 und gegen PROD belegt.
--
-- DIE ZUSAGE UND DIE WIRKLICHKEIT
-- Der Kopf von 20260907180000_protokolle_sichtbarkeit.sql:82-85 sagt ueber die
-- Regel "eigene protokollaufgabe abhaken" ausdruecklich zu: "Nur diese eine
-- Spalte ... Text, Zustaendigkeit und Frist bleiben unangetastet." Die Regel
-- ist aber ein spaltenloses "for update", und eine Zeilenregel kann in
-- PostgreSQL gar keine Spalte einschraenken - sie entscheidet ueber ZEILEN.
-- authenticated hat UPDATE auf allen sieben Spalten von protocol_tasks
-- (nachgesehen mit has_column_privilege, 04.10.2026): id, protocol_id, text,
-- assignee_membership_id, due_date, done, club_id. Einen schuetzenden
-- Ausloeser gab es nicht.
--
-- NACHGEWIESEN am 04.10.2026 gegen PROD in begin; ... rollback;: Ein Protokoll
-- mit einer Aufgabe "Hallenschluessel beim Platzwart abholen", Frist in sieben
-- Tagen, zugewiesen an ein Konto mit der einzigen Rolle 'mitglied'.
-- darf_protokolle_verwalten gibt fuer dieses Konto false. Trotzdem:
--   update protocol_tasks set text = 'Nichts zu tun',
--                             due_date = current_date + 365  -> UPDATE 1
-- Danach stand im Protokoll der Vorstandssitzung eine andere Aufgabe als
-- beschlossen, mit einer Frist ein Jahr spaeter.
--
-- WAS AUSSERDEM MOEGLICH WAR
-- protocol_id ist frei setzbar: Die Zeile liess sich an ein anderes sichtbares
-- Protokoll umhaengen - der Ausloeser club_id_aus_elternteil zieht club_id
-- dann brav vom neuen Elternteil nach, die Aufgabe verschwindet also aus dem
-- Protokoll, in dem sie beschlossen wurde, und erscheint in einem anderen.
-- Ebenso die Zustaendigkeit: Man konnte seine Aufgabe jemand anderem
-- zuschieben.
--
-- IN PROD IST NICHTS PASSIERT
-- Es gibt heute 1 Protokoll (vom 01.09.2026) und 0 Protokollaufgaben. Die
-- Luecke stand seit dem 07.09. offen und wurde nie betreten - es ist nichts
-- nachzutragen.
--
-- WARUM EIN AUSLOESER UND KEIN SPALTENRECHT
-- Ein "grant update (done)" waere die kuerzere Loesung, trifft aber die
-- falsche Ebene: Dasselbe Recht braucht die Protokollverwaltung fuer ALLE
-- Spalten, und ein Spaltenrecht gilt der Rolle, nicht der Regel. Beide
-- hiessen authenticated. Der Ausloeser kann unterscheiden, wer gerade
-- schreibt - das Spaltenrecht nicht.
--
-- club_id steht bewusst NICHT in der Liste der geschuetzten Spalten: Sie wird
-- vom Geschwister-Ausloeser protocol_tasks_club_id aus dem Elternteil gesetzt,
-- der wegen seines Namens VOR diesem hier laeuft. Sie folgt damit immer
-- protocol_id, und protocol_id ist geschuetzt. Stuende club_id in der Liste,
-- waere der Alarm nur ein Fehlalarm.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Die App bietet dem
-- Zustaendigen ohnehin nur den Haken an. Dieser Ausloeser ist der Riegel
-- dahinter, nicht eine Aenderung an der Bedienung.

create or replace function public.protokollaufgabe_nur_abhaken()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  /* Datenpflege und Ausloeserketten ohne Anmeldung laufen durch. */
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  /* Die Protokollverwaltung darf alles - sie hat die Aufgabe geschrieben. */
  if exists (select 1 from public.protocols p
              where p.id = new.protocol_id
                and public.darf_protokolle_verwalten(p.club_id)) then
    return new;
  end if;

  /* Alle anderen: Der Haken, und nur der Haken. Sonst stand im Protokoll
     einer Vorstandssitzung spaeter eine andere Aufgabe als beschlossen. */
  if new.protocol_id            is distinct from old.protocol_id
     or new.text                is distinct from old.text
     or new.assignee_membership_id is distinct from old.assignee_membership_id
     or new.due_date            is distinct from old.due_date then
    raise exception 'protokollaufgabe_nur_abhaken' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists protocol_tasks_nur_abhaken on public.protocol_tasks;
create trigger protocol_tasks_nur_abhaken
  before update on public.protocol_tasks
  for each row execute function public.protokollaufgabe_nur_abhaken();

comment on function public.protokollaufgabe_nur_abhaken() is
  'Haelt die Zusage der Regel "eigene protokollaufgabe abhaken" ein: Der Zustaendige darf done setzen, nicht Text, Frist, Zustaendigkeit oder Protokoll. Die Protokollverwaltung darf alles.';

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: ausloeser_haengt = true, laeuft_vor_update = true,
--           nach_dem_geschwister = true, aufgaben_unveraendert = 0.
-- laeuft_vor_update: Nach dem Schreiben waere es zu spaet.
-- nach_dem_geschwister: PostgreSQL ruft Ausloeser derselben Art in
-- Namensreihenfolge auf. protocol_tasks_club_id < protocol_tasks_nur_abhaken,
-- club_id ist also schon vom Elternteil gesetzt, wenn hier geprueft wird.
select
  exists (select 1 from pg_trigger
           where tgrelid = 'public.protocol_tasks'::regclass
             and tgname = 'protocol_tasks_nur_abhaken'
             and not tgisinternal)                            as ausloeser_haengt,
  (select pg_get_triggerdef(oid) like '%BEFORE UPDATE%'
     from pg_trigger
    where tgrelid = 'public.protocol_tasks'::regclass
      and tgname = 'protocol_tasks_nur_abhaken')              as laeuft_vor_update,
  'protocol_tasks_club_id' < 'protocol_tasks_nur_abhaken'     as nach_dem_geschwister,
  (select count(*) from public.protocol_tasks)                as aufgaben_unveraendert;
