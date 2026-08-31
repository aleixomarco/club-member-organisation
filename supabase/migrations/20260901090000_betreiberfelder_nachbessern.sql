-- Nachbesserung am Schutz der Betreiberfelder.
--
-- Die erste Fassung brach bei jeder Änderung an referral_credit_months ab. Das
-- traf aber nicht nur den Missbrauch, sondern auch den einzigen legitimen Weg:
-- register_new_club() schreibt dem empfehlenden Verein drei Monate gut, und
-- diese Funktion läuft zwar mit erhöhten Rechten, behält aber die Anmeldung des
-- Aufrufers — auth.uid() ist also gesetzt, und der Trigger schlug zu. Damit
-- wäre jede Vereinsanlage mit Empfehlungscode gescheitert.
--
-- Die Unterscheidung, auf die es ankommt, ist nicht "wer schreibt", sondern
-- "wem wird gutgeschrieben": Der Bonus geht an den EMPFEHLENDEN Verein, den der
-- Gründer des neuen Vereins nicht verwaltet. Wer dagegen seinem eigenen Verein
-- Monate gutschreiben will, empfiehlt sich selbst.
--
-- Dieser Fall bricht bewusst nicht ab, sondern verwirft die Änderung still: Ein
-- Abbruch würde die ganze Vereinsanlage mitnehmen, und das wäre eine harte
-- Strafe für einen Versuch, der ohnehin ins Leere läuft.
--
-- Bei den beiden anderen Feldern bleibt es beim Abbruch. Dort geht es um
-- bezahlte Leistung, und ein stiller Fehlschlag wäre die schlechtere Antwort.

create or replace function public.betreiberfelder_schuetzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.role() = 'service_role' or auth.uid() is null then
    return new;
  end if;

  if new.vereinbarte_zugaenge is distinct from old.vereinbarte_zugaenge then
    raise exception 'Die Zahl der Zugaenge wird vom Betreiber vereinbart.' using errcode = 'P0001';
  end if;
  if new.sponsoring_freigeschaltet is distinct from old.sponsoring_freigeschaltet then
    raise exception 'Der Sponsorenzusatz wird vom Betreiber freigeschaltet.' using errcode = 'P0001';
  end if;

  if new.referral_credit_months is distinct from old.referral_credit_months
     and public.has_club_role(new.id, array['sysadmin','vereinsadmin']::public.club_role[]) then
    new.referral_credit_months := old.referral_credit_months;
  end if;

  return new;
end;
$$;
