-- Ziel im Repo: supabase/migrations/20260928120000_fehlerpruefung_behoben.sql
--
-- Was die Durchsicht vom 28.09.2026 gefunden hat.
--
-- Fuenfundzwanzig Behauptungen wurden geprueft, fuenfzehn haben der
-- Gegenprobe standgehalten. Diese Migration behebt die, die in der Datenbank
-- liegen. Die beiden schwersten stammen aus der Arbeit desselben Tages - das
-- ist der Grund, warum es diese Durchsicht gibt.
--
-- ============================================================ 1. VEREINSGRENZE
-- apply_duty_template prueft, ob der Aufrufer den TERMIN verwalten darf - aber
-- nie, ob das Helferset ueberhaupt zu dessen Verein gehoert. ev_club wird
-- gelesen und danach nie benutzt.
-- Solange das eine einmalige Kopie von Namen war, blieb der Schaden klein.
-- Seit der Herkunftsspur (20260928030000) wird daraus ein DAUERHAFTER
-- Schreibkanal: Wer in Verein A die Leitung hat und in Verein B Mitglied ist,
-- legt das Set von B auf einen Termin von A - und von da an aendert jede
-- Speicherung des Sets durch die Leitung von B die Termine von A mit.
-- Nachgespielt und zurueckgenommen: helferset_nutzung meldete dem fremden
-- Admin "spiele": 11 statt 10, und eine Set-Aenderung raeumte am fremden
-- Termin fuenf von sechs Stationen ab.
-- Die Leseregel auf duty_task_templates laesst JEDES aktive Mitglied die
-- Set-Kennungen seines Vereins lesen - die Voraussetzung ist also niedrig.
--
-- ============================================================ 2. DIE SPUR BLEIBT LIEGEN
-- remove_duty_station und clear_duty_stations raeumen helper_slots,
-- helper_caps, duty_assignments und duty_tasks auf - aber nicht die Spur.
-- Der Abgleich erkennt "frisch" allein an helper_slots und legt die Station
-- beim naechsten Speichern des Sets wieder an. Eine Station, die die Leitung
-- bewusst entfernt hat (samt der Eintragungen, die dabei geloescht wurden),
-- steht danach leer wieder da - und es gibt keinen Weg, sie dauerhaft
-- loszuwerden. Nach "Alle entfernen" kommt der ganze Satz zurueck.
-- Damit verletzt der Code genau die Regel, die im Kopf von 20260928030000
-- steht: Spur vorhanden = aus einem Set, Spur fehlt = von Hand und wird nie
-- angefasst.
--
-- ============================================================ 3. OFFENE PUNKTE
-- Zwei Dinge in offene_punkte_fuer_verein:
-- (a) Der Zweig 'mitgliedsantrag' zeigt JEDEM Organisator die wartenden
--     Bewerber samt E-Mail - genau die Entitaet, die am 27.09. auf die
--     Vereinsadministration eingeengt wurde (20260927160000). Die Leseregel
--     auf club_memberships verbirgt sie, diese Funktion reicht sie weiter;
--     sie laeuft als security definer an der Regel vorbei.
-- (b) Der Zweig 'helferstation' zaehlt eine Station als besetzt, sobald EINE
--     Person darauf steht. Die Plaetze je Station kamen einen Tag nach dem
--     Umbau dieses Zweigs (20260926100000). run_duty_gap_check wurde
--     nachgezogen, diese Funktion nicht. Heute schon falsch in PROD: An der
--     Station "Zeitnahme" mit zwei Plaetzen steht eine Person; die
--     Verwaltungsuebersicht meldet eine Luecke, der taegliche Waechter meldet
--     "Helfer gesucht" - die Liste "Offene Punkte" schweigt.
--
-- ============================================================ 4. KONTAKTDATEN
-- kontaktdaten_im_verein gibt dem Organisator alle Zeilen des Vereins ohne
-- Einschraenkung auf den Status - also auch E-Mail, Mitgliedsnummer,
-- Ablehnungszahl und Sperrfrist WARTENDER Bewerber. Die Funktion laeuft bei
-- jedem Anmelden. In der Oberflaeche sieht man die Zeilen nicht, auf dem
-- Geraet liegen sie trotzdem. Dieselbe Grenze wie in der Leseregel.
--
-- ============================================================ 5. LEERER GASTNAME
-- Die Bedingung "entweder Mitglied oder Gast" wertet einen Namen aus lauter
-- Leerzeichen als nicht gesetzt, die beiden Gastindizes dagegen nur als
-- "is not null". Ein Mitglied kann sich deshalb mit gast_name = "   " selbst
-- eintragen: Die Bedingung laesst es durch, und die Zeile belegt im Gastindex
-- den Schluessel (event_id, station, "") - das naechste Mitglied, das dasselbe
-- tut, wird abgewiesen. Klein, aber es widerspricht der Zusicherung im
-- Spaltenkommentar.

