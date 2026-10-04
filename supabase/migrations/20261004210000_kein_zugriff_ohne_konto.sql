-- Ziel im Repo: supabase/migrations/20261004210000_kein_zugriff_ohne_konto.sql
--
-- SICHERHEIT: Vierzehn Funktionen standen jedem offen, der nur den
-- oeffentlichen Schluessel der App hat - ohne Konto, ohne Mitgliedschaft.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 (Fund "Sponsoren-Anzeigen
-- jedes Vereins ohne Anmeldung lesbar") und beim Nachmessen deutlich groesser
-- als gemeldet.
--
-- DIE URSACHE IST EINE POSTGRES-VORGABE
-- PostgreSQL vergibt EXECUTE auf einer NEUEN Funktion von sich aus an PUBLIC,
-- und PUBLIC schliesst anon ein - also den Schluessel, der in jeder
-- installierten App steckt und in jedem Browser steht. Jede Funktion, die
-- dieses Haus anlegt oder mit drop + create neu anlegt, ist damit erst einmal
-- offen. Genau dieselbe Vorgabe hat am 24.09. das Loch in
-- verein_freischalten gerissen (20261004140000).
-- 20260928060000_anzeige_knopftext.sql:106-107 hat es zusaetzlich
-- festgeschrieben: dort steht "to public, authenticated", waehrend alle
-- frueheren Fassungen derselben zwei Rechtevergaben "to authenticated" sagen
-- (20260831150000:130/146, 20260831210000:90/106, 20260910050000:47/63,
-- 20260910060000:72/90). Gemeint war der Stand fuer angemeldete Konten.
--
-- GEMESSEN AM 04.10.2026 GEGEN PROD, jede Funktion einzeln als Rolle anon
-- aufgerufen (in begin; ... rollback;). 407 Funktionen im Schema public, 241
-- davon fuer anon ausfuehrbar, 49 davon security definer; nach Abzug der
-- Ausloeserfunktionen, die sich nicht aufrufen lassen, bleiben 15 echte
-- Aufrufe. Das Ergebnis, ehrlich getrennt:
--
--   OFFEN UND SCHAEDLICH - anon bekam wirklich etwas:
--   anzeigen_fuer_verein(uuid)       1 Zeile: Titel, Text, Bildpfad,
--                                    Zieladresse, Telefon und E-Mail der
--                                    Sponsoren jedes Vereins. Zum Vergleich:
--                                    auf der Tabelle anzeigen hat anon gar
--                                    kein SELECT-Recht - die Funktion war der
--                                    einzige Weg hinein, und sie ist security
--                                    definer, umgeht also die Leseregel
--                                    "anzeigen lesbar" (club_id is null or
--                                    is_club_member(club_id)).
--   anzeigen_kennzahlen(uuid,int)    die VOLLE Auswertung einer Anzeige:
--                                    Verein, Titel, Platz, Laufzeit,
--                                    Reichweite 14, Klicks, Impressionen,
--                                    Kontakte und der Tagesverlauf ueber 30
--                                    Tage. Das sind die Zahlen, mit denen ein
--                                    Sponsor ueberzeugt wird.
--   anzeige_ereignis(...)            lief OHNE Fehler durch - ein Fremder
--                                    konnte also Impressionen und Klicks
--                                    SCHREIBEN. Damit laesst sich die
--                                    Reichweite einer Anzeige faelschen, nach
--                                    oben wie nach unten.
--   anzeige_fuer_platz(uuid,text)    dieselbe Familie, dieselbe Lage.
--
--   OFFEN, ABER HARMLOS - die Funktion antwortet ohne Konto mit nichts:
--   darf_anwesenheit_sehen           false
--   darf_fahrzeug_entscheiden        false
--   ungelesene_benachrichtigungen    0
--   benachrichtigungen_gelesen       0 (schreibt nichts, auth.uid() ist null)
--
--   SCHON ZU - eine eigene Pruefung im Rumpf weist anon ab:
--   anwesenheit_fuer_termin          "Not authorized"
--   tipprunden_fuer_verein           "Not authorized"
--   tipprunde_setzen                 "Not authorized"
--   sprache_setzen                   "Not authenticated"
--   aufgabe_erledigen                "Aufgabe nicht gefunden"
--   tipp_tabelle                     nicht messbar - es gibt in PROD noch
--                                    keine Tipprunde. Der Riegel steht hier
--                                    trotzdem, statt sich auf den Rumpf zu
--                                    verlassen.
--
-- Die vier harmlosen und die sechs schon zugesperrten kommen MIT. Nicht, weil
-- sie heute schaden, sondern weil ein Riegel im Rumpf eine Entscheidung von
-- heute ist und das Ausfuehrungsrecht eine Entscheidung fuer immer: Wer
-- morgen den Rumpf anfasst, soll nicht auch noch an das Recht denken muessen.
--
-- WAS BEWUSST OFFEN BLEIBT
-- registrierung_moeglich() - die Frage, ob die Plattform noch Konten annimmt.
-- Die App stellt sie NACH einem fehlgeschlagenen signUp und damit ohne
-- Anmeldung (app/page.tsx:18660). Ohne dieses Recht stuende dort wieder
-- "gerade nicht moeglich" statt eines verstaendlichen Satzes.
--
-- WAS DIESE MIGRATION NICHT ERLEDIGT
-- Zwei Dinge bleiben offen und sind eigene Funde:
--  1. Auch ein ANGEMELDETES Mitglied darf diese Funktionen mit der Kennung
--     eines FREMDEN Vereins aufrufen - die Rumpfe pruefen keine
--     Mitgliedschaft. Das trifft dieselbe Anzeigen-Familie und dazu
--     punkte_je_mitglied, club_account_*, club_fan_*,
--     club_subscription_tier, club_kontingent_uebersicht und
--     get_task_signup_ratio. Das gehoert in eine eigene Migration, weil es
--     Rumpfe aendert und nicht nur Rechte.
--  2. 192 weitere Funktionen sind fuer anon ausfuehrbar, aber nicht security
--     definer - sie laufen mit den Rechten des Aufrufers, und fuer anon
--     halten die Zeilenregeln. Kein Loch, nur Laerm.
--
-- NACHTRAG VOM 04.10.2026, NOCH AM SELBEN TAG
-- Die Angabe oben zu anzeigen_fuer_verein ist zu stark und wird hier
-- berichtigt, statt sie stehen zu lassen.
-- Gezaehlt hatte ich "1 Zeile" und daraus geschlossen, anon bekomme Titel,
-- Text, Zieladresse, Telefon und E-Mail eines Sponsors. Nachgesehen, WELCHE
-- Zeile es war: Es gibt in PROD genau zwei Anzeigen - eine des Betreibers
-- (club_id is null, laeuft seit 25.09.) und eine von SV Musterstadt, die am
-- 06.09. ausgelaufen ist und deren Verein sponsoring_freigeschaltet = false
-- hat. Die eine Zeile war also die BETREIBER-Anzeige, und die ist oeffentliche
-- Werbung - kein Geheimnis.
-- Was bleibt: Die MOEGLICHKEIT lag offen. Jede aktive, laufende Anzeige eines
-- Vereins mit freigeschaltetem Sponsoring waere mit Telefon und E-Mail
-- herausgekommen, sobald es eine gibt; heute gibt es keine. Fuer die beiden
-- anderen Funde aendert sich nichts, und sie sind die schwereren:
-- anzeigen_kennzahlen gab anon die VOLLE Auswertung der Anzeige von SV
-- Musterstadt heraus (Verein, Titel 'Iwanowski', Platz, Laufzeit, Reichweite
-- 14, Klicks, Impressionen, Tagesverlauf) - das ist club-eigen und war echt.
-- anzeige_ereignis liess anon schreiben; das war unabhaengig von den Daten
-- offen.
-- Der Entzug bleibt also richtig, nur die Begruendung bei einer von vierzehn
-- Funktionen war ein Fund in der Anlage und keiner in den Daten.

-- MUSS NICHT zusammen mit der App ausgeliefert werden: Alle vierzehn werden
-- in der App erst nach der Anmeldung aufgerufen (geprueft, Treffer fuer
-- Treffer in app/ und lib/).

revoke all on function public.anzeigen_fuer_verein(uuid)                 from public, anon;
revoke all on function public.anzeige_fuer_platz(uuid, text)             from public, anon;
revoke all on function public.anzeigen_kennzahlen(uuid, integer)         from public, anon;
revoke all on function public.anzeige_ereignis(uuid, text, text, uuid)   from public, anon;
revoke all on function public.anwesenheit_fuer_termin(uuid)              from public, anon;
revoke all on function public.aufgabe_erledigen(uuid, boolean)           from public, anon;
revoke all on function public.benachrichtigungen_gelesen(uuid)           from public, anon;
revoke all on function public.darf_anwesenheit_sehen(uuid)               from public, anon;
revoke all on function public.darf_fahrzeug_entscheiden(uuid)            from public, anon;
revoke all on function public.sprache_setzen(text)                       from public, anon;
revoke all on function public.tipp_tabelle(uuid)                         from public, anon;
revoke all on function public.tipprunde_setzen(uuid, uuid, boolean)      from public, anon;
revoke all on function public.tipprunden_fuer_verein(uuid)               from public, anon;
revoke all on function public.ungelesene_benachrichtigungen(uuid)        from public, anon;

-- Der Entzug von PUBLIC nimmt das Recht auch authenticated, wenn es dort nur
-- ueber PUBLIC hing. Deshalb steht es hier ausdruecklich wieder da - das ist
-- der Stand, der gemeint war.
grant execute on function public.anzeigen_fuer_verein(uuid)               to authenticated;
grant execute on function public.anzeige_fuer_platz(uuid, text)           to authenticated;
grant execute on function public.anzeigen_kennzahlen(uuid, integer)       to authenticated, service_role;
grant execute on function public.anzeige_ereignis(uuid, text, text, uuid) to authenticated;
grant execute on function public.anwesenheit_fuer_termin(uuid)            to authenticated;
grant execute on function public.aufgabe_erledigen(uuid, boolean)         to authenticated;
grant execute on function public.benachrichtigungen_gelesen(uuid)         to authenticated;
grant execute on function public.darf_anwesenheit_sehen(uuid)             to authenticated;
grant execute on function public.darf_fahrzeug_entscheiden(uuid)          to authenticated;
grant execute on function public.sprache_setzen(text)                     to authenticated;
grant execute on function public.tipp_tabelle(uuid)                        to authenticated;
grant execute on function public.tipprunde_setzen(uuid, uuid, boolean)     to authenticated;
grant execute on function public.tipprunden_fuer_verein(uuid)              to authenticated;
grant execute on function public.ungelesene_benachrichtigungen(uuid)       to authenticated;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: fuer_anon_zu = 14, fuer_angemeldete_offen = 14,
--           registrierung_bleibt_offen = true,
--           kennzahlen_fuer_dienst = true,
--           anon_security_definer_rest = 1 (nur registrierung_moeglich).
with ziele(name) as (values
  ('public.anzeigen_fuer_verein(uuid)'),
  ('public.anzeige_fuer_platz(uuid,text)'),
  ('public.anzeigen_kennzahlen(uuid,integer)'),
  ('public.anzeige_ereignis(uuid,text,text,uuid)'),
  ('public.anwesenheit_fuer_termin(uuid)'),
  ('public.aufgabe_erledigen(uuid,boolean)'),
  ('public.benachrichtigungen_gelesen(uuid)'),
  ('public.darf_anwesenheit_sehen(uuid)'),
  ('public.darf_fahrzeug_entscheiden(uuid)'),
  ('public.sprache_setzen(text)'),
  ('public.tipp_tabelle(uuid)'),
  ('public.tipprunde_setzen(uuid,uuid,boolean)'),
  ('public.tipprunden_fuer_verein(uuid)'),
  ('public.ungelesene_benachrichtigungen(uuid)'))
select
  count(*) filter (where not has_function_privilege('anon', name, 'execute'))          as fuer_anon_zu,
  count(*) filter (where has_function_privilege('authenticated', name, 'execute'))     as fuer_angemeldete_offen,
  (select has_function_privilege('anon', 'public.registrierung_moeglich()', 'execute')) as registrierung_bleibt_offen,
  (select has_function_privilege('service_role',
            'public.anzeigen_kennzahlen(uuid,integer)', 'execute'))                     as kennzahlen_fuer_dienst,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef
      and pg_get_function_result(p.oid) <> 'trigger'
      and has_function_privilege('anon', p.oid, 'execute'))                             as anon_security_definer_rest
from ziele;
