-- Zugang wiederherstellen, nachdem das Aufräumen ein Konto zu viel entfernt hat
--
-- Was passiert war: 20260904210000_prod_aufraeumen.sql suchte die zu
-- behaltenden Konten über die E-Mail in club_memberships. Getroffen hat es nur
-- eines der beiden - im anderen Datensatz stand offenbar eine andere Adresse
-- oder keine. Das eingebaute Netz brach nur bei NULL Treffern ab, nicht bei
-- einem. Das war der Fehler.
--
-- Ein Anmeldekonto lässt sich per SQL nicht sinnvoll neu anlegen; das Passwort
-- gehört in auth.users und wird von Supabase gehasht. Der Weg ist deshalb:
--
--   1. In der App ganz normal NEU REGISTRIEREN, mit derselben E-Mail.
--      Dabei KEINEN Verein auswählen - nur das Konto anlegen.
--   2. Dieses Skript laufen lassen. Es hängt das frische Konto an den
--      richtigen Verein und gibt ihm die Rollen zurück.
--
-- Vor dem Ausführen die beiden Werte unten setzen.

do $$
declare
  -- HIER EINTRAGEN: die E-Mail des neu registrierten Kontos
  v_email    text := 'BITTE-EINTRAGEN@example.com';
  -- HIER EINTRAGEN: 'betreiber' oder 'pruefzugang'
  v_zweck    text := 'betreiber';

  v_demo     uuid := 'd0000000-0000-4000-a000-000000000001';
  v_profil   uuid;
  v_verein   uuid;
  v_mitglied uuid;
  v_team     uuid;
begin
  select id into v_profil from auth.users where lower(email) = lower(v_email);
  if v_profil is null then
    raise exception 'Kein Konto mit % gefunden. Erst in der App registrieren.', v_email;
  end if;

  if v_zweck = 'pruefzugang' then
    v_verein := v_demo;
  else
    select id into v_verein from public.clubs where id <> v_demo order by created_at limit 1;
  end if;
  if v_verein is null then raise exception 'Verein nicht gefunden.'; end if;

  insert into public.club_memberships (club_id, profile_id, display_name, email, status)
  values (v_verein, v_profil, split_part(v_email, '@', 1), v_email, 'active')
  on conflict (club_id, profile_id) do update set status = 'active'
  returning id into v_mitglied;

  if v_mitglied is null then
    select id into v_mitglied from public.club_memberships
     where club_id = v_verein and profile_id = v_profil;
  end if;

  /* Rollen: Der Betreiber braucht volle Verwaltung, damit der Verein wieder
     einen Administrator hat. Der Prüfzugang braucht nur ein Mitgliedskonto -
     Apple prüft die Sicht eines normalen Mitglieds. */
  if v_zweck = 'pruefzugang' then
    insert into public.membership_roles (membership_id, role)
    values (v_mitglied, 'mitglied'), (v_mitglied, 'spieler')
    on conflict do nothing;

    /* In die Mannschaft aufnehmen, in deren Kanal der Prüfer liest -
       sonst sieht er einen leeren Chat (Richtlinie 1.2). */
    select ch.team_id into v_team from public.channels ch
     where ch.club_id = v_demo and ch.team_id is not null limit 1;
    if v_team is not null then
      insert into public.team_members (team_id, membership_id, function)
      values (v_team, v_mitglied, 'spieler') on conflict do nothing;
    end if;
  else
    insert into public.membership_roles (membership_id, role)
    values (v_mitglied, 'mitglied'), (v_mitglied, 'sysadmin'), (v_mitglied, 'vorstand')
    on conflict do nothing;
  end if;

  raise notice 'Fertig: % ist jetzt Mitglied in Verein %', v_email, v_verein;
end $$;

select m.email, c.name as verein, array_agg(r.role) as rollen
  from public.club_memberships m
  join public.clubs c on c.id = m.club_id
  left join public.membership_roles r on r.membership_id = m.id
 group by m.email, c.name;
