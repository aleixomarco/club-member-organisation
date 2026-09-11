-- Obergrenze für Nutzerkonten: vorerst höchstens 50.000 auf der ganzen Plattform
--
-- Ist die Grenze erreicht, entsteht kein neues Konto mehr - weder über die
-- Registrierung in der App noch über das Supabase-Dashboard oder die
-- Admin-Schnittstelle. Bestehende Konten bleiben unberührt: Anmelden,
-- Vereinsbeitritt und alles andere geht weiter.
--
-- WARUM IN DER DATENBANK
-- Jedes Konto entsteht als Zeile in auth.users, egal auf welchem Weg. Eine
-- Prüfung nur in der App hielte genau einen dieser Wege auf; der Trigger hier
-- hält alle auf. Die App fragt erst nach einem Fehler nach, ob es die Grenze
-- war - GoTrue meldet die Sperre selbst bloß als "Database error saving new
-- user" - und zeigt dann einen verständlichen Satz.
--
-- GEZÄHLT wird jedes nicht gelöschte Konto in auth.users, bestätigt oder
-- nicht. Ein gelöschtes Konto gibt seinen Platz frei.
--
-- GLEICHZEITIGE Registrierungen: In den letzten 100 Plätzen reiht ein
-- Advisory-Lock die Prüfung ein. Ohne ihn sähen zwei Anmeldungen bei 49.999
-- beide "noch Platz" und kämen beide durch. Die zweite Zählung ist ein eigener
-- Befehl nach dem Lock und sieht, was der Vorgänger eben festgeschrieben hat.
-- Weiter unten bleibt der Lock weg: Er gilt bis zum Ende der Transaktion von
-- GoTrue, und die schließt den Versand der Bestätigungsmail ein. Immer
-- gesperrt, liefe jede Registrierung hinter der Mail der vorigen her, und ein
-- Schwung Anmeldungen - ein Verein verschickt seinen Einladungslink - belegte
-- die wenigen Datenbankverbindungen von GoTrue, auch die für Anmeldungen.
--
-- ANHEBEN (eine Zeile im SQL-Editor):
--   update public.plattform_grenzen set konten_obergrenze = 100000, geaendert_am = now() where id;
-- Stand abfragen:
--   select (select count(*) from auth.users where deleted_at is null) as belegt, public.konten_obergrenze() as grenze;

create table if not exists public.plattform_grenzen (
  id boolean primary key default true check (id),
  konten_obergrenze integer not null default 50000 check (konten_obergrenze > 0),
  geaendert_am timestamptz not null default now()
);

comment on table public.plattform_grenzen is
  'Genau eine Zeile: plattformweite Grenzen. Nur für den Betreiber (SQL-Editor, Dienstschlüssel).';

insert into public.plattform_grenzen (id, konten_obergrenze)
values (true, 50000)
on conflict (id) do nothing;

-- Keine Policy: Für App-Nutzer ist die Tabelle unsichtbar.
alter table public.plattform_grenzen enable row level security;
revoke all on public.plattform_grenzen from anon, authenticated;

create or replace function public.konten_obergrenze()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  -- Fehlt die Zeile, gilt 50.000: Eine gelöschte Einstellung darf weder alle
  -- Registrierungen sperren noch die Grenze stillschweigend aufheben.
  select coalesce((select g.konten_obergrenze from public.plattform_grenzen g where g.id), 50000);
$$;

create or replace function public.konten_obergrenze_pruefen()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grenze integer;
  v_belegt bigint;
begin
  v_grenze := public.konten_obergrenze();
  select count(*) into v_belegt from auth.users u where u.deleted_at is null;
  if v_belegt >= v_grenze - 100 then
    perform pg_advisory_xact_lock(hashtext('cmo.konten_obergrenze'));
    select count(*) into v_belegt from auth.users u where u.deleted_at is null;
  end if;
  if v_belegt >= v_grenze then
    raise exception 'konten_obergrenze_erreicht'
      using detail = format('%s von %s Konten belegt', v_belegt, v_grenze),
            hint = 'Grenze in public.plattform_grenzen anheben.';
  end if;
  return new;
end;
$$;

drop trigger if exists konten_obergrenze on auth.users;
create trigger konten_obergrenze
  before insert on auth.users
  for each row execute function public.konten_obergrenze_pruefen();

-- Für die App, wenn eine Registrierung scheitert: Ist noch Platz? Nur ja oder
-- nein - wie viele Konten es gibt, geht außerhalb des Betreibers niemanden
-- etwas an.
create or replace function public.registrierung_moeglich()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select count(*) from auth.users u where u.deleted_at is null) < public.konten_obergrenze();
$$;

-- Supabase gibt neuen Funktionen in public automatisch Ausführungsrechte für
-- anon und authenticated. Hier nur die eine, die die App wirklich braucht.
revoke all on function public.konten_obergrenze() from public, anon, authenticated;
revoke all on function public.konten_obergrenze_pruefen() from public, anon, authenticated;
revoke all on function public.registrierung_moeglich() from public;
grant execute on function public.registrierung_moeglich() to anon, authenticated;
