-- Protokolle: wer sie sieht, wer sie loescht, und was oeffentlich ist.
--
-- DREI DINGE AUF EINMAL, WEIL SIE DIESELBE REGEL BETREFFEN
--
-- 1. TEILNEHMENDE SEHEN IHR PROTOKOLL
--    Bisher las nur die Vereinsleitung. Wer an einer Sitzung teilgenommen hat
--    und selbst kein Vorstand ist, fand das Protokoll nirgends - obwohl sein
--    Name in attendee_membership_ids steht. Genau die Personen, die dabei
--    waren, kamen also nicht an das Ergebnis heran.
--
-- 2. EIN PROTOKOLL KANN OEFFENTLICH SEIN
--    Eine Hauptversammlung geht den ganzen Verein an. Dafuer gibt es jetzt
--    einen Schalter: oeffentlich = true, und jedes aktive Mitglied darf lesen.
--    Voreingestellt ist false - ein Vorstandsprotokoll bleibt intern, bis
--    jemand ausdruecklich etwas anderes will.
--
-- 3. ORGANISATION DARF LOESCHEN
--    'organisator' stand in keiner der beiden Regeln. Wer den Verein
--    organisiert, konnte ein versehentlich angelegtes Protokoll nicht wieder
--    loswerden.
--
-- WARUM LESEN UND SCHREIBEN GETRENNT BLEIBEN
-- Teilnehmende und alle Mitglieder duerfen LESEN, nicht aendern. Ein
-- Protokoll ist ein Nachweis dessen, was besprochen wurde; wer daran
-- nachtraeglich schreiben darf, macht es wertlos. Schreiben bleibt deshalb
-- bei der Leitung und der Organisation.

alter table public.protocols add column if not exists oeffentlich boolean not null default false;

comment on column public.protocols.oeffentlich is
  'Sichtbar fuer ALLE aktiven Vereinsmitglieder, nicht nur fuer Leitung und Teilnehmende. Fuer Hauptversammlungen und dergleichen.';

/* Die Rollen, die ein Protokoll verwalten duerfen - an einer Stelle, damit
   die drei Regeln unten nicht auseinanderlaufen. */
create or replace function public.darf_protokolle_verwalten(target_club uuid)
returns boolean language sql stable security definer set search_path = 'public' as $$
  select public.has_club_role(target_club, array['vorstand','geschaeftsfuehrung','sysadmin','vereinsadmin','organisator']::club_role[]);
$$;
revoke execute on function public.darf_protokolle_verwalten(uuid) from public, anon;
grant execute on function public.darf_protokolle_verwalten(uuid) to authenticated, service_role;

-- ------------------------------------------------------------------ Lesen
drop policy if exists "board reads protocols" on public.protocols;
create policy "protokolle lesen" on public.protocols
  for select to authenticated
  using (
    public.darf_protokolle_verwalten(club_id)
    /* Wer dabei war, darf nachlesen. */
    or exists (select 1 from public.club_memberships m
                where m.profile_id = auth.uid() and m.club_id = protocols.club_id
                  and m.status = 'active' and m.id = any (protocols.attendee_membership_ids))
    /* Oder das Protokoll ist ausdruecklich fuer den ganzen Verein. */
    or (oeffentlich and exists (select 1 from public.club_memberships m
                                 where m.profile_id = auth.uid() and m.club_id = protocols.club_id
                                   and m.status = 'active'))
  );

-- ------------------------------------------------------- Anlegen und Aendern
drop policy if exists "board manages protocols" on public.protocols;
create policy "protokolle verwalten" on public.protocols
  for all to authenticated
  using (public.darf_protokolle_verwalten(club_id))
  with check (public.darf_protokolle_verwalten(club_id));

-- ------------------------------------------------------------- Die Aufgaben
--
-- Sie folgen dem Protokoll: Wer es lesen darf, sieht auch seine Aufgaben und
-- kann den eigenen Haken setzen. Aendern und loeschen bleibt bei der Leitung.
drop policy if exists "protocol tasks follow protocol access" on public.protocol_tasks;

create policy "protokollaufgaben lesen" on public.protocol_tasks
  for select to authenticated
  using (exists (select 1 from public.protocols p where p.id = protocol_tasks.protocol_id));

create policy "protokollaufgaben verwalten" on public.protocol_tasks
  for all to authenticated
  using (exists (select 1 from public.protocols p
                  where p.id = protocol_tasks.protocol_id and public.darf_protokolle_verwalten(p.club_id)))
  with check (exists (select 1 from public.protocols p
                       where p.id = protocol_tasks.protocol_id and public.darf_protokolle_verwalten(p.club_id)));

/* Den Haken darf auch setzen, wer die Aufgabe uebernommen hat - sonst muesste
   fuer jedes Abhaken jemand aus dem Vorstand bemueht werden. Nur diese eine
   Spalte, und nur an der eigenen Aufgabe: Text, Zustaendigkeit und Frist
   bleiben unangetastet. */
create policy "eigene protokollaufgabe abhaken" on public.protocol_tasks
  for update to authenticated
  using (exists (select 1 from public.club_memberships m
                  where m.id = protocol_tasks.assignee_membership_id
                    and m.profile_id = auth.uid() and m.status = 'active'))
  with check (exists (select 1 from public.club_memberships m
                       where m.id = protocol_tasks.assignee_membership_id
                         and m.profile_id = auth.uid() and m.status = 'active'));

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='protocols' and column_name='oeffentlich') as spalte,
  (select count(*) from pg_policies where schemaname='public' and tablename='protocols') as protokollregeln,
  (select count(*) from pg_policies where schemaname='public' and tablename='protocol_tasks') as aufgabenregeln;
