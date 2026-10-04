-- Ziel im Repo: supabase/migrations/20261004200000_mannschaft_loeschen_ohne_lawine.sql
--
-- Eine Mannschaft loeschen schickt nicht mehr tausende Meldungen und Pushes.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 und gegen PROD gerechnet.
--
-- WIE DIE LAWINE ENTSTEHT
-- mannschaft_loeschen (20260927210000:106) loescht die teams-Zeile. Der
-- Fremdschluessel events.team_id steht auf "on delete set null"
-- (20260801160000:101, in PROD nachgesehen: confdeltype = 'n'), also setzt die
-- Datenbank team_id bei JEDEM Termin dieser Mannschaft auf NULL. Das ist ein
-- UPDATE auf events, und der Ausloeser events_notify_audience haengt
-- ausdruecklich auch an "UPDATE OF ... team_id" (20260905110000:108).
--
-- In notify_event_audience steigt dann nichts aus:
--   - Die Frueh-Pruefung vergleicht old und new nur ohne die Ergebnisspalten.
--     team_id ist nicht ausgenommen, der Vergleich schlaegt also an.
--   - Es bleibt der Zweig 'geaendert' uebrig: "Das Spiel wurde geaendert".
--   - Weil team_id jetzt NULL IST, greift "new.team_id is null or ..." in der
--     Empfaengerabfrage, und team_meldung_erlaubt gibt bei NULL-Mannschaft
--     true zurueck. Der Empfaengerkreis ist damit der GANZE VEREIN.
--   - Einen Datumsfilter gibt es nicht: Auch Termine von vor einem Jahr melden.
--   - Die Serien-Entdoppelung greift nur beim Anlegen und beim Absagen, nicht
--     bei einer Massenaenderung von team_id.
-- Jede Zeile in user_notifications zieht ausserdem user_notifications_push
-- nach sich.
--
-- GERECHNET AM 04.10.2026 (nur lesend, PROD), Termine x aktive Mitglieder
-- mit Konto - die Obergrenze:
--   Herren 1   / ERG Iserlohn     105 x 21 = 2205
--   Damen 1    / SV Musterstadt    40 x 14 =  560
--   C-Jugend   / ERG Iserlohn      20 x 21 =  420
--
-- NACHGEWIESEN, nicht nur gerechnet: Am 04.10.2026 wurde Herren 1 / ERG
-- Iserlohn in einer Transaktion gegen PROD geloescht und die Transaktion
-- zurueckgenommen. Mit der alten Fassung entstanden dabei 1780 Zeilen in
-- user_notifications - weniger als die Obergrenze 2205, weil die
-- persoenlichen Meldungsarten und der Trainings-Riegel fuer Fans einen Teil
-- wegnehmen. Mit der neuen Fassung: 0. Angelegt und echt geaendert wird
-- weiter gemeldet (je 16 Zeilen), ein Wechsel zu einer anderen Mannschaft
-- ebenfalls (8 Zeilen). Der Stand von 210 Meldungen war danach unveraendert.
--
-- Ein Vereinsadmin tippt also auf Bearbeiten > Loeschen, bestaetigt die
-- Vorschau - und 21 Menschen bekommen zusammen 1780 Push-Nachrichten
-- "Das Spiel wurde geaendert" fuer Spiele, die teils ein Jahr zurueckliegen.
-- Die Vorschau sagt dazu nichts; sie weist nur aus, dass die Termine bleiben.
--
-- DER RIEGEL
-- old.team_id is not null and new.team_id is null kann NUR durch dieses
-- "on delete set null" entstehen. Geprueft am 04.10.2026:
--   - Die App schreibt team_id ausschliesslich beim Anlegen
--     (app/page.tsx:5736); der Aenderungsweg (ebd.:5811-5822) fasst die Spalte
--     nicht an.
--   - Ein Termin der Art 'training' oder 'spiel' kann ohne Mannschaft gar
--     nicht angelegt werden (ebd.:5653 bricht mit sichtbarer Meldung ab).
--   - Keine Migration setzt events.team_id (kein Treffer).
-- Der Riegel trifft also genau das Loeschen einer Mannschaft und nichts
-- sonst. Ein Termin, der von einer Mannschaft zu einer ANDEREN wechselt,
-- meldet weiter - deshalb bleibt team_id in der Spaltenliste des Ausloesers.
--
-- WARUM GAR KEINE MELDUNG, STATT EINER KLEINEREN
-- Der Betreiber hat am 27.09. entschieden, dass die Termine als Geschichte
-- stehen bleiben (20260927210000:29-36). Am Termin hat sich inhaltlich nichts
-- geaendert: gleiche Zeit, gleicher Ort, gleicher Titel. Geaendert hat sich,
-- wer dafuer zustaendig ist - und zwar, weil es niemanden mehr gibt. Darueber
-- gibt es nichts zu melden, was ein Mitglied tun koennte.
--
-- MUSS zusammen mit der App ausgeliefert werden: app/page.tsx haelt die
-- Zusagen-Abfrage an einem Termin ohne Mannschaft jetzt geschlossen, wenn es
-- ein Training oder Spiel ist. Beides sind Waisen einer geloeschten
-- Mannschaft, und fuer sie gibt es keinen Trainer, der die Frage freigeben
-- koennte - bisher erschien sie an allen 105 Terminen neu, auch dort, wo der
-- Trainer sie bewusst aus hatte.

