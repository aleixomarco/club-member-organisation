-- Nachtrag zu 20260905200000: Die doppelten Ausloeser sind noch da.
--
-- Ich hatte sie mit dem Namen der FUNKTION zu loeschen versucht - Ausloeser
-- heissen hier aber anders als die Funktionen, die sie aufrufen:
--
--   on_event_created        ruft  notify_event_created
--   on_news_posted          ruft  notify_news_posted
--   on_join_request_created ruft  notify_new_join_request
--
-- "drop trigger if exists" auf einen nicht existierenden Namen ist stumm
-- erfolgreich. Die Migration lief also durch und meldete Erfolg, waehrend die
-- Doppelungen unveraendert bestehen blieben - genau die Sorte Fehler, die man
-- nur findet, wenn man hinterher nachzaehlt.
--
-- Diese fuenf Ereignisse werden inzwischen von den neuen Funktionen gemeldet
-- (notify_event_audience, news_melden, beitritt_melden). Blieben die alten
-- stehen, bekaeme jedes Mitglied jede dieser Meldungen zweimal, sobald ein
-- Geraet angemeldet ist.

drop trigger if exists on_event_created        on public.events;
drop trigger if exists on_event_updated        on public.events;
drop trigger if exists on_news_posted          on public.news_posts;
drop trigger if exists on_join_request_created on public.club_memberships;
drop trigger if exists on_join_request_decided on public.club_memberships;

-- Kontrolle: keine dieser fuenf Funktionen darf noch an einem Ausloeser haengen.
select count(*) as doppelte_uebrig
from pg_trigger t join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and p.proname in
  ('notify_event_created','notify_event_updated','notify_news_posted',
   'notify_new_join_request','notify_join_request_decided');
