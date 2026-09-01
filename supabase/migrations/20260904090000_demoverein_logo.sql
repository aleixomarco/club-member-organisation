-- Der Demo-Verein bekommt ein Logo.
--
-- SV Musterstadt hatte keines. In einer Vereins-App heisst das: Der Prüfer
-- sieht die ganze Sitzung lang oben links eine farbige Kachel mit dem
-- Buchstaben "S" - die vorgesehene Rückfallanzeige (ClubLogo in app/page.tsx),
-- also kein Fehler, aber ausgerechnet an der Stelle, an der ein Verein sich
-- zeigt. Das Wappen ist in den Vereinsfarben gehalten (#1D4ED8 / #2B2F36) und
-- so gezeichnet, dass es auch bei 36 Pixeln in der Kopfzeile noch lesbar ist.
--
-- Die Datei liegt unter demselben Pfadschema, das auch die App beim Hochladen
-- benutzt: <club_id>/logo-*.png im öffentlichen Eimer club-logos.

update public.clubs
   set logo_url = 'https://kymokcqebfruhlvcyqnw.supabase.co/storage/v1/object/public/club-logos/d0000000-0000-4000-a000-000000000001/logo-svm.png'
 where id = 'd0000000-0000-4000-a000-000000000001'
   and logo_url is null;
