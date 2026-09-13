-- Die Erinnerung an ein fehlendes Ergebnis geht an genau die Menschen, die es
-- eintragen duerfen (Betreiberentscheidung 13.09.2026, Punkt 3).
--
-- Bisher (20260907060000:1022-1056): nur Vereinsadmin, Sysadmin, Organisator.
-- Trainer, Kapitaen und Teammanager kennen den Endstand aber am ehesten - 7 der
-- 11 offenen vergangenen Spiele auf PROD gehoeren zu Mannschaften mit Betreuern.
-- Die Regel ist darf_ergebnis_eintragen_fuer aus 20260914100000: erinnert wird,
-- wer eintragen darf - nicht mehr und nicht weniger. Auswahl der Spiele,
-- Einmal-Markierung ergebnis_erinnert_at und Sperre fuer Nutzer bleiben.
-- Der Suchpfad ist jetzt leer; jeder Name im Rumpf ist voll qualifiziert.
create or replace function public.ergebnis_erinnerung_senden()
 returns integer language plpgsql security definer set search_path to ''
as $function$
declare v_anzahl integer := 0;
begin
  with faellig as (
    select e.id, e.club_id, e.title
    from public.events e
    left join public.event_results r on r.event_id = e.id
    where e.type = 'spiel'
      and e.status is distinct from 'cancelled'
      and e.starts_at < now() - interval '3 hours'
      and e.starts_at > now() - interval '7 days'
      and r.event_id is null
      and e.ergebnis_erinnert_at is null
  ), gesendet as (
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, f.club_id, 'results',
           public.meldungstext('ergebnis.fehlt.titel', p.language),
           public.meldungstext('ergebnis.fehlt.text', p.language, jsonb_build_object('titel', f.title)),
           'termin', f.id
    from faellig f
    join public.club_memberships m
      on m.club_id = f.club_id and m.status = 'active' and m.profile_id is not null
    left join public.profiles p on p.id = m.profile_id
    where public.darf_ergebnis_eintragen_fuer(m.profile_id, f.club_id, f.id)
      and public.meldung_erlaubt(m.profile_id, 'results')
    returning 1
  )
  update public.events set ergebnis_erinnert_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$function$;

-- Wie 20260907110000:57 - nur der Zeitplan ruft das auf.
revoke execute on function public.ergebnis_erinnerung_senden() from public, anon, authenticated;

-- Probelauf ohne Versand (nur Zahlen): Empfaenger je offenem vergangenen Spiel
-- ohne Zeitfenster. Erwartet: mehr Empfaenger als vorher, Fans nie dabei.
select count(distinct x.event_id) as offene_spiele, count(*) as empfaenger_paare
from (
  select distinct m.profile_id, e.id as event_id
  from public.events e
  left join public.event_results r on r.event_id = e.id
  join public.club_memberships m
    on m.club_id = e.club_id and m.status = 'active' and m.profile_id is not null
  where e.type = 'spiel' and e.status is distinct from 'cancelled'
    and e.starts_at < now() and r.event_id is null
    and public.darf_ergebnis_eintragen_fuer(m.profile_id, e.club_id, e.id)
) as x;
