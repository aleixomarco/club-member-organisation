-- Auch dieser Ausloeser hiess anders als seine Funktion:
--   on_notification_queued  ruft  trigger_send_push
--
-- Derselbe Fehler wie beim vorigen Nachtrag - und dieselbe Lehre: "drop
-- trigger if exists" schweigt, wenn der Name nicht stimmt. Es hilft nur,
-- hinterher nachzuzaehlen, statt der Erfolgsmeldung zu glauben.
--
-- Warum er weg muss: Er ruft den Versender mit dem OEFFENTLICHEN Schluessel
-- auf, den dieser seit der Absicherung ablehnt. Und ueber die Bruecke
-- notification_queue -> user_notifications laeuft der Versand ohnehin auf dem
-- geprueften Weg. Zwei Aufrufe pro Meldung waeren nur doppelte Last - einer
-- davon ins Leere.

drop trigger if exists on_notification_queued on public.notification_queue;

select count(*) as alter_pushaufruf_uebrig
from pg_trigger t join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal and p.proname = 'trigger_send_push';
