-- Der Trainer entscheidet, was seine Mannschaft sieht.
--
-- WARUM
-- Zu- und Absagen und der Strafenkatalog passen nicht zu jeder Mannschaft.
-- Bei der U9 sagt niemand ab, da ruft ein Elternteil an. In der Herren 2
-- gibt es keinen Strafenkatalog, weil ihn nie jemand fuehren wollte. Bisher
-- war beides fuer alle da - und was man nicht braucht, steht trotzdem im
-- Weg.
--
-- Die Entscheidung gehoert dem Trainer, nicht der Vereinsleitung: Er kennt
-- seine Mannschaft, und er ist derjenige, der die Liste danach pflegen muss.
--
-- ZWEI UNTERSCHIEDLICHE VOREINSTELLUNGEN, UND DAS MIT ABSICHT
-- zusagen_aktiv steht auf false. Die Zu- und Absagen sind neu; niemand
-- arbeitet damit. Wer sie will, schaltet sie ein - so hat es der Verein
-- bestellt.
--
-- strafen_aktiv steht auf true. Den Strafenkatalog gibt es laenger, es
-- stehen Regeln und vergebene Strafen darin. Eine Voreinstellung auf false
-- wuerde diese Listen von einem Tag auf den anderen unsichtbar machen -
-- die Daten waeren noch da, aber niemand kaeme mehr heran. Wer den Katalog
-- nicht braucht, schaltet ihn aus.

alter table public.teams add column if not exists zusagen_aktiv boolean not null default false;
alter table public.teams add column if not exists strafen_aktiv boolean not null default true;

comment on column public.teams.zusagen_aktiv is
  'Der Trainer hat Zu- und Absagen fuer diese Mannschaft freigegeben.';
comment on column public.teams.strafen_aktiv is
  'Der Trainer zeigt den Strafenkatalog dieser Mannschaft.';

-- Schreiben darf nur, wer die Mannschaft fuehrt.
--
-- Auf teams liegt bisher nur "admins manage teams" - ein Trainer kommt an
-- die Tabelle gar nicht heran. Die Regel dafuer zu oeffnen waere zu viel:
-- dann duerfte er auch Namen, Kategorie und den Aktiv-Status aendern.
-- Diese Funktion schreibt genau zwei Spalten und sonst nichts.
create or replace function public.mannschaft_funktionen_setzen(
  target_team uuid,
  p_zusagen boolean default null,
  p_strafen boolean default null
) returns void
language plpgsql security definer set search_path = 'public' as $$
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
         strafen_aktiv = coalesce(p_strafen, strafen_aktiv)
   where id = target_team;
end;
$$;

grant execute on function public.mannschaft_funktionen_setzen(uuid, boolean, boolean)
  to authenticated, service_role;

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='teams'
      and column_name in ('zusagen_aktiv','strafen_aktiv')) as spalten,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='mannschaft_funktionen_setzen') as funktion;
