-- Ziel im Repo: supabase/migrations/20261004190000_helferstation_sperre_zurueck.sql
--
-- Die Platzgrenze der Helferstationen haelt wieder gegen Gleichzeitigkeit -
-- und die Leitung darf wieder ueberbuchen.
--
-- GEFUNDEN in der Systempruefung vom 04.10.2026. Beim Oeffnen der Stationen
-- fuer Fans (20261002200000_fans_duerfen_eingeteilt_werden.sql:55) wurde
-- helferdienst_eintrag_pruefen neu geschrieben, und dabei sind DREI Dinge aus
-- der Fassung vom 26.09. herausgefallen. Nachgelesen am 04.10.2026 (nur
-- lesend, PROD) in pg_get_functiondef der lebenden Funktion:
--
--   1. "for update" beim Lesen des Termins
--      20260926100000_helferstationen_plaetze.sql:208 sperrte die Terminzeile,
--      bevor es zu zaehlen begann. Diese Sperre war der ganze Schutz gegen
--      zwei gleichzeitige Eintragungen: Die zweite Transaktion wartete, bis
--      die erste festgeschrieben war, und zaehlte sie dann mit.
--      Ohne sie zaehlen beide auf ihrem eigenen Schnappschuss, sehen die noch
--      nicht festgeschriebene Zeile der anderen nicht, und beide bestehen die
--      Pruefung. Es gibt keine zweite Schranke. Die zwei eindeutigen Indexe
--      auf duty_assignments halten etwas anderes: mitglied_je_station und
--      gast_je_station verhindern, dass DIESELBE Person zweimal an derselben
--      Station steht - von der Platzzahl wissen sie nichts, und zwei
--      VERSCHIEDENE Personen auf einem Platz laesst beides durch. Keine der
--      drei Zeilenregeln kennt die Platzzahl ebenfalls.
--      SCHADEN: Station "Grill" mit 2 Plaetzen, einer belegt. Zwei Mitglieder
--      sehen nach der Push "Helfer gesucht" beide "1/2" und tippen im selben
--      Moment auf Uebernehmen. Danach stehen 3 Leute auf 2 Plaetzen. Die
--      Anzeige rechnet mit Math.min (app/page.tsx:743) und verschweigt den
--      Ueberhang; austragen darf nur die Leitung (20260925220000), der
--      Ueberzaehlige kann sich also nicht einmal selbst zurueckziehen.
--      Bei den Fahrzeugen loest dasselbe Problem eine EXCLUDE-Bedingung
--      (20260914110400:38), beim Helferset wurde die fehlende Sperre am 28.09.
--      ausdruecklich nachgetragen (20260928130000_abgleich_sperre_richtig.sql)
--      - nur hier ist sie am 02.10. still verschwunden.
--
--   2. Der Durchlass fuer den Dienstschluessel und fuer alles ohne Anmeldung
--      20260926100000:205 liess jeden Aufruf ohne auth.uid() und jeden mit
--      service_role durch. Daran haengen Spielplan-Import und Datenpflege:
--      Sie laufen ohne Mitgliedschaft, und can_manage_duty_task gibt dort
--      false - jede Einteilung aus einem Import waere an der Fan-Sperre
--      haengen geblieben, sobald sie einen reinen Fan betrifft.
--
--   3. Die Leitung darf eine VOLLE Station belegen
--      20260926100000:193-196 hat es ausdruecklich zugesagt: "sie darf auch
--      eine volle Station belegen, etwa wenn sie jemanden kurzfristig
--      zusaetzlich einteilt". Seit dem 02.10. bekam sie dafuer "voll" - eine
--      Zusage, die das Haus gebrochen hat, ohne es zu erwaehnen.
--
-- WAS BLEIBT WIE AM 02.10.
-- Die Fan-Sperre selbst, Wortlaut unveraendert: Ein reiner Fan kann
-- eingeteilt werden, aber nicht sich selbst eintragen. Sie steht jetzt hinter
-- dem Leitungs-Durchlass, was nichts aendert - sie prueft ohnehin als Erstes
-- "not can_manage_duty_task".
--
-- Geprueft am 04.10.2026 (nur lesend, PROD): 3 Eintragungen insgesamt, keine
-- einzige Station mit mehr Eintragungen als Plaetzen - der Fall ist noch nicht
-- eingetreten, die Luecke stand zwei Tage offen.
--
-- MUSS NICHT zusammen mit der App ausgeliefert werden: Die App ruft die
-- Funktion nicht auf, sie haengt am Ausloeser duty_assignments_platz_pruefen.

