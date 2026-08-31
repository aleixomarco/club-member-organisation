-- Höchstens zwei Geräte je Konto.
--
-- Ohne Begrenzung reicht ein Zugang für einen ganzen Verein: Ein Vorstand legt
-- ein Konto an, gibt das Passwort weiter, und dreißig Leute nutzen die App mit
-- drei Zugängen. Die Zahl der Zugänge wäre dann keine Größe mehr, sondern eine
-- Empfehlung.
--
-- Zwei Geräte, weil ein Mensch üblicherweise Telefon und Tablet hat. Der Wert
-- steht bewusst als Konstante in der Funktion und nicht in einer Tabelle: Er
-- gilt für alle gleich, und eine Ausnahme davon wäre eine Absprache, keine
-- Einstellung.
--
-- Durchgesetzt wird nicht durch Abweisen, sondern durch Verdrängen: Das
-- älteste Gerät fliegt heraus, wenn ein drittes dazukommt. Wer sein Telefon
-- wechselt, soll nicht anrufen müssen — er meldet sich einfach an, und das
-- alte Gerät verliert den Zugang.

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  -- Vom Gerät erzeugt und dort gespeichert. Keine Hardwarekennung: Die gibt
  -- iOS gar nicht heraus, und wir wollen sie auch nicht.
  device_id text not null,
  device_name text,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (profile_id, device_id)
);

create index if not exists user_devices_profile_idx on public.user_devices(profile_id, last_seen desc);

alter table public.user_devices enable row level security;

-- Jeder sieht nur seine eigenen Geräte, und nur die eigenen darf er entfernen.
create policy "own devices readable" on public.user_devices
for select to authenticated using (profile_id = auth.uid());

create policy "own devices removable" on public.user_devices
for delete to authenticated using (profile_id = auth.uid());

grant select, delete on public.user_devices to authenticated;
grant all on public.user_devices to service_role;

/* Meldet das Gerät an und sagt, ob es weiterlaufen darf.
 *
 * Rückgabe erlaubt = false heißt: Dieses Gerät wurde verdrängt, die App meldet
 * sich ab. Das passiert nur, wenn zwischenzeitlich woanders angemeldet wurde -
 * der Aufruf selbst verdrängt immer nur ältere, nie sich selbst. */
create or replace function public.geraet_anmelden(kennung text, bezeichnung text default null)
returns table (erlaubt boolean, geraete integer)
language plpgsql security definer set search_path = '' as $$
declare
  grenze constant integer := 2;
  wer uuid := auth.uid();
begin
  if wer is null then raise exception 'Authentication required'; end if;
  if nullif(trim(kennung), '') is null then raise exception 'Geraetekennung fehlt'; end if;

  insert into public.user_devices (profile_id, device_id, device_name)
  values (wer, trim(kennung), nullif(trim(bezeichnung), ''))
  on conflict (profile_id, device_id) do update
    set last_seen = now(),
        device_name = coalesce(excluded.device_name, public.user_devices.device_name);

  -- Alles jenseits der beiden zuletzt gesehenen Geräte entfernen. Das eigene
  -- ist gerade eben gesehen worden und damit immer unter den ersten beiden.
  delete from public.user_devices d
   where d.profile_id = wer
     and d.id not in (
       select d2.id from public.user_devices d2
        where d2.profile_id = wer
        order by d2.last_seen desc
        limit grenze
     );

  return query
    select exists (
      select 1 from public.user_devices d
       where d.profile_id = wer and d.device_id = trim(kennung)
    ),
    (select count(*)::integer from public.user_devices d where d.profile_id = wer);
end;
$$;

grant execute on function public.geraet_anmelden(text, text) to authenticated;

/* Prüft ohne Anmeldung, ob dieses Gerät noch gilt. Die App ruft das beim Start
 * auf: Wurde sie zwischenzeitlich woanders verdrängt, meldet sie sich ab,
 * statt weiterzulaufen, als sei nichts gewesen. */
create or replace function public.geraet_gilt_noch(kennung text)
returns boolean
language sql security definer stable set search_path = '' as $$
  select exists (
    select 1 from public.user_devices d
     where d.profile_id = auth.uid() and d.device_id = trim(kennung)
  );
$$;

grant execute on function public.geraet_gilt_noch(text) to authenticated;
