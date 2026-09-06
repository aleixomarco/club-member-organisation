-- Wer die Mannschaft angelegt hat, wird jetzt auch festgehalten.
--
-- Die Spalte teams.created_by gibt es seit heute; gefuellt hat sie niemand.
-- Mannschaften entstehen ausschliesslich ueber create_club_team - dort
-- gehoert der Eintrag hin, nicht in die App: Die Funktion kennt auth.uid()
-- ohnehin, und so kann kein Aufrufer einen falschen Namen mitgeben.
--
-- teams.created_by verweist auf club_memberships, nicht auf profiles. Der
-- Wert muss also erst nachgeschlagen werden - dieselbe Person hat in jedem
-- Verein eine eigene Mitgliedschaft.
--
-- Die Funktion ist ansonsten Wort fuer Wort die aus der Produktionsdatenbank.
-- Eine Funktion, die man nicht ganz kennt, aendert man an der einen Zeile,
-- um die es geht - ich habe heute Nacht schon einmal eine aus dem Gedaechtnis
-- neu geschrieben und dabei die Haelfte verloren.

create or replace function public.create_club_team(
  target_club uuid, team_name text, team_category text default null::text, team_is_adult boolean default false
) returns uuid
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  created_team uuid;
  normalized_name text := nullif(trim(team_name), '');
  meine_mitgliedschaft uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_name is null then raise exception 'Team name required'; end if;
  if char_length(normalized_name) > 80 then raise exception 'Team name too long'; end if;

  if not public.has_club_role(
    target_club,
    array['sysadmin','vereinsadmin']::public.club_role[]
  ) then raise exception 'Club administrator role required'; end if;

  /* Die eigene Mitgliedschaft in DIESEM Verein. Bleibt sie leer, wird die
     Mannschaft trotzdem angelegt - eine fehlende Herkunftsangabe ist kein
     Grund, das Anlegen scheitern zu lassen. */
  select m.id into meine_mitgliedschaft
  from public.club_memberships m
  where m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
  limit 1;

  insert into public.teams (club_id, name, category, active, is_adult, created_by)
  values (target_club, normalized_name, nullif(trim(team_category), ''), true, coalesce(team_is_adult, false), meine_mitgliedschaft)
  on conflict (club_id, name) do nothing
  returning id into created_team;

  if created_team is null then raise exception 'Team already exists'; end if;
  return created_team;
end;
$function$;

select count(*) as funktion from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_club_team';
