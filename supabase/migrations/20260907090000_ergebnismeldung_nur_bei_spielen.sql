-- Auch ergebnis_melden prueft jetzt die Terminart.
--
-- Beim Durchsehen aller Ausloeser, die auf Termine schauen, blieb dieser als
-- letzter uebrig. Er haengt an event_results und baut daraus Saetze wie "Das
-- Heimspiel der U15 haben wir mit 3:2 gewonnen!" - ohne je zu pruefen, ob der
-- Termin ein Spiel ist. Traegt jemand ein Ergebnis zu einem Training ein,
-- meldet der Verein einen Heimsieg im Training.
--
-- Noch nicht passiert: 0 von 1 Ergebnissen haengt an einem Nicht-Spiel. Der
-- Waechter kostet eine Zeile und schliesst die Luecke, bevor sie jemand
-- findet.
--
-- Damit ist die Fehlerklasse durch. Alle vier Ausloeser, die auf Termine
-- schauen, pruefen jetzt entweder die Art oder haben einen besseren Waechter:
--   ergebnis_erinnerung_senden  type = 'spiel'
--   ergebnis_melden             type = 'spiel'   (hier)
--   run_carpool_gap_check       type = 'spiel'   (20260907080000)
--   spielergebnis_melden        type = 'spiel'   (20260907070000)
--   run_duty_gap_check          home_away = 'heim' UND unbesetzte Helferaufgaben
create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_empfaenger  record;
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

  /* Nur Spiele. Ein Training hat kein Heim und kein Auswaerts - und wer
     wollte schon "Das Auswaertsspiel der U15 haben wir gewonnen" ueber eine
     Trainingseinheit lesen. Der Waechter steht VOR dem Tippspiel-Block, denn
     getippt wird ebenfalls nur auf Spiele. */
  if v_event.type is distinct from 'spiel' then return new; end if;

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

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

  for v_empfaenger in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and m.team_filter = v_mannschaft
  loop
    v_sprache := public.sprache_der_mitgliedschaft(v_empfaenger.id);
    perform public.notify(v_empfaenger.id, 'results'::text,
      public.meldungstext(v_schluessel, v_sprache, jsonb_build_object(
        'verein', coalesce(v_vereinsname, public.meldungstext('allg.verein', v_sprache)),
        'mannschaft', v_mannschaft,
        'heim', new.heim, 'auswaerts', new.auswaerts)),
      null::text);
  end loop;

  return new;
end;
$$;

select count(*) as ausloeser_ohne_artpruefung
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prosrc like '%public.events%'
  and (p.prosrc like '%user_notifications%' or p.prosrc like '%public.notify%')
  and p.prosrc !~ 'type\s+is\s+distinct\s+from\s+''spiel'''
  and p.prosrc !~ 'type\s*=\s*''spiel'''
  and p.prosrc !~ 'new\.type'
  and p.proname <> 'run_duty_gap_check';
