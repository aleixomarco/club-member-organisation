-- "Neues Gerät angemeldet" nur noch EINMAL je Anmeldung - nicht je Verein.
--
-- notify_new_device lief bisher in einer Schleife ueber alle aktiven
-- Mitgliedschaften des Kontos. Wer in zehn Vereinen ist, bekam nach einer
-- Anmeldung auf einem neuen Geraet zehn Meldungen in der Glocke und zehn
-- Pushes - fuer ein Ereignis, das das Konto betrifft und keinen Verein.
--
-- Jetzt ist es EINE Kontomeldung ohne Verein (club_id null):
--   * Glocke: Liste, Zaehler und "alle gelesen" nehmen Kontomeldungen in
--     jedem Verein mit. Sie steht also einmal da und ist trotzdem sichtbar,
--     egal in welchem Verein man gerade ist. (Ein erster Entwurf schrieb sie
--     einem einzigen Verein zu - wer meist in einem anderen ist, haette die
--     Sicherheitswarnung nie gesehen.)
--   * Push: push-versenden schickt bei club_id null an die Geraete aller
--     aktiven Mitgliedschaften und fasst doppelte Geraete zusammen - jedes
--     Geraet bekommt genau einen Push, auch wenn es fuer zehn Vereine
--     registriert ist. (Der erste Entwurf erreichte nur die Geraete EINES
--     Vereins.)
--   * Kein Vereinsname vorangestellt - meldung_vereinsname_voranstellen
--     laesst club_id null ohnehin aus.
--
-- Die Einstellung "Sicherheitshinweise" haengt am Profil (meldung_erlaubt),
-- wie bisher. Konten ohne aktive Mitgliedschaft bekommen weiterhin nichts -
-- sie haben keine Glocke, und push-versenden fande kein Geraet.
--
-- Der Ausloeser haengt an auth.sessions: Ein Fehler hier wuerde die Anmeldung
-- selbst scheitern lassen. Deshalb faengt ein eigener Block jeden Fehler beim
-- Melden ab - lieber eine ausgefallene Meldung als ein ausgesperrtes Konto.

create or replace function public.notify_new_device()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare
  computed_hash text;
  is_new boolean;
  v_sprache text;
begin
  computed_hash := md5(coalesce(new.user_agent, '') || '|' || coalesce(host(new.ip), ''));
  select not exists (
    select 1 from public.known_devices where profile_id = new.user_id and device_hash = computed_hash
  ) into is_new;
  insert into public.known_devices (profile_id, device_hash, user_agent, last_seen_at)
  values (new.user_id, computed_hash, new.user_agent, now())
  on conflict (profile_id, device_hash) do update set last_seen_at = now();

  if is_new then
    begin
      if exists (select 1 from public.club_memberships where profile_id = new.user_id and status = 'active')
         and public.meldung_erlaubt(new.user_id, 'security') then
        select coalesce(p.language, 'de') into v_sprache from public.profiles p where p.id = new.user_id;
        v_sprache := coalesce(v_sprache, 'de');
        insert into public.user_notifications (profile_id, club_id, kind, title, body)
        values (new.user_id, null, 'security',
                public.meldungstext('geraet.neu.titel', v_sprache),
                public.meldungstext('geraet.neu.text', v_sprache));
      end if;
    exception when others then
      -- Auch meldung_erlaubt gehoert in diesen Block: Es wandelt die
      -- gespeicherte Einstellung per ::boolean um - ein kaputter Wert wuerde
      -- sonst die Anmeldung selbst abbrechen.
      raise warning 'Geraetemeldung fehlgeschlagen: %', sqlerrm;
    end;
  end if;
  return new;
end;
$$;

-- Glocke: Kontomeldungen (club_id null) zaehlen in jedem Verein mit.
create or replace function public.ungelesene_benachrichtigungen(target_club uuid default null)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.user_notifications n
   where n.profile_id = auth.uid()
     and n.read_at is null
     and (target_club is null or n.club_id = target_club or n.club_id is null);
$$;

create or replace function public.benachrichtigungen_gelesen(target_club uuid default null)
returns integer language sql security definer set search_path = '' as $$
  with erledigt as (
    update public.user_notifications n set read_at = now()
     where n.profile_id = auth.uid() and n.read_at is null
       and (target_club is null or n.club_id = target_club or n.club_id is null)
    returning 1
  )
  select count(*)::integer from erledigt;
$$;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'notify_new_device'
      and p.prosrc not like '%loop%' and p.prosrc like '%null, ''security''%') as geraetemeldung_kontoweit,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('ungelesene_benachrichtigungen', 'benachrichtigungen_gelesen')
      and p.prosrc like '%n.club_id is null%') as glocke_kennt_kontomeldungen,
  (select count(*) from pg_trigger t join pg_proc p on p.oid = t.tgfoid
    where p.proname = 'notify_new_device' and t.tgname = 'on_new_session_check_device') as ausloeser_haengt;
