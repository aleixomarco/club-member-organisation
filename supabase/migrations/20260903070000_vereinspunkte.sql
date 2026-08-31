-- Vereinspunkte, die man wirklich bekommt.
--
-- Im Profil steht ein Fortschrittsbalken „Vereinspunkte 0 / 1000" und darunter
-- „Noch 1000 Punkte bis zum kostenlosen Vereins-Hoodie". Beides war Fassade:
-- Aus der Datenbank geladene Mitglieder bekamen fest points = 0, Werte ungleich
-- null gab es nur bei den erfundenen Demo-Konten. Jedes echte Mitglied sah also
-- dauerhaft 0 von 1000 — und eine Prämie, von der sein Verein nie gehört hatte.
--
-- Das Versprechen ist dabei das Schlimmere: Die App verpflichtete jeden Verein
-- zu einem Hoodie. Deshalb zwei Dinge:
--
-- 1. Die Punkte werden aus dem gerechnet, was ohnehin in der Datenbank steht —
--    Mitmachen. Kein neues Erfassen, keine neue Pflege.
-- 2. Was es dafür gibt, entscheidet der Verein. Ohne Eintrag steht schlicht
--    kein Versprechen da.

alter table public.club_settings
  add column if not exists punkte_ziel integer not null default 1000
    check (punkte_ziel > 0),
  add column if not exists punkte_praemie text;

comment on column public.club_settings.punkte_praemie is
  'Was der Verein beim Erreichen des Ziels verspricht. Null bedeutet: nichts versprechen.';

/* Die Punkte eines ganzen Vereins auf einmal.
 *
 * Gewichtet nach Aufwand: Sich für einen Helferdienst einzutragen kostet einen
 * Nachmittag, ein Tipp kostet zehn Sekunden. Die Zahlen sind gerundet und
 * sollen es sein — eine Nachkommastelle würde eine Genauigkeit vortäuschen, die
 * es bei so etwas nicht gibt.
 *
 * Bewusst berechnet und nicht gespeichert: Ein gespeicherter Punktestand müsste
 * bei jeder Änderung nachgeführt werden und liefe irgendwann auseinander. So
 * stimmt er immer, und niemand kann ihn von Hand hochsetzen.
 */
create or replace function public.punkte_je_mitglied(target_club uuid)
returns table (membership_id uuid, punkte integer)
language sql stable security definer set search_path = '' as $$
  select m.id,
         (
           -- Helferdienste: der größte Beitrag, den jemand leisten kann
           coalesce((select count(*) * 25 from public.duty_assignments d
                      join public.events e on e.id = d.event_id
                     where d.membership_id = m.id and e.club_id = target_club), 0)
           -- Übernommene Helferaufgaben
           + coalesce((select count(*) * 15 from public.duty_tasks t
                       where t.assignee_membership_id = m.id and t.club_id = target_club), 0)
           -- Mitmachen bei Umfragen und Wahlen
           + coalesce((select count(*) * 5 from public.poll_votes v
                        join public.polls p on p.id = v.poll_id
                       where p.club_id = target_club and v.profile_id = m.profile_id), 0)
           + coalesce((select count(*) * 5 from public.season_votes sv
                       where sv.club_id = target_club and sv.voter_profile_id = m.profile_id), 0)
           -- Tippspiel
           + coalesce((select count(*) * 2 from public.predictions pr
                        join public.events e2 on e2.id = pr.event_id
                       where e2.club_id = target_club and pr.profile_id = m.profile_id), 0)
           -- Vereinstreue: zehn Punkte je vollem Jahr
           + coalesce((extract(year from now())::integer - m.member_since) * 10, 0)
         )::integer
    from public.club_memberships m
   where m.club_id = target_club and m.status = 'active';
$$;

grant execute on function public.punkte_je_mitglied(uuid) to authenticated;
