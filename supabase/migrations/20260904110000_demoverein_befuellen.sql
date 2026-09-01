-- Den Demo-Verein dort befüllen, wo er leer war.
--
-- Anlass: Die eingereichte Store-Beschreibung nennt ausdrücklich
-- "Vereinsnachrichten", "Umfragen" und "Aufgabenverteilung". In SV Musterstadt
-- standen dafür null Einträge. Ein Prüfer, der diese Bereiche antippt, sieht
-- dann drei leere Flächen — und "beschriebene Funktion tut nichts" ist genau
-- die Schublade, in die Richtlinie 2.1 greift. Termine (63, davon 44 künftige),
-- Mannschaften, Helferdienste, Kanäle und Fahrzeuge waren dagegen gefüllt.
--
-- Was hier NICHT entsteht: Chat-Nachrichten. messages.author_id verweist auf
-- profiles und ist Pflicht; der Demo-Verein hat aber nur zwei echte Profile,
-- die übrigen 20 Mitglieder sind betreute Datensätze ohne eigenen Zugang. Ein
-- vorgetäuschtes Gespräch bräuchte also erfundene Konten. Die vier Kanäle
-- stehen bereit, der Prüfer kann selbst schreiben und sieht, dass es
-- funktioniert.
--
-- Alle Zeitangaben sind relativ zu now(), damit nichts veraltet, egal wann
-- geprüft wird. Alle Einfügungen sind gegen doppeltes Ausführen abgesichert
-- und betreffen ausschließlich SV Musterstadt.

do $$
declare
  verein constant uuid := 'd0000000-0000-4000-a000-000000000001';
  schreiber text;
  umfrage uuid;
  team_herren uuid;
begin
  if not exists (select 1 from public.clubs where id = verein) then
    raise notice 'SV Musterstadt gibt es nicht - nichts zu tun.';
    return;
  end if;

  /* Als Verfasser den Namen eines vorhandenen Mitglieds nehmen, statt einen zu
     erfinden: So passt die News zur Mitgliederliste, die daneben steht. */
  select display_name into schreiber
    from public.club_memberships
   where club_id = verein and display_name is not null and display_name <> ''
   order by created_at
   limit 1;
  schreiber := coalesce(schreiber, 'Geschäftsstelle');

  select id into team_herren from public.teams
   where club_id = verein order by created_at limit 1;

  -- ------------------------------------------------------------------ News
  if not exists (select 1 from public.news_posts where club_id = verein) then
    insert into public.news_posts (club_id, title, body, author_name, created_at) values
      (verein,
       'Hallensaison eröffnet',
       E'Am Wochenende ist die Halle am Deichweg wieder unser Zuhause. Die Herren 1 starten am Samstag um 18 Uhr gegen den SV Buchenfelde, danach wird im Vereinsheim angestossen.\n\nWer beim Aufbau helfen kann: Der Helferplan steht in der App, zwei Plätze an der Theke sind noch offen.',
       schreiber, now() - interval '2 days'),
      (verein,
       'Neue Trainingszeiten für die U15',
       E'Ab sofort trainiert die U15 dienstags von 17 bis 18:30 Uhr statt wie bisher mittwochs. Grund ist die Hallenbelegung durch die Grundschule.\n\nDie Termine in der App sind bereits umgestellt — wer den Kalender abonniert hat, sieht die Änderung automatisch.',
       schreiber, now() - interval '6 days'),
      (verein,
       'Mitgliederversammlung: Termin steht',
       E'Die ordentliche Mitgliederversammlung findet in vier Wochen im Vereinsheim statt. Auf der Tagesordnung stehen der Kassenbericht, die Entlastung des Vorstands und die Planung des Sommerfests.\n\nAnträge bitte bis zwei Wochen vorher bei der Geschäftsstelle einreichen.',
       schreiber, now() - interval '13 days');
  end if;

  -- --------------------------------------------------------------- Umfragen
  if not exists (select 1 from public.polls where club_id = verein) then
    insert into public.polls (club_id, title, active)
    values (verein, 'Wann soll die Weihnachtsfeier stattfinden?', true)
    returning id into umfrage;

    insert into public.poll_options (poll_id, label, position) values
      (umfrage, 'Freitag, 12. Dezember', 0),
      (umfrage, 'Samstag, 13. Dezember', 1),
      (umfrage, 'Samstag, 20. Dezember', 2);

    insert into public.polls (club_id, title, active)
    values (verein, 'Neue Trikotfarbe für die Auswärtsspiele', false)
    returning id into umfrage;

    insert into public.poll_options (poll_id, label, position) values
      (umfrage, 'Weiß mit blauem Streifen', 0),
      (umfrage, 'Anthrazit', 1);
  end if;

  -- --------------------------------------------------------------- Aufgaben
  if not exists (select 1 from public.club_tasks where club_id = verein) then
    insert into public.club_tasks (club_id, team_id, title, description, due_date, slots_needed) values
      (verein, null, 'Kuchen für das Heimspiel',
       'Für den Kuchenstand am Samstag suchen wir drei Bäckerinnen oder Bäcker. Abgabe bis 16 Uhr im Vereinsheim.',
       (now() + interval '9 days')::date, 3),
      (verein, team_herren, 'Trikots einsammeln und waschen',
       'Nach dem letzten Heimspiel bitte die Trikots einsammeln, waschen und zum nächsten Training mitbringen.',
       (now() + interval '4 days')::date, 1),
      (verein, null, 'Banner für das Sommerfest aufhängen',
       'Das Banner liegt in der Geschäftsstelle. Es soll zwei Wochen vorher an der Halle und am Sportplatz hängen.',
       (now() + interval '21 days')::date, 2);
  end if;

  -- ------------------------------------------------------------- Protokolle
  if not exists (select 1 from public.protocols where club_id = verein) then
    insert into public.protocols (club_id, title, meeting_date, raw_text, attendee_membership_ids)
    values (verein,
      'Vorstandssitzung',
      (now() - interval '11 days')::date,
      E'1. Kassenstand\nDer Kassenwart berichtet, dass die Beiträge für das laufende Jahr weitgehend eingegangen sind. Offen sind noch vier Mitgliedsbeiträge; die Erinnerungen sind raus.\n\n2. Hallenzeiten\nDie Stadt hat die Belegung für die kommende Saison bestätigt. Die U15 wechselt auf Dienstag.\n\n3. Sommerfest\nTermin und Ort stehen. Für den Aufbau werden Helfer gesucht, die Aufgabe ist in der App eingetragen.\n\n4. Verschiedenes\nDas Vereinsfahrzeug braucht neue Reifen. Angebot wird eingeholt.',
      coalesce((select array_agg(id) from (
        select id from public.club_memberships
         where club_id = verein order by created_at limit 5) x), '{}'::uuid[]));
  end if;

  raise notice 'Demo-Verein befuellt.';
end $$;
