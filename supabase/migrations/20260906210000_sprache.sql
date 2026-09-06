-- Sprache je Konto.
--
-- Die App ist bisher durchgehend deutsch - Beschriftungen, Fehlermeldungen und
-- die Texte der Push-Benachrichtigungen. Das aendert sich in Schritten; diese
-- Migration legt die Grundlage: WO die Wahl steht.
--
-- Am PROFIL, nicht an der Mitgliedschaft: Die Sprache gehoert zum Menschen,
-- nicht zu seinem Verein. Wer in zwei Vereinen ist, will nicht in einem
-- Deutsch und im anderen Portugiesisch lesen.
--
-- Voreinstellung bleibt Deutsch. Bestehende Konten aendern sich damit nicht -
-- niemand findet die App morgen auf Tuerkisch vor.

alter table public.profiles
  add column if not exists language text not null default 'de';

do $$ begin
  alter table public.profiles
    add constraint profiles_language_check
    check (language in ('de','en','es','pt','it','tr','fr'));
exception when duplicate_object then null; end $$;

/* Die eigene Sprache setzen darf jeder fuer sich - mehr nicht. */
create or replace function public.sprache_setzen(neue_sprache text)
returns text language plpgsql security definer set search_path = 'public' as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if neue_sprache not in ('de','en','es','pt','it','tr','fr') then
    raise exception 'Unsupported language';
  end if;
  update public.profiles set language = neue_sprache where id = auth.uid();
  return neue_sprache;
end;
$$;

grant execute on function public.sprache_setzen(text) to authenticated, service_role;

select column_name, column_default from information_schema.columns
 where table_schema='public' and table_name='profiles' and column_name='language';
