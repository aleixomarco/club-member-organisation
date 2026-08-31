-- Was der Betreiber über einen Verein sehen kann.
--
-- Zwei Funktionen, und die Trennung dazwischen ist Absicht.
--
-- 1. mitglieder_eines_vereins() liefert die einzelnen Menschen — Name,
--    Kontakt, Rollen, Eintritt, Mannschaften. Das braucht der Betreiber für
--    den Betrieb: eine Rückfrage beantworten, eine falsche Rolle finden,
--    einen Verein beim Aufräumen unterstützen.
--
-- 2. zielgruppe_eines_vereins() liefert Zahlen ohne Namen — Altersverteilung,
--    Geschlechterverhältnis, Mannschaftsgrößen, Aktivität.
--
-- Warum getrennt: Ein Werbepartner, der wissen will, ob sich eine Anzeige bei
-- diesem Verein lohnt, hat ein berechtigtes Interesse an der Struktur — aber
-- keines an einzelnen Personen. Die Mitglieder haben ihre Daten dem VEREIN
-- gegeben, nicht dessen Sponsoren. Wer beides in einer Abfrage vermischt, gibt
-- irgendwann versehentlich eine Liste weiter, die niemand weitergeben darf.
--
-- Die zweite Funktion ist deshalb die, die man einem Werbepartner zeigen kann.
-- Die erste nicht.

create or replace function public.mitglieder_eines_vereins(target_club uuid)
returns table (
  id uuid, name text, email text, status text, mitglied_seit integer,
  mitgliedsnummer text, geburtsdatum date, alter_jahre integer, geschlecht text,
  ort text, rollen text[], mannschaften text[], letzte_aenderung timestamptz,
  geraete integer, punkte integer
)
language sql stable security definer set search_path = '' as $$
  select
    m.id,
    m.display_name,
    m.email,
    m.status::text,
    m.member_since,
    m.membership_number,
    p.birthdate,
    case when p.birthdate is null then null
         else extract(year from age(p.birthdate))::integer end,
    p.gender,
    p.city,
    coalesce((select array_agg(r.role::text order by r.role)
                from public.membership_roles r where r.membership_id = m.id), '{}'),
    coalesce((select array_agg(distinct t.name order by t.name)
                from public.team_members tm join public.teams t on t.id = tm.team_id
               where tm.membership_id = m.id), '{}'),
    m.updated_at,
    coalesce((select count(*)::integer from public.user_devices d where d.profile_id = m.profile_id), 0),
    coalesce((select pm.punkte from public.punkte_je_mitglied(target_club) pm where pm.membership_id = m.id), 0)
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = target_club
  order by m.display_name;
$$;

revoke all on function public.mitglieder_eines_vereins(uuid) from public, anon, authenticated;

/* Das Zielgruppenprofil — Zahlen, keine Namen.
 *
 * Kleine Gruppen werden ausdrücklich nicht ausgewiesen: Bei zwei Frauen in
 * einem Verein ist „zwei Frauen" keine Statistik mehr, sondern ein Hinweis auf
 * zwei bestimmte Personen. Unter fünf wird deshalb null zurückgegeben. */
create or replace function public.zielgruppe_eines_vereins(target_club uuid)
returns table (
  mitglieder integer, aktive integer,
  alter_unter_18 integer, alter_18_29 integer, alter_30_49 integer, alter_50_plus integer,
  alter_unbekannt integer, durchschnittsalter numeric,
  weiblich integer, maennlich integer, divers_oder_offen integer,
  mannschaften integer, groesste_mannschaft text, groesste_mannschaft_groesse integer,
  aktiv_letzte_30_tage integer
)
language sql stable security definer set search_path = '' as $$
  with m as (
    select cm.id, cm.status, p.birthdate, p.gender, cm.profile_id,
           case when p.birthdate is null then null else extract(year from age(p.birthdate))::integer end as jahre
      from public.club_memberships cm
      left join public.profiles p on p.id = cm.profile_id
     where cm.club_id = target_club
  ),
  klein as (select 5 as grenze)
  select
    (select count(*)::integer from m),
    (select count(*)::integer from m where status = 'active'),
    (select count(*)::integer from m where jahre < 18),
    (select count(*)::integer from m where jahre between 18 and 29),
    (select count(*)::integer from m where jahre between 30 and 49),
    (select count(*)::integer from m where jahre >= 50),
    (select count(*)::integer from m where jahre is null),
    (select round(avg(jahre), 1) from m),
    -- Unter fuenf keine Angabe: sonst zeigt die Zahl auf einzelne Personen.
    (select case when count(*) >= (select grenze from klein) then count(*)::integer end from m where gender = 'weiblich'),
    (select case when count(*) >= (select grenze from klein) then count(*)::integer end from m where gender = 'maennlich'),
    (select case when count(*) >= (select grenze from klein) then count(*)::integer end from m where gender is null or gender not in ('weiblich','maennlich')),
    (select count(*)::integer from public.teams t where t.club_id = target_club and t.active),
    (select t.name from public.teams t
       join public.team_members tm on tm.team_id = t.id
      where t.club_id = target_club and t.active
      group by t.name order by count(*) desc limit 1),
    (select count(*)::integer from public.team_members tm
       join public.teams t on t.id = tm.team_id
      where t.club_id = target_club and t.active
      group by t.name order by count(*) desc limit 1),
    (select count(distinct d.profile_id)::integer from public.user_devices d
      where d.profile_id in (select profile_id from m where profile_id is not null)
        and d.last_seen > now() - interval '30 days');
$$;

revoke all on function public.zielgruppe_eines_vereins(uuid) from public, anon, authenticated;

/* Die Sponsoren eines Vereins - nur, wenn der Zusatz freigeschaltet ist.
   Ohne Freischaltung kann der Verein zwar eintragen, angezeigt wird nichts;
   dann gibt es hier auch nichts zu sehen. */
create or replace function public.sponsoren_eines_vereins(target_club uuid)
returns table (
  id uuid, platz text, titel text, text text, bild_pfad text, ziel_url text,
  aktion_titel text, aktion_text text, aktion_url text,
  laeuft_von timestamptz, laeuft_bis timestamptz, aktion_von timestamptz, aktion_bis timestamptz,
  aktiv boolean, impressionen bigint, klicks bigint, laeuft_gerade boolean
)
language sql stable security definer set search_path = '' as $$
  select a.id, a.platz, a.titel, a.text, a.bild_pfad, a.ziel_url,
         a.aktion_titel, a.aktion_text, a.aktion_url,
         a.laeuft_von, a.laeuft_bis, a.aktion_von, a.aktion_bis,
         a.aktiv, a.impressionen, a.klicks,
         (a.aktiv and a.laeuft_von <= now() and (a.laeuft_bis is null or a.laeuft_bis > now()))
    from public.anzeigen a
    join public.clubs c on c.id = a.club_id
   where a.club_id = target_club
     and c.sponsoring_freigeschaltet
   order by a.platz, a.created_at desc;
$$;

revoke all on function public.sponsoren_eines_vereins(uuid) from public, anon, authenticated;
