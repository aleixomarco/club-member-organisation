-- Aufnahme eines neuen Mitglieds: Mitteilung nur an Vereinsleitung und Organisation
--
-- Wunsch des Betreibers (11.09.2026): "bitte nur eine Nachricht an die
-- Vereinsadmins und Organisatoren senden, wenn ein neuer User in dem Verein
-- aufgenommen wurde".
--
-- BISHER: Bei jeder Aufnahme legte willkommens_news() einen Beitrag
-- "Willkommen im Verein, …!" an - und news_melden() schickte dazu jedem
-- Mitglied "Neue Vereins-News". Jede Aufnahme erreichte also den ganzen Verein.
-- Die Vereinsleitung selbst erfuhr von der Aufnahme dagegen gar nichts.
--
-- JETZT:
-- 1. Der Willkommensbeitrag erscheint weiter im News-Bereich (abschaltbar über
--    club_settings.welcome_automation), löst aber keine Mitteilung mehr aus.
--    willkommens_news setzt dafür für die eine Einfügung eine
--    transaktionslokale Markierung, news_melden fragt sie ab. Andere News
--    melden unverändert.
-- 2. Neu: Mitteilung an vereinsadmin, sysadmin und organisator des Vereins,
--    sobald ein Konto aktiv wird - nicht an den, der selbst aufgenommen hat
--    (auth.uid()), und nicht an das neue Mitglied selbst. Art 'join_requests'
--    ("Beitrittsanfragen" im Profil), Ziel 'beitritt' wie bei der Anfrage.
--    Verwaltete Profile ohne Konto (Kinder) zählen nicht als neuer User.
-- 3. Unverändert: Das neue Mitglied bekommt selbst "Deine Beitrittsanfrage
--    wurde angenommen" (beitritt_melden) - darauf wartet es.

-- Texte
insert into public.meldungstexte (schluessel, sprache, text) values
  ('beitritt.aufgenommen.titel', 'de', 'Neues Mitglied'),
  ('beitritt.aufgenommen.titel', 'en', 'New member'),
  ('beitritt.aufgenommen.titel', 'es', 'Nuevo miembro'),
  ('beitritt.aufgenommen.titel', 'pt', 'Novo membro'),
  ('beitritt.aufgenommen.titel', 'it', 'Nuovo membro'),
  ('beitritt.aufgenommen.titel', 'tr', 'Yeni üye'),
  ('beitritt.aufgenommen.titel', 'fr', 'Nouveau membre'),
  ('beitritt.aufgenommen.text', 'de', '{wer} ist jetzt Mitglied im Verein.'),
  ('beitritt.aufgenommen.text', 'en', '{wer} is now a member of the club.'),
  ('beitritt.aufgenommen.text', 'es', '{wer} ya es miembro del club.'),
  ('beitritt.aufgenommen.text', 'pt', '{wer} já é membro do clube.'),
  ('beitritt.aufgenommen.text', 'it', '{wer} ora è membro della società.'),
  ('beitritt.aufgenommen.text', 'tr', '{wer} artık kulübün üyesi.'),
  ('beitritt.aufgenommen.text', 'fr', '{wer} est désormais membre du club.'),
  ('beitritt.aufgenommen.textOhneName', 'de', 'Ein neues Mitglied wurde in den Verein aufgenommen.'),
  ('beitritt.aufgenommen.textOhneName', 'en', 'A new member has joined the club.'),
  ('beitritt.aufgenommen.textOhneName', 'es', 'Un nuevo miembro se ha unido al club.'),
  ('beitritt.aufgenommen.textOhneName', 'pt', 'Um novo membro juntou-se ao clube.'),
  ('beitritt.aufgenommen.textOhneName', 'it', 'Un nuovo membro è entrato nella società.'),
  ('beitritt.aufgenommen.textOhneName', 'tr', 'Kulübe yeni bir üye katıldı.'),
  ('beitritt.aufgenommen.textOhneName', 'fr', 'Un nouveau membre a rejoint le club.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- 1a. news_melden: Kopf und Rumpf wie bisher, dazu die Abfrage der Markierung.
create or replace function public.news_melden()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  /* Der Willkommensbeitrag bei einer Aufnahme meldet nicht an alle - die
     Aufnahme melden wir der Vereinsleitung eigens (aufnahme_leitung_melden). */
  if coalesce(current_setting('cmo.news_still', true), '') = 'an' then
    return new;
  end if;
  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select m.profile_id, new.club_id, 'news',
         public.meldungstext('news.titel', p.language),
         public.meldungstext('news.text', p.language)
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'news');
  return new;
end;
$function$;

-- 1b. willkommens_news: wie bisher, der Beitrag entsteht aber still.
create or replace function public.willkommens_news()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
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

  -- Still: news_melden überspringt diesen einen Beitrag. Die Markierung gilt
  -- nur in dieser Transaktion und wird gleich danach wieder gelöscht.
  perform set_config('cmo.news_still', 'an', true);
  insert into public.news_posts (club_id, title, body, author_id, author_name)
  values (
    new.club_id,
    'Willkommen im Verein, ' || split_part(trim(new.display_name), ' ', 1) || '!',
    'Schön, dass du da bist. Unter „Termine" findest du Training und Spiele, im Chat erreichst du deine Mannschaft.',
    null,
    'Verein'
  );
  perform set_config('cmo.news_still', '', true);

  return new;
end;
$function$;

-- 2.
create or replace function public.aufnahme_leitung_melden()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wer text;
begin
  if new.status <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'active' then return new; end if;
  if new.profile_id is null or new.is_managed_profile then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldungstext('beitritt.aufgenommen.titel', p.language),
         case when v_wer is null
              then public.meldungstext('beitritt.aufgenommen.textOhneName', p.language)
              else public.meldungstext('beitritt.aufgenommen.text', p.language, jsonb_build_object('wer', v_wer)) end,
         'beitritt', new.id
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and m.id <> new.id
    and m.profile_id is distinct from new.profile_id
    and m.profile_id is distinct from auth.uid()
    and public.meldung_erlaubt(m.profile_id, 'join_requests');
  return new;
end;
$$;

drop trigger if exists club_memberships_aufnahme_melden on public.club_memberships;
create trigger club_memberships_aufnahme_melden
  after insert or update on public.club_memberships
  for each row execute function public.aufnahme_leitung_melden();

revoke all on function public.aufnahme_leitung_melden() from public, anon, authenticated;
