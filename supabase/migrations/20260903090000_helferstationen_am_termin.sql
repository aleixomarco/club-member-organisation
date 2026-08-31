-- Helferstationen gehören an den Termin.
--
-- Die Helferplanung ist für echte Vereine bisher immer leer. Der Grund ist
-- schlicht: Welche Stationen es an einem Termin gibt (Theke, Kasse, Grill,
-- Kuchenbuffet …), stand nur an den erfundenen Demo-Terminen im Code. Termine
-- aus der Datenbank tragen die Eigenschaft nicht, und die Ansicht filtert genau
-- danach — sie zeigt deshalb nichts, für immer.
--
-- duty_assignments speichert zwar, WER an einer Station steht, aber nirgends,
-- welche Stationen ein Termin überhaupt hat. Genau diese Lücke schließt die
-- Spalte.
--
-- Ein Textfeld-Array und keine eigene Tabelle: Die Stationen sind eine kurze,
-- geordnete Liste, die immer zusammen mit dem Termin gelesen und geschrieben
-- wird. Eine Tabelle mit Fremdschlüssel wäre hier mehr Verwaltung als Nutzen.

alter table public.events
  add column if not exists helper_slots text[] not null default '{}';

comment on column public.events.helper_slots is
  'Die Helferstationen dieses Termins, in der Reihenfolge der Anzeige. Leer bedeutet: keine Helfer gesucht.';

create index if not exists events_helfer_idx on public.events(club_id)
  where cardinality(helper_slots) > 0;

/* Aufräumen: Eine Einteilung ohne zugehörige Station ergibt keinen Sinn mehr.
   Bestehende Einteilungen bleiben unangetastet - falls schon welche existieren,
   werden ihre Stationen am Termin nachgetragen, damit nichts unsichtbar wird. */
update public.events e
   set helper_slots = s.stationen
  from (
    select d.event_id, array_agg(distinct d.station order by d.station) as stationen
      from public.duty_assignments d
     group by d.event_id
  ) s
 where s.event_id = e.id
   and cardinality(e.helper_slots) = 0;
