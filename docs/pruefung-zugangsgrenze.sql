-- Prüfung der Zugangsgrenze — legt einen Testverein an, löst die Sperre
-- gezielt aus und räumt alles wieder weg. Es bleibt nichts zurück.
--
-- Nur in der TEST-Datenbank ausführen.

create temporary table if not exists testergebnis (nr int, schritt text, ergebnis text);
truncate testergebnis;

do $$
declare
  test_club uuid := gen_random_uuid();
  fremdes_profil uuid;
  zweites_profil uuid;
  meldung text;
  plan_basic uuid;
begin
  -- Zwei vorhandene Profile ausleihen. Sie sind in einem anderen Verein
  -- Mitglied; unique (club_id, profile_id) erlaubt sie hier zusätzlich.
  select profile_id into fremdes_profil
  from public.club_memberships where profile_id is not null order by created_at limit 1;
  select profile_id into zweites_profil
  from public.club_memberships where profile_id is not null and profile_id <> fremdes_profil
  order by created_at limit 1;

  if fremdes_profil is null then
    insert into testergebnis values (0, 'Vorbereitung', 'ABBRUCH: kein Profil zum Ausleihen gefunden');
    return;
  end if;

  -- Verein bewusst mit altem Datum, damit der 14-Tage-Test nicht greift.
  insert into public.clubs (id, slug, name, short_name, created_at)
  values (test_club, 'zzz-test-' || replace(test_club::text, '-', ''),
          'ZZZ Testverein Zugangsgrenze', 'ZZZ', now() - interval '60 days');

  -- 1) Ohne Abo: Tarif none, Grenze 0
  insert into testergebnis values
    (1, 'Tarif ohne Abo', public.club_subscription_tier(test_club)),
    (2, 'Grenze ohne Abo', public.club_account_limit(test_club)::text);

  -- 2) Konto anlegen muss scheitern
  begin
    insert into public.club_memberships (club_id, profile_id, display_name, status)
    values (test_club, fremdes_profil, 'Testkonto A', 'active');
    insert into testergebnis values (3, 'Konto ohne Abo', 'FEHLER — wurde angelegt, die Sperre greift nicht');
  exception when others then
    get stacked diagnostics meldung = message_text;
    insert into testergebnis values (3, 'Konto ohne Abo', 'blockiert (' || meldung || ') — richtig');
  end;

  -- 3) Verwaltetes Profil ohne eigenen Login muss trotzdem durchgehen
  begin
    insert into public.club_memberships (club_id, profile_id, display_name, status, is_managed_profile)
    values (test_club, null, 'Kind ohne eigenes Konto', 'active', true);
    insert into testergebnis values (4, 'Verwaltetes Profil', 'angelegt — richtig, zählt nicht als Zugang');
  exception when others then
    get stacked diagnostics meldung = message_text;
    insert into testergebnis values (4, 'Verwaltetes Profil', 'FEHLER — blockiert (' || meldung || ')');
  end;

  insert into testergebnis values (5, 'Zähler nach verwaltetem Profil', public.club_account_count(test_club)::text || ' (erwartet 0)');

  -- 4) Basic-Abo geben: Grenze muss auf 100 springen
  select id into plan_basic from public.subscription_plans where code = 'club_basic_monthly';
  insert into public.club_subscriptions
    (club_id, plan_id, provider, provider_subscription_id, status, current_period_start, current_period_end)
  values (test_club, plan_basic, 'manual', 'test-' || test_club::text, 'active', now(), now() + interval '1 year');

  insert into testergebnis values
    (6, 'Tarif mit Basic', public.club_subscription_tier(test_club) || ' (erwartet basic)'),
    (7, 'Grenze mit Basic', public.club_account_limit(test_club)::text || ' (erwartet 100)');

  -- 5) Jetzt muss dasselbe Konto durchgehen
  begin
    insert into public.club_memberships (club_id, profile_id, display_name, status)
    values (test_club, fremdes_profil, 'Testkonto A', 'active');
    insert into testergebnis values (8, 'Konto mit Basic', 'angelegt — richtig');
  exception when others then
    get stacked diagnostics meldung = message_text;
    insert into testergebnis values (8, 'Konto mit Basic', 'FEHLER — blockiert (' || meldung || ')');
  end;

  insert into testergebnis values (9, 'Zähler nach echtem Konto', public.club_account_count(test_club)::text || ' (erwartet 1)');

  -- 6) Grenze künstlich auf 1 bringen, indem das Abo entfernt wird und
  --    stattdessen geprüft wird, ob ein zweites Konto bei erschöpfter
  --    Grenze scheitert. Dafür Abo weg -> Grenze 0, Zähler 1.
  delete from public.club_subscriptions where club_id = test_club;

  if zweites_profil is not null then
    begin
      insert into public.club_memberships (club_id, profile_id, display_name, status)
      values (test_club, zweites_profil, 'Testkonto B', 'active');
      insert into testergebnis values (10, 'Zweites Konto über Grenze', 'FEHLER — wurde angelegt');
    exception when others then
      get stacked diagnostics meldung = message_text;
      insert into testergebnis values (10, 'Zweites Konto über Grenze', 'blockiert — richtig');
    end;
  end if;

  -- 7) Bestehendes Konto bearbeiten muss weiterhin gehen
  begin
    update public.club_memberships set display_name = 'Testkonto A umbenannt'
    where club_id = test_club and profile_id = fremdes_profil;
    insert into testergebnis values (11, 'Bestehendes Konto ändern', 'ging durch — richtig');
  exception when others then
    get stacked diagnostics meldung = message_text;
    insert into testergebnis values (11, 'Bestehendes Konto ändern', 'FEHLER — blockiert (' || meldung || ')');
  end;

  -- Aufräumen: cascade entfernt Mitgliedschaften und Abos mit
  delete from public.clubs where id = test_club;
  insert into testergebnis values (12, 'Aufräumen', 'Testverein entfernt');
end $$;

select nr, schritt, ergebnis from testergebnis order by nr;
