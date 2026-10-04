-- Ziel im Repo: supabase/migrations/20261004240000_kennzahlen_nur_eigener_verein.sql
--
-- Jeder Verein ist seine eigene Kugel - auch bei den Kennzahlen.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026 ("Kennzahlen fremder Vereine
-- ueber SECURITY-DEFINER-Helfer") und in 20261004210000 als naechster Schritt
-- angekuendigt: Dort wurde anon ausgesperrt, hier geht es um das angemeldete
-- Mitglied, das nach einem FREMDEN Verein fragt.
--
-- NACHGEMESSEN AM 04.10.2026 GEGEN PROD mit einem Konto, das ausschliesslich
-- in ERG Iserlohn Mitglied ist (is_club_member('SV Musterstadt') = false),
-- Abfrage gegen SV Musterstadt:
--   punkte_je_mitglied        14 Zeilen mit den Punkten fremder Mitglieder
--   club_subscription_tier    'pro'          - welchen Tarif ein Fremdverein zahlt
--   club_kontingent_uebersicht (pro,13,1000,1,500,f)
--   get_task_signup_ratio     0,0714         - wie aktiv fremde Mitglieder sind
--   club_account_count        13
--   club_fan_usage            (1,500,pro)
--   anzeigen_fuer_verein      1 Zeile mit Titel, Text, Bildpfad, Zieladresse
--                             sowie Telefon und E-Mail des Sponsors
-- Keine dieser Funktionen prueft im Rumpf eine Mitgliedschaft; sie sind alle
-- security definer, umgehen also jede Leseregel. Nur anzeigen_kennzahlen hat
-- einen eigenen Riegel ("Keine Berechtigung fuer die Zahlen dieser Anzeige")
-- und bleibt deshalb unberuehrt.
--
-- DREI WEGE, WEIL DREI LAGEN
--
-- 1. RECHT ENTZIEHEN, wo die App die Funktion gar nicht aufruft.
--    club_account_count/limit/usage und club_fan_count/limit/usage sind reine
--    Bausteine. Kein Treffer in app/ und lib/ (geprueft, Funktion fuer
--    Funktion). Ihre Aufrufer sind selbst security definer -
--    betreiber_kennzahlen, club_kontingent_pruefen,
--    club_kontingent_uebersicht, verein_freischalten, verein_sperren - und
--    laufen damit als Eigentuemer der Funktion, nicht als authenticated. Ein
--    Entzug trifft sie nicht.
--    Dazu club_subscription_tier: Die App rief es getrennt auf, obwohl
--    club_kontingent_uebersicht den Tarif als erste Spalte mitliefert. Die
--    App nimmt ihn jetzt von dort, und die Funktion bleibt ein Baustein.
--
-- 2. RIEGEL IN DEN RUMPF, wo die App die Funktion fuer den EIGENEN Verein
--    braucht: punkte_je_mitglied, club_kontingent_uebersicht,
--    get_task_signup_ratio. Sie werfen jetzt 'fremder_verein'.
--    Der Riegel laesst zwei Faelle durch: auth.uid() is null (Cron,
--    Ausloeserkette, Dienstschluessel) und den Dienstschluessel selbst. Sonst
--    stuenden die naechtlichen Auftraege still, und das waere ein neuer
--    Schaden anstelle eines geschlossenen.
--    Geprueft, dass kein Aufrufer darueber stolpert: punkte_je_mitglied wird
--    nur von mitglieder_eines_vereins gerufen (die Leitung liest ihren
--    eigenen Verein), die anderen zwei von niemandem.
--
-- 3. BEDINGUNG IN DIE ABFRAGE, wo die Funktion zwei Arten von Daten liefert:
--    anzeige_fuer_platz gibt Betreiber-Anzeigen (club_id is null) UND die
--    Anzeigen eines Vereins zurueck. Die Betreiber-Anzeige ist dieselbe fuer
--    alle und darf bleiben; nur der vereinseigene Zweig bekommt die
--    Mitgliedschaftsbedingung. Hier wird NICHT geworfen, sondern gefiltert -
--    eine Ausnahme wuerde sonst auch die Betreiber-Anzeige mitnehmen.
--    anzeigen_fuer_verein ruft anzeige_fuer_platz vier Mal auf und erbt die
--    Bedingung, bleibt also unveraendert.
--
-- MUSS zusammen mit der App ausgeliefert werden: Ohne den App-Teil ruft die
-- Tarifanzeige eine Funktion auf, die sie nicht mehr aufrufen darf, und der
-- Vollzugangs-Bereich zeigte "none" statt des gezahlten Tarifs.

-- ------------------------------------------------- 1. Recht entziehen
revoke all on function public.club_subscription_tier(uuid) from public, anon, authenticated;
revoke all on function public.club_account_count(uuid)     from public, anon, authenticated;
revoke all on function public.club_account_limit(uuid)     from public, anon, authenticated;
revoke all on function public.club_account_usage(uuid)     from public, anon, authenticated;
revoke all on function public.club_fan_count(uuid)         from public, anon, authenticated;
revoke all on function public.club_fan_limit(uuid)         from public, anon, authenticated;
revoke all on function public.club_fan_usage(uuid)         from public, anon, authenticated;

-- ------------------------------------------------- 2. Riegel in den Rumpf
/* Ein Platz fuer die Entscheidung, nicht drei. Wer sie morgen aendert, aendert
   sie an einer Stelle. */
create or replace function public.nur_eigener_verein(target_club uuid)
returns boolean
language plpgsql stable security definer set search_path = '' as $$
begin
  /* Cron, Ausloeserketten und der Dienstschluessel haben keinen Verein, dem
     sie angehoeren - sie arbeiten fuer alle. */
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
    return true;
  end if;
  if public.is_club_member(target_club) then
    return true;
  end if;
  raise exception 'fremder_verein' using errcode = 'P0001';
end;
$$;

comment on function public.nur_eigener_verein(uuid) is
  'Wirft fremder_verein, wenn ein angemeldetes Konto Zahlen eines Vereins verlangt, in dem es nicht aktives Mitglied ist. Cron, Ausloeser und Dienstschluessel kommen durch.';

revoke all on function public.nur_eigener_verein(uuid) from public, anon;
grant execute on function public.nur_eigener_verein(uuid) to authenticated, service_role;

create or replace function public.punkte_je_mitglied(target_club uuid)
returns table(membership_id uuid, punkte integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.nur_eigener_verein(target_club);
  return query
  select m.id,
         (
           -- Helferdienste: der groesste Beitrag, den jemand leisten kann
           coalesce((select count(*) * 25 from public.duty_assignments d
                      join public.events e on e.id = d.event_id
                     where d.membership_id = m.id and e.club_id = target_club), 0)
           -- Uebernommene Helferaufgaben
           + coalesce((select count(*) * 15 from public.duty_tasks t
                       where t.assignee_membership_id = m.id and t.club_id = target_club), 0)
           -- Mitmachen bei Umfragen und Wahlen
           + coalesce((select count(*) * 5 from public.poll_votes v
                        join public.polls p on p.id = v.poll_id
                       where p.club_id = target_club and v.profile_id = m.profile_id), 0)
           + coalesce((select count(*) * 5 from public.season_votes sv
                       where sv.club_id = target_club and sv.voter_profile_id = m.profile_id), 0)
           -- Tippspiel
           + coalesce((select count(*) * 2 from public.predictions pr
                        join public.events e2 on e2.id = pr.event_id
                       where e2.club_id = target_club and pr.profile_id = m.profile_id), 0)
           -- Vereinstreue: zehn Punkte je vollem Jahr
           + coalesce((extract(year from now())::integer - m.member_since) * 10, 0)
         )::integer
    from public.club_memberships m
   where m.club_id = target_club and m.status = 'active';
end;
$$;

create or replace function public.club_kontingent_uebersicht(target_club uuid)
returns table(tarif text, mitglieder integer, mitglieder_grenze integer,
              fans integer, fan_grenze integer, gemeinsamer_topf boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.nur_eigener_verein(target_club);
  return query
  select public.club_subscription_tier(target_club),
         public.club_account_count(target_club),
         public.club_account_limit(target_club),
         public.club_fan_count(target_club),
         public.club_fan_limit(target_club),
         public.club_subscription_tier(target_club) = 'none';
end;
$$;

create or replace function public.get_task_signup_ratio(target_club uuid)
returns numeric
language plpgsql stable security definer set search_path = 'public' as $$
declare
  v_quote numeric;
begin
  perform public.nur_eigener_verein(target_club);
  select case when count(distinct m.id) = 0 then 0 else
    (select count(distinct s.membership_id)::numeric
       from public.club_task_signups s
       join public.club_memberships m2 on m2.id = s.membership_id
      where m2.club_id = target_club and m2.status = 'active')
    / count(distinct m.id)::numeric
  end
    into v_quote
    from public.club_memberships m
   where m.club_id = target_club and m.status = 'active';
  return v_quote;
end;
$$;

-- ------------------------------------------------- 3. Bedingung in die Abfrage
create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table(id uuid, herkunft text, titel text, text text, bild_pfad text,
              ziel_url text, ziel_knopf text, telefon text, email text,
              aktion_titel text, aktion_text text, aktion_url text,
              aktion_bis timestamp with time zone, laeuft_bis timestamp with time zone)
language sql stable security definer set search_path = '' as $$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft,
           /* Die Aktion hat einen eigenen Zeitraum innerhalb der Laufzeit des
              Sponsors. Laeuft sie nicht, kommen ihre Felder leer zurueck - der
              Sponsor bleibt stehen, der Aktionsknopf verschwindet von selbst. */
           (a.aktion_titel is not null
            and coalesce(a.aktion_von, a.laeuft_von) <= now()
            and a.aktion_bis > now()) as aktion_laeuft
      from public.anzeigen a
     where a.platz = ziel_platz
       and a.aktiv
       and a.laeuft_von <= now()
       and (a.laeuft_bis is null or a.laeuft_bis > now())
       and (
         a.club_id is null
         or (a.club_id = target_club
             /* Die Sponsoren eines Vereins sieht, wer in diesem Verein ist.
                Vorher reichte die Vereins-Kennung, und die bekommt jeder
                Angemeldete ueber die Regel "clubs are discoverable" - damit
                lagen Telefon und E-Mail der Sponsoren jedes Vereins offen.
                Gefiltert, nicht geworfen: Eine Ausnahme nimmt die
                Betreiber-Anzeige mit, die hier gar nicht gemeint ist.
                auth.uid() is null laesst Cron und Dienstschluessel durch. */
             and (auth.uid() is null or public.is_club_member(target_club))
             and exists (select 1 from public.clubs c
                          where c.id = target_club and c.sponsoring_freigeschaltet))
       )
  )
  select l.id, l.herkunft, l.titel, l.text, l.bild_pfad, l.ziel_url,
         l.ziel_knopf, l.telefon, l.email,
         case when l.aktion_laeuft then l.aktion_titel end,
         case when l.aktion_laeuft then l.aktion_text end,
         case when l.aktion_laeuft then l.aktion_url end,
         case when l.aktion_laeuft then l.aktion_bis end,
         l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$$;

revoke all on function public.anzeige_fuer_platz(uuid, text) from public, anon;
grant execute on function public.anzeige_fuer_platz(uuid, text) to authenticated;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: bausteine_zu = 7, riegel_in_drei_rumpfen = 3,
--           anzeige_prueft_mitgliedschaft = true,
--           kennzahlen_behalten_riegel = true,
--           uebersicht_fuer_angemeldete_offen = true.
with bausteine(name) as (values
  ('public.club_subscription_tier(uuid)'), ('public.club_account_count(uuid)'),
  ('public.club_account_limit(uuid)'),     ('public.club_account_usage(uuid)'),
  ('public.club_fan_count(uuid)'),         ('public.club_fan_limit(uuid)'),
  ('public.club_fan_usage(uuid)'))
select
  count(*) filter (where not has_function_privilege('authenticated', name, 'execute')) as bausteine_zu,
  (select count(*) from (values
     ('public.punkte_je_mitglied(uuid)'), ('public.club_kontingent_uebersicht(uuid)'),
     ('public.get_task_signup_ratio(uuid)')) as f(n)
    where pg_get_functiondef(f.n::regprocedure) like '%nur_eigener_verein%')          as riegel_in_drei_rumpfen,
  (select pg_get_functiondef('public.anzeige_fuer_platz(uuid,text)'::regprocedure)
            like '%is_club_member(target_club)%')                                     as anzeige_prueft_mitgliedschaft,
  (select pg_get_functiondef('public.anzeigen_kennzahlen(uuid,integer)'::regprocedure)
            like '%Keine Berechtigung%')                                              as kennzahlen_behalten_riegel,
  (select has_function_privilege('authenticated',
            'public.club_kontingent_uebersicht(uuid)', 'execute'))                    as uebersicht_fuer_angemeldete_offen
from bausteine;
