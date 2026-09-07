-- Die Fahrgemeinschafts-Erinnerung kommt nur noch fuer Spiele.
--
-- WAS PASSIERT IST
-- Am 07.09. ging an die Mannschaft "Für ... am 10.09. gibt es noch keine
-- Fahrgemeinschaft" - fuer ein TRAINING. Zu einem Training in der eigenen
-- Halle faehrt niemand in Fahrgemeinschaft.
--
-- WARUM
-- run_carpool_gap_check prueft die Terminart nicht. Es steht nur
--   coalesce(e.home_away, 'auswaerts') <> 'heim'
-- da - und ein Training hat gar kein home_away. Das coalesce macht daraus
-- 'auswaerts', und 'auswaerts' <> 'heim' ist wahr. Jedes Training drei Tage
-- im Voraus loeste die Meldung aus.
--
-- Nachgezaehlt: 130 Termine im Bestand sind keine Spiele und haetten die
-- Meldung im Lauf der Saison ausgeloest, zwei davon heute frueh.
--
-- Dieselbe Luecke steckte in spielergebnis_melden (20260907070000): ein
-- Ausloeser, der Tore oder Fahrten meint, aber die Terminart nicht prueft.
--
-- WARUM run_duty_gap_check UNANGETASTET BLEIBT
-- Dort steht home_away = 'heim' ohne coalesce - ein Training mit home_away
-- null faellt also von selbst heraus. Zusaetzlich feuert die Meldung nur,
-- wenn es zu dem Termin ueberhaupt unbesetzte Helferaufgaben gibt. Das ist
-- der bessere Waechter: Er fragt nicht nach der Terminart, sondern danach,
-- ob jemand fuer diesen Termin Helfer eingeplant hat. Ein Vereinsfest mit
-- Helferbedarf soll die Meldung bekommen duerfen.
create or replace function public.run_carpool_gap_check()
returns void language plpgsql security definer set search_path = 'public' as $$
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
      and e.starts_at::date = current_date + interval '3 days'
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id = e.id)
  loop
    for member in select distinct membership_id as id from public.team_members where team_id = ev.team_id loop
      perform public.notify_uebersetzt(member.id, 'carpool',
        'fahrgemeinschaft.fehlt.titel', 'fahrgemeinschaft.fehlt.text',
        jsonb_build_object('titel', ev.title, 'datum', to_char(ev.starts_at, 'DD.MM.')),
        jsonb_build_object('event_id', ev.id));
    end loop;
  end loop;
end;
$$;

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='run_carpool_gap_check'
      and p.prosrc like '%e.type = ''spiel''%') as waechter_gesetzt,
  (select count(*) from public.events e
    where e.status='scheduled' and e.type='spiel'
      and coalesce(e.home_away,'auswaerts') <> 'heim'
      and e.starts_at::date = current_date + interval '3 days'
      and e.team_id is not null
      and not exists (select 1 from public.carpools c where c.event_id=e.id)) as heute_noch_betroffen;
