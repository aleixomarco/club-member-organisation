-- Mitfahrgelegenheit: Abfahrtsadresse als eigenes Feld
--
-- Bisher stand der Abfahrtsort nur als Vorschlag in der freien Notiz
-- ("Notiz (optional), z. B. Abfahrtsort"). Genau die Art Feld, die in der
-- Praxis leer bleibt - und dann muss jeder Mitfahrer nachfragen, wo er
-- einsteigen soll.
--
-- Jetzt ein eigenes, verpflichtendes Feld. Die Notiz bleibt daneben bestehen,
-- fuer alles Weitere: "nehme nur zwei Taschen mit", "fahre direkt weiter".
--
-- Bestehende Eintraege behalten ihre Notiz; departure bleibt dort leer und die
-- Oberflaeche zeigt dann wie bisher nur die Notiz an.

alter table public.carpools
  add column if not exists departure text;

comment on column public.carpools.departure is
  'Adresse, von der die Fahrgemeinschaft startet. Pflichtfeld in der App.';

-- Kontrolle
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'carpools'
order by ordinal_position;
