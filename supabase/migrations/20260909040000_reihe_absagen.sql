/* Eine ganze Trainingsreihe absagen - und dafuer EINE Nachricht.

 * Bisher konnte man nur einen einzelnen Termin absagen. Bei einer Reihe hiess
 * das: zwanzigmal aufklappen, zwanzigmal denselben Grund tippen - und
 * zwanzig Push-Nachrichten an jedes Mitglied.
 *
 * Diese Migration bringt drei Dinge:
 *   1. absage_serie() - sagt alle noch nicht begonnenen Termine einer Reihe in
 *      einer einzigen Anweisung ab, mit denselben Rechten wie
 *      delete_event_series.
 *   2. Den Ausloeser: Eine Reihenabsage meldet einmal statt je Termin.
 *      Erkannt wird sie an einem gemeinsamen cancelled_at - genau das
 *      erzeugt die eine Anweisung aus 1. Ein einzeln abgesagter Termin einer
 *      Reihe hat keine solche Schwester und meldet normal weiter.
 *   3. Die Texte dazu in sieben Sprachen.
 */

insert into public.meldungstexte (schluessel, sprache, text) values
  ('termin.training.serie_abgesagt.titel', 'de', 'Trainingseinheiten abgesagt'),
  ('termin.training.serie_abgesagt.titel', 'en', 'Training sessions cancelled'),
  ('termin.training.serie_abgesagt.titel', 'es', 'Entrenamientos cancelados'),
  ('termin.training.serie_abgesagt.titel', 'pt', 'Treinos cancelados'),
  ('termin.training.serie_abgesagt.titel', 'it', 'Allenamenti annullati'),
  ('termin.training.serie_abgesagt.titel', 'tr', 'Antrenmanlar iptal edildi'),
  ('termin.training.serie_abgesagt.titel', 'fr', 'Entraînements annulés'),
  ('termin.training.serie_abgesagt.text', 'de', 'Wiederholende Trainingseinheiten wurden abgesagt.'),
  ('termin.training.serie_abgesagt.text', 'en', 'Recurring training sessions have been cancelled.'),
  ('termin.training.serie_abgesagt.text', 'es', 'Se han cancelado entrenamientos periódicos.'),
  ('termin.training.serie_abgesagt.text', 'pt', 'Foram cancelados treinos recorrentes.'),
  ('termin.training.serie_abgesagt.text', 'it', 'Sono stati annullati allenamenti ricorrenti.'),
  ('termin.training.serie_abgesagt.text', 'tr', 'Yinelenen antrenmanlar iptal edildi.'),
  ('termin.training.serie_abgesagt.text', 'fr', 'Des entraînements récurrents ont été annulés.'),
  ('termin.spiel.serie_abgesagt.titel', 'de', 'Spiele abgesagt'),
  ('termin.spiel.serie_abgesagt.titel', 'en', 'Games cancelled'),
  ('termin.spiel.serie_abgesagt.titel', 'es', 'Partidos cancelados'),
  ('termin.spiel.serie_abgesagt.titel', 'pt', 'Jogos cancelados'),
  ('termin.spiel.serie_abgesagt.titel', 'it', 'Partite annullate'),
  ('termin.spiel.serie_abgesagt.titel', 'tr', 'Maçlar iptal edildi'),
  ('termin.spiel.serie_abgesagt.titel', 'fr', 'Matchs annulés'),
  ('termin.spiel.serie_abgesagt.text', 'de', 'Wiederholende Spiele wurden abgesagt.'),
  ('termin.spiel.serie_abgesagt.text', 'en', 'Recurring games have been cancelled.'),
  ('termin.spiel.serie_abgesagt.text', 'es', 'Se han cancelado partidos periódicos.'),
  ('termin.spiel.serie_abgesagt.text', 'pt', 'Foram cancelados jogos recorrentes.'),
  ('termin.spiel.serie_abgesagt.text', 'it', 'Sono state annullate partite ricorrenti.'),
  ('termin.spiel.serie_abgesagt.text', 'tr', 'Yinelenen maçlar iptal edildi.'),
  ('termin.spiel.serie_abgesagt.text', 'fr', 'Des matchs récurrents ont été annulés.'),
  ('termin.event.serie_abgesagt.titel', 'de', 'Termine abgesagt'),
  ('termin.event.serie_abgesagt.titel', 'en', 'Events cancelled'),
  ('termin.event.serie_abgesagt.titel', 'es', 'Eventos cancelados'),
  ('termin.event.serie_abgesagt.titel', 'pt', 'Eventos cancelados'),
  ('termin.event.serie_abgesagt.titel', 'it', 'Eventi annullati'),
  ('termin.event.serie_abgesagt.titel', 'tr', 'Etkinlikler iptal edildi'),
  ('termin.event.serie_abgesagt.titel', 'fr', 'Événements annulés'),
  ('termin.event.serie_abgesagt.text', 'de', 'Wiederholende Termine wurden abgesagt.'),
  ('termin.event.serie_abgesagt.text', 'en', 'Recurring events have been cancelled.'),
  ('termin.event.serie_abgesagt.text', 'es', 'Se han cancelado eventos periódicos.'),
  ('termin.event.serie_abgesagt.text', 'pt', 'Foram cancelados eventos recorrentes.'),
  ('termin.event.serie_abgesagt.text', 'it', 'Sono stati annullati eventi ricorrenti.'),
  ('termin.event.serie_abgesagt.text', 'tr', 'Yinelenen etkinlikler iptal edildi.'),
  ('termin.event.serie_abgesagt.text', 'fr', 'Des événements récurrents ont été annulés.')
on conflict (schluessel, sprache) do update set text = excluded.text;


/* Eine ganze Reihe absagen - in EINER Anweisung.

   Warum eine Funktion und nicht ein UPDATE aus der App: Die Rechte gehoeren in
   die Datenbank, und der Ausloeser oben unterscheidet Reihen- von
   Einzelabsage an einem gemeinsamen cancelled_at. Ein UPDATE je Termin aus der
   App haette verschiedene Zeitpunkte erzeugt - und damit wieder eine Nachricht
   pro Termin.

   Die Rechtefrage ist woertlich dieselbe wie bei delete_event_series: die
   Vereinsleitung, oder wer die Mannschaft betreut.

   Abgesagt wird nur, was noch NICHT begonnen hat. delete_event_series loescht
   zwar die ganze Reihe samt Vergangenheit, aber ein Training abzusagen, das
   vor drei Wochen stattgefunden hat, ergibt keinen Sinn - und wuerde eine
   Meldung darueber ausloesen. */
create or replace function public.absage_serie(target_series uuid, grund text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club uuid; v_team uuid; v_anzahl integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if target_series is null then raise exception 'Serie fehlt'; end if;
  if nullif(trim(grund), '') is null then raise exception 'Grund fehlt'; end if;

  select club_id, team_id into v_club, v_team
    from public.events where series_id = target_series limit 1;
  if v_club is null then raise exception 'Reihe nicht gefunden'; end if;

  if not (
    public.has_club_role(v_club, array['sysadmin','vereinsadmin']::public.club_role[])
    or (v_team is not null and public.can_manage_team(v_team))
  ) then raise exception 'Not authorized'; end if;

  update public.events
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = auth.uid(),
         cancel_reason = trim(grund)
   where series_id = target_series
     and status <> 'cancelled'
     and starts_at >= now();

  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

revoke all on function public.absage_serie(uuid, text) from public, anon;
grant execute on function public.absage_serie(uuid, text) to authenticated;

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
           || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
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
    and public.meldung_erlaubt(m.profile_id, v_schluessel);

  return new;
end;
$function$;
