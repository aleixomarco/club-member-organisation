-- Testzugang: marcoaleixo004@gmail.com im versteckten Demo-Verein "SV Musterstadt"
--
-- Zweck: Ein Verein in PROD, in dem neue Funktionen an echter Technik
-- ausprobiert werden können, ohne dass ein echter Verein etwas davon sieht.
-- SV Musterstadt ist dafür geeignet, weil er
--   * versteckt ist (clubs.hidden = true): Er erscheint in keiner Vereinssuche,
--     niemand kann einen Beitritt anfragen, weil ihn niemand findet;
--   * nur Konten des Betreibers enthält (demo@idbranding.de für die
--     Apple-Prüfung, aleixo.marco@idbranding.de) - wer dort etwas anlegt,
--     erreicht keine fremde Person;
--   * schon Termine, Teams, News, Umfragen und Fahrzeuge hat.
-- Es entstehen hier KEINE neuen Demodaten, nur eine Mitgliedschaft.
--
-- Was beim Anlegen automatisch passiert (Trigger, gewollt):
--   * willkommens_news: eine News "Willkommen im Verein, Marco!" im Demo-Verein
--   * news_melden: Glocken-Meldung dazu an die beiden anderen Konten
--   * notify_team_joined: je Mannschaft eine Meldung an das neue Konto selbst
--
-- Rollen wie in ERG Iserlohn, damit sich jede Ansicht prüfen lässt.
-- Mannschaften: Spieler in "Damen 1" (dort liegen die meisten Termine),
-- Trainer in "Herren 1" (Damen 1 hat schon eine Trainerin, pro Mannschaft
-- ist nur eine erlaubt).
--
-- Ausführen: supabase db query --linked -f docs/testzugang-demo-verein.sql
-- probelauf = true rechnet alles durch, meldet das Ergebnis als Fehler und
-- verwirft es damit vollständig. Erst mit false wird geschrieben.
-- Mehrfach ausführen ist unschädlich: Vorhandenes bleibt, wie es ist.
--
-- Rückgängig (Rollen und Mannschaften fallen per Kaskade mit weg):
--   delete from public.club_memberships
--    where club_id = 'd0000000-0000-4000-a000-000000000001'
--      and profile_id = (select id from auth.users where lower(email) = 'marcoaleixo004@gmail.com');

do $$
declare
  probelauf constant boolean := true;
  v_verein constant uuid := 'd0000000-0000-4000-a000-000000000001';
  v_profil uuid;
  v_mitgliedschaft uuid;
  v_bericht text;
begin
  select id into v_profil from auth.users where lower(email) = 'marcoaleixo004@gmail.com';
  if v_profil is null then
    raise exception 'Kein Konto mit der Adresse marcoaleixo004@gmail.com - abgebrochen.';
  end if;

  /* Nur in einen versteckten Verein. Wäre SV Musterstadt irgendwann wieder
     sichtbar geschaltet, gehört dieser Zugang neu durchdacht. */
  if not exists (select 1 from public.clubs where id = v_verein and hidden) then
    raise exception 'Demo-Verein fehlt oder ist nicht mehr versteckt - abgebrochen.';
  end if;

  insert into public.club_memberships
    (club_id, profile_id, display_name, email, member_since, status, team_filter, created_by)
  values
    (v_verein, v_profil, 'Marco Aleixo', 'marcoaleixo004@gmail.com', 2026, 'active', 'Damen 1', v_profil)
  on conflict (club_id, profile_id) do nothing;

  select id into v_mitgliedschaft
    from public.club_memberships
   where club_id = v_verein and profile_id = v_profil;

  insert into public.membership_roles (membership_id, role)
  select v_mitgliedschaft, r
    from unnest(array['mitglied', 'spieler', 'trainer', 'kapitaen', 'teammanager', 'redakteur',
                      'sponsorenmanager', 'sysadmin', 'vereinsadmin', 'organisator', 'fan']::public.club_role[]) as r
  on conflict do nothing;

  insert into public.team_members (team_id, membership_id, function) values
    ('d0000000-0000-4000-a000-000000000102', v_mitgliedschaft, 'spieler'),
    ('d0000000-0000-4000-a000-000000000101', v_mitgliedschaft, 'trainer')
  on conflict do nothing;

  select format(
    'Mitgliedschaft %s, Status %s | Rollen: %s | Mannschaften: %s | neue News im Demo-Verein: %s | neue Glocken-Meldungen: %s | Mitglieder im Demo-Verein jetzt: %s | Zugänge belegt %s von %s',
    v_mitgliedschaft,
    (select status from public.club_memberships where id = v_mitgliedschaft),
    (select string_agg(role::text, ', ' order by role) from public.membership_roles where membership_id = v_mitgliedschaft),
    (select string_agg(t.name || ' (' || tm.function || ')', ', ' order by t.name)
       from public.team_members tm join public.teams t on t.id = tm.team_id where tm.membership_id = v_mitgliedschaft),
    (select coalesce(string_agg(n.title, ' / '), '-') from public.news_posts n where n.club_id = v_verein and n.created_at = now()),
    (select coalesce(string_agg(coalesce(m.display_name, '?') || ': ' || un.kind, ', '), '-')
       from public.user_notifications un
       left join public.club_memberships m on m.profile_id = un.profile_id and m.club_id = v_verein
      where un.created_at = now()),
    (select count(*) from public.club_memberships where club_id = v_verein and status = 'active'),
    public.club_account_count(v_verein), public.club_account_limit(v_verein)
  ) into v_bericht;

  if probelauf then
    raise exception 'PROBELAUF (nichts gespeichert): %', v_bericht;
  end if;
  raise notice 'GESCHRIEBEN: %', v_bericht;
end $$;