-- ------------------------------------------------- 1. Vereinsgrenze
create or replace function public.apply_duty_template(target_event uuid, target_template uuid)
returns integer
language plpgsql security definer set search_path to 'public' as $function$
declare
  ev_club    uuid;
  v_vorher   text[];
  v_neu      text[];
  v_neue_caps jsonb;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  select club_id, coalesce(helper_slots, '{}'::text[]) into ev_club, v_vorher
    from public.events where id = target_event for update;
  if ev_club is null then return 0; end if;

  /* Das Set muss zum Verein des Termins gehoeren. Ohne diese Zeile wird die
     Herkunftsspur zu einem dauerhaften Schreibkanal in einen fremden Verein -
     siehe Kopf. */
  if not exists (select 1 from public.duty_task_templates t
                  where t.id = target_template and t.club_id = ev_club) then
    raise exception 'Template belongs to a different club' using errcode = '42501';
  end if;

  select coalesce(array_agg(i.title order by i.sort_order), '{}'::text[]),
         coalesce(jsonb_object_agg(i.title, greatest(1, least(10, coalesce(i.plaetze, 2)))), '{}'::jsonb)
    into v_neu, v_neue_caps
    from public.duty_task_template_items i
   where i.template_id = target_template
     and not (i.title = any(v_vorher));

  insert into public.event_duty_station_source (event_id, station, template_id)
  select target_event, i.title, target_template
    from public.duty_task_template_items i
   where i.template_id = target_template
     and (i.title = any(v_vorher) or i.title = any(v_neu))
  on conflict (event_id, station) do update set template_id = excluded.template_id, gesetzt_am = now();

  if cardinality(v_neu) = 0 then return 0; end if;

  update public.events e
     set helper_slots = coalesce(e.helper_slots, '{}'::text[]) || v_neu,
         helper_caps  = coalesce(e.helper_caps, '{}'::jsonb) || v_neue_caps,
         updated_at   = now()
   where e.id = target_event;

  return cardinality(v_neu);
end;
$function$;

-- ------------------------------------------------- 2. Die Spur mit abraeumen
create or replace function public.remove_duty_station(target_event uuid, station_name text)
returns integer
language plpgsql security definer set search_path to '' as $function$
declare
  v_club        uuid;
  v_eintragungen integer;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  select club_id into v_club from public.events where id = target_event;
  if v_club is null then return 0; end if;

  delete from public.duty_assignments
   where event_id = target_event and station = station_name;
  get diagnostics v_eintragungen = row_count;

  delete from public.duty_tasks
   where event_id = target_event and title = station_name;

  /* Auch die Herkunft. Ohne diese Zeile legt der naechste Abgleich die eben
     entfernte Station wieder an - siehe Kopf. */
  delete from public.event_duty_station_source
   where event_id = target_event and station = station_name;

  update public.events
     set helper_slots = array_remove(helper_slots, station_name),
         helper_caps  = coalesce(helper_caps, '{}'::jsonb) - station_name,
         updated_at = now()
   where id = target_event;

  return v_eintragungen;
end;
$function$;

create or replace function public.clear_duty_stations(target_event uuid)
returns integer
language plpgsql security definer set search_path to '' as $function$
declare
  v_eintragungen integer;
