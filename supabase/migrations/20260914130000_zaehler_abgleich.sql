-- Die Zahl am App-Symbol auf Zuruf der App abgleichen - und die Grenzen dafuer.
--
-- 20260914120000 zieht die Zahl nach, sobald Meldungen gelesen oder geloescht
-- werden. Das hilft nicht, wenn auf dem Symbol noch eine ALTE Zahl steht und
-- es nichts mehr zu lesen gibt: Dann aendert "Alle gelesen" keine Zeile, und
-- nichts stoesst an. Genau so am 14.09.2026 getestet - Glocke leer, Symbol
-- weiter mit Zahl.
--
-- Die Store-Fassung 1.2 kann die Zahl nicht selbst setzen (kein Badge-Plugin).
-- Sie ruft deshalb beim Oeffnen und beim Zurueckkehren in die App
-- app_zaehler_abgleichen(); das schickt ueber push-versenden (type ZAEHLER)
-- eine stille Mitteilung mit der richtigen Zahl an die eigenen iPhones.
--
-- Dazu drei Befunde der Gegenpruefung vor dem Einspielen:
--
-- 1. push_subscriptions.platform sagt nicht, ob das Geraet die App ist. Der
--    Browser-Zweig speichert fuer ein iPhone ebenfalls 'ios' (Web-App auf dem
--    Home-Bildschirm). Eine Mitteilung ohne Text an so ein Geraet zeigt Safari
--    als leeren Hinweis - oder entzieht der Seite die Push-Erlaubnis. Neue
--    Spalte nativ: Die App setzt sie bei jedem Start selbst (ihr Code wird live
--    geladen), der Browser nie. Bestehende Zeilen starten mit false und werden
--    beim naechsten Oeffnen der App richtig.
-- 2. Die Regel "users update own notifications" liess read_at auch zurueck auf
--    null setzen. Hin und her gesetzt, loeste jede Runde einen Versand aus -
--    ohne Grenze. Die App setzt read_at nirgends zurueck; jetzt darf eine
--    eigene Meldung nur noch gelesen sein, wenn sie geaendert wird. Damit
--    stoesst jede Meldung hoechstens einmal an.
-- 3. Der Aufruf der App ist je Konto auf einmal je Minute begrenzt.
--
-- Wie die Trigger: Ein Fehler hier darf die App nie stoeren.

alter table public.push_subscriptions add column if not exists nativ boolean not null default false;

/* 2: Gelesen bleibt gelesen. Die App aendert an einer Meldung nur read_at
   (meldungGelesen); alles andere laeuft ueber security-definer-Funktionen. */
revoke update on public.user_notifications from authenticated;
grant update (read_at) on public.user_notifications to authenticated;

drop policy if exists "users update own notifications" on public.user_notifications;
create policy "users update own notifications" on public.user_notifications
  for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid() and read_at is not null);

/* Und falls es doch jemand versucht: Ein gesetztes read_at bleibt, leise statt
   mit Fehler. Dann ist die Zeile im AFTER-Trigger schon "vorher gelesen" und
   stoesst nichts an. Gilt fuer alle Rollen - nichts im Code setzt eine Meldung
   wieder auf ungelesen. */
create or replace function public.meldung_bleibt_gelesen()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.read_at is not null then new.read_at := old.read_at; end if;
  return new;
end;
$$;
revoke all on function public.meldung_bleibt_gelesen() from public, anon, authenticated;
drop trigger if exists user_notifications_bleibt_gelesen on public.user_notifications;
create trigger user_notifications_bleibt_gelesen
before update of read_at on public.user_notifications
for each row execute function public.meldung_bleibt_gelesen();

/* 1: Der Trigger aus 20260914120000 fragt jetzt nach nativ statt nach platform. */
create or replace function public.push_zaehler_anstossen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_zeile intern.push_zustellung%rowtype;
  v_profile uuid[];
  v_profil uuid;
