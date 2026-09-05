-- Abgeschaffte Rollen dauerhaft sperren - und die zurueckgekehrten entfernen.
--
-- WAS PASSIERT IST
-- Migration 20260905160000 hat Vorstand, Geschaeftsfuehrung, Finanzmanager und
-- Eltern geloescht. Sieben Minuten spaeter standen vier davon wieder da.
--
-- Der Weg dorthin: saveMemberRoles in der App schreibt die DIFFERENZ zwischen
-- dem Entwurf und dem Rollenstand IM GERAET. Dieser Stand war beim Betrachter
-- noch der von vor der Migration - er enthielt die vier Rollen. Wer danach die
-- Rollen irgendeines Mitglieds speicherte, liess die Schleife sie neu anlegen.
-- Niemand hat sie angeklickt; sie kamen von allein zurueck.
--
-- WARUM EIN AUSLOESER UND NICHT NUR DER FILTER IN DER APP
-- Der Filter in der App wirkt erst, wenn ein Geraet die neue Fassung geladen
-- hat. Bis dahin - und in der ausgelieferten Store-App noch laenger - koennte
-- jedes alte Telefon die Rollen weiter zurueckschreiben. Die Datenbank ist die
-- einzige Stelle, die das fuer alle zugleich beendet.
--
-- Bewusst eine Ausnahme statt stillem Verwerfen: Wer versucht, eine
-- abgeschaffte Rolle zu vergeben, soll das merken. Stilles Verwerfen erzeugt
-- genau die Sorte Fehler, bei der die App Erfolg meldet und nichts passiert.

-- 1) Zurueckgekehrte Rollen erneut entfernen - Rechte wie beim ersten Mal zuerst
insert into public.membership_roles (membership_id, role)
select distinct r.membership_id, 'vereinsadmin'::public.club_role
from public.membership_roles r
where r.role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager')
on conflict (membership_id, role) do nothing;

delete from public.membership_roles
 where role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager', 'eltern');

-- 2) Tuer zuschliessen
create or replace function public.abgeschaffte_rolle_ablehnen()
returns trigger language plpgsql as $$
begin
  if new.role in ('vorstand', 'geschaeftsfuehrung', 'finanzmanager', 'eltern') then
    raise exception 'Die Rolle % wurde abgeschafft. Vorstand, Geschaeftsfuehrung und Finanzmanager sind im Vereins-Administrator aufgegangen.', new.role
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists membership_roles_abgeschaffte_sperren on public.membership_roles;
create trigger membership_roles_abgeschaffte_sperren
  before insert or update on public.membership_roles
  for each row execute function public.abgeschaffte_rolle_ablehnen();

-- Kontrolle
select
  (select count(*) from public.membership_roles
    where role in ('vorstand','geschaeftsfuehrung','finanzmanager','eltern')) as uebrig,
  (select count(*) from pg_trigger where tgname='membership_roles_abgeschaffte_sperren') as sperre;