begin
  if not public.can_manage_duty_task(target_event) then raise exception 'Not authorized'; end if;

  delete from public.duty_assignments where event_id = target_event;
  get diagnostics v_eintragungen = row_count;

  delete from public.duty_tasks where event_id = target_event;
  delete from public.event_duty_station_source where event_id = target_event;

  update public.events
     set helper_slots = '{}',
         helper_caps  = '{}'::jsonb,
         updated_at = now()
   where id = target_event;

  return v_eintragungen;
end;
$function$;

/* Was schon liegen geblieben ist. In PROD am 28.09.2026: null Zeilen - die
   Luecke war offen, aber noch nicht getreten. Die Anweisung steht trotzdem
   hier, damit eine zweite Umgebung nicht mit Karteileichen startet. */
delete from public.event_duty_station_source q
 where not exists (
   select 1 from public.events e
    where e.id = q.event_id and q.station = any(coalesce(e.helper_slots, '{}'::text[])));

/* Und Spuren, die ueber eine Vereinsgrenze zeigen - moeglich gemacht durch
   den Fehler oben. Ebenfalls null in PROD. */
delete from public.event_duty_station_source q
 using public.events e, public.duty_task_templates t
 where e.id = q.event_id and t.id = q.template_id and t.club_id <> e.club_id;

