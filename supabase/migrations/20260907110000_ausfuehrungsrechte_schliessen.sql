-- Funktionen, die niemand von aussen aufrufen darf, duerfen es jetzt auch nicht.
--
-- DAS PROBLEM
-- Postgres vergibt bei JEDER neuen Funktion automatisch EXECUTE an PUBLIC.
-- Ein "grant execute ... to service_role" nimmt das nicht weg - es steht nur
-- daneben. Wer also eine Funktion schreibt und sie brav nur an service_role
-- vergibt, hat sie trotzdem fuer alle geoeffnet, auch fuer anon.
--
-- Nachgezaehlt: 61 der 150 SECURITY-DEFINER-Funktionen waren fuer anon
-- ausfuehrbar. Die meisten davon sind Ausloeser (returns trigger) und ueber
-- PostgREST gar nicht erreichbar. Uebrig blieben 23 - und darunter vier, mit
-- denen man echten Schaden anrichten kann:
--
--   betreiber_nachricht_senden(uuid,text,text,boolean)
--     Schreibt einen frei waehlbaren Titel und Text in die Glocke ALLER
--     aktiven Mitglieder eines FREI WAEHLBAREN Vereins. An
--     user_notifications haengt push_anstossen - es sind also echte
--     Push-Meldungen auf den Sperrbildschirmen. Keine einzige Pruefung im
--     Rumpf; die einzige Bedingung ist, dass Titel und Text nicht leer sind.
--     Mit dem oeffentlichen anon-Schluessel aus dem App-Bundle war das ein
--     fertiger Kanal, um im Namen des Betreibers an jeden Verein zu
--     schreiben.
--
--   notify_uebersetzt(uuid,text,text,text,jsonb,jsonb)
--     Heute frueh von mir angelegt, mit demselben Fehler. Reicht an notify()
--     durch, das ungeprueft in die Warteschlange schreibt. notify() selbst
--     war fuer anon gesperrt - der neue Weg daran vorbei nicht.
--
--   aufgaben_erinnerung_senden(), ergebnis_erinnerung_senden()
--     Naechtliche Auftraege. Von aussen ausloesbar hiess: Erinnerungen an den
--     halben Verein, wann immer jemand mag.
--
-- Dazu zwei, die zwar nichts schreiben, aber Daten herausgeben, die niemanden
-- ohne Anmeldung etwas angehen: betreiber_kennzahlen() (Betriebszahlen ueber
-- alle Vereine) und punkte_je_mitglied(uuid).
--
-- WARUM DAS ENTZIEHEN GEFAHRLOS IST
-- Nachgesehen, wer die Funktionen ruft:
--   betreiber_nachricht_senden - nur app/api/betreiber/aktion/route.ts, und
--     zwar ueber getSupabaseAdmin(), also mit SUPABASE_SECRET_KEY. Das ist
--     service_role, dem das Recht bleibt.
--   die beiden Erinnerungen - nur cron.
--   notify_uebersetzt, notify, meldungstext, meldung_erlaubt,
--     team_meldung_erlaubt, sprache_der_mitgliedschaft - nur aus anderen
--     Funktionen heraus. Ein Aufruf INNERHALB einer SECURITY-DEFINER-Funktion
--     laeuft mit deren Rechten (postgres), nicht mit denen des Anwenders. Die
--     Ausloeser arbeiten also weiter.
--   punkte_je_mitglied ruft die App - dort bleibt authenticated.
-- Keine einzige davon steht im rpc-Verzeichnis der App ausser den letzten
-- beiden Faellen.

-- ---------------------------------------------------- Betreiberfunktionen
revoke execute on function public.betreiber_nachricht_senden(uuid, text, text, boolean) from public, anon, authenticated;
revoke execute on function public.betreiber_kennzahlen() from public, anon, authenticated;

-- ------------------------------------------------------ Naechtliche Laeufe
revoke execute on function public.aufgaben_erinnerung_senden() from public, anon, authenticated;
revoke execute on function public.ergebnis_erinnerung_senden() from public, anon, authenticated;

-- --------------------------------------------- Innere Helfer der Meldungen
revoke execute on function public.notify_uebersetzt(uuid, text, text, text, jsonb, jsonb) from public, anon, authenticated;
revoke execute on function public.notify(uuid, text, text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.meldungstext(text, text) from public, anon, authenticated;
revoke execute on function public.meldungstext(text, text, jsonb) from public, anon, authenticated;
revoke execute on function public.meldung_erlaubt(uuid, text) from public, anon, authenticated;
revoke execute on function public.team_meldung_erlaubt(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.sprache_der_mitgliedschaft(uuid) from public, anon, authenticated;

/* Die App braucht das - aber ohne Anmeldung hat dort niemand etwas zu suchen. */
revoke execute on function public.punkte_je_mitglied(uuid) from public, anon;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and has_function_privilege('anon', p.oid, 'EXECUTE')
      and pg_get_function_result(p.oid) <> 'trigger'
      and (p.prosrc ~* '\minsert\M|\mupdate\M|\mdelete\M')
      and not (p.prosrc ~* 'has_club_role|is_club_member|auth\.uid|Not authorized|darf_|ist_betreiber')
  ) as schreibend_ohne_pruefung_offen,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef and has_function_privilege('anon', p.oid, 'EXECUTE')
      and pg_get_function_result(p.oid) <> 'trigger') as von_aussen_erreichbar_gesamt,
  (select has_function_privilege('anon', 'public.betreiber_nachricht_senden(uuid,text,text,boolean)', 'EXECUTE')) as betreiber_noch_offen,
  (select has_function_privilege('service_role', 'public.betreiber_nachricht_senden(uuid,text,text,boolean)', 'EXECUTE')) as service_role_darf_weiter;
