-- Der Willkommensgruß, der nie ankam.
--
-- In der Verwaltung gibt es den Schalter „Willkommens-Automatik: Neue
-- Mitglieder erhalten automatisch eine Begrüßung im Kanal Vereins-News". Die
-- App hängte dafür eine Nachricht an einen Kanal mit der Kennung "news" — den
-- es gab, solange die Kanäle fest im Code standen. Seit sie aus der Tabelle
-- channels kommen, haben sie echte Kennungen, und der Gruß landete im
-- Arbeitsspeicher dessen, der das Mitglied freigegeben hat. Beim nächsten
-- Öffnen war er weg, und der Begrüßte hat ihn ohnehin nie gesehen.
--
-- Ein Gruß, den nur der Absender kurz sieht, ist keiner. Er gehört dorthin, wo
-- die Vereins-News stehen, und er muss dann geschrieben werden, wenn die
-- Aufnahme wirklich durch ist — nicht wenn jemand ein Formular abschickt.

create or replace function public.willkommens_news()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  angeschaltet boolean;
begin
  -- Nur beim Übergang auf 'active'. Ein erneutes Speichern derselben Zeile
  -- soll nicht jedes Mal grüßen.
  if new.status <> 'active' or (tg_op = 'UPDATE' and old.status = 'active') then
    return new;
  end if;

  select coalesce(s.welcome_automation, true) into angeschaltet
    from public.club_settings s where s.club_id = new.club_id;
  if angeschaltet is false then return new; end if;

  insert into public.news_posts (club_id, title, body, author_id, author_name)
  values (
    new.club_id,
    'Willkommen im Verein, ' || split_part(trim(new.display_name), ' ', 1) || '!',
    'Schön, dass du da bist. Unter „Termine" findest du Training und Spiele, im Chat erreichst du deine Mannschaft.',
    null,
    'Verein'
  );

  return new;
end;
$$;

drop trigger if exists club_memberships_willkommen on public.club_memberships;
create trigger club_memberships_willkommen after insert or update of status on public.club_memberships
for each row execute function public.willkommens_news();
