-- Vor- und Nachname schon beim Anlegen des Kontos
--
-- Bisher legte handle_new_user() nur full_name an. Die Spalten first_name und
-- last_name gibt es seit 20260802090000 - befüllt wurden sie aber erst, wenn
-- jemand später im Profil auf "Persönliche Daten" ging. Bis dahin stand in der
-- App nur das, was die Registrierung als einen Namen mitgab.
--
-- In der Praxis führte das zu Begrüßungen wie "Hallo marcoaleixo004": Blieb das
-- Namensfeld leer, fiel der Code auf den Teil der E-Mail vor dem @ zurück, und
-- der Vorname wurde daraus geraten - name.split(" ")[0].
--
-- Ab jetzt nimmt der Trigger beide Namen aus den Kontodaten entgegen. Der
-- Rückfall auf full_name bleibt, damit ältere Registrierungswege weiter
-- funktionieren.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_vorname  text := nullif(trim(new.raw_user_meta_data ->> 'first_name'), '');
  v_nachname text := nullif(trim(new.raw_user_meta_data ->> 'last_name'), '');
  v_voll     text := nullif(trim(new.raw_user_meta_data ->> 'full_name'), '');
begin
  /* Kommt nur ein voller Name herein, wird er geteilt: alles vor dem ersten
     Leerzeichen ist der Vorname, der Rest der Nachname. Das ist eine Naeherung
     und bei Doppelnamen nicht immer richtig - aber besser als gar nichts, und
     im Profil laesst es sich jederzeit richtigstellen. */
  if v_vorname is null and v_voll is not null then
    v_vorname  := split_part(v_voll, ' ', 1);
    v_nachname := nullif(trim(substr(v_voll, length(split_part(v_voll, ' ', 1)) + 1)), '');
  end if;

  insert into public.profiles (id, full_name, first_name, last_name)
  values (
    new.id,
    coalesce(v_voll, trim(coalesce(v_vorname, '') || ' ' || coalesce(v_nachname, '')), ''),
    v_vorname,
    v_nachname
  );
  return new;
end;
$$;

-- Bestehende Profile nachziehen, bei denen der Vorname fehlt, der volle Name
-- aber da ist. Aendert nichts an bereits gepflegten Datensaetzen.
update public.profiles
   set first_name = split_part(full_name, ' ', 1),
       last_name  = nullif(trim(substr(full_name, length(split_part(full_name, ' ', 1)) + 1)), '')
 where coalesce(trim(first_name), '') = ''
   and coalesce(trim(full_name), '') <> '';

select id, full_name, first_name, last_name from public.profiles;
