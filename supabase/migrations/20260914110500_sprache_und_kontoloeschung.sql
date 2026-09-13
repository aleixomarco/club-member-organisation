-- Sprache ab dem ersten Start und News nach der Kontoloeschung.
--
-- konto-3  Die beim ersten Start gewaehlte Sprache kam nie in
--          profiles.language - Push und Glocke blieben deutsch. Die App gibt
--          sie jetzt bei der Registrierung mit (raw_user_meta_data.language);
--          handle_new_user uebernimmt sie. Die Meldung "Konto geloescht" an die
--          Leitung kommt aus meldungstexte statt als deutscher Freitext.
-- konto-2  Nach einer Kontoloeschung trugen News-Beitraege weiter den Namen
--          der Person, obwohl /konto-loeschen und der Hinweis in der App etwas
--          anderes sagen. Betreiberentscheidung 13.09.2026: Die Beitraege
--          bleiben, als Verfasser steht 'Verein'. author_name ist NOT NULL -
--          niemals null setzen.
--
-- Rumpfe aus PROD (pg_get_functiondef, 14.09.2026).

-- ================================================================ konto-3
-- Rumpf aus PROD (20260907190000 plus Aenderungen auf PROD); neu: language
-- aus den Kontodaten, nur wenn es eine der sieben Sprachen ist, sonst 'de'.
-- Darf nie scheitern - eine unbekannte Angabe faellt still auf 'de'.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_vorname  text := nullif(trim(new.raw_user_meta_data ->> 'first_name'), '');
  v_nachname text := nullif(trim(new.raw_user_meta_data ->> 'last_name'), '');
  v_voll     text := nullif(trim(new.raw_user_meta_data ->> 'full_name'), '');
  v_land     text := upper(nullif(trim(new.raw_user_meta_data ->> 'country_code'), ''));
  v_plz      text := nullif(trim(new.raw_user_meta_data ->> 'postal_code'), '');
  v_ort      text := nullif(trim(new.raw_user_meta_data ->> 'city'), '');
  v_sprache  text := lower(nullif(trim(new.raw_user_meta_data ->> 'language'), ''));
begin
  /* Kommt nur ein voller Name herein, wird er geteilt: alles vor dem ersten
     Leerzeichen ist der Vorname, der Rest der Nachname. */
  if v_vorname is null and v_voll is not null then
    v_vorname  := split_part(v_voll, ' ', 1);
    v_nachname := nullif(trim(substr(v_voll, length(split_part(v_voll, ' ', 1)) + 1)), '');
  end if;

  /* Das Land nur uebernehmen, wenn es wie ein Laendercode aussieht. */
  if v_land is not null and v_land !~ '^[A-Z]{2}$' then
    v_land := null;
  end if;

  /* Dieselbe Liste wie profiles_language_check und sprache_setzen. */
  if v_sprache is null or v_sprache not in ('de','en','es','pt','it','tr','fr') then
    v_sprache := 'de';
  end if;

  insert into public.profiles (id, full_name, first_name, last_name, country_code, postal_code, city, language)
  values (
    new.id,
    coalesce(v_voll, trim(coalesce(v_vorname, '') || ' ' || coalesce(v_nachname, '')), ''),
    v_vorname,
    v_nachname,
    v_land,
    left(v_plz, 20),
    left(v_ort, 120),
    v_sprache
  );
  return new;
end;
$$;

insert into public.meldungstexte (schluessel, sprache, text) values
  ('konto.geloescht.titel', 'de', 'Konto gelöscht'),
  ('konto.geloescht.titel', 'en', 'Account deleted'),
  ('konto.geloescht.titel', 'es', 'Cuenta eliminada'),
  ('konto.geloescht.titel', 'pt', 'Conta eliminada'),
  ('konto.geloescht.titel', 'it', 'Account eliminato'),
  ('konto.geloescht.titel', 'tr', 'Hesap silindi'),
  ('konto.geloescht.titel', 'fr', 'Compte supprimé'),
  ('konto.geloescht.text', 'de', '{wer} hat das eigene Konto dauerhaft gelöscht.'),
  ('konto.geloescht.text', 'en', '{wer} has permanently deleted their account.'),
  ('konto.geloescht.text', 'es', '{wer} ha eliminado su cuenta de forma permanente.'),
  ('konto.geloescht.text', 'pt', '{wer} eliminou a sua conta de forma permanente.'),
  ('konto.geloescht.text', 'it', '{wer} ha eliminato definitivamente il proprio account.'),
  ('konto.geloescht.text', 'tr', '{wer} hesabını kalıcı olarak sildi.'),
  ('konto.geloescht.text', 'fr', '{wer} a supprimé définitivement son compte.'),
  ('konto.geloescht.textOhneName', 'de', 'Ein Mitglied hat das eigene Konto dauerhaft gelöscht.'),
  ('konto.geloescht.textOhneName', 'en', 'A member has permanently deleted their account.'),
  ('konto.geloescht.textOhneName', 'es', 'Un miembro ha eliminado su cuenta de forma permanente.'),
  ('konto.geloescht.textOhneName', 'pt', 'Um membro eliminou a sua conta de forma permanente.'),
  ('konto.geloescht.textOhneName', 'it', 'Un membro ha eliminato definitivamente il proprio account.'),
  ('konto.geloescht.textOhneName', 'tr', 'Bir üye hesabını kalıcı olarak sildi.'),
  ('konto.geloescht.textOhneName', 'fr', 'Un membre a supprimé définitivement son compte.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ================================================================ konto-2
-- Greift bei jedem Loeschweg: auth.admin.deleteUser (app/api/account/delete)
-- loescht auth.users, die Kaskade profiles_id_fkey (ON DELETE CASCADE, PROD
-- 14.09.2026) loescht das Profil, und Zeilen-Ausloeser feuern auch fuer
-- Kaskaden. news_posts_author_id_fkey setzt author_id danach auf null.
create or replace function public.newsautor_verein_setzen()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.news_posts set author_name = 'Verein' where author_id = old.id;
  return old;
end;
$$;
revoke all on function public.newsautor_verein_setzen() from public, anon, authenticated;

drop trigger if exists profiles_news_autor_verein on public.profiles;
create trigger profiles_news_autor_verein
  before delete on public.profiles
  for each row execute function public.newsautor_verein_setzen();

-- Erwartet: texte = 21, ausloeser = 1, sprache_im_rumpf = true.
select
  (select count(*) from public.meldungstexte where schluessel like 'konto.geloescht.%') as texte,
  (select count(*) from pg_trigger where tgrelid = 'public.profiles'::regclass and tgname = 'profiles_news_autor_verein') as ausloeser,
  (select prosrc like '%raw_user_meta_data ->> ''language''%' from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'handle_new_user') as sprache_im_rumpf;
