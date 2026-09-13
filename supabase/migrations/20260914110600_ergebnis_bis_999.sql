-- Ergebnisse von 0 bis 999 (Voreinstellung U7, 13.09.2026).
--
-- 0 bis 99 sperrte Sportarten mit Punkten aus (Basketball, Handball in hohen
-- Ligen erreicht die Grenze nicht, Basketball ueberschreitet sie regelmaessig).
-- Die Pruefung ergebnis_pruefgrund in 20260914100000 (noch nicht angewendet)
-- ist dort direkt auf 999 geaendert, ebenso lib/ergebnis.mjs und die Tests.
-- Die beiden CHECKs stammen aus einer bereits angewendeten Migration und
-- werden hier ersetzt. Die Tippspalten predictions.home_score/away_score
-- haben nur eine Untergrenze (>= 0) und bleiben, wie sie sind.
--
-- Bisher (PROD, 14.09.2026):
--   tipp_results_heim_check      CHECK ((heim >= 0) AND (heim <= 99))
--   tipp_results_auswaerts_check CHECK ((auswaerts >= 0) AND (auswaerts <= 99))

alter table public.event_results drop constraint if exists tipp_results_heim_check;
alter table public.event_results add constraint tipp_results_heim_check
  check (heim >= 0 and heim <= 999);

alter table public.event_results drop constraint if exists tipp_results_auswaerts_check;
alter table public.event_results add constraint tipp_results_auswaerts_check
  check (auswaerts >= 0 and auswaerts <= 999);

-- Erwartet: zwei Zeilen, beide mit 999.
select conname, pg_get_constraintdef(oid) as regel
from pg_constraint
where conrelid = 'public.event_results'::regclass
  and conname in ('tipp_results_heim_check', 'tipp_results_auswaerts_check')
order by conname;
