-- Wie oft eine Anzeige gesehen und angetippt wurde.
--
-- Bisher lagen diese Zahlen im gemeinsamen Zustandsblock der Administratoren.
-- Geschrieben wird der aber nur von Administratoren — gezählt wurden also die
-- Aufrufe der Vorstandschaft, nicht die des Vereins. Wer damit einem Sponsor
-- gegenübertritt, nennt ihm eine falsche Zahl.
--
-- Jetzt zählt jedes Gerät an der Anzeige selbst. Zwei Zahlen genügen; wer
-- auswerten will, wann und von wem, bräuchte Einzelereignisse — und die wären
-- eine Bewegungsaufzeichnung über Mitglieder, die hier niemand braucht.

alter table public.anzeigen
  add column if not exists impressionen bigint not null default 0,
  add column if not exists klicks bigint not null default 0;

/* Zählt eine Einblendung oder einen Klick.
 *
 * Security definer, weil Mitglieder die Anzeigen sonst nicht verändern dürfen —
 * und auch hier nur diese beiden Zähler und nur an Anzeigen, die sie überhaupt
 * sehen dürfen. */
create or replace function public.anzeige_zaehlen(ziel uuid, art text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then return; end if;
  if art not in ('impression', 'klick') then
    raise exception 'Unbekannte Art "%"', art;
  end if;

  update public.anzeigen a
     set impressionen = a.impressionen + case when art = 'impression' then 1 else 0 end,
         klicks       = a.klicks       + case when art = 'klick'      then 1 else 0 end
   where a.id = ziel
     and (a.club_id is null or public.is_club_member(a.club_id));
end;
$$;

grant execute on function public.anzeige_zaehlen(uuid, text) to authenticated;
