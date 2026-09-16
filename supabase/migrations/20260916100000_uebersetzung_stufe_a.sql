-- Uebersetzung Stufe A: Datum je Empfaengersprache, Leitungsmeldungen vom
-- Server, Willkommensbeitrag je Leser, italienisch 'club'.
--
-- a) public.meldung_datum(timestamptz, text, boolean) und
--    public.meldung_datum(date, text, boolean default false): kurzes Datum im
--    Muster der Sprache (de 'DD.MM.', tr 'DD.MM', en/es/pt/it/fr 'DD/MM'),
--    Zeitpunkte in Europe/Berlin. Die Datenbank laeuft in UTC - bisher stand
--    die Uhrzeit in Termin-Meldungen im Sommer 2 Stunden zu frueh da.
-- b) notify_event_audience, run_carpool_gap_check, run_duty_gap_check,
--    helferdienst_einteilung_melden: Rumpf aus PROD (pg_get_functiondef,
--    16.09.2026), geaendert NUR das Datum (Nachweis: diff-<name>.txt).
--    helferdienst_einteilung_melden holt die Sprache jetzt VOR dem Datum.
-- c) public.leitung_melden(...) ersetzt notify_many aus dem Client
--    (notifyClubAdmins): Empfaenger, Texte und Datum bestimmt der Server, je
--    Empfaenger in seiner Sprache. notify_many bleibt vorerst (alte Apps).
-- d) news_posts.vorlage/werte: Der automatische Willkommensbeitrag traegt
--    vorlage 'news.willkommen' und werte {"name": Vorname}; die App uebersetzt
--    ihn je Leser. Alte Willkommensbeitraege werden nachgezogen.
--    update_news_post loest die Vorlage, sobald jemand Titel/Text aendert.
--    news_melden bleibt unveraendert (schweigt weiter ueber cmo.news_still).
-- e) meldungstexte: it 'società' -> 'club' (13), pt allg.jemand 'Alguém',
--    de ergebnis.fehlt.text in du-Form, fr familie.anfrage.text informell.
--
-- Vorher scripts/sicherung-vor-migration.sh ausfuehren.

-- ================================================================ a) meldung_datum
create or replace function public.meldung_datum(p_ts timestamptz, p_sprache text, p_mit_uhrzeit boolean)
returns text
language sql
stable
set search_path = ''
as $$
  /* Zeitpunkt in Berliner Zeit, Muster wie DATUMS_LOCALES in der App
     (de-DE, tr-TR, en-GB, es-ES, pt-PT, it-IT, fr-FR). Unbekannte oder
     fehlende Sprache: deutsch. p_ts null ergibt null. */
  select to_char(p_ts at time zone 'Europe/Berlin',
           case when p_sprache = 'tr' then 'DD.MM'
                when p_sprache in ('en', 'es', 'pt', 'it', 'fr') then 'DD/MM'
                else 'DD.MM.' end
           || case when coalesce(p_mit_uhrzeit, false) then ' HH24:MI' else '' end);
$$;

create or replace function public.meldung_datum(p_tag date, p_sprache text, p_mit_jahr boolean default false)
returns text
language sql
stable
set search_path = ''
as $$
  /* Reines Datum - keine Zeitzone noetig. Mit Jahr: de/tr 'DD.MM.YYYY',
     en/es/pt/it/fr 'DD/MM/YYYY'. */
  select to_char(p_tag::timestamp,
           case when p_sprache = 'tr' then
                  case when coalesce(p_mit_jahr, false) then 'DD.MM.YYYY' else 'DD.MM' end
                when p_sprache in ('en', 'es', 'pt', 'it', 'fr') then
                  case when coalesce(p_mit_jahr, false) then 'DD/MM/YYYY' else 'DD/MM' end
                else
                  case when coalesce(p_mit_jahr, false) then 'DD.MM.YYYY' else 'DD.MM.' end
           end);
$$;

-- Nur fuer Serverfunktionen (SECURITY DEFINER laufen als postgres), wie meldungstext.
revoke all on function public.meldung_datum(timestamptz, text, boolean) from public, anon, authenticated;
revoke all on function public.meldung_datum(date, text, boolean) from public, anon, authenticated;
grant execute on function public.meldung_datum(timestamptz, text, boolean) to service_role;
grant execute on function public.meldung_datum(date, text, boolean) to service_role;

