-- To-Do-Board fuer die Vereinsleitung - und die Erinnerung an fehlende
-- Spielergebnisse.
--
-- DAS PROBLEM
-- Was offen ist, verteilt sich heute ueber drei Bildschirme: Mitgliedsantraege
-- unter "Mitgliedsantraege", fehlende Ergebnisse unter "Spielergebnisse",
-- Aufgaben in der Terminkarte. Wer nicht danach sucht, findet es nicht - und
-- ein Mitgliedsantrag, den niemand sieht, ist ein Mensch, der vor der Tuer
-- steht und wartet.
--
-- EINE FUNKTION, DREI QUELLEN
-- offene_punkte_fuer_verein sammelt alles in einer Liste. Jede Zeile weiss,
-- WOHIN sie fuehrt (ziel) und WELCHER Datensatz gemeint ist (ziel_id) - die
-- App muss nicht raten, wo die Aenderung stattfindet.
--
-- WARUM IN DER DATENBANK UND NICHT IN DER APP
-- Die App muesste sonst Mitgliedsantraege, Termine, Ergebnisse und Aufgaben
-- vollstaendig laden, um daraus abzuleiten, was fehlt. Das sind vier Abfragen
-- fuer eine Liste, die meistens leer ist - und drei davon liefern Daten, die
-- den Betrachter nichts angehen, wenn er die Rechte nicht hat.
--
-- WAS ERLEDIGT IST, VERSCHWINDET VON SELBST
-- Es gibt keine "abgehakt"-Spalte. Ein Punkt steht in der Liste, WEIL etwas
-- fehlt - sobald es da ist, faellt er aus der Abfrage. Ein Haken, den jemand
-- setzen muss, waere eine zweite Wahrheit neben der ersten.

create or replace function public.offene_punkte_fuer_verein(target_club uuid)
returns table (art text, titel text, detail text, ziel text, ziel_id uuid, seit timestamptz)
language plpgsql stable security definer set search_path = 'public' as $$
begin
  if not public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::club_role[]) then
    raise exception 'Not authorized';
  end if;

  return query
  /* 1. Mitgliedsantraege, ueber die noch niemand entschieden hat */
  select 'mitgliedsantrag'::text,
         'Offener Mitgliedsantrag'::text,
         m.display_name || coalesce(', ' || u.email, ''),
         'memberships'::text, m.id, m.created_at
  from public.club_memberships m
  left join auth.users u on u.id = m.profile_id
  where m.club_id = target_club and m.status = 'pending'

  union all

  /* 2. Spiele, die vorbei sind und kein Ergebnis haben.
        Erst ab drei Stunden nach Anpfiff - vorher laeuft das Spiel noch. */
  select 'spielergebnis'::text,
         'Offenes Spielergebnis'::text,
         e.title || coalesce(' · ' || t.name, ''),
         'results'::text, e.id, e.starts_at
  from public.events e
  left join public.teams t on t.id = e.team_id
  left join public.event_results r on r.event_id = e.id
  where e.club_id = target_club and e.type = 'spiel'
    and e.status is distinct from 'cancelled'
    and e.starts_at < now() - interval '3 hours'
    and e.starts_at > now() - interval '60 days'
    and r.event_id is null

  union all

  /* 3. Aufgaben, die niemand erledigt hat */
  select 'aufgabe'::text,
         'Offene Aufgabe'::text,
         t.title,
         'duty'::text, t.id, t.created_at
  from public.duty_tasks t
  where t.club_id = target_club and t.done is not true

  order by 6 asc;
end;
$$;

grant execute on function public.offene_punkte_fuer_verein(uuid) to authenticated, service_role;

/* Erinnerung an fehlende Spielergebnisse.
   Drei Stunden nach Anpfiff, einmalig. Ohne die Spalte wuerde die Erinnerung
   stuendlich wiederkommen, solange das Ergebnis fehlt - das liest niemand
   zweimal, es schaltet nur die Benachrichtigungen ab. */
alter table public.events add column if not exists ergebnis_erinnert_at timestamptz;

create or replace function public.ergebnis_erinnerung_senden()
returns integer language plpgsql security definer set search_path = 'public' as $$
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
    insert into public.user_notifications (profile_id, club_id, kind, title, body)
    select distinct m.profile_id, f.club_id, 'result', 'Ergebnis fehlt',
           'Bitte das Ergebnis vom Spiel ' || f.title || ' eintragen.'
    from faellig f
    join public.membership_roles ro on true
    join public.club_memberships m on m.id = ro.membership_id
    where m.club_id = f.club_id and m.status = 'active' and m.profile_id is not null
      and ro.role in ('vereinsadmin','sysadmin','organisator')
    returning 1
  )
  update public.events set ergebnis_erinnert_at = now() where id in (select id from faellig);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

select cron.unschedule('ergebnis-erinnerung')
 where exists (select 1 from cron.job where jobname = 'ergebnis-erinnerung');
select cron.schedule('ergebnis-erinnerung', '15 * * * *',
  $$select public.ergebnis_erinnerung_senden();$$);

select
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('offene_punkte_fuer_verein','ergebnis_erinnerung_senden')) as funktionen,
  (select count(*) from cron.job where jobname='ergebnis-erinnerung') as auftrag;
