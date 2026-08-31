-- Regeln, die fehlten, weil die Tabellen nie benutzt wurden.
--
-- Solange die Daten im gemeinsamen JSON-Klumpen lagen, ist nie aufgefallen,
-- dass zwei alltägliche Vorgänge an der Sicherheitsregel scheitern würden.

/* Die Vereinsleitung teilt Helfer ein — nicht nur sich selbst.
 *
 * "members manage own duties" erlaubt ausschliesslich die eigene Zeile. Der
 * Helferplan der Vereinsleitung besteht aber gerade darin, ANDERE einzuteilen;
 * ohne diese Regel waere die Verwaltung ein Formular ohne Wirkung. */
drop policy if exists "leaders manage duties" on public.duty_assignments;
create policy "leaders manage duties" on public.duty_assignments for all to authenticated
using (
  exists (select 1 from public.events e where e.id = duty_assignments.event_id
           and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]))
) with check (
  exists (select 1 from public.events e where e.id = duty_assignments.event_id
           and public.has_club_role(e.club_id, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]))
);

/* Seine Wahl darf man ändern, solange die Frist läuft.
 *
 * season_votes hatte nur SELECT und INSERT. Der Schlüssel laesst eine Zeile je
 * Waehler zu — ein zweiter Versuch scheiterte also, und die Oberflaeche, die
 * das Umwaehlen anbietet, haette ins Leere gegriffen. */
drop policy if exists "members change season vote" on public.season_votes;
create policy "members change season vote" on public.season_votes for update to authenticated
using (voter_profile_id = auth.uid())
with check (voter_profile_id = auth.uid() and public.is_club_member(club_id));

drop policy if exists "members withdraw season vote" on public.season_votes;
create policy "members withdraw season vote" on public.season_votes for delete to authenticated
using (voter_profile_id = auth.uid());

/* Jeder darf sein eigenes Profil ändern - die Kachelreihenfolge liegt jetzt
   dort. Vorhanden war das vermutlich schon; ausdrücklich ist es besser. */
drop policy if exists "own profile updatable" on public.profiles;
create policy "own profile updatable" on public.profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