-- ================================================================ b) Datum je Empfaengersprache
-- Rumpfe aus PROD (pg_get_functiondef, 16.09.2026). CREATE OR REPLACE behaelt
-- Rechte und Ausloeser. Geaendert ist nur die Datumsformatierung.

-- ---------------------------------------------------------------- notify_event_audience
CREATE OR REPLACE FUNCTION public.notify_event_audience()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_situation  text;   -- angelegt | abgesagt | geaendert
  v_basis      text;   -- z. B. termin.spiel.abgesagt
  v_schluessel text;   -- zugleich kind und Einstellungsschluessel
  v_teamart    text;   -- trainings | spiele | null
  v_grund      text;
begin
  v_teamart := case new.type when 'training' then 'trainings' when 'spiel' then 'spiele' else null end;

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

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, v_schluessel,
         public.meldungstext(v_basis || '.titel', p.language),
         /* Der Grund steht am ENDE, nicht direkt hinter dem Satz. Vorher las
            sich eine Absage als "Das Spiel wurde abgesagt. Grund: Glatteis
            Herren 1 gegen Herringen · 12.09. · Hemberghalle" - der Grund
            klebte am Spieltitel und man wusste nicht, wo er aufhoert. */
         public.meldungstext(v_basis || '.text', p.language)
           || ' ' || coalesce(new.title, '')
           || coalesce(' · ' || public.meldung_datum(new.starts_at, p.language, true), '')
           || coalesce(' · ' || new.location, '')
           || case when v_situation = 'abgesagt' and v_grund is not null
                   then ' ·' || public.meldungstext('termin.grund', p.language, jsonb_build_object('grund', v_grund))
                   else '' end,
         'termin', new.id
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
$function$
;

-- ---------------------------------------------------------------- run_carpool_gap_check
CREATE OR REPLACE FUNCTION public.run_carpool_gap_check()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled'
      and e.type = 'spiel'
      and coalesce(e.home_away, 'auswaerts') <> 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', public.meldung_datum(ev.starts_at, public.sprache_der_mitgliedschaft(member.id), false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$function$
;

-- ---------------------------------------------------------------- run_duty_gap_check
CREATE OR REPLACE FUNCTION public.run_duty_gap_check()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev record;
  member record;
begin
  for ev in
    select e.id, e.club_id, e.team_id, e.title, e.starts_at
    from public.events e
    where e.status = 'scheduled' and e.home_away = 'heim'
      and (e.starts_at at time zone 'Europe/Berlin')::date = (now() at time zone 'Europe/Berlin')::date + 3
      and exists (select 1 from public.duty_tasks dt where dt.event_id = e.id and dt.assignee_membership_id is null and dt.done = false)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'duty',
        'helfer.gesucht.titel', 'helfer.gesucht.text',
        jsonb_build_object('titel', ev.title, 'datum', public.meldung_datum(ev.starts_at, public.sprache_der_mitgliedschaft(member.id), false)),
        jsonb_build_object('ziel_art', 'termin', 'ziel_id', ev.id));
    end loop;
  end loop;
end;
$function$
;

-- ---------------------------------------------------------------- helferdienst_einteilung_melden
CREATE OR REPLACE FUNCTION public.helferdienst_einteilung_melden()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_profil  uuid;
  v_wer     text;
  v_sprache text;
  v_termin  text;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;
  if not public.meldung_erlaubt(v_profil, 'duty') then return new; end if;
  v_sprache := public.sprache_der_mitgliedschaft(new.membership_id);
  select nullif(trim(coalesce(e.title, '') || coalesce(' · ' || public.meldung_datum(e.starts_at, v_sprache, false), '')), '')
    into v_termin from public.events e where e.id = new.event_id;
  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = new.club_id limit 1;
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, 'duty',
          public.meldungstext('aufgabe.zugewiesen.titel', v_sprache),
          public.meldungstext('aufgabe.zugewiesen.textMitTitel', v_sprache,
            jsonb_build_object(
              'wer', coalesce(v_wer, public.meldungstext('allg.vereinsleitung', v_sprache)),
              'titel', new.station || coalesce(' – ' || v_termin, ''))),
          'helferdienst', new.event_id);
  return new;
end;
$function$
;

