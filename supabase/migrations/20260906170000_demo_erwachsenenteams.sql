-- Herren 1 und Damen 1 des Demo-Vereins sind Erwachsenenmannschaften.
--
-- Der Strafenkatalog gilt nur fuer Erwachsenenteams (is_adult_team in den
-- Sicherheitsregeln von team_penalty_rules und team_penalty_assignments) -
-- bewusst so, damit niemand Kindern Geldstrafen aufschreibt.
--
-- Im Demo-Verein standen aber ALLE Mannschaften auf "nicht erwachsen", auch
-- Herren 1 und Damen 1. Dort war der Katalog damit gesperrt, ohne dass ein
-- Grund erkennbar war: Der Menuepunkt fehlte einfach. Besonders unguenstig,
-- weil der App-Store-Pruefer genau diesen Verein sieht.
--
-- U11 und U15 bleiben, wie sie sind - dort ist die Sperre richtig.

update public.teams set is_adult = true
 where club_id = 'd0000000-0000-4000-a000-000000000001'
   and name in ('Herren 1', 'Damen 1');

select name, is_adult from public.teams
 where club_id = 'd0000000-0000-4000-a000-000000000001' order by name;
