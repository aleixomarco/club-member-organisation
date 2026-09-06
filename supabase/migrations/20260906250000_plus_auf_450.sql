-- Plus fasst jetzt 450 Zugänge statt 350.
--
-- Die Staffel sonst unveraendert:
--   Basic  bis  100
--   Plus   bis  450   (vorher 350)
--   Pro    bis 1000
--   ohne Abo         3 kostenlos
--
-- Die Aenderung geht nach OBEN. Kein Verein verliert Zugaenge, keiner wird
-- durch das Update gesperrt. Umgekehrt waere Vorsicht geboten: Eine Absenkung
-- wuerde bestehende Mitglieder ueber der neuen Grenze aussperren, und zwar
-- ohne Vorwarnung.
--
-- Diese Migration nimmt die Funktion, wie sie in der Produktion steht, und
-- aendert daran EINE Zahl. Ich hatte sie zuerst aus dem Gedaechtnis neu
-- geschrieben - mit einer eigenen Abfrage auf club_subscriptions und einer
-- Sonderbehandlung fuer vereinbarte_zugaenge. Die echte Funktion arbeitet
-- ueber club_subscription_tier() und ist in SQL statt PL/pgSQL geschrieben;
-- meine Fassung haette anderes Verhalten gehabt, ohne dass es aufgefallen
-- waere. Dieselbe Falle hat heute schon register_for_club zerlegt.

CREATE OR REPLACE FUNCTION public.club_account_limit(target_club uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case
    -- Ohne Freischaltung bleibt es bei der kostenlosen Stufe, auch wenn eine
    -- Zahl vereinbart wurde. Sonst liesse sich die Grenze durch einen Eintrag
    -- aushebeln, den niemand bezahlt hat.
    when public.club_subscription_tier(target_club) = 'none' then 3
    else coalesce(
      (select c.vereinbarte_zugaenge from public.clubs c where c.id = target_club),
      case public.club_subscription_tier(target_club)
        when 'basic' then 100
        when 'plus'  then 450
        when 'pro'   then 1000
        else 3
      end
    )
  end;
$function$;

select public.club_account_limit((select id from public.clubs limit 1)) as beispielgrenze;
