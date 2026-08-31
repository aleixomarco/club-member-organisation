-- Das Tippspiel bekommt eigene Tabellen.
--
-- Die Tipps lagen bisher ausschließlich im Arbeitsspeicher: `tippPredictions`
-- wurde nirgends geladen und nirgends geschrieben. Wer tippte, verlor seinen
-- Tipp beim nächsten Öffnen der App — und mit ihm seine Punkte, denn die
-- Rangliste rechnet sie aus den Tipps aus. Ein Tippspiel, das nach jedem
-- Neustart bei null anfängt, ist keines.
--
-- Die Ergebnisse lagen im gemeinsamen Zustandsblock der Administratoren. Der
-- ist dafür der falsche Ort, aber nicht der schlimmste Fall — Ergebnisse trägt
-- ohnehin nur die Vereinsleitung ein.
--
-- Zwei Tabellen, weil es zwei verschiedene Dinge sind: Was jemand tippt, gehört
-- ihm. Was am Ende herauskam, gehört dem Verein.

create table if not exists public.tipp_predictions (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  membership_id uuid not null references public.club_memberships(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  heim smallint check (heim is null or (heim >= 0 and heim <= 99)),
  auswaerts smallint check (auswaerts is null or (auswaerts >= 0 and auswaerts <= 99)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (membership_id, event_id)
);

create index if not exists tipp_predictions_club_idx on public.tipp_predictions(club_id, event_id);

create table if not exists public.tipp_results (
  club_id uuid not null references public.clubs(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  heim smallint not null check (heim >= 0 and heim <= 99),
  auswaerts smallint not null check (auswaerts >= 0 and auswaerts <= 99),
  erfasst_von uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (club_id, event_id)
);

create trigger tipp_predictions_touch before update on public.tipp_predictions
for each row execute function public.touch_updated_at();
create trigger tipp_results_touch before update on public.tipp_results
for each row execute function public.touch_updated_at();

alter table public.tipp_predictions enable row level security;
alter table public.tipp_results enable row level security;

/* Fremde Tipps sind erst sichtbar, wenn das Ergebnis feststeht.
 *
 * Ohne diese Einschränkung könnte jedes Mitglied vor dem Anpfiff nachsehen,
 * was die anderen getippt haben — und danach seinen eigenen Tipp anpassen. Die
 * Rangliste braucht die fremden Tipps trotzdem; sie braucht sie nur nicht
 * vorher. Nach dem Eintragen des Ergebnisses sind sie offen, und genau dann
 * rechnet die Rangliste. */
create policy "eigene tipps lesbar, fremde nach dem ergebnis" on public.tipp_predictions
for select to authenticated using (
  public.is_club_member(club_id)
  and (
    membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
    or exists (select 1 from public.tipp_results r where r.club_id = tipp_predictions.club_id and r.event_id = tipp_predictions.event_id)
  )
);

/* Tippen darf jeder für sich - und nur, solange das Ergebnis nicht feststeht.
   Ein Tipp nach dem Abpfiff wäre kein Tipp. */
create policy "eigene tipps abgeben" on public.tipp_predictions
for insert to authenticated with check (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid() and m.club_id = tipp_predictions.club_id and m.status = 'active')
  and not exists (select 1 from public.tipp_results r where r.club_id = tipp_predictions.club_id and r.event_id = tipp_predictions.event_id)
);

create policy "eigene tipps aendern" on public.tipp_predictions
for update to authenticated using (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
  and not exists (select 1 from public.tipp_results r where r.club_id = tipp_predictions.club_id and r.event_id = tipp_predictions.event_id)
) with check (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
);

create policy "eigene tipps zuruecknehmen" on public.tipp_predictions
for delete to authenticated using (
  membership_id in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
  and not exists (select 1 from public.tipp_results r where r.club_id = tipp_predictions.club_id and r.event_id = tipp_predictions.event_id)
);

create policy "ergebnisse lesbar" on public.tipp_results
for select to authenticated using (public.is_club_member(club_id));

create policy "ergebnisse pflegen" on public.tipp_results
for all to authenticated
using (public.has_club_role(club_id, array['vereinsadmin','sysadmin']::public.club_role[]))
with check (public.has_club_role(club_id, array['vereinsadmin','sysadmin']::public.club_role[]));

grant select, insert, update, delete on public.tipp_predictions to authenticated;
grant select, insert, update, delete on public.tipp_results to authenticated;
grant all on public.tipp_predictions to service_role;
grant all on public.tipp_results to service_role;