-- ================================================================ c) leitung_melden
-- Texte (aus lib/sprachen.ts fzg.neueBuchung, fzg.gebuchtText, mit.gesperrt,
-- mit.wurdeGesperrt, mit.mitgliedschaftBeendet, mit.nichtMehrAktivesMitglied,
-- mit.entfernt, mit.ausVereinEntfernt; {name} heisst hier {wer}).
insert into public.meldungstexte (schluessel, sprache, text) values
  ('fahrzeug.gebucht.titel', 'de', 'Neue Fahrzeugbuchung'),
  ('fahrzeug.gebucht.titel', 'en', 'New vehicle booking'),
  ('fahrzeug.gebucht.titel', 'es', 'Nueva reserva de vehículo'),
  ('fahrzeug.gebucht.titel', 'pt', 'Nova reserva de veículo'),
  ('fahrzeug.gebucht.titel', 'it', 'Nuova prenotazione veicolo'),
  ('fahrzeug.gebucht.titel', 'tr', 'Yeni araç rezervasyonu'),
  ('fahrzeug.gebucht.titel', 'fr', 'Nouvelle réservation de véhicule'),
  ('fahrzeug.gebucht.text', 'de', '{wer} hat {fahrzeug} gebucht ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'en', '{wer} booked {fahrzeug} ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'es', '{wer} ha reservado {fahrzeug} ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'pt', '{wer} reservou {fahrzeug} ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'it', '{wer} ha prenotato {fahrzeug} ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'tr', '{wer}, {fahrzeug} için rezervasyon yaptı ({von} – {bis}).'),
  ('fahrzeug.gebucht.text', 'fr', '{wer} a réservé {fahrzeug} ({von} – {bis}).'),
  ('mitglied.gesperrt.titel', 'de', 'Mitglied gesperrt'),
  ('mitglied.gesperrt.titel', 'en', 'Member blocked'),
  ('mitglied.gesperrt.titel', 'es', 'Miembro bloqueado'),
  ('mitglied.gesperrt.titel', 'pt', 'Membro bloqueado'),
  ('mitglied.gesperrt.titel', 'it', 'Membro bloccato'),
  ('mitglied.gesperrt.titel', 'tr', 'Üye engellendi'),
  ('mitglied.gesperrt.titel', 'fr', 'Membre bloqué'),
  ('mitglied.gesperrt.text', 'de', '{wer} wurde für den Verein gesperrt.'),
  ('mitglied.gesperrt.text', 'en', '{wer} has been blocked from the club.'),
  ('mitglied.gesperrt.text', 'es', 'Se ha bloqueado a {wer} en el club.'),
  ('mitglied.gesperrt.text', 'pt', 'O acesso de {wer} ao clube foi bloqueado.'),
  ('mitglied.gesperrt.text', 'it', 'L''accesso di {wer} al club è stato bloccato.'),
  ('mitglied.gesperrt.text', 'tr', '{wer} kulüpte engellendi.'),
  ('mitglied.gesperrt.text', 'fr', 'L''accès de {wer} au club a été bloqué.'),
  ('mitglied.beendet.titel', 'de', 'Mitgliedschaft beendet'),
  ('mitglied.beendet.titel', 'en', 'Membership ended'),
  ('mitglied.beendet.titel', 'es', 'Afiliación finalizada'),
  ('mitglied.beendet.titel', 'pt', 'Filiação terminada'),
  ('mitglied.beendet.titel', 'it', 'Iscrizione terminata'),
  ('mitglied.beendet.titel', 'tr', 'Üyelik sonlandırıldı'),
  ('mitglied.beendet.titel', 'fr', 'Adhésion terminée'),
  ('mitglied.beendet.text', 'de', '{wer} ist nicht mehr aktives Mitglied.'),
  ('mitglied.beendet.text', 'en', '{wer} is no longer an active member.'),
  ('mitglied.beendet.text', 'es', '{wer} ya no es miembro activo.'),
  ('mitglied.beendet.text', 'pt', '{wer} já não é membro ativo.'),
  ('mitglied.beendet.text', 'it', '{wer} non è più un membro attivo.'),
  ('mitglied.beendet.text', 'tr', '{wer} artık aktif üye değil.'),
  ('mitglied.beendet.text', 'fr', '{wer} n''est plus membre actif.'),
  ('mitglied.entfernt.titel', 'de', 'Mitglied entfernt'),
  ('mitglied.entfernt.titel', 'en', 'Member removed'),
  ('mitglied.entfernt.titel', 'es', 'Miembro eliminado'),
  ('mitglied.entfernt.titel', 'pt', 'Membro removido'),
  ('mitglied.entfernt.titel', 'it', 'Membro rimosso'),
  ('mitglied.entfernt.titel', 'tr', 'Üye kaldırıldı'),
  ('mitglied.entfernt.titel', 'fr', 'Membre supprimé'),
  ('mitglied.entfernt.text', 'de', '{wer} wurde aus dem Verein entfernt.'),
  ('mitglied.entfernt.text', 'en', '{wer} has been removed from the club.'),
  ('mitglied.entfernt.text', 'es', 'Se ha eliminado a {wer} del club.'),
  ('mitglied.entfernt.text', 'pt', '{wer} já não faz parte do clube.'),
  ('mitglied.entfernt.text', 'it', '{wer} non fa più parte del club.'),
  ('mitglied.entfernt.text', 'tr', '{wer} kulüpten çıkarıldı.'),
  ('mitglied.entfernt.text', 'fr', '{wer} ne fait plus partie du club.')
on conflict (schluessel, sprache) do update set text = excluded.text;

create or replace function public.leitung_melden(
  p_club       uuid,
  p_art        text,
  p_schluessel text,
  p_werte      jsonb default '{}'::jsonb,
  p_ausser     uuid  default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
/* Meldet der Vereinsleitung (vereinsadmin, sysadmin, organisator - dieselbe
   Menge wie notifyClubAdmins/notify_many) eine Aktion aus der App. Anders als
   notify_many kommen keine fertigen Saetze vom Client: Titel und Text entstehen
   hier aus meldungstexte, je Empfaenger in SEINER Sprache, das Datum im Muster
   dieser Sprache.
   p_werte: wer, fahrzeug, von, bis (von/bis als 'YYYY-MM-DD').
   p_ausser: Mitgliedschafts- ODER Profil-Kennung, die nichts bekommt (die
   betroffene Person). Der Aufrufer selbst bekommt nie etwas.
   Einstellungen wie bei notify_many: notify() und warteschlange_in_glocke
   pruefen beide notification_master und notification_preferences[p_art] -
   genau das ist meldung_erlaubt. Rueckgabe: Anzahl geschriebener Meldungen. */
declare
  v_ich      uuid := auth.uid();
  v_werte    jsonb := case when jsonb_typeof(p_werte) = 'object' then p_werte else '{}'::jsonb end;
  v_wer      text;
  v_fahrzeug text;
  v_von_roh  text;
  v_bis_roh  text;
  v_von      date;
  v_bis      date;
  v_anzahl   integer;
begin
  if v_ich is null then
    raise exception 'nicht_angemeldet' using errcode = '42501';
  end if;
  if p_art is null or p_art not in ('vehicle', 'membership') then
    raise exception 'meldungsart_nicht_erlaubt' using errcode = '42501';
  end if;
  if p_schluessel is null or p_schluessel not in
     ('fahrzeug.gebucht', 'mitglied.gesperrt', 'mitglied.beendet', 'mitglied.entfernt') then
    raise exception 'schluessel_nicht_erlaubt' using errcode = '22023';
  end if;
  /* Art und Text gehoeren zusammen: Fahrzeug nur mit Fahrzeugtext, Mitglied
     nur mit Mitgliedstext. Sonst liesse sich eine Meldung mit fremder Art
     (und damit an der falschen Einstellung vorbei) verschicken. */
  if (p_art = 'vehicle') <> (p_schluessel = 'fahrzeug.gebucht') then
    raise exception 'meldungsart_passt_nicht' using errcode = '22023';
  end if;
  if p_club is null or not public.is_club_member(p_club) then
    raise exception 'nicht_im_verein' using errcode = '42501';
  end if;
  /* Sperren, Beenden und Entfernen kann nur die Vereinsleitung - also darf
     auch nur sie diese Meldungen ausloesen (Gegenpruefung 16.09.2026). */
  if p_art = 'membership' and not exists (
       select 1 from public.club_memberships ich
         join public.membership_roles r on r.membership_id = ich.id
        where ich.club_id = p_club and ich.profile_id = v_ich and ich.status = 'active'
          and r.role in ('vereinsadmin', 'sysadmin', 'organisator')) then
    raise exception 'nur_vereinsleitung' using errcode = '42501';
  end if;

  v_wer      := left(nullif(btrim(v_werte ->> 'wer'), ''), 200);
  v_fahrzeug := left(coalesce(btrim(v_werte ->> 'fahrzeug'), ''), 200);
  v_von_roh  := left(coalesce(btrim(v_werte ->> 'von'), ''), 40);
  v_bis_roh  := left(coalesce(btrim(v_werte ->> 'bis'), ''), 40);
  /* Ein Datum, das sich nicht lesen laesst, bleibt als Rohtext stehen - die
     Meldung soll daran nicht scheitern. */
  if v_von_roh ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
    begin v_von := left(v_von_roh, 10)::date; exception when others then v_von := null; end;
  end if;
  if v_bis_roh ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' then
    begin v_bis := left(v_bis_roh, 10)::date; exception when others then v_bis := null; end;
  end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select m.profile_id, p_club, p_art,
         left(public.meldungstext(p_schluessel || '.titel', w.sprache, w.werte), 200),
         left(public.meldungstext(p_schluessel || '.text',  w.sprache, w.werte), 1000),
         null, null
    from public.club_memberships m
    left join public.profiles p on p.id = m.profile_id
    cross join lateral (
      select coalesce(p.language, 'de') as sprache
    ) s
    cross join lateral (
      select s.sprache,
             jsonb_build_object(
               'wer',      coalesce(v_wer, public.meldungstext('allg.jemand', s.sprache)),
               'fahrzeug', v_fahrzeug,
               'von',      coalesce(public.meldung_datum(v_von, s.sprache, true), v_von_roh),
               'bis',      coalesce(public.meldung_datum(v_bis, s.sprache, true), v_bis_roh)) as werte
    ) w
   where m.club_id = p_club
     and m.status = 'active'
     and m.profile_id is not null
     and m.profile_id <> v_ich
     and (p_ausser is null or (m.id <> p_ausser and m.profile_id <> p_ausser))
     and exists (select 1 from public.membership_roles r
                  where r.membership_id = m.id
                    and r.role in ('vereinsadmin', 'sysadmin', 'organisator'))
     and public.meldung_erlaubt(m.profile_id, p_art);

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

revoke all on function public.leitung_melden(uuid, text, text, jsonb, uuid) from public, anon;
grant execute on function public.leitung_melden(uuid, text, text, jsonb, uuid) to authenticated;

-- ================================================================ d) Willkommensbeitrag je Leser
alter table public.news_posts
  add column if not exists vorlage text,
  add column if not exists werte   jsonb;

/* Eine Vorlage setzt nur der Server (willkommens_news, ohne Verfasser).
   Redakteure legen Beitraege immer mit author_id = auth.uid() an
   (create_news_post, Policy "news editors create posts") - so kann niemand
   einen Beitrag als uebersetzte Vereinsbegruessung tarnen. */
alter table public.news_posts drop constraint if exists news_posts_vorlage_check;
alter table public.news_posts add constraint news_posts_vorlage_check
  check (vorlage is null or (vorlage = 'news.willkommen' and author_id is null));
alter table public.news_posts drop constraint if exists news_posts_werte_check;
alter table public.news_posts add constraint news_posts_werte_check
  check (werte is null or jsonb_typeof(werte) = 'object');

-- Lesen: authenticated hat SELECT auf der ganzen Tabelle, neue Spalten sind
-- damit lesbar; die Zeilen regelt weiter die Policy "club members read news posts".

-- ---------------------------------------------------------------- willkommens_news
CREATE OR REPLACE FUNCTION public.willkommens_news()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  angeschaltet boolean;
begin
  -- Nur beim Übergang auf 'active'. Ein erneutes Speichern derselben Zeile
  -- soll nicht jedes Mal grüßen.
  if new.status <> 'active' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;

  -- Kein oeffentlicher Willkommensbeitrag fuer einen Fan (12.09.2026). Die
  -- Rolle steht schon da: beitritt_entscheiden schreibt sie vor dem Status.
  -- Die Vereinsleitung erfaehrt es trotzdem - ueber aufnahme_leitung_melden.
  if exists (select 1 from public.membership_roles r
              where r.membership_id = new.id and r.role = 'fan') then
    return new;
  end if;

  select coalesce(s.welcome_automation, true) into angeschaltet
    from public.club_settings s where s.club_id = new.club_id;
  if angeschaltet is false then return new; end if;

  -- Still: news_melden überspringt diesen einen Beitrag. Die Markierung gilt
  -- nur in dieser Transaktion und wird gleich danach wieder gelöscht.
  perform set_config('cmo.news_still', 'an', true);
  -- vorlage/werte (16.09.2026): Die App zeigt den Beitrag in der Sprache des
  -- Lesers. title/body/author_name bleiben der deutsche Rueckfall fuer alte Apps.
  insert into public.news_posts (club_id, title, body, author_id, author_name, vorlage, werte)
  values (
    new.club_id,
    'Willkommen im Verein, ' || split_part(trim(new.display_name), ' ', 1) || '!',
    'Schön, dass du da bist. Unter „Termine" findest du Training und Spiele, im Chat erreichst du deine Mannschaft.',
    null,
    'Verein',
    'news.willkommen',
    jsonb_build_object('name', split_part(trim(new.display_name), ' ', 1))
  );
  perform set_config('cmo.news_still', '', true);

  return new;
exception when others then
  -- Die Aufnahme ist wichtiger als der Gruss: Sie gilt, auch wenn der
  -- Beitrag nicht entsteht. Die Markierung faellt mit dem Block zurueck.
  raise warning 'Willkommensbeitrag fehlgeschlagen: %', sqlerrm;
  return new;
end;
$function$
;

-- ---------------------------------------------------------------- update_news_post
CREATE OR REPLACE FUNCTION public.update_news_post(target_post uuid, new_title text, new_body text, new_image_path text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  post_club uuid;
  altes_bild text;
begin
  select club_id, image_path into post_club, altes_bild
    from public.news_posts where id = target_post;

  if post_club is null then raise exception 'Post not found'; end if;
  if auth.uid() is null or not public.has_club_role(
    post_club,
    array['redakteur','vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::public.club_role[]
  ) then raise exception 'Not authorized'; end if;

  if nullif(trim(new_title), '') is null or nullif(trim(new_body), '') is null then
    raise exception 'Title and body are required';
  end if;
  if new_image_path is not null and new_image_path not like post_club::text || '/%' then
    raise exception 'Invalid image path';
  end if;

  update public.news_posts
     set title = trim(new_title),
         body = trim(new_body),
         image_path = coalesce(new_image_path, image_path),
         /* Wer Titel oder Text eines Vorlagen-Beitrags (Willkommen) aendert,
            macht daraus einen normalen Beitrag - sonst zeigte die App weiter
            die uebersetzte Vorlage statt des geaenderten Textes. Nur ein
            neues Bild laesst die Vorlage stehen. */
         vorlage = case when trim(new_title) is distinct from title
                          or trim(new_body) is distinct from body then null else vorlage end,
         werte = case when trim(new_title) is distinct from title
                        or trim(new_body) is distinct from body then null else werte end
   where id = target_post;

  return case when new_image_path is not null and altes_bild is distinct from new_image_path
              then altes_bild end;
end;
$function$
;

/* Alte Willkommensbeitraege nachziehen (PROD 16.09.2026: 15 Stueck). Erkannt
   am exakten deutschen Text ohne Verfasser. news_posts hat keinen
   UPDATE-Ausloeser - es entsteht keine Meldung, updated_at bleibt. */
update public.news_posts
   set vorlage = 'news.willkommen',
       werte   = jsonb_build_object('name', substring(title from '^Willkommen im Verein, (.*)!$'))
 where vorlage is null
   and author_id is null
   and author_name = 'Verein'
   and title ~ '^Willkommen im Verein, .*!$'
   and body = 'Schön, dass du da bist. Unter „Termine" findest du Training und Spiele, im Chat erreichst du deine Mannschaft.';

-- ================================================================ e) Textkorrekturen
-- it: 'club' (maskulin) statt 'società'. Die Ersatzwoerter landen als {verein}
-- bzw. {wer} in Saetzen ohne Geschlechtsangleichung (Pruefung bestand-server.json).
insert into public.meldungstexte (schluessel, sprache, text) values
  ('allg.deinVerein', 'it', 'Il tuo club'),
  ('allg.verein', 'it', 'Il club'),
  ('allg.vereinsleitung', 'it', 'La dirigenza del club'),
  ('allg.vereinsmeldung', 'it', 'Comunicazione del club'),
  ('aufgaben.schwelle.titel', 'it', 'Il club ha bisogno di te'),
  ('beitritt.anfrage.text', 'it', '{wer} vuole iscriversi al club. Accetta o rifiuta ora.'),
  ('beitritt.anfrage.textOhneName', 'it', 'Qualcuno vuole iscriversi al club. Accetta o rifiuta ora.'),
  ('beitritt.aufgenommen.text', 'it', '{wer} ora è membro del club.'),
  ('beitritt.aufgenommen.textOhneName', 'it', 'Un nuovo membro è entrato nel club.'),
  ('fahrzeug.abgelehnt', 'it', 'La tua richiesta di prenotazione del veicolo del club è stata rifiutata.'),
  ('fahrzeug.angenommen', 'it', 'La tua richiesta di prenotazione del veicolo del club è stata accettata.'),
  ('fahrzeug.titel', 'it', 'Veicolo del club'),
  ('news.titel', 'it', 'Nuove notizie del club'),
  ('allg.jemand', 'pt', 'Alguém'),
  ('ergebnis.fehlt.text', 'de', 'Trag bitte das Ergebnis vom Spiel {titel} ein.'),
  ('familie.anfrage.text', 'fr', '{wer} souhaite créer un lien familial. Confirme ou refuse.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ================================================================ f) Pruefung
-- Erwartet: datum_funktionen = 2, datum_de = '15.09. 00:30', datum_tr = '15.09',
-- datum_en_jahr = '20/09/2026', neue_texte = 56, it_societa = 0,
-- pt_jemand = 'Alguém', de_ergebnis = 'Trag bitte das Ergebnis vom Spiel {titel} ein.',
-- rumpfe_mit_to_char = 0, rumpfe_mit_meldung_datum = 4,
-- leitung_definer = true, leitung_authenticated = true, leitung_anon = false,
-- news_spalten = 2, news_spalten_lesbar = true, willkommen_mit_vorlage = true,
-- update_loest_vorlage = true, willkommen_nachgezogen >= 15 (PROD-Stand 16.09.).
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'meldung_datum') as datum_funktionen,
  public.meldung_datum('2026-09-14 22:30:00+00'::timestamptz, 'de', true) as datum_de,
  public.meldung_datum('2026-09-14 22:30:00+00'::timestamptz, 'tr', false) as datum_tr,
  public.meldung_datum('2026-09-20'::date, 'en', true) as datum_en_jahr,
  (select count(*) from public.meldungstexte
    where schluessel in ('fahrzeug.gebucht.titel', 'fahrzeug.gebucht.text',
                         'mitglied.gesperrt.titel', 'mitglied.gesperrt.text',
                         'mitglied.beendet.titel', 'mitglied.beendet.text',
                         'mitglied.entfernt.titel', 'mitglied.entfernt.text')) as neue_texte,
  (select count(*) from public.meldungstexte where sprache = 'it' and text ilike '%societ%') as it_societa,
  (select text from public.meldungstexte where schluessel = 'allg.jemand' and sprache = 'pt') as pt_jemand,
  (select text from public.meldungstexte where schluessel = 'ergebnis.fehlt.text' and sprache = 'de') as de_ergebnis,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('notify_event_audience', 'run_carpool_gap_check', 'run_duty_gap_check', 'helferdienst_einteilung_melden')
      and p.prosrc like '%to_char(%') as rumpfe_mit_to_char,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('notify_event_audience', 'run_carpool_gap_check', 'run_duty_gap_check', 'helferdienst_einteilung_melden')
      and p.prosrc like '%public.meldung_datum(%') as rumpfe_mit_meldung_datum,
  (select p.prosecdef from pg_proc p where p.oid = 'public.leitung_melden(uuid,text,text,jsonb,uuid)'::regprocedure) as leitung_definer,
  has_function_privilege('authenticated', 'public.leitung_melden(uuid,text,text,jsonb,uuid)', 'execute') as leitung_authenticated,
  has_function_privilege('anon', 'public.leitung_melden(uuid,text,text,jsonb,uuid)', 'execute') as leitung_anon,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'news_posts' and column_name in ('vorlage', 'werte')) as news_spalten,
  (has_column_privilege('authenticated', 'public.news_posts', 'vorlage', 'select')
   and has_column_privilege('authenticated', 'public.news_posts', 'werte', 'select')) as news_spalten_lesbar,
  (select p.prosrc like '%''news.willkommen''%' from pg_proc p where p.oid = 'public.willkommens_news()'::regprocedure) as willkommen_mit_vorlage,
  (select p.prosrc like '%vorlage = case%' from pg_proc p where p.oid = 'public.update_news_post(uuid,text,text,text)'::regprocedure) as update_loest_vorlage,
  (select count(*) from public.news_posts where vorlage = 'news.willkommen') as willkommen_nachgezogen;