-- ------------------------------------------------- 2b. Riegel im Abgleich
create or replace function public.helferset_nutzung(target_template uuid)
returns jsonb
language plpgsql stable security definer set search_path to '' as $function$
declare
  v_club uuid;
  ergebnis jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select club_id into v_club from public.duty_task_templates where id = target_template;
  if v_club is null then raise exception 'Template not found'; end if;
  if not public.can_manage_duty_templates(v_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;

  select jsonb_build_object(
    'spiele', count(distinct e.id),
    'eintragungen', coalesce(sum((select count(*) from public.duty_assignments d
                                   where d.event_id = e.id and d.station = q.station)), 0)
  ) into ergebnis
    from public.event_duty_station_source q
    join public.events e on e.id = q.event_id
   where q.template_id = target_template
     /* Zweiter Riegel: Selbst wenn je wieder eine Spur ueber die
        Vereinsgrenze entstuende, zaehlt sie hier nicht mit. */
     and e.club_id = v_club
     and e.starts_at >= now() and e.status = 'scheduled';

  return coalesce(ergebnis, jsonb_build_object('spiele', 0, 'eintragungen', 0));
end;
$function$;

create or replace function public.helferset_speichern(target_template uuid, posten jsonb)
returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare
  v_club uuid;
  p jsonb;
  v_titel text;
  v_plaetze int;
  v_behalten text[] := '{}';
  v_weg text[];
  ev record;
  v_spiele int := 0;
  v_neu int := 0;
  v_geaendert int := 0;
  v_entfernt int := 0;
  v_behalten_wegen int := 0;
  v_sortierung int := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select club_id into v_club from public.duty_task_templates where id = target_template;
  if v_club is null then raise exception 'Template not found'; end if;
  if not public.can_manage_duty_templates(v_club) then
    raise exception 'Not authorized' using errcode = 'insufficient_privilege';
  end if;
  if jsonb_typeof(posten) <> 'array' then raise exception 'Posten must be an array'; end if;

  for p in select * from jsonb_array_elements(posten) loop
    v_titel := nullif(btrim(coalesce(p->>'title', '')), '');
    if v_titel is null then continue; end if;
    if length(v_titel) > 60 then v_titel := left(v_titel, 60); end if;
    v_plaetze := greatest(1, least(10, coalesce((p->>'plaetze')::int, 2)));
    v_behalten := v_behalten || v_titel;

    if exists (select 1 from public.duty_task_template_items
                where template_id = target_template and title = v_titel) then
      update public.duty_task_template_items
         set plaetze = v_plaetze, sort_order = v_sortierung
       where template_id = target_template and title = v_titel;
    else
      insert into public.duty_task_template_items (template_id, title, sort_order, plaetze)
      values (target_template, v_titel, v_sortierung, v_plaetze);
    end if;
    v_sortierung := v_sortierung + 1;
  end loop;

  select coalesce(array_agg(title), '{}') into v_weg
    from public.duty_task_template_items
   where template_id = target_template and not (title = any(v_behalten));

  delete from public.duty_task_template_items
   where template_id = target_template and title = any(v_weg);

  for ev in
    select distinct e.id, coalesce(e.helper_slots, '{}'::text[]) as slots,
           coalesce(e.helper_caps, '{}'::jsonb) as caps
      from public.event_duty_station_source q
      join public.events e on e.id = q.event_id
     where q.template_id = target_template
       and e.club_id = v_club          -- zweiter Riegel, siehe helferset_nutzung
       and e.starts_at >= now() and e.status = 'scheduled'
     /* Die Termine in fester Reihenfolge sperren: Zwei Leitungen, die
        gleichzeitig zwei Sets desselben Vereins speichern, fassen sonst
        dieselben Termine in unterschiedlicher Folge an. */
     order by e.id
     for update of e
  loop
    v_spiele := v_spiele + 1;

    declare
      i record;
      neue_slots text[] := ev.slots;
      neue_caps jsonb := ev.caps;
      frisch boolean;
    begin
      for i in select title, greatest(1, least(10, coalesce(plaetze, 2))) as plaetze
                 from public.duty_task_template_items where template_id = target_template
      loop
        frisch := not (i.title = any(neue_slots));
        if frisch then
          neue_slots := neue_slots || i.title;
          v_neu := v_neu + 1;
          insert into public.event_duty_station_source (event_id, station, template_id)
          values (ev.id, i.title, target_template)
          on conflict (event_id, station) do update set template_id = excluded.template_id;
        end if;
        if exists (select 1 from public.event_duty_station_source q2
                    where q2.event_id = ev.id and q2.station = i.title and q2.template_id = target_template)
           and public.helferstation_plaetze(neue_caps, i.title) is distinct from i.plaetze then
          neue_caps := neue_caps || jsonb_build_object(i.title, i.plaetze);
          if not frisch then v_geaendert := v_geaendert + 1; end if;
        end if;
      end loop;

      declare g text;
      begin
        foreach g in array v_weg loop
          if exists (select 1 from public.event_duty_station_source q3
                      where q3.event_id = ev.id and q3.station = g and q3.template_id = target_template) then
            if exists (select 1 from public.duty_assignments d
                        where d.event_id = ev.id and d.station = g) then
              delete from public.event_duty_station_source
               where event_id = ev.id and station = g;
              v_behalten_wegen := v_behalten_wegen + 1;
            else
              /* Nur zaehlen, wenn die Station am Termin ueberhaupt stand -
                 sonst meldet die Rueckfrage mehr Entfernungen als geschehen
                 sind. */
              if g = any(neue_slots) then v_entfernt := v_entfernt + 1; end if;
              neue_slots := array_remove(neue_slots, g);
              neue_caps := neue_caps - g;
              delete from public.event_duty_station_source
               where event_id = ev.id and station = g;
            end if;
          end if;
        end loop;
      end;

      update public.events
         set helper_slots = neue_slots, helper_caps = neue_caps, updated_at = now()
       where id = ev.id;
    end;
  end loop;

  return jsonb_build_object(
    'spiele', v_spiele, 'stationen_neu', v_neu, 'plaetze_geaendert', v_geaendert,
    'stationen_entfernt', v_entfernt, 'stationen_behalten', v_behalten_wegen);
end;
$function$;

-- ------------------------------------------------- 3. Offene Punkte
create or replace function public.offene_punkte_fuer_verein(target_club uuid)
returns table(art text, titel text, detail text, ziel text, ziel_id uuid, seit timestamp with time zone)
language plpgsql stable security definer set search_path to 'public' as $function$
begin
  if not public.has_club_role(target_club, array['vereinsadmin','sysadmin','organisator']::club_role[]) then
    raise exception 'Not authorized';
  end if;

  return query
  select 'mitgliedsantrag'::text, 'Offener Mitgliedsantrag'::text,
         m.display_name || coalesce(', ' || u.email, ''),
         'memberships'::text, m.id, m.created_at
  from public.club_memberships m
  left join auth.users u on u.id = m.profile_id
  where m.club_id = target_club and m.status = 'pending'
    /* Nur die Vereinsadministration - dieselbe Grenze wie in der Leseregel
       "members read club memberships" seit 20260927160000. Ohne diese Zeile
       reicht die Funktion als security definer genau die Daten weiter, die
       die Regel verbirgt. */
    and public.has_club_role(target_club, array['vereinsadmin','sysadmin']::club_role[])

  union all

  select 'fahrzeuganfrage'::text, 'Offene Fahrzeug-Buchungsanfrage'::text,
         coalesce(m.display_name, 'Unbekannt') || ' · ' || to_char(b.starts_at, 'DD.MM. HH24:MI'),
         'vehicle'::text, b.id, b.created_at
  from public.vehicle_bookings b
  left join public.club_memberships m on m.id = b.membership_id
  where b.club_id = target_club and b.status = 'angefragt'

  union all

  select 'spielergebnis'::text, 'Offenes Spielergebnis'::text,
         e.title || coalesce(' · ' || t.name, ''),
         'results'::text, e.id, e.starts_at
  from public.events e
  left join public.teams t on t.id = e.team_id
  left join public.event_results r on r.event_id = e.id
  where e.club_id = target_club and e.type = 'spiel'
    and e.status is distinct from 'cancelled'
    and e.starts_at < now() - interval '3 hours'
    and e.starts_at > now() - interval '60 days'
    and r.event_id is null

  union all

  /* Helferstationen -> Helferplanung.
     Gezaehlt wird jetzt gegen die PLATZZAHL der Station, nicht gegen "steht
     ueberhaupt jemand darauf". Die Plaetze kamen einen Tag nach dem letzten
     Umbau dieses Zweigs; run_duty_gap_check wurde nachgezogen, diese Funktion
     nicht - seitdem schwieg die Liste bei halb besetzten Stationen, waehrend
     Uebersicht und Waechter eine Luecke meldeten.
     Der Detailtext nennt den Stand, sonst stuende dieselbe Zeile bis zur
     Vollbesetzung unveraendert da. */
  select 'helferstation'::text, 'Unbesetzte Helferstation'::text,
         s.station || ' · '
           || (select count(*) from public.duty_assignments a
                where a.event_id = e.id and a.station = s.station)::text
           || '/' || public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), s.station)::text
           || coalesce(' · ' || to_char(e.starts_at, 'DD.MM.'), ''),
         'duty'::text, e.id, e.starts_at
  from public.events e
  cross join lateral unnest(e.helper_slots) as s(station)
  where e.club_id = target_club
    and e.helper_slots is not null
    and e.starts_at between now() and now() + interval '14 days'
    and e.status is distinct from 'cancelled'
    and (select count(*) from public.duty_assignments a
          where a.event_id = e.id and a.station = s.station)
        < public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), s.station)

  union all

  select 'aufgabe'::text, 'Offene Aufgabe'::text,
         t.title || coalesce(' · fällig ' || to_char(t.due_date, 'DD.MM.'), ''),
         'tasks'::text, t.id, coalesce(t.due_date::timestamptz, t.created_at)
  from public.club_tasks t
  where t.club_id = target_club
    and t.erledigt_am is null
    and (t.due_date is null or t.due_date <= current_date + 14)

  order by 6 asc;
