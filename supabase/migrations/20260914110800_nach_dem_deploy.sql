-- Teil B der Rechte vom 14.09.2026 - ERST NACH DEM APP-DEPLOY einspielen.
--
-- Die bis dahin live laufende App liest club_memberships.email und
-- membership_number beim Anmelden und zaehlt die Saisonstimmen selbst. Mit
-- dieser Migration vorher haette sich niemand mehr anmelden koennen
-- (Durchsicht 14.09.2026). Die neue App liest beides nicht mehr: Kontaktdaten
-- ueber kontaktdaten_im_verein, den Stand der Wahl ueber saisonwahl_stand.

-- rollen-03: Spalten. Ein Spaltenrecht laesst sich nicht entziehen, solange
-- das Recht auf die ganze Tabelle besteht. Also die Tabelle entziehen und die
-- Spalten ohne email, membership_number, rejection_count und blocked_until
-- einzeln geben (Spaltenliste von PROD, 14.09.2026).
revoke select on public.club_memberships from anon, authenticated;
grant select (id, club_id, profile_id, display_name, member_since, status,
              is_managed_profile, created_by, created_at, updated_at,
              requested_role, requested_team, team_filter)
  on public.club_memberships to authenticated;

-- U5: Jede und jeder liest nur die eigene Stimme.
drop policy if exists "members read season votes" on public.season_votes;
drop policy if exists "members read own season vote" on public.season_votes;
create policy "members read own season vote" on public.season_votes
  for select to authenticated
  using (voter_profile_id = (select auth.uid()));

-- Kontrolle
select has_column_privilege('authenticated', 'public.club_memberships', 'email', 'SELECT') as email_lesbar,
       (select count(*) from pg_policies where tablename = 'season_votes' and policyname = 'members read own season vote') as eigene_stimme;
