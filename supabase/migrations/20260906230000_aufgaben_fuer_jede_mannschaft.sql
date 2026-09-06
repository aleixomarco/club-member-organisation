-- Vereinsleitung darf Aufgaben fuer JEDE Mannschaft anlegen.
--
-- Die Einfuegeregel verlangte bisher:
--   Mannschaftsaufgabe -> can_manage_team(team_id)
--   Vereinsaufgabe     -> has_beyond_basic_role(club_id)
--
-- can_manage_team prueft die FUNKTION IN DER MANNSCHAFT (trainer, kapitaen,
-- teammanager). Ein Vereinsadmin, der selbst keine Mannschaft betreut, faellt
-- durch - er darf Beitraege verwalten und Rollen vergeben, aber der U15 keine
-- Aufgabe geben.
--
-- Das fiel erst auf, als das Anlegeformular ein Auswahlfeld fuer die
-- Mannschaft bekam: Vorher ergab sich die Mannschaft daraus, ueber welchen
-- Knopf man anlegte - und diesen Knopf sah nur, wer die Mannschaft betreute.
-- Die Regel und die Bedienung passten also zusammen, solange die Bedienung
-- eng war. Mit der freien Auswahl bot die App etwas an, das die Datenbank
-- ablehnte: "Aufgabe konnte nicht angelegt werden", ohne Grund.
--
-- Jetzt darf zusaetzlich die Vereinsleitung. Wer den ganzen Verein verwaltet,
-- soll auch einer einzelnen Mannschaft eine Aufgabe geben duerfen.

drop policy if exists "authorized members create tasks" on public.club_tasks;
create policy "authorized members create tasks" on public.club_tasks
  for insert with check (
    created_by in (
      select m.id from public.club_memberships m
      where m.profile_id = auth.uid() and m.status = 'active'
    )
    and (
      (team_id is not null and (
          public.can_manage_team(team_id)
          or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])))
      or (team_id is null and public.has_beyond_basic_role(club_id))
    )
  );

/* Aendern fehlte ganz - eine angelegte Aufgabe liess sich nicht mehr
   bearbeiten, obwohl die App einen Knopf dafuer hat. */
drop policy if exists "authorized members update tasks" on public.club_tasks;
create policy "authorized members update tasks" on public.club_tasks
  for update using (
    created_by in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
    or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  );

select polcmd, polname from pg_policy where polrelid='public.club_tasks'::regclass order by polcmd;