create or replace function public.helferdienst_eintrag_pruefen()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_club      uuid;
  v_stationen text[];
  v_caps      jsonb;
  v_belegt    int;
begin
  /* Import und Datenpflege laufen ohne Mitgliedschaft - sie haben keine
     Station zu verteidigen. */
  if auth.uid() is null or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  /* "for update" ist hier der ganze Schutz gegen zwei gleichzeitige
     Eintragungen auf den letzten Platz: Die zweite Transaktion wartet auf die
     erste und zaehlt sie dann mit. Ohne diese Zeile zaehlen beide auf ihrem
     eigenen Schnappschuss und beide kommen durch. */
  select e.club_id, coalesce(e.helper_slots, '{}'::text[]), coalesce(e.helper_caps, '{}'::jsonb)
    into v_club, v_stationen, v_caps
    from public.events e where e.id = new.event_id for update;
  if v_club is null then return new; end if;

  /* Die Leitung bleibt aussen vor - sie darf auch eine volle Station belegen,
     etwa wenn sie jemanden kurzfristig zusaetzlich einteilt. */
  if public.has_club_role(v_club, array['vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand','organisator']::public.club_role[]) then
    return new;
  end if;

  if not (new.station = any(coalesce(v_stationen, '{}'::text[]))) then
    raise exception 'station_unbekannt' using errcode = 'P0001';
  end if;

  select count(*) into v_belegt
    from public.duty_assignments d
   where d.event_id = new.event_id and d.station = new.station;
  if v_belegt >= public.helferstation_plaetze(coalesce(v_caps, '{}'::jsonb), new.station) then
    raise exception 'voll' using errcode = 'P0001';
  end if;

  /* Die Fan-Sperre gilt nur fuer die SELBSTeintragung.
     Traegt die Leitung ein, ist es eine Absprache - sie hat den Fan gefragt.
     Traegt er sich selbst ein, waere es eine Zusage, die ihm niemand
     abgenommen hat. can_manage_duty_task deckt Vereinsleitung, Organisation
     und die Mannschaftsfuehrung am eigenen Termin ab (20260902190000).
     new.membership_id kann null sein - dann steht ein Gastname in der Zeile
     (20260928010000), und es gibt keine Rolle zu pruefen. */
  if new.membership_id is not null
     and not public.can_manage_duty_task(new.event_id)
     and exists (select 1 from public.membership_roles r
                  where r.membership_id = new.membership_id and r.role = 'fan')
     and not exists (select 1 from public.membership_roles r
                      where r.membership_id = new.membership_id and r.role <> 'fan') then
    raise exception 'fan_kein_helferdienst' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: sperre_zurueck = true, dienstschluessel_durch = true,
--           leitung_darf_ueberbuchen = true, fan_sperre_bleibt = true,
--           ausloeser_haengt = true, keine_ueberbuchte_station = 0.
select
  pg_get_functiondef('public.helferdienst_eintrag_pruefen()'::regprocedure)
    like '%for update%'                                   as sperre_zurueck,
  pg_get_functiondef('public.helferdienst_eintrag_pruefen()'::regprocedure)
    like '%service_role%'                                 as dienstschluessel_durch,
  pg_get_functiondef('public.helferdienst_eintrag_pruefen()'::regprocedure)
    like '%has_club_role%'                                as leitung_darf_ueberbuchen,
  pg_get_functiondef('public.helferdienst_eintrag_pruefen()'::regprocedure)
    like '%fan_kein_helferdienst%'                        as fan_sperre_bleibt,
  exists (select 1 from pg_trigger
           where tgrelid = 'public.duty_assignments'::regclass
             and tgfoid  = 'public.helferdienst_eintrag_pruefen()'::regprocedure
             and not tgisinternal)                        as ausloeser_haengt,
  (select count(*) from (
     select d.event_id, d.station, count(*) as belegt,
            public.helferstation_plaetze(coalesce(e.helper_caps, '{}'::jsonb), d.station) as plaetze
       from public.duty_assignments d
       join public.events e on e.id = d.event_id
      group by d.event_id, d.station, e.helper_caps) z
    where z.belegt > z.plaetze)                           as keine_ueberbuchte_station;
