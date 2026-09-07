-- Eine Ergebnismeldung gibt es nur fuer Spiele.
--
-- spielergebnis_melden pruefte bisher nur, ob Tore eingetragen wurden - nicht,
-- ob der Termin ueberhaupt ein Spiel ist. Traegt jemand bei einem Training
-- oder einem Vereinstermin Zahlen in die beiden Felder, ging eine
-- Ergebnismeldung an die halbe Mannschaft.
--
-- Aufgefallen beim Uebersetzen: In der Sprachprobe stand
-- "Ergebnis | PRUEF-Training: 4:1".
create or replace function public.spielergebnis_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_werte jsonb;
begin
  if new.type is distinct from 'spiel' then return new; end if;
  if new.home_score is null or new.away_score is null then return new; end if;
  if old.home_score is not distinct from new.home_score
     and old.away_score is not distinct from new.away_score then return new; end if;

  v_werte := jsonb_build_object('titel', coalesce(new.title, ''),
                                'heim', new.home_score, 'auswaerts', new.away_score);

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldungstext('ergebnis.titel', p.language),
         public.meldungstext('ergebnis.text', p.language, v_werte),
         'termin', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = new.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, new.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$function$;

select (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='spielergebnis_melden'
           and p.prosrc like '%new.type is distinct from ''spiel''%') as wachposten_gesetzt;
