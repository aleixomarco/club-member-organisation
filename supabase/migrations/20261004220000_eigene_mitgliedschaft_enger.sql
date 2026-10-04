-- Ziel im Repo: supabase/migrations/20261004220000_eigene_mitgliedschaft_enger.sql
--
-- Niemand setzt sein eigenes Eintrittsjahr und niemand erklaert sein eigenes
-- Konto zum verwalteten Profil.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 und gegen PROD belegt.
--
-- WIE DIE LUECKE ENTSTAND
-- Die Regel aus 20260901230000_eigene_ansicht_speichern.sql:16 erlaubt UPDATE
-- auf der EIGENEN Zeile in club_memberships, ohne Spalten zu nennen, und
-- authenticated hat UPDATE auf allen 17 Spalten. Den Schaden sollte der
-- Ausloeser eigene_mitgliedschaft_schuetzen abfangen. Der war anfangs breit
-- und wurde am 02.09. eingeengt
-- (20260902030000_schutz_praeziser_fassen.sql:29-32) - auf status, club_id und
-- profile_id. Begruendet wurde die Einengung damals mit display_name und
-- membership_number, die update_own_profile_settings ohnehin schreibt. Dass
-- dabei zwei Spalten mit herausfielen, die KEINE Selbstbedienungs-Funktion
-- schreibt, ist damals niemandem aufgefallen.
--
-- NACHGEWIESEN am 04.10.2026 gegen PROD, in begin; ... rollback;: Ein Konto
-- mit der einzigen Rolle 'mitglied' hat auf seiner eigenen Zeile
--   update club_memberships set is_managed_profile = true  -> UPDATE 1
--   update club_memberships set member_since = 1800        -> UPDATE 1
-- Beides ging glatt durch.
--
-- WAS DAS ANRICHTET
-- is_managed_profile=true: club_account_count zaehlt nur Zeilen mit
-- is_managed_profile=false. Das Konto fehlt danach im Kontingent, und
-- enforce_club_account_limit laesst an der Tarifgrenze weitere Konten zu -
-- die bezahlte Zugangszahl wird unterlaufen. Dazu liest die App
-- is_managed_profile als "Konto noch nicht da" (app/page.tsx:16471) und
-- behandelt das Mitglied in der Liste der Leitung anders als es ist.
-- member_since=1800: In der Mitgliederliste der Leitung und im Profil steht
-- ein falsches Eintrittsjahr, und punkte_je_mitglied rechnet 10 Punkte je
-- Jahr Mitgliedschaft - 2260 Punkte aus dem Nichts. Begrenzt war das nur
-- durch den CHECK 1800..2200.
--
-- WARUM GENAU DIESE ZWEI UND NICHT MEHR
-- Die beiden schreibt sonst NIEMAND bei einem UPDATE. Nachgesehen, Treffer
-- fuer Treffer: member_since wird nur beim Anlegen eines Vereins gesetzt
-- (20260801160000:347 und die spaeteren Fassungen derselben Funktion) und von
-- sysadmin_update_member_profile; is_managed_profile nur beim Anlegen eines
-- verwalteten Profils. In app/ und lib/ gibt es zu beiden Spalten
-- ausschliesslich Lesezugriffe plus den RPC-Aufruf new_member_since
-- (app/page.tsx:10792), der ueber sysadmin_update_member_profile laeuft.
-- display_name, membership_number, email und team_filter bleiben deshalb
-- bewusst draussen: Die schreibt update_own_profile_settings, und ein Riegel
-- davor waere eine neue Baustelle statt einer geschlossenen Luecke.
--
-- Die Vereinsleitung kommt wie bisher durch - der Durchlass oben im Rumpf
-- (has_club_role vereinsadmin/sysadmin/geschaeftsfuehrung/vorstand) und der
-- Schalter app.mitgliedschaft_pflege bleiben unveraendert.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Die App schreibt keine
-- der beiden Spalten direkt.

create or replace function public.eigene_mitgliedschaft_schuetzen()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null
     or auth.role() = 'service_role'
     or coalesce(current_setting('app.mitgliedschaft_pflege', true), '') = 'ja'
     or public.has_club_role(new.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
  then
    return new;
  end if;

  if new.profile_id = auth.uid()
     and (new.status is distinct from old.status
          or new.club_id is distinct from old.club_id
          or new.profile_id is distinct from old.profile_id)
  then
    raise exception 'Aufnahmestatus und Vereinszugehoerigkeit setzt die Vereinsleitung.' using errcode = 'P0001';
  end if;

  /* Diese zwei Spalten schreibt keine Selbstbedienungs-Funktion, deshalb
     steht hier eine eigene Meldung: Es ist kein Versehen im Formular, es ist
     ein Zugriff, den es nicht geben soll.
     is_managed_profile entscheidet, ob das Konto im Kontingent mitzaehlt -
     wer es selbst setzt, unterlaeuft die bezahlte Zugangszahl.
     member_since geht in punkte_je_mitglied ein, 10 Punkte je Jahr. */
  if new.profile_id = auth.uid()
     and (new.is_managed_profile is distinct from old.is_managed_profile
          or new.member_since is distinct from old.member_since)
  then
    raise exception 'Eintrittsjahr und Profilart setzt die Vereinsleitung.' using errcode = 'P0001';
  end if;

  return new;
end;
$$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: profilart_geschuetzt = true, eintrittsjahr_geschuetzt = true,
--           alter_schutz_bleibt = true, ausloeser_haengt = true,
--           verwaltete_profile = <Stand, unveraendert>.
select
  pg_get_functiondef('public.eigene_mitgliedschaft_schuetzen()'::regprocedure)
    like '%is_managed_profile is distinct from old.is_managed_profile%' as profilart_geschuetzt,
  pg_get_functiondef('public.eigene_mitgliedschaft_schuetzen()'::regprocedure)
    like '%member_since is distinct from old.member_since%'            as eintrittsjahr_geschuetzt,
  pg_get_functiondef('public.eigene_mitgliedschaft_schuetzen()'::regprocedure)
    like '%new.status is distinct from old.status%'                    as alter_schutz_bleibt,
  exists (select 1 from pg_trigger
           where tgrelid = 'public.club_memberships'::regclass
             and tgfoid  = 'public.eigene_mitgliedschaft_schuetzen()'::regprocedure
             and not tgisinternal)                                     as ausloeser_haengt,
  (select count(*) from public.club_memberships where is_managed_profile) as verwaltete_profile;
