-- Die Altersregel fuer Helferdienste entfaellt ganz.
--
-- Heimspiel-Stationen "erst ab 16" war eine Voreinstellung der App, keine
-- gesetzliche Pflicht; der Verein entscheidet selbst, wen er wo einsetzt
-- (Entscheidung des Betreibers am 11.09.2026). Damit braucht es auch die
-- Altersauskunft helfer_altersstatus nicht mehr, die die App seit
-- 20260911080000 nur fuer diese Regel abgefragt hat. Eine Funktion, die
-- niemand aufruft und die trotzdem Auskunft ueber Mitglieder gibt, bleibt
-- nicht stehen.

drop function if exists public.helfer_altersstatus(uuid);

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'helfer_altersstatus') as altersauskunft_uebrig;
