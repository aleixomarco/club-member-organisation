/* Wohnort aus der Registrierung in profiles schreiben.
 *
 * Die Spalten street, postal_code, city und country_code gibt es in profiles
 * laengst - gefuellt wurden sie bisher nur im Profil, also NACH der
 * Registrierung. Das Registrierungsformular fragt Land, Postleitzahl und Ort
 * jetzt gleich ab; hier landen sie.
 *
 * WARUM IM TRIGGER UND NICHT IM CLIENT
 * Zwischen supabase.auth.signUp() und der ersten Anmeldung liegt der Klick in
 * der Bestaetigungsmail. Solange der nicht erfolgt ist, gibt es keine Sitzung -
 * und ohne Sitzung kein Recht, in profiles zu schreiben. Ein Nachtrag durch
 * die App koennte also fruehestens beim ersten Anmelden passieren, und ob der
 * Nutzer dann noch dieselbe Sitzung im Browser hat, ist reine Hoffnung.
 * handle_new_user() laeuft dagegen im selben Moment, in dem das Konto
 * entsteht, und sieht die Angaben in raw_user_meta_data.
 *
 * Der Rest der Funktion bleibt unveraendert - insbesondere das Aufteilen des
 * vollen Namens, wenn Vor- und Nachname nicht getrennt ankommen.
 */

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vorname  text := nullif(trim(new.raw_user_meta_data ->> 'first_name'), '');
  v_nachname text := nullif(trim(new.raw_user_meta_data ->> 'last_name'), '');
  v_voll     text := nullif(trim(new.raw_user_meta_data ->> 'full_name'), '');
  v_land     text := upper(nullif(trim(new.raw_user_meta_data ->> 'country_code'), ''));
  v_plz      text := nullif(trim(new.raw_user_meta_data ->> 'postal_code'), '');
  v_ort      text := nullif(trim(new.raw_user_meta_data ->> 'city'), '');
begin
  /* Kommt nur ein voller Name herein, wird er geteilt: alles vor dem ersten
     Leerzeichen ist der Vorname, der Rest der Nachname. Das ist eine Naeherung
     und bei Doppelnamen nicht immer richtig - aber besser als gar nichts, und
     im Profil laesst es sich jederzeit richtigstellen. */
  if v_vorname is null and v_voll is not null then
    v_vorname  := split_part(v_voll, ' ', 1);
    v_nachname := nullif(trim(substr(v_voll, length(split_part(v_voll, ' ', 1)) + 1)), '');
  end if;

  /* Das Land nur uebernehmen, wenn es wie ein Laendercode aussieht. Der Wert
     kommt aus Nutzereingaben in den Kontodaten und ist an dieser Stelle noch
     ungeprueft; profiles.country_code soll aber ein ISO-Code sein und keine
     beliebige Zeichenkette, damit die Auswertung im Verein sich darauf
     verlassen kann. */
  if v_land is not null and v_land !~ '^[A-Z]{2}$' then
    v_land := null;
  end if;

  insert into public.profiles (id, full_name, first_name, last_name, country_code, postal_code, city)
  values (
    new.id,
    coalesce(v_voll, trim(coalesce(v_vorname, '') || ' ' || coalesce(v_nachname, '')), ''),
    v_vorname,
    v_nachname,
    v_land,
    left(v_plz, 20),
    left(v_ort, 120)
  );
  return new;
end;
$$;

/* Der Trigger selbst bleibt, wie er ist - create or replace function ersetzt
   nur den Rumpf. Zur Sicherheit trotzdem festhalten, dass er existiert:
   Ohne ihn entstuende zu einem neuen Konto ueberhaupt kein Profil, und das
   waere ein stiller Totalausfall der Registrierung. */
do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'on_auth_user_created' and not tgisinternal
  ) then
    raise exception 'Trigger on_auth_user_created fehlt - handle_new_user() wird nicht aufgerufen';
  end if;
end $$;