create or replace function public.notify_event_audience()
returns trigger
language plpgsql security definer set search_path = 'public' as $$
declare
  v_situation  text;   -- angelegt | abgesagt | geaendert
  v_basis      text;   -- z. B. termin.spiel.abgesagt
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null
  v_grund      text;
  v_werte      jsonb;  -- Rezept fuer das Neu-Rendern (Stufe B)
begin
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

  /* Eine Mannschaft wurde geloescht - kein Termin hat sich geaendert.
     events.team_id steht auf "on delete set null": Mit der teams-Zeile fallen
     alle Termine der Mannschaft in EINER Anweisung auf team_id = NULL. Ohne
     diesen Riegel liest der Ausloeser das als Aenderung JEDES Termins, und
     weil team_id dann NULL ist, gilt der Empfaengerkreis "ganzer Verein".
     Gemessen am 04.10.2026 gegen PROD (geloescht und zurueckgenommen):
     Herren 1 / ERG Iserlohn ergab 1780 Meldungen und 1780 Pushes in einer
     Transaktion, fuer Spiele, die teils ein Jahr zurueckliegen.
     Dieser Fall kann nur so entstehen: Die App schreibt team_id allein beim
     Anlegen, und ein Training oder Spiel laesst sich ohne Mannschaft nicht
     anlegen. Ein Wechsel zu einer ANDEREN Mannschaft meldet weiter. */
  if tg_op = 'UPDATE' and old.team_id is not null and new.team_id is null then
    return new;
  end if;


  /* Ein reiner Ergebniseintrag ist keine Aenderung des Termins - dafuer gibt
     es spielergebnis_melden. Sonst bekaeme der halbe Verein "Das Spiel wurde
     geaendert", sobald jemand 3:2 eintraegt. */
  if tg_op = 'UPDATE'
     and to_jsonb(old) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
       = to_jsonb(new) - 'home_score' - 'away_score' - 'result_entered_at'
                       - 'result_entered_by' - 'updated_at' - 'ergebnis_erinnert_at'
  then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_situation := 'angelegt';
    v_schluessel := case new.type when 'training' then 'training_created'
                                  when 'spiel'    then 'game_created'
                                  else 'events' end;

    /* Eine Serie meldet EINMAL, nicht je Termin.
       create_recurring_events legt alle Termine in einer einzigen
       INSERT-...-SELECT-Anweisung an. Dieser Ausloeser haengt aber an FOR EACH
       ROW - bisher entstand also je Termin und je Empfaenger eine Meldung und
       damit eine Push-Nachricht. In den Daten steht der Beleg: eine Serie mit
       drei Terminen erzeugte neun Meldungen. Die groesste vorhandene Serie hat
       85 Termine.
       Weil alle Zeilen derselben Anweisung dieselbe created_at tragen - now()
       ist innerhalb einer Transaktion konstant -, entscheidet die Kennung den
       Gleichstand. Genau eine Zeile findet keine aeltere vor sich und meldet;
       alle uebrigen steigen hier aus.
       Wird der Serie spaeter ein Termin hinzugefuegt, hat er eine juengere
       created_at und schweigt ebenfalls - richtig so: angekuendigt wurde die
       Serie bereits. */
    if new.series_id is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and (e.created_at, e.id) < (new.created_at, new.id)
      ) then
        return new;
      end if;
      v_situation := 'serie_angelegt';
    end if;
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_situation := 'abgesagt';
    v_schluessel := case new.type when 'training' then 'training_cancelled'
                                  when 'spiel'    then 'game_cancelled'
                                  else 'events' end;

    /* Dieselbe Ueberlegung wie beim Anlegen, nur umgekehrt: Wer eine ganze
       Reihe absagt, soll EINE Nachricht ausloesen, nicht zwanzig.
       Unterschieden wird an cancelled_at. absage_serie setzt alle Termine in
       EINER Anweisung ab, und now() ist innerhalb einer Transaktion konstant -
       alle abgesagten Zeilen der Reihe tragen deshalb denselben Zeitpunkt auf
       die Mikrosekunde. Findet eine Zeile eine Schwester mit GENAU derselben
       cancelled_at und kleinerer Kennung, war es eine Reihenabsage und sie
       schweigt.
       Wird dagegen ein EINZELNER Termin einer Reihe abgesagt, gibt es keine
       solche Schwester - er meldet ganz normal mit "abgesagt". Genau das
       braucht die Auswahl "nur dieser Termin". */
    if new.series_id is not null and new.cancelled_at is not null then
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
           and e.id < new.id
      ) then
        return new;
      end if;
      if exists (
        select 1 from public.events e
         where e.series_id = new.series_id
           and e.id <> new.id
           and e.status = 'cancelled'
           and e.cancelled_at = new.cancelled_at
      ) then
        v_situation := 'serie_abgesagt';
      end if;
    end if;
  elsif tg_op = 'UPDATE' then
    v_situation := 'geaendert';
    v_schluessel := case new.type when 'training' then 'training_changed'
                                  when 'spiel'    then 'game_changed'
                                  else 'events' end;
  else
    return new;
  end if;

  /* Ganze Saetze je Terminart, nicht "Das {art} wurde …" zusammengesetzt:
     Artikel und Geschlecht haengen in den meisten Sprachen am Wort. */
  v_basis := 'termin.' || case new.type when 'training' then 'training'
                                        when 'spiel'    then 'spiel'
                                        else 'event' end
             || '.' || v_situation;

  v_grund := nullif(trim(new.cancel_reason), '');

  /* Stufe B: Der Text entsteht aus Bausteinen, damit ihn glocke_neu_rendern
     spaeter in einer anderen Sprache wiederholen kann. termin.zeile ist
     '{satz} {titel}{wann}{ortzusatz}{grundzusatz}' - Zeichen fuer Zeichen
     dasselbe wie die bisherige Verkettung. Satz, Datum und Grund-Baustein
     folgen der Sprache; Titel, Ort und Grund selbst bleiben Rohtext. */
  v_werte := jsonb_build_object(
    'satz',        jsonb_build_object('s', v_basis || '.text'),
    'titel',       coalesce(new.title, ''),
    'wann',        case when new.starts_at is null then to_jsonb(''::text)
                        else jsonb_build_object('vor', ' · ', 'zeit', new.starts_at, 'uhrzeit', true) end,
    'ortzusatz',   coalesce(' · ' || new.location, ''),
    'grundzusatz', case when v_situation = 'abgesagt' and v_grund is not null
                        then jsonb_build_object('vor', ' ·', 's', 'termin.grund',
                                               'w', jsonb_build_object('grund', v_grund))
                        else to_jsonb(''::text) end);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, v_schluessel,
         public.meldung_rendern(v_basis || '.titel', coalesce(p.language, 'de'), '{}'::jsonb),
         /* Der Grund steht am ENDE, nicht direkt hinter dem Satz. Vorher las
            sich eine Absage als "Das Spiel wurde abgesagt. Grund: Glatteis
            Herren 1 gegen Herringen · 12.09. · Hemberghalle" - der Grund
            klebte am Spieltitel und man wusste nicht, wo er aufhoert. */
         public.meldung_rendern('termin.zeile', coalesce(p.language, 'de'), v_werte),
         'termin', new.id,
         v_basis || '.titel', 'termin.zeile', v_werte, coalesce(p.language, 'de')
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, v_teamart)
    and public.meldung_erlaubt(m.profile_id, v_schluessel)
    /* Fans sehen keine Trainings (12.09.2026) - also auch keine Meldung
       darueber. Ein Fan ist in keiner Mannschaft, konnte einer aber ueber
       team_benachrichtigungen folgen, und vereinsweite Trainings erreichten
       ohnehin jeden. "Nur Fan" heisst: 'fan' und keine andere Rolle. Seit
       20260911110000 laesst die Datenbank neben 'fan' nichts mehr zu; die
       zweite Bedingung haelt trotzdem fest, was gemeint ist. */
    and not (
      new.type = 'training'
      and exists (select 1 from public.membership_roles r
                   where r.membership_id = m.id and r.role = 'fan')
      and not exists (select 1 from public.membership_roles r
                       where r.membership_id = m.id and r.role <> 'fan')
    );

  return new;
