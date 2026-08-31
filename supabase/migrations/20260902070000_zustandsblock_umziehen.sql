-- Was im Zustandsblock liegt, zieht in die Tabellen um.
--
-- Die App liest club_app_state nicht mehr. Ohne diesen Umzug wäre alles, was
-- die Vereine dort angesammelt haben — Helferpläne, Protokolle, Umfragen,
-- Ergebnisse, Wahlen —, von einem Tag auf den anderen unsichtbar. Nicht
-- gelöscht, aber unerreichbar, und das ist für den, der davorsitzt, dasselbe.
--
-- Der Umzug läuft einmal und überspringt, was schon dasteht. Was sich nicht
-- übertragen lässt, wird ausdrücklich benannt statt stillschweigend fallen
-- gelassen.

/* Die alten Stimmenzahlen der Umfragen.
 *
 * Im Block stand je Antwort nur eine Summe, nicht wer wie gestimmt hat
 * (voterIds führte die Abstimmenden, aber nicht ihre Antwort). Diese Summen
 * lassen sich deshalb nicht in einzelne Stimmen zerlegen — erfinden wäre die
 * Alternative, und eine erfundene Stimme ist schlimmer als eine unvollständige
 * Statistik. Sie bleiben als Altbestand stehen und werden zur Zahl der neuen
 * Stimmen addiert. */
alter table public.poll_options
  add column if not exists legacy_votes integer not null default 0;

comment on column public.poll_options.legacy_votes is
  'Stimmen aus der Zeit vor dem 02.09.2026, als Umfragen als JSON im gemeinsamen Zustandsblock lagen. Dort stand nur die Summe, nicht wer wie gestimmt hat.';

do $$
declare
  z record;
  daten jsonb;
  eintrag jsonb;
  station record;
  mitglied jsonb;
  umfrage jsonb;
  antwort jsonb;
  neue_umfrage uuid;
  neues_protokoll uuid;
  aufgabe jsonb;
  waehler uuid;
  i integer;
