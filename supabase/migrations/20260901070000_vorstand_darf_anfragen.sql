-- Der Vorstand darf die Freischaltung anfragen.
--
-- Die Leseregel schliesst den Vorstand ein, die Schreibregel nicht. In der App
-- stand zugleich der Satz "Den Vollzugang kann die Vereinsleitung anfragen —
-- Vorstand, Geschäftsführung oder Vereinsadmin." Ein Vorstand las also genau
-- das und hatte keinen Knopf; hätte er einen gehabt, wäre die Zeile an der
-- Regel gescheitert.
--
-- Gemeint war von Anfang an die Vereinsleitung. Der Vorstand gehört dazu.

drop policy if exists "club leaders create access requests" on public.club_access_requests;
create policy "club leaders create access requests" on public.club_access_requests
for insert to authenticated with check (
  status = 'offen'
  and public.has_club_role(club_id, array['sysadmin','vereinsadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
);