exception when others then
  /* Ein Termin ist wichtiger als die Meldung darueber: Er wird angelegt,
     auch wenn das Melden scheitert. Die Warnung steht im Protokoll. */
  raise warning 'Terminmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: riegel_steht = true, ausloeser_kennt_team_id_noch = true,
--           groesste_lawine_waere = 2205, meldungen_jetzt = <Stand vor dem
--           Einspielen, unveraendert>.
-- Die dritte Zeile ist die Zahl, die ohne den Riegel bei einem einzigen
-- Loeschvorgang entstanden waere - sie steht hier als Mass, nicht als Fund.
select
  pg_get_functiondef('public.notify_event_audience()'::regprocedure)
    like '%old.team_id is not null and new.team_id is null%' as riegel_steht,
  (select count(*) > 0 from pg_trigger t
    where t.tgrelid = 'public.events'::regclass
      and t.tgfoid = 'public.notify_event_audience()'::regprocedure
      and pg_get_triggerdef(t.oid) like '%team_id%')         as ausloeser_kennt_team_id_noch,
  (select max(z.termine * z.empfaenger) from (
     select count(e.id) as termine,
            (select count(*) from public.club_memberships m
              where m.club_id = t.club_id and m.status = 'active'
                and m.profile_id is not null) as empfaenger
       from public.teams t
       left join public.events e on e.team_id = t.id
      group by t.id, t.club_id) z)                           as groesste_lawine_waere,
  (select count(*) from public.user_notifications)           as meldungen_jetzt;
