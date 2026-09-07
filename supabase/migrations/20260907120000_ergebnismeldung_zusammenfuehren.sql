-- Die Ergebnismeldung laeuft ueber den Weg, den die App wirklich benutzt.
--
-- WAS ICH HEUTE FRUEH FALSCH GEMACHT HABE
-- Ich habe spielergebnis_melden gebaut, einen Ausloeser auf events, der
-- feuert, wenn sich events.home_score/away_score aendern - und dir gesagt,
-- die Einstellung "Spielergebnisse" habe jetzt endlich einen Absender.
--
-- Sie hat ihn nicht. Die App schreibt Ergebnisse ausschliesslich nach
-- event_results (app/page.tsx: supabase.from("event_results").upsert(...)),
-- niemals nach events.home_score. Von 202 Terminen haben dort ganze zwei
-- ueberhaupt einen Wert, beide aus einem Test. Mein Ausloeser hat im echten
-- Betrieb also nie gefeuert.
--
-- Gefeuert hat die ganze Zeit ergebnis_melden auf event_results. Der schickt
-- aber an einen anderen Kreis - an alle, deren gespeicherte Ansicht
-- (club_memberships.team_filter) zufaellig auf den Mannschaftsnamen passt -,
-- traegt kein Ziel und ignoriert die Mannschafts-Einstellungen von heute.
--
-- Zwei Wege fuer dieselbe Meldung sind ohnehin einer zu viel. Es bleibt der,
-- den die App benutzt.

-- ------------------------------------------------- Der tote Weg verschwindet
drop trigger if exists events_ergebnis_melden on public.events;
drop function if exists public.spielergebnis_melden();

-- ------------------------------------- Der lebende bekommt, was ihm fehlte
create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_tipper      record;
  v_sprache     text;
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title, e.type
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;
  if v_event.type is distinct from 'spiel' then return new; end if;

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* Tippspiel zuerst - der Mannschaftsblock kehrt ohne Mannschaft frueh
     zurueck, getippt wird aber auch auf Begegnungen ohne hinterlegte
     Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    v_sprache := public.sprache_der_mitgliedschaft(v_tipper.id);
    perform public.notify_uebersetzt(v_tipper.id, 'tipp',
      'tipp.titel', 'tipp.text',
      jsonb_build_object(
        'titel', coalesce(v_event.title, public.meldungstext('allg.begegnung', v_sprache)),
        'heim', new.heim, 'auswaerts', new.auswaerts));
  end loop;

  if v_mannschaft is null then return new; end if;

  v_schluessel := 'ergebnis.'
    || case when v_event.home_away = 'heim' then 'heim' else 'auswaerts' end
    || case when new.heim > new.auswaerts then '.gewonnen'
            when new.heim = new.auswaerts then '.unentschieden'
            else '.verloren' end;

  /* Der Empfaengerkreis ist jetzt derselbe wie bei Terminen: wer in der
     Mannschaft steht oder sie ausdruecklich abonniert hat - und wer die
     Ergebnisse dieser Mannschaft nicht abbestellt hat.
     Vorher lief es ueber club_memberships.team_filter, also ueber die
     zufaellig gespeicherte Ansicht. Wer seine Ansicht auf "alle" stehen
     hatte, bekam gar nichts; wer sie auf eine fremde Mannschaft gestellt
     hatte, bekam deren Ergebnisse. */
  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldungstext(v_schluessel, p.language, jsonb_build_object(
           'verein', coalesce(v_vereinsname, public.meldungstext('allg.verein', p.language)),
           'mannschaft', v_mannschaft,
           'heim', new.heim, 'auswaerts', new.auswaerts)),
         '',
         'termin', new.event_id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = v_event.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = v_event.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, v_event.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$$;

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname='spielergebnis_melden') as toter_weg_weg,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname='ergebnis_melden' and prosrc like '%team_meldung_erlaubt%') as lebender_weg_gefiltert;
