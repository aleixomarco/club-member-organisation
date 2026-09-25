-- Raeumt die Demo-Zugaenge aus docs/demo-rollenkonten.sql wieder weg.
--
--   cd ~/Projekte/club-member-organisation
--   supabase db query --linked -f docs/demo-rollenkonten-loeschen.sql
--
-- Geloescht wird ausschliesslich, was zum Muster demo.<rolle>@idbranding.de
-- gehoert und im Demo-Verein SV Musterstadt liegt. Das Pruefkonto des App
-- Store, demo@idbranding.de, passt nicht auf dieses Muster und bleibt
-- unberuehrt - ebenso jedes Konto von ERG Iserlohn.

with betroffen as (
  select m.id as mitgliedschaft, m.profile_id
    from public.club_memberships m
   where m.club_id = 'd0000000-0000-4000-a000-000000000001'
     and m.email like 'demo.%@idbranding.de'
),
weg_team as (
  delete from public.team_members tm
   using betroffen b where tm.membership_id = b.mitgliedschaft returning 1),
weg_rollen as (
  delete from public.membership_roles mr
   using betroffen b where mr.membership_id = b.mitgliedschaft returning 1),
weg_mitglied as (
  delete from public.club_memberships m
   using betroffen b where m.id = b.mitgliedschaft returning 1),
weg_konto as (
  delete from auth.users u
   using betroffen b where u.id = b.profile_id returning 1)
select (select count(*) from weg_team)     as mannschaftszuordnungen,
       (select count(*) from weg_rollen)   as rollen,
       (select count(*) from weg_mitglied) as mitgliedschaften,
       (select count(*) from weg_konto)    as konten;

-- Profil und Anmeldedaten haengen per Fremdschluessel am Konto und
-- verschwinden mit ihm.
select count(*) as demo_konten_uebrig
  from public.club_memberships
 where club_id = 'd0000000-0000-4000-a000-000000000001'
   and email like 'demo.%@idbranding.de';