end;
$function$;

-- ------------------------------------------------- 4. Kontaktdaten
create or replace function public.kontaktdaten_im_verein(target_club uuid)
returns table(membership_id uuid, email text, membership_number text, rejection_count integer, blocked_until timestamp with time zone)
language sql stable security definer set search_path to '' as $function$
  select m.id, m.email, m.membership_number, m.rejection_count, m.blocked_until
    from public.club_memberships m
   where m.club_id = target_club
     and (m.profile_id = (select auth.uid())
          or public.has_club_role(target_club, array['vereinsadmin','sysadmin']::public.club_role[])
          /* Der Organisator bekommt weiter die Kontakte der aufgenommenen
             Mitglieder - er plant mit ihnen. Wartende Bewerber gehen ihn seit
             20260927160000 nichts mehr an; ohne diese Einschraenkung reicht
             die Funktion sie bei jedem Anmelden mit aus. */
          or (public.has_club_role(target_club, array['organisator']::public.club_role[])
              and m.status = any (array['active','inactive']::public.membership_status[])));
$function$;

-- ------------------------------------------------- 5. Leerer Gastname
/* Erst aufraeumen, dann die Indizes angleichen - andersherum koennte eine
   schon vorhandene Unsinnszeile den neuen Index sprengen. In PROD am
   28.09.2026: keine solche Zeile. */
