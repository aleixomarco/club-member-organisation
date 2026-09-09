/* Der Trainer entscheidet getrennt, ob auch bei SPIELEN abgefragt wird.

 * Bisher gab es einen Schalter "Zusagen erlauben" je Mannschaft, und der galt
 * fuer alles: Training, Spiel, Vereinsevent. Ein Trainer, der vor dem
 * Training wissen will, wer kommt, bekam die Abfrage damit zwangslaeufig auch
 * unter jedes Spiel - oder musste auf beides verzichten.
 *
 * Jetzt sind es zwei Schalter. zusagen_aktiv gilt weiterhin fuer Trainings
 * und alles Uebrige, zusagen_spiele_aktiv fuer Spiele.
 *
 * WICHTIG BEIM UMSTIEG
 * Die neue Spalte wird mit dem bisherigen Wert gefuellt, nicht mit dem
 * Vorgabewert. Sonst verschwaende die Abfrage bei den Spielen genau der
 * Mannschaft, die sie heute benutzt (Damen 1) - eine stille Aenderung, die
 * niemand angeordnet hat. So bleibt zunaechst alles, wie es ist, und der
 * Trainer entscheidet ab jetzt selbst.
 *
 * Die Rechte bleiben woertlich, wie sie waren: der Trainer oder Teammanager
 * DIESER Mannschaft, oder die Vereinsleitung - damit sich niemand aussperrt,
 * wenn ein Trainer den Verein verlaesst.
 */

alter table public.teams
  add column if not exists zusagen_spiele_aktiv boolean not null default false;

update public.teams set zusagen_spiele_aktiv = zusagen_aktiv
 where zusagen_spiele_aktiv is distinct from zusagen_aktiv;

comment on column public.teams.zusagen_spiele_aktiv is
  'Zusage-Abfrage unter Spielen dieser Mannschaft. zusagen_aktiv gilt fuer Trainings.';

CREATE OR REPLACE FUNCTION public.mannschaft_funktionen_setzen(target_team uuid, p_zusagen boolean DEFAULT NULL::boolean, p_strafen boolean DEFAULT NULL::boolean, p_zusagen_spiele boolean DEFAULT NULL::boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_club uuid;
begin
  select club_id into v_club from public.teams where id = target_team;
  if v_club is null then raise exception 'Team not found'; end if;

  /* Der Trainer der Mannschaft - oder die Vereinsleitung, damit sich
     niemand aussperrt, wenn ein Trainer den Verein verlaesst. */
  if not exists (
    select 1 from public.team_members tm
    join public.club_memberships m on m.id = tm.membership_id
    where tm.team_id = target_team and m.profile_id = auth.uid()
      and m.status = 'active' and tm.function in ('trainer', 'teammanager')
  ) and not public.has_club_role(v_club, array['vereinsadmin','sysadmin']::club_role[]) then
    raise exception 'Not authorized';
  end if;

  update public.teams
     set zusagen_aktiv = coalesce(p_zusagen, zusagen_aktiv),
         strafen_aktiv = coalesce(p_strafen, strafen_aktiv),
         zusagen_spiele_aktiv = coalesce(p_zusagen_spiele, zusagen_spiele_aktiv)
   where id = target_team;
end;
$function$;
