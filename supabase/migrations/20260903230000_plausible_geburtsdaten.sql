-- Geburtsdaten, die es geben kann.
--
-- In den Profilen standen zwei Geburtsdaten aus den Jahren 11 und 23 — jemand
-- hat „11.11.11" in ein Datumsfeld getippt, und das Feld hat es genommen. Das
-- fiel erst auf, als die Zielgruppen-Auswertung ein Durchschnittsalter von
-- 1009,8 Jahren meldete.
--
-- Zwei Lehren, beide hier umgesetzt:
--
-- 1. Die Auswertung darf an einem einzelnen Ausreisser nicht kippen. Sie
--    ignoriert jetzt, was ausserhalb des Moeglichen liegt, statt es
--    mitzumitteln.
-- 2. Wichtiger: So etwas darf gar nicht erst hineinkommen. Ein Geburtsdatum vor
--    1900 oder in der Zukunft ist kein Datum, sondern ein Vertipper.
--
-- Die beiden vorhandenen Werte werden auf null gesetzt. Ein unmoegliches Datum
-- ist keine Angabe, die man erhalten muesste — es ist eine falsche.

update public.profiles
   set birthdate = null
 where birthdate is not null
   and (birthdate < date '1900-01-01' or birthdate > current_date);

alter table public.profiles drop constraint if exists profiles_geburtsdatum_plausibel;
alter table public.profiles
  add constraint profiles_geburtsdatum_plausibel
  check (birthdate is null or (birthdate >= date '1900-01-01' and birthdate <= current_date + 1));

/* Und die Auswertung robust machen: ein einzelner Ausreisser darf das Bild
   nicht kippen, auch wenn er kuenftig auf anderem Weg hineinkaeme. */
create or replace function public.zielgruppe_eines_vereins(target_club uuid)
returns table (
  mitglieder integer, aktive integer,
  alter_unter_18 integer, alter_18_29 integer, alter_30_49 integer, alter_50_plus integer,
  alter_unbekannt integer, durchschnittsalter numeric,
  weiblich integer, maennlich integer, divers_oder_offen integer,
  mannschaften integer, groesste_mannschaft text, groesste_mannschaft_groesse integer,
  aktiv_letzte_30_tage integer
)
language sql stable security definer set search_path = '' as $$
  with m as (
    select cm.id, cm.status, p.gender, cm.profile_id,
           -- Nur was moeglich ist: alles andere gilt als "keine Angabe".
           nullif(
             case when p.birthdate is null then null
                  else extract(year from age(p.birthdate))::integer end,
             null
           ) filter_dummy,
           case when p.birthdate is null then null
                when extract(year from age(p.birthdate)) < 0 then null
                when extract(year from age(p.birthdate)) > 120 then null
                else extract(year from age(p.birthdate))::integer end as jahre
      from public.club_memberships cm
      left join public.profiles p on p.id = cm.profile_id
     where cm.club_id = target_club
  )
  select
    (select count(*)::integer from m),
    (select count(*)::integer from m where status = 'active'),
    (select count(*)::integer from m where jahre < 18),
    (select count(*)::integer from m where jahre between 18 and 29),
    (select count(*)::integer from m where jahre between 30 and 49),
    (select count(*)::integer from m where jahre >= 50),
    (select count(*)::integer from m where jahre is null),
    (select round(avg(jahre), 1) from m),
    (select case when count(*) >= 5 then count(*)::integer end from m where gender = 'weiblich'),
    (select case when count(*) >= 5 then count(*)::integer end from m where gender = 'maennlich'),
    (select case when count(*) >= 5 then count(*)::integer end from m where gender is null or gender not in ('weiblich','maennlich')),
    (select count(*)::integer from public.teams t where t.club_id = target_club and t.active),
    (select t.name from public.teams t
       join public.team_members tm on tm.team_id = t.id
      where t.club_id = target_club and t.active
      group by t.name order by count(*) desc limit 1),
    (select count(*)::integer from public.team_members tm
       join public.teams t on t.id = tm.team_id
      where t.club_id = target_club and t.active
      group by t.name order by count(*) desc limit 1),
    (select count(distinct d.profile_id)::integer from public.user_devices d
      where d.profile_id in (select profile_id from m where profile_id is not null)
        and d.last_seen > now() - interval '30 days');
$$;

revoke all on function public.zielgruppe_eines_vereins(uuid) from public, anon, authenticated;
