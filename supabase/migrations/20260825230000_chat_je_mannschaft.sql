-- Chat: ein Kanal je Mannschaft, sichtbar für deren Mitglieder
--
-- Bisheriges Modell: Sichtbarkeit über visible_roles, also über Rollen. Das
-- kann nicht ausdrücken, was gebraucht wird - ein Herren-1-Spieler und ein
-- Herren-2-Spieler haben dieselbe Rolle "spieler", sollen aber verschiedene
-- Kanäle sehen. Entscheidend ist die Mannschaft, nicht die Rolle.
--
-- Neues Modell:
--   Je Mannschaft genau ein Kanal, automatisch angelegt.
--   Sehen darf ihn, wer in der Mannschaft steht - oder ein Elternteil, dessen
--   Kind darin steht.
--   Schreiben dürfen nur die Organisatoren: Trainer, Kapitän, Teammanager
--   sowie Vorstand, Geschäftsführung und die Vereinsverwaltung.
--   Neue Kanäle kann niemand von Hand anlegen.

-- ---------------------------------------------------------------- Hilfsmittel

/* Gehört die angemeldete Person zu dieser Mannschaft - selbst oder über ein
   Kind? security definer, weil die Abfrage sonst wieder durch die Regeln
   liefe, die sie gerade beantworten soll. */
create or replace function public.gehoert_zu_mannschaft(target_team uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with meine as (
    select m.id from public.club_memberships m
    where m.profile_id = auth.uid() and m.status = 'active'
  ),
  kinder as (
    select case
             when f.first_membership_id in (select id from meine) and f.first_to_second = 'eltern'
               then f.second_membership_id
             when f.second_membership_id in (select id from meine) and f.second_to_first = 'eltern'
               then f.first_membership_id
           end as id
    from public.family_links f
  )
  select exists (
    select 1 from public.team_members tm
    where tm.team_id = target_team
      and (tm.membership_id in (select id from meine)
           or tm.membership_id in (select id from kinder where id is not null))
  );
$$;

grant execute on function public.gehoert_zu_mannschaft(uuid) to authenticated;

-- ------------------------------------------------------------- Kanäle anlegen

/* Ein Kanal je Mannschaft. Schreiben nur die Organisatoren; visible_roles
   bleibt leer, weil die Sichtbarkeit jetzt über die Mannschaft läuft. */
insert into public.channels (club_id, name, emoji, team_id, write_roles, visible_roles)
select t.club_id, t.name, '🏒', t.id,
       array['trainer','kapitaen','teammanager','vorstand','geschaeftsfuehrung','vereinsadmin','sysadmin']::public.club_role[],
       '{}'::public.club_role[]
from public.teams t
where not exists (select 1 from public.channels c where c.team_id = t.id);

/* Neue Mannschaften bekommen ihren Kanal automatisch - sonst müsste jemand
   daran denken, und irgendwann fehlt einer. */
create or replace function public.kanal_fuer_neue_mannschaft()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.channels (club_id, name, emoji, team_id, write_roles, visible_roles)
  values (new.club_id, new.name, '🏒', new.id,
          array['trainer','kapitaen','teammanager','vorstand','geschaeftsfuehrung','vereinsadmin','sysadmin']::public.club_role[],
          '{}'::public.club_role[])
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists teams_kanal_anlegen on public.teams;
create trigger teams_kanal_anlegen
  after insert on public.teams
  for each row execute function public.kanal_fuer_neue_mannschaft();

-- ------------------------------------------------------------------- Regeln

/* Kanäle legt niemand von Hand an - sie entstehen mit der Mannschaft. */
drop policy if exists "admins create channels" on public.channels;

drop policy if exists "members read channels" on public.channels;
create policy "members read channels" on public.channels for select using (
  public.is_club_member(club_id)
  and (
    -- Mannschaftskanal: nur für die Mannschaft
    (team_id is not null and public.gehoert_zu_mannschaft(team_id))
    -- Vereinsweiter Kanal: nach Rollen, leer heißt alle
    or (team_id is null and (cardinality(visible_roles) = 0 or public.has_club_role(club_id, visible_roles)))
  )
);

drop policy if exists "members read messages" on public.messages;
create policy "members read messages" on public.messages for select using (
  exists (
    select 1 from public.channels c
    where c.id = channel_id
      and public.is_club_member(c.club_id)
      and (
        (c.team_id is not null and public.gehoert_zu_mannschaft(c.team_id))
        or (c.team_id is null and (cardinality(c.visible_roles) = 0 or public.has_club_role(c.club_id, c.visible_roles)))
      )
  )
);

/* Schreiben: zusätzlich zur Sichtbarkeit muss die Rolle passen. Leeres
   write_roles hieße "alle" - bei Mannschaftskanälen steht dort jetzt die
   Liste der Organisatoren. */
drop policy if exists "authorized members write messages" on public.messages;
create policy "authorized members write messages" on public.messages for insert with check (
  author_id = auth.uid() and exists (
    select 1 from public.channels c
    where c.id = channel_id
      and public.is_club_member(c.club_id)
      and (
        (c.team_id is not null and public.gehoert_zu_mannschaft(c.team_id))
        or (c.team_id is null and (cardinality(c.visible_roles) = 0 or public.has_club_role(c.club_id, c.visible_roles)))
      )
      and (cardinality(c.write_roles) = 0 or public.has_club_role(c.club_id, c.write_roles))
  )
);

-- Kontrolle
select c.name, c.emoji, t.name as mannschaft, c.write_roles
from public.channels c
left join public.teams t on t.id = c.team_id
order by t.name nulls last, c.name;
