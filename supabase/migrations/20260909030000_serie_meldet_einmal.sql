/* Eine Serie meldet einmal - nicht je Termin.

 * Wer eine wiederkehrende Trainingsreihe anlegt, loeste bisher je Termin eine
 * Meldung und damit eine Push-Nachricht aus. An den Daten nachgewiesen: eine
 * Serie mit drei Terminen erzeugte neun Meldungen (drei Termine mal drei
 * Empfaenger). Die groesste vorhandene Serie hat 85 Termine - das waeren 85
 * Push-Nachrichten auf jedem Telefon, fuer ein einziges Anlegen.
 *
 * Der Grund liegt nicht im Text, sondern im Ausloeser: events_notify_audience
 * haengt an FOR EACH ROW. Geaendert wird deshalb beides - die Zahl der
 * Meldungen und ihr Wortlaut.
 *
 * WORTLAUT
 * Fuer eine Serie gibt es eine eigene Lage "serie_angelegt", damit dort nicht
 * "Das Training wurde angelegt" steht, wenn zwanzig angelegt wurden. Je
 * Terminart ein eigener Satz - "Trainingseinheiten" waere bei einer Spielserie
 * falsch. Den Vereinsnamen stellt meldung_vereinsname_voranstellen voran; er
 * gehoert deshalb nicht in den Text.
 *
 * Einzelne Termine bleiben unveraendert bei "angelegt".
 */

insert into public.meldungstexte (schluessel, sprache, text) values
  ('termin.training.serie_angelegt.titel', 'de', 'Trainingseinheiten angelegt'),
  ('termin.training.serie_angelegt.titel', 'en', 'Training sessions created'),
  ('termin.training.serie_angelegt.titel', 'es', 'Entrenamientos creados'),
  ('termin.training.serie_angelegt.titel', 'pt', 'Treinos criados'),
  ('termin.training.serie_angelegt.titel', 'it', 'Allenamenti creati'),
  ('termin.training.serie_angelegt.titel', 'tr', 'Antrenmanlar oluşturuldu'),
  ('termin.training.serie_angelegt.titel', 'fr', 'Entraînements créés'),
  ('termin.training.serie_angelegt.text', 'de', 'Wiederholende Trainingseinheiten wurden angelegt.'),
  ('termin.training.serie_angelegt.text', 'en', 'Recurring training sessions have been created.'),
  ('termin.training.serie_angelegt.text', 'es', 'Se han creado entrenamientos periódicos.'),
  ('termin.training.serie_angelegt.text', 'pt', 'Foram criados treinos recorrentes.'),
  ('termin.training.serie_angelegt.text', 'it', 'Sono stati creati allenamenti ricorrenti.'),
  ('termin.training.serie_angelegt.text', 'tr', 'Yinelenen antrenmanlar oluşturuldu.'),
  ('termin.training.serie_angelegt.text', 'fr', 'Des entraînements récurrents ont été créés.'),
  ('termin.spiel.serie_angelegt.titel', 'de', 'Spiele angelegt'),
  ('termin.spiel.serie_angelegt.titel', 'en', 'Games created'),
  ('termin.spiel.serie_angelegt.titel', 'es', 'Partidos creados'),
  ('termin.spiel.serie_angelegt.titel', 'pt', 'Jogos criados'),
  ('termin.spiel.serie_angelegt.titel', 'it', 'Partite create'),
  ('termin.spiel.serie_angelegt.titel', 'tr', 'Maçlar oluşturuldu'),
  ('termin.spiel.serie_angelegt.titel', 'fr', 'Matchs créés'),
  ('termin.spiel.serie_angelegt.text', 'de', 'Wiederholende Spiele wurden angelegt.'),
  ('termin.spiel.serie_angelegt.text', 'en', 'Recurring games have been created.'),
  ('termin.spiel.serie_angelegt.text', 'es', 'Se han creado partidos periódicos.'),
  ('termin.spiel.serie_angelegt.text', 'pt', 'Foram criados jogos recorrentes.'),
  ('termin.spiel.serie_angelegt.text', 'it', 'Sono state create partite ricorrenti.'),
  ('termin.spiel.serie_angelegt.text', 'tr', 'Yinelenen maçlar oluşturuldu.'),
  ('termin.spiel.serie_angelegt.text', 'fr', 'Des matchs récurrents ont été créés.'),
  ('termin.event.serie_angelegt.titel', 'de', 'Termine angelegt'),
  ('termin.event.serie_angelegt.titel', 'en', 'Events created'),
  ('termin.event.serie_angelegt.titel', 'es', 'Eventos creados'),
  ('termin.event.serie_angelegt.titel', 'pt', 'Eventos criados'),
  ('termin.event.serie_angelegt.titel', 'it', 'Eventi creati'),
  ('termin.event.serie_angelegt.titel', 'tr', 'Etkinlikler oluşturuldu'),
  ('termin.event.serie_angelegt.titel', 'fr', 'Événements créés'),
  ('termin.event.serie_angelegt.text', 'de', 'Wiederholende Termine wurden angelegt.'),
  ('termin.event.serie_angelegt.text', 'en', 'Recurring events have been created.'),
  ('termin.event.serie_angelegt.text', 'es', 'Se han creado eventos periódicos.'),
  ('termin.event.serie_angelegt.text', 'pt', 'Foram criados eventos recorrentes.'),
  ('termin.event.serie_angelegt.text', 'it', 'Sono stati creati eventi ricorrenti.'),
  ('termin.event.serie_angelegt.text', 'tr', 'Yinelenen etkinlikler oluşturuldu.'),
  ('termin.event.serie_angelegt.text', 'fr', 'Des événements récurrents ont été créés.')
on conflict (schluessel, sprache) do update set text = excluded.text;

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
