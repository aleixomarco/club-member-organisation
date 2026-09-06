-- Wer darf ein Training oder Spiel fuer eine Mannschaft anlegen?
--
-- GEWUENSCHT
-- Vereinsadministration, Organisator, Trainer, Teammanager und Kapitaen -
-- die drei letzten nur fuer IHRE Mannschaft.
--
-- WAS BISHER GALT
--   has_club_role(club_id, ['sysadmin','vereinsadmin'])
--   OR (team_id IS NOT NULL AND can_manage_team(team_id))
--
-- can_manage_team deckt Trainer, Kapitaen und Teammanager der jeweiligen
-- Mannschaft ab - das war also schon richtig. Es fehlte der Organisator.
-- Er plant im Verein die Helferdienste und die Vereinstermine, durfte aber
-- kein Training eintragen; wer das versuchte, bekam "dir fehlt das Recht,
-- fuer diese Mannschaft einzutragen" und keine Erklaerung dazu.
--
-- WARUM DER ORGANISATOR VEREINSWEIT DARF
-- Trainer, Kapitaen und Teammanager haengen an einer Mannschaft - fuer sie
-- ergibt "nur die eigene" Sinn. Der Organisator haengt an keiner. Ihn auf
-- "seine Mannschaften" zu beschraenken hiesse, ihn auf gar keine zu
-- beschraenken. Er steht deshalb neben der Vereinsadministration.
--
-- SYSADMIN BLEIBT
-- Das ist die technische Verantwortung im Verein, nicht eine Rolle, die
-- jemand nebenbei hat. Wer sie hat, muss im Zweifel alles reparieren
-- koennen - auch einen Termin, den sonst niemand mehr aendern kann.

drop policy if exists "authorized roles create events" on public.events;
create policy "authorized roles create events" on public.events for insert
  to authenticated with check (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  );

drop policy if exists "authorized roles update events" on public.events;
create policy "authorized roles update events" on public.events for update
  to authenticated using (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  ) with check (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  );

drop policy if exists "authorized roles delete events" on public.events;
create policy "authorized roles delete events" on public.events for delete
  to authenticated using (
    public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  );

select policyname, cmd from pg_policies
where schemaname='public' and tablename='events' order by cmd;