update public.duty_assignments set gast_name = null
 where gast_name is not null and btrim(gast_name) = '' and membership_id is not null;
update public.club_task_assignees set gast_name = null
 where gast_name is not null and btrim(gast_name) = '' and membership_id is not null;
delete from public.duty_assignments
 where membership_id is null and (gast_name is null or btrim(gast_name) = '');
delete from public.club_task_assignees
 where membership_id is null and (gast_name is null or btrim(gast_name) = '');

drop index if exists public.duty_assignments_gast_je_station;
create unique index duty_assignments_gast_je_station
  on public.duty_assignments (event_id, station, lower(btrim(gast_name)))
  where nullif(btrim(gast_name), '') is not null;

drop index if exists public.club_task_assignees_gast_je_aufgabe;
create unique index club_task_assignees_gast_je_aufgabe
  on public.club_task_assignees (task_id, lower(btrim(gast_name)))
  where nullif(btrim(gast_name), '') is not null;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: anwenden_prueft_verein = true, entfernen_raeumt_spur = true,
-- leeren_raeumt_spur = true, abgleich_prueft_verein = true,
-- nutzung_prueft_verein = true, antraege_nur_admin = true,
-- punkte_kennen_plaetze = true, kontakte_ohne_wartende = true,
-- spuren_verwaist = 0, spuren_fremd = 0, gastindizes_getrimmt = 2.
select
  (select pg_get_functiondef(p.oid) like '%Template belongs to a different club%'
     from pg_proc p where p.proname = 'apply_duty_template') as anwenden_prueft_verein,
  (select pg_get_functiondef(p.oid) like '%event_duty_station_source%'
     from pg_proc p where p.proname = 'remove_duty_station') as entfernen_raeumt_spur,
  (select pg_get_functiondef(p.oid) like '%event_duty_station_source%'
     from pg_proc p where p.proname = 'clear_duty_stations') as leeren_raeumt_spur,
  (select pg_get_functiondef(p.oid) like '%e.club_id = v_club%'
     from pg_proc p where p.proname = 'helferset_speichern') as abgleich_prueft_verein,
  (select pg_get_functiondef(p.oid) like '%e.club_id = v_club%'
     from pg_proc p where p.proname = 'helferset_nutzung') as nutzung_prueft_verein,
  (select pg_get_functiondef(p.oid) like '%and public.has_club_role(target_club, array[''vereinsadmin'',''sysadmin'']::club_role[])%'
     from pg_proc p where p.proname = 'offene_punkte_fuer_verein') as antraege_nur_admin,
  (select pg_get_functiondef(p.oid) like '%helferstation_plaetze%'
     from pg_proc p where p.proname = 'offene_punkte_fuer_verein') as punkte_kennen_plaetze,
  (select pg_get_functiondef(p.oid) like '%active'',''inactive%'
     from pg_proc p where p.proname = 'kontaktdaten_im_verein') as kontakte_ohne_wartende,
  (select count(*) from public.event_duty_station_source q
    where not exists (select 1 from public.events e
                       where e.id = q.event_id and q.station = any(coalesce(e.helper_slots, '{}'::text[])))) as spuren_verwaist,
  (select count(*) from public.event_duty_station_source q
     join public.events e on e.id = q.event_id
     join public.duty_task_templates t on t.id = q.template_id
    where t.club_id <> e.club_id) as spuren_fremd,
  (select count(*) from pg_indexes where schemaname = 'public'
     and indexname in ('duty_assignments_gast_je_station', 'club_task_assignees_gast_je_aufgabe')
     and indexdef like '%btrim%') as gastindizes_getrimmt;