begin
  for z in select club_id, state from public.club_app_state loop
    daten := z.state;
    if daten is null then continue; end if;

    ---------------------------------------------------------------- Einstellungen
    insert into public.club_settings (club_id, maintenance_mode, welcome_automation, billing_automation)
    values (
      z.club_id,
      coalesce((daten->>'maintenanceMode')::boolean, false),
      coalesce((daten->>'welcomeAutomation')::boolean, true),
      coalesce((daten->>'billingAutomation')::boolean, true)
    )
    on conflict (club_id) do nothing;

    ---------------------------------------------------------------- Helferplan
    -- Aufbau: { "<event>": { "<Station>": ["<Mitgliedschaft>", ...] } }
    -- Schlüssel, die keine UUID sind, stammen aus den Demo-Terminen und haben
    -- in der Datenbank keine Entsprechung.
    if jsonb_typeof(daten->'dutyPlan') = 'object' then
      for station in
        select e.key as event_text, s.key as station_name, s.value as mitglieder
          from jsonb_each(daten->'dutyPlan') e,
               jsonb_each(e.value) s
         where jsonb_typeof(e.value) = 'object'
      loop
        if station.event_text !~ '^[0-9a-f]{8}-' then continue; end if;
        if not exists (select 1 from public.events ev where ev.id = station.event_text::uuid) then continue; end if;
        for mitglied in select * from jsonb_array_elements(station.mitglieder) loop
          if trim(both '"' from mitglied::text) !~ '^[0-9a-f]{8}-' then continue; end if;
          insert into public.duty_assignments (event_id, station, membership_id)
          select station.event_text::uuid, station.station_name, (trim(both '"' from mitglied::text))::uuid
           where exists (select 1 from public.club_memberships m where m.id = (trim(both '"' from mitglied::text))::uuid)
          on conflict do nothing;
        end loop;
      end loop;
    end if;

    ---------------------------------------------------------------- Ergebnisse
    if jsonb_typeof(daten->'tippResults') = 'object' then
      for eintrag in select jsonb_build_object('k', key, 'v', value) from jsonb_each(daten->'tippResults') loop
        continue when (eintrag->>'k') !~ '^[0-9a-f]{8}-';
        insert into public.event_results (club_id, event_id, heim, auswaerts)
        select z.club_id, (eintrag->>'k')::uuid,
               ((eintrag->'v')->>'home')::smallint, ((eintrag->'v')->>'away')::smallint
         where ((eintrag->'v')->>'home') ~ '^[0-9]+$' and ((eintrag->'v')->>'away') ~ '^[0-9]+$'
           and exists (select 1 from public.events ev where ev.id = (eintrag->>'k')::uuid)
        on conflict (club_id, event_id) do nothing;
      end loop;
    end if;

    ---------------------------------------------------------------- Athletenwahl
    if jsonb_typeof(daten->'seasonVotes') = 'object' then
      for eintrag in select jsonb_build_object('k', key, 'v', value) from jsonb_each(daten->'seasonVotes') loop
        continue when (eintrag->>'k') !~ '^[0-9a-f]{8}-';
        select m.profile_id into waehler from public.club_memberships m where m.id = (eintrag->>'k')::uuid;
        continue when waehler is null;
        insert into public.season_votes (club_id, season, voter_profile_id, candidate_membership_id)
        select z.club_id, '2025/26', waehler, (eintrag->>'v')::uuid
         where (eintrag->>'v') ~ '^[0-9a-f]{8}-'
           and exists (select 1 from public.club_memberships m2 where m2.id = (eintrag->>'v')::uuid)
        on conflict (club_id, season, voter_profile_id) do nothing;
      end loop;
    end if;

    ---------------------------------------------------------------- Erinnerungen
    if jsonb_typeof(daten->'remindersSent') = 'object' then
      insert into public.fee_reminders (club_id, membership_id, jahr, gesendet_am)
      select z.club_id, key::uuid, 2026, now()
        from jsonb_each_text(daten->'remindersSent')
       where key ~ '^[0-9a-f]{8}-'
         and value = 'true'
         and exists (select 1 from public.club_memberships m where m.id = key::uuid)
      on conflict (membership_id, jahr) do nothing;
    end if;

    ---------------------------------------------------------------- Umfragen
    if jsonb_typeof(daten->'polls') = 'array' then
      for umfrage in select * from jsonb_array_elements(daten->'polls') loop
        continue when coalesce(trim(umfrage->>'title'), '') = '';
        -- Schon umgezogen? Dann nicht doppelt.
        continue when exists (
          select 1 from public.polls p where p.club_id = z.club_id and p.title = (umfrage->>'title')
        );
        insert into public.polls (club_id, title, active)
        values (z.club_id, umfrage->>'title', coalesce((umfrage->>'active')::boolean, true))
        returning id into neue_umfrage;

        i := 0;
        for antwort in select * from jsonb_array_elements(coalesce(umfrage->'options', '[]'::jsonb)) loop
          insert into public.poll_options (poll_id, label, position, legacy_votes)
          values (neue_umfrage, coalesce(antwort->>'label', 'Antwort'), i, coalesce((antwort->>'votes')::integer, 0));
          i := i + 1;
        end loop;
      end loop;
    end if;

    ---------------------------------------------------------------- Protokolle
    if jsonb_typeof(daten->'protocols') = 'array' then
      for eintrag in select * from jsonb_array_elements(daten->'protocols') loop
        continue when coalesce(trim(eintrag->>'title'), '') = '';
        continue when exists (
          select 1 from public.protocols p where p.club_id = z.club_id and p.title = (eintrag->>'title')
        );
        insert into public.protocols (club_id, title, meeting_date, raw_text, attendee_membership_ids)
        values (
          z.club_id, eintrag->>'title',
          coalesce((eintrag->>'date')::date, current_date),
          eintrag->>'rawText',
          coalesce((
            select array_agg(a::uuid) from jsonb_array_elements_text(coalesce(eintrag->'attendees', '[]'::jsonb)) a
             where a ~ '^[0-9a-f]{8}-'
          ), '{}'::uuid[])
        )
        returning id into neues_protokoll;

        for aufgabe in select * from jsonb_array_elements(coalesce(eintrag->'tasks', '[]'::jsonb)) loop
          continue when coalesce(trim(aufgabe->>'text'), '') = '';
          insert into public.protocol_tasks (protocol_id, text, assignee_membership_id, due_date, done)
          values (
            neues_protokoll, aufgabe->>'text',
            case when (aufgabe->>'assignee') ~ '^[0-9a-f]{8}-'
                  and exists (select 1 from public.club_memberships m where m.id = (aufgabe->>'assignee')::uuid)
                 then (aufgabe->>'assignee')::uuid end,
            case when (aufgabe->>'due') ~ '^\d{4}-\d{2}-\d{2}$' then (aufgabe->>'due')::date end,
            coalesce((aufgabe->>'done')::boolean, false)
          );
        end loop;
      end loop;
    end if;
  end loop;
end $$;

comment on table public.club_app_state is
  'Altbestand. Bis zum 02.09.2026 lag hier der gesamte veraenderliche Zustand eines Vereins als ein JSON-Block - geschrieben ausschliesslich von Administratoren, weshalb Stimmen, Tipps und Helfereintraege der Mitglieder nie ankamen. Der Inhalt ist in eigene Tabellen umgezogen; die Tabelle bleibt als Sicherung stehen und wird nicht mehr gelesen oder geschrieben.';
