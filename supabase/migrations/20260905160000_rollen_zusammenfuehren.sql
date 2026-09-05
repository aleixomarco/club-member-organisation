-- Rollen zusammenfuehren: Vorstand, Geschaeftsfuehrung und Finanzmanager gehen
-- in Vereins-Administrator auf. Die Rolle "Eltern" faellt ersatzlos weg.
--
-- REIHENFOLGE IST HIER ALLES
-- Zuerst bekommt JEDE Mitgliedschaft, die eine der drei Rollen haelt, den
-- Vereins-Administrator. Erst danach werden die alten Zeilen geloescht. Anders
-- herum waere jemand fuer die Dauer der Migration ohne Rechte - und wenn der
-- zweite Schritt fehlschlaegt, dauerhaft ausgesperrt.
--
-- WARUM DIE 22 FUNKTIONEN UNVERAENDERT BLEIBEN
-- 22 Datenbankfunktionen pruefen Rechte mit Listen wie
--   role in ('vereinsadmin','vorstand','geschaeftsfuehrung')
-- Man koennte sie alle umschreiben. Das waere 22 Gelegenheiten, sich zu
-- vertun - bei Funktionen, an denen Zahlungen, Mitgliedsantraege und
-- Loeschrechte haengen. Sie bleiben, wie sie sind: Da niemand die alten Rollen
-- mehr haelt, laufen diese Zweige einfach ins Leere, und der Zweig
-- 'vereinsadmin' greift fuer genau dieselben Menschen wie vorher. Kein
-- Verhalten aendert sich, kein Recht geht verloren.
--
-- WARUM DIE ENUM-WERTE BLEIBEN
-- Postgres kann Enum-Werte nicht ohne Weiteres entfernen, und die Funktionen
-- oben nennen sie noch. Ein Wert, den keine Zeile benutzt, schadet nicht. In
-- der App verschwinden die Rollen trotzdem - sie stehen dort nicht mehr zur
-- Auswahl.
--
-- ELTERN: GEPRUEFT, NICHT ANGENOMMEN
-- 'eltern' gibt es ZWEIMAL: als club_role (die Mitgliedsrolle, die hier
-- verschwindet) und als family_relation (die Beziehung Elternteil/Kind im
-- Familienbaum). Nachgesehen: Keine einzige Funktion prueft die ROLLE eltern -
-- sie schaltet nichts frei. Der Familienbaum benutzt ausschliesslich den
-- gleichnamigen family_relation-Wert und bleibt unberuehrt.

-- 1) Rechte sichern, BEVOR etwas verschwindet
insert into public.membership_roles (membership_id, role)
select distinct r.membership_id, 'vereinsadmin'::public.club_role
from public.membership_roles r
where r.role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager')
on conflict (membership_id, role) do nothing;

-- 2) Erst jetzt die alten Zeilen entfernen
delete from public.membership_roles
 where role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager', 'eltern');

-- Kontrolle: Keine der vier Rollen darf uebrig sein, und jede Mitgliedschaft,
-- die vorher eine der drei Verwaltungsrollen hatte, muss jetzt Vereins-
-- Administrator sein.
select
  (select count(*) from public.membership_roles
    where role in ('vorstand','geschaeftsfuehrung','finanzmanager','eltern')) as alte_rollen_uebrig,
  (select count(*) from public.membership_roles where role = 'vereinsadmin') as vereinsadmins;
