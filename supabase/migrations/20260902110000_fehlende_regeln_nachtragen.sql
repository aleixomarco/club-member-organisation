-- Die Sicherheitsregeln der sieben nachgetragenen Tabellen.
--
-- Ebenfalls aus der laufenden Datenbank ausgelesen. Bis auf eine sind sie
-- unveraendert uebernommen.
--
-- Die Ausnahme ist "adult team leaders assign penalties". Dort standen zwei
-- Bedingungen, die nichts pruefen:
--
--   (r.team_id = r.team_id)
--   (tm.team_id = tm.team_id) AND (tm.membership_id = tm.membership_id)
--
-- Beide vergleichen eine Spalte mit sich selbst und sind damit immer wahr.
-- Gemeint war offensichtlich der Bezug auf die einzufuegende Zeile. Wie es
-- dastand, konnte eine Mannschaftsleitung eine Strafe nach einer Regel einer
-- FREMDEN Mannschaft verhaengen, und gegen jemanden, der gar nicht in ihrer
-- Mannschaft ist. Hier steht es richtig.

drop policy if exists "club members read tasks" on public.club_tasks;
create policy "club members read tasks" on public.club_tasks for select to authenticated using (
  exists (select 1 from public.club_memberships m
           where m.club_id = club_tasks.club_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "authorized members create tasks" on public.club_tasks;
create policy "authorized members create tasks" on public.club_tasks for insert to authenticated with check (
  created_by in (select m.id from public.club_memberships m where m.profile_id = auth.uid() and m.status = 'active')
  and ((team_id is not null and public.can_manage_team(team_id))
       or (team_id is null and public.has_beyond_basic_role(club_id)))
);

drop policy if exists "task creator deletes task" on public.club_tasks;
create policy "task creator deletes task" on public.club_tasks for delete to authenticated using (
  created_by in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
);

drop policy if exists "club members read task signups" on public.club_task_signups;
create policy "club members read task signups" on public.club_task_signups for select to authenticated using (
  exists (select 1 from public.club_tasks t join public.club_memberships m on m.club_id = t.club_id
           where t.id = club_task_signups.task_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "club members signup for tasks" on public.club_task_signups;
create policy "club members signup for tasks" on public.club_task_signups for insert to authenticated with check (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "club members withdraw own signup" on public.club_task_signups;
create policy "club members withdraw own signup" on public.club_task_signups for delete to authenticated using (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
);

drop policy if exists "club members read carpools" on public.carpools;
create policy "club members read carpools" on public.carpools for select to authenticated using (
  exists (select 1 from public.events e join public.club_memberships m on m.club_id = e.club_id
           where e.id = carpools.event_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "club members create carpools" on public.carpools;
create policy "club members create carpools" on public.carpools for insert to authenticated with check (
  driver_membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "driver deletes own carpool" on public.carpools;
create policy "driver deletes own carpool" on public.carpools for delete to authenticated using (
  driver_membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
);

drop policy if exists "club members read carpool passengers" on public.carpool_passengers;
create policy "club members read carpool passengers" on public.carpool_passengers for select to authenticated using (
  exists (select 1 from public.carpools c
            join public.events e on e.id = c.event_id
            join public.club_memberships m on m.club_id = e.club_id
           where c.id = carpool_passengers.carpool_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "club members join carpool" on public.carpool_passengers;
create policy "club members join carpool" on public.carpool_passengers for insert to authenticated with check (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "club members leave carpool" on public.carpool_passengers;
create policy "club members leave carpool" on public.carpool_passengers for delete to authenticated using (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
);

drop policy if exists "club members read duty templates" on public.duty_task_templates;
create policy "club members read duty templates" on public.duty_task_templates for select to authenticated using (
  exists (select 1 from public.club_memberships m
           where m.club_id = duty_task_templates.club_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "organisers manage duty templates" on public.duty_task_templates;
create policy "organisers manage duty templates" on public.duty_task_templates for all to authenticated
using (public.can_manage_duty_templates(club_id))
with check (public.can_manage_duty_templates(club_id));

drop policy if exists "club members read duty template items" on public.duty_task_template_items;
create policy "club members read duty template items" on public.duty_task_template_items for select to authenticated using (
  exists (select 1 from public.duty_task_templates t join public.club_memberships m on m.club_id = t.club_id
           where t.id = duty_task_template_items.template_id and m.profile_id = auth.uid() and m.status = 'active')
);

drop policy if exists "organisers manage duty template items" on public.duty_task_template_items;
create policy "organisers manage duty template items" on public.duty_task_template_items for all to authenticated
using (exists (select 1 from public.duty_task_templates t
                where t.id = duty_task_template_items.template_id and public.can_manage_duty_templates(t.club_id)))
with check (exists (select 1 from public.duty_task_templates t
                where t.id = duty_task_template_items.template_id and public.can_manage_duty_templates(t.club_id)));

drop policy if exists "adult team participants read penalty assignments" on public.team_penalty_assignments;
create policy "adult team participants read penalty assignments" on public.team_penalty_assignments for select to authenticated using (
  public.is_team_participant(team_id) and public.is_adult_team(team_id)
);

drop policy if exists "club leaders read all penalty assignments" on public.team_penalty_assignments;
create policy "club leaders read all penalty assignments" on public.team_penalty_assignments for select to authenticated using (
  exists (select 1 from public.teams t join public.club_memberships m on m.club_id = t.club_id
           where t.id = team_penalty_assignments.team_id and m.profile_id = auth.uid() and m.status = 'active'
             and exists (select 1 from public.membership_roles r
                          where r.membership_id = m.id
                            and r.role = any (array['vorstand','finanzmanager','sysadmin','vereinsadmin']::public.club_role[])))
);

drop policy if exists "adult team leaders assign penalties" on public.team_penalty_assignments;
create policy "adult team leaders assign penalties" on public.team_penalty_assignments for insert to authenticated with check (
  public.can_manage_team(team_id)
  and public.is_adult_team(team_id)
  and assigned_by = auth.uid()
  -- Die Regel muss zu DIESER Mannschaft gehoeren ...
  and exists (select 1 from public.team_penalty_rules r
               where r.id = team_penalty_assignments.rule_id
                 and r.team_id = team_penalty_assignments.team_id)
  -- ... und die bestrafte Person in ihr sein.
  and exists (select 1 from public.team_members tm
               where tm.team_id = team_penalty_assignments.team_id
                 and tm.membership_id = team_penalty_assignments.membership_id)
);

drop policy if exists "adult team leaders delete penalty assignments" on public.team_penalty_assignments;
create policy "adult team leaders delete penalty assignments" on public.team_penalty_assignments for delete to authenticated using (
  public.can_manage_team(team_id) and public.is_adult_team(team_id)
);
