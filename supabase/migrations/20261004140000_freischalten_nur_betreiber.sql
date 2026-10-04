-- Ziel im Repo: supabase/migrations/20261004140000_freischalten_nur_betreiber.sql
--
-- SICHERHEIT: Jedes angemeldete Konto konnte seinen Verein selbst freischalten.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 und gegen PROD belegt:
--   has_function_privilege('authenticated', 'verein_freischalten(...)') = true
--   has_function_privilege('authenticated', 'verein_sperren(uuid)')     = false
-- Diese Asymmetrie ist der Beweis, dass es ein Versehen war und keine
-- Entscheidung: Die beiden gehoeren zusammen, und nur eine war zu.
--
-- WIE DAS LOCH ENTSTAND
-- 20260902210000_funktionen_nicht_fuer_jeden.sql:45-51 hatte das Recht schon
-- einmal entzogen - ausdruecklich auch von authenticated, mit der Begruendung,
-- ein Vereinsadministrator duerfe sich nicht selbst freischalten.
-- 20260924100000_fan_kontingent.sql:736 hat die Funktion dann VERWORFEN und mit
-- einem siebten Parameter neu angelegt. Ein drop + create setzt die Rechte
-- zurueck, und Supabase vergibt beim Anlegen wieder EXECUTE an authenticated.
-- Zeile 884 nahm es danach nur "from public" - das Vorgaberecht blieb stehen.
--
-- Eine Rechtevergabe, die an einem create haengt, ueberlebt kein drop. Deshalb
-- steht der Entzug hier unten OHNE vorangehendes create: Er gilt der Funktion,
-- die gerade da ist.
--
-- WAS JEMAND HAETTE TUN KOENNEN
-- Die Vereins-Kennung bekommt jeder Angemeldete (Regel "clubs are
-- discoverable", using true). Mit ihr und einem Aufruf von
-- POST /rest/v1/rpc/verein_freischalten:
--   - den eigenen Verein auf 'pro' setzen, Laufzeit frei gewaehlt
--   - das laufende Abo auf 'expired' setzen und ein neues anlegen
--   - bezahlte Zugangsanfragen als 'freigeschaltet' abhaken
-- Also: kostenloser Tarifsprung und verfaelschte Abrechnungsdaten.
-- NICHT moeglich waren frei gewaehlte Kontingente und Sponsoring - der
-- Ausloeser clubs_betreiberfelder (20260901050000) haette das zurueckgerollt.
-- Das mindert den Schaden, nicht das Loch.
--
-- NACHGESEHEN, OB ES JEMAND GETAN HAT (04.10.2026, nur lesend): Es gibt zwei
-- Vereine, beide mit genau einem aktiven Abo, angelegt vom Betreiber; keine
-- Anfrage steht auf 'freigeschaltet', ohne vorher bezahlt gewesen zu sein.
-- Nichts deutet auf einen Missbrauch hin.
--
-- betreiber_kennzahlen() KOMMT MIT
-- Sie liefert die Zahlen der ganzen Plattform - wie viele Vereine, wie viele
-- Konten, welche Tarife - und prueft im Rumpf gar nichts. Das sind
-- Geschaeftszahlen des Betreibers und gehen ein Vereinsmitglied nichts an.
-- Die Betreiber-Konsole liest sie serverseitig mit dem Dienstschluessel
-- (app/api/betreiber/daten/route.ts), ihr nimmt der Entzug nichts.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Die App ruft keine der
-- beiden Funktionen auf (geprueft: kein Treffer in app/ und lib/).

revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean, integer)
  from public, anon, authenticated;
grant execute on function public.verein_freischalten(uuid, text, integer, interval, text, boolean, integer)
  to service_role;

revoke all on function public.betreiber_kennzahlen() from public, anon, authenticated;
grant execute on function public.betreiber_kennzahlen() to service_role;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: freischalten_zu = true, kennzahlen_zu = true,
--           freischalten_fuer_dienst = true, kennzahlen_fuer_dienst = true,
--           sperren_bleibt_zu = true.
-- Die beiden Zwillinge stehen jetzt gleich: Freischalten und Sperren sind
-- Betreibersache, und zwar beide.
select
  not has_function_privilege('authenticated',
    'public.verein_freischalten(uuid,text,integer,interval,text,boolean,integer)', 'execute') as freischalten_zu,
  not has_function_privilege('authenticated',
    'public.betreiber_kennzahlen()', 'execute') as kennzahlen_zu,
  has_function_privilege('service_role',
    'public.verein_freischalten(uuid,text,integer,interval,text,boolean,integer)', 'execute') as freischalten_fuer_dienst,
  has_function_privilege('service_role',
    'public.betreiber_kennzahlen()', 'execute') as kennzahlen_fuer_dienst,
  not has_function_privilege('authenticated',
    'public.verein_sperren(uuid)', 'execute') as sperren_bleibt_zu;