begin
  select * into v_zeile from intern.push_zustellung where id;
  if not found or not v_zeile.aktiv then return null; end if;

  /* Nur wer dadurch WENIGER Ungelesene hat. plpgsql plant jede Abfrage erst,
     wenn sie laeuft - der Verweis auf "nachher" im UPDATE-Zweig stoert den
     DELETE-Trigger also nicht. */
  if tg_op = 'UPDATE' then
    select array_agg(distinct v.profile_id) into v_profile
      from vorher v join nachher n on n.id = v.id
     where v.read_at is null and n.read_at is not null;
  else
    select array_agg(distinct v.profile_id) into v_profile
      from vorher v
     where v.read_at is null;
  end if;

  for v_profil in
    select u.p from unnest(coalesce(v_profile, '{}'::uuid[])) as u(p)
     where exists (select 1 from public.push_subscriptions ps
                     join public.club_memberships m on m.id = ps.membership_id
                    where m.profile_id = u.p and ps.platform = 'ios' and ps.nativ)
  loop
    perform net.http_post(
      url := v_zeile.ziel_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cmo-signatur', v_zeile.geheimnis
      ),
      body := jsonb_build_object('type', 'ZAEHLER', 'profile_id', v_profil),
      timeout_milliseconds := 30000
    );
  end loop;
  return null;
exception when others then
  raise warning 'Zahl fuer das App-Symbol nicht angestossen: %', sqlerrm;
  return null;
end;
$$;

/* 3: Abgleich auf Zuruf. */
create table if not exists intern.zaehler_abgleich (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  zuletzt    timestamptz not null default now()
);
revoke all on table intern.zaehler_abgleich from public, anon, authenticated;

create or replace function public.app_zaehler_abgleichen()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_ich uuid := auth.uid();
  v_zeile intern.push_zustellung%rowtype;
  v_neu integer;
begin
  if v_ich is null then return false; end if;
  if not exists (select 1 from public.push_subscriptions ps
                   join public.club_memberships m on m.id = ps.membership_id
                  where m.profile_id = v_ich and ps.platform = 'ios' and ps.nativ) then
    return false;
  end if;

  select * into v_zeile from intern.push_zustellung where id;
  if not found or not v_zeile.aktiv then return false; end if;

  /* Die Sperre: Nur wenn der letzte Abgleich laenger als eine Minute her
     ist, wird die Zeile geschrieben - sonst zaehlt row_count 0. */
  insert into intern.zaehler_abgleich as z (profile_id, zuletzt) values (v_ich, now())
  on conflict (profile_id) do update set zuletzt = now()
   where z.zuletzt < now() - interval '1 minute';
  get diagnostics v_neu = row_count;
  if v_neu = 0 then return false; end if;

  perform net.http_post(
    url := v_zeile.ziel_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cmo-signatur', v_zeile.geheimnis
    ),
    body := jsonb_build_object('type', 'ZAEHLER', 'profile_id', v_ich),
    timeout_milliseconds := 30000
  );
  return true;
exception when others then
  raise warning 'Abgleich der Symbol-Zahl nicht angestossen: %', sqlerrm;
  return false;
end;
$$;

revoke all on function public.app_zaehler_abgleichen() from public, anon;
grant execute on function public.app_zaehler_abgleichen() to authenticated;

select
  (select count(*) from pg_proc where proname = 'app_zaehler_abgleichen')                        as funktion,
  (select has_function_privilege('authenticated', 'public.app_zaehler_abgleichen()', 'execute')) as fuer_angemeldete,
  (select has_function_privilege('anon', 'public.app_zaehler_abgleichen()', 'execute'))          as fuer_anonyme,
  (select with_check from pg_policies where tablename = 'user_notifications'
    and policyname = 'users update own notifications')                                           as regel_aendern,
  (select count(*) from information_schema.columns
    where table_name = 'push_subscriptions' and column_name = 'nativ')                           as spalte_nativ;
