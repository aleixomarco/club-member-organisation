-- Der letzte Vereinsadmin kann sein Konto nicht loeschen, ohne einen
-- Nachfolger zu bestimmen - es sei denn, er ist allein im Verein.
--
-- WARUM ES DAS BRAUCHT
-- Heute prueft beim Loeschen NICHTS. Der einzige Vereinsadmin kann gehen und
-- laesst einen Verein zurueck, den niemand mehr verwalten kann: Rollen
-- vergeben darf nur ein Admin, und register_for_club vergibt die Leitung nur
-- an den ERSTEN Beitretenden. Ein fuehrungsloser Verein ist damit dauerhaft
-- fuehrungslos.
--
-- DIE REGEL
--   Bin ich aktiver Vereinsadmin und bleibt nach meinem Weggang KEIN
--   weiterer aktiver Vereinsadmin mit eigenem Konto uebrig, aber es sind
--   noch andere Nutzer da -> Loeschung abgelehnt.
--   Bin ich der einzige Nutzer mit Konto in diesem Verein -> der Verein wird
--   mitgeloescht, nach ausdruecklicher Bestaetigung.
-- Die Regel vererbt sich von selbst: Sie zaehlt bei jedem Loeschversuch neu.
--
-- ENTSCHEIDUNGEN, DIE ICH GETROFFEN HABE
--
-- Als NACHFOLGER zaehlt nur, wer die Leitung wirklich uebernehmen kann:
-- status 'active', profile_id nicht null, is_managed_profile false, Rolle
-- 'vereinsadmin'. Ein wartendes Mitglied kann sich nicht anmelden; ein
-- verwaltetes Kinderprofil hat gar kein Konto. Beide als Nachfolger zu
-- zaehlen hiesse, einen Verein fuer versorgt zu halten, der es nicht ist.
-- 'sysadmin' zaehlt bewusst NICHT: Das Betreiberkonto sitzt mit dieser Rolle
-- in Kundenvereinen, und ein betriebsfremdes Konto ist keine Vereinsleitung.
--
-- Als weiterer NUTZER zaehlt ebenfalls nur, wer ein eigenes Konto hat.
-- Anders waere ein Verein aus einem Admin und fuenf Kinderprofilen eine
-- Sackgasse: kein Nachfolger ernennbar, Ausnahme greift nicht, Konto nie
-- loeschbar. Das verstoesst gegen die App-Store-Richtlinie 5.1.1(v). Die
-- Kinderprofile gehen mit dem Verein unter; der Dialog nennt sie.
--
-- DIE REIHENFOLGE - UND WARUM SIE SO HERUM IST
-- Erst vormerken, dann das Konto loeschen, dann die Vormerkung ausfuehren.
-- Umgekehrt (erst Verein, dann Konto) waere der Fehlerfall der schlimmste:
-- admin.auth.admin.deleteUser ist ein HTTP-Aufruf und kann NICHT in derselben
-- Transaktion liegen wie das SQL; scheitert er an einem Fremdschluessel - die
-- Route beschreibt genau diesen Fall -, waere der Verein weg und das Konto
-- noch da. So herum bleibt schlimmstenfalls ein leerer Verein stehen, den
-- ein Nachlauf aufraeumt.
--
-- WAS DIE SPERRE NICHT LEISTET
-- Sie sichert die Vorstufe mit ab (Rolle ablegen), aber nicht jeden denkbaren
-- Weg. Wer als letzter Admin seine Mitgliedschaft loescht, kommt weiterhin
-- durch - dafuer braucht es einen eigenen Waechter auf club_memberships, der
-- hier bewusst nicht mit eingebaut ist, um den Eingriff ueberschaubar zu
-- halten.

-- ------------------------------------------------------------ Vormerkungen
create table if not exists public.konto_loeschungen (
  id            uuid primary key default gen_random_uuid(),
  /* BEWUSST ohne Fremdschluessel auf profiles: Die Vormerkung muss die
     Loeschung des Kontos ueberleben - sie wird ja erst danach ausgefuehrt. */
  profile_id    uuid not null,
  club_id       uuid not null,
  club_name     text not null,
  vorgemerkt_am timestamptz not null default now(),
  erledigt_am   timestamptz
);
alter table public.konto_loeschungen enable row level security;
/* Keine Zeilenregel: Nur Funktionen mit Eigentuemerrechten kommen heran. */
create index if not exists konto_loeschungen_offen_idx
  on public.konto_loeschungen (profile_id) where erledigt_am is null;

comment on table public.konto_loeschungen is
  'Vereine, die mit einer Kontoloeschung mit untergehen. Wird vor dem Loeschen des Kontos geschrieben, damit der zweite Schritt auch nach einem Abbruch noch weiss, was zu tun ist.';

-- ------------------------------------------------------------- Die Lage
--
-- Nimmt die Kennung als PARAMETER und benutzt auth.uid() NICHT. Die Route
-- arbeitet mit dem Dienstschluessel; dort ist auth.uid() null, und jede
-- Pruefung ueber has_club_role oder is_club_member liefe ins Leere.
create or replace function public.konto_loeschung_lage(p_profile uuid)
returns table (
  club_id uuid, club_name text,
  ist_admin boolean, andere_admins int, andere_nutzer int,
  verwaltete int, wartende int, aktives_abo boolean)
language sql stable security definer set search_path = 'public' as $$
  select c.id, c.name,
    exists (select 1 from public.membership_roles r
             where r.membership_id = eigen.id and r.role = 'vereinsadmin'),
    (select count(distinct m.profile_id)::int
       from public.club_memberships m
       join public.membership_roles r on r.membership_id = m.id
      where m.club_id = c.id and m.status = 'active'
        and m.profile_id is not null and m.profile_id <> p_profile
        and coalesce(m.is_managed_profile, false) = false
        and r.role = 'vereinsadmin'),
    (select count(*)::int from public.club_memberships m
      where m.club_id = c.id and m.status = 'active'
        and m.profile_id is not null and m.profile_id <> p_profile
        and coalesce(m.is_managed_profile, false) = false),
    (select count(*)::int from public.club_memberships m
      where m.club_id = c.id and (m.profile_id is null or coalesce(m.is_managed_profile, false))),
    (select count(*)::int from public.club_memberships m
      where m.club_id = c.id and m.status <> 'active'
        and m.profile_id is not null and m.profile_id <> p_profile),
    exists (select 1 from public.club_subscriptions s
             where s.club_id = c.id and s.status = 'active')
  from public.club_memberships eigen
  join public.clubs c on c.id = eigen.club_id
  where eigen.profile_id = p_profile and eigen.status = 'active';
$$;

/* Die Bewertung fuer die Oberflaeche. Reine Anzeige - sie wird nie geglaubt,
   die Vormerkung prueft alles noch einmal. */
create or replace function public.konto_loeschung_pruefen(p_profile uuid)
returns jsonb language sql stable security definer set search_path = 'public' as $$
  with l as (select * from public.konto_loeschung_lage(p_profile))
  select jsonb_build_object(
    'erlaubt', not exists (select 1 from l where ist_admin and andere_admins = 0 and andere_nutzer > 0),
    'blockiert', coalesce((select jsonb_agg(jsonb_build_object('id', club_id, 'name', club_name))
                             from l where ist_admin and andere_admins = 0 and andere_nutzer > 0), '[]'::jsonb),
    'vereine_gehen_mit', coalesce((select jsonb_agg(jsonb_build_object(
                             'id', club_id, 'name', club_name,
                             'verwaltete', verwaltete, 'wartende', wartende, 'abo', aktives_abo))
                             from l where andere_nutzer = 0), '[]'::jsonb));
$$;

-- ------------------------------------------------- Vormerken (Schritt eins)
--
-- Prueft unter Sperre und schreibt die Vormerkungen. Die Sperre auf clubs ist
-- der Kern gegen das Rennen: Loeschen die beiden letzten Admins gleichzeitig,
-- sieht sonst jeder den jeweils anderen, beide Pruefungen sagen ja, und der
-- Verein bleibt ohne Leitung zurueck.
create or replace function public.konto_loeschung_vormerken(
  p_profile uuid, p_vereine_bestaetigt boolean default false)
returns jsonb language plpgsql security definer set search_path = 'public' as $$
declare
  v_lage record;
  v_blockiert jsonb := '[]'::jsonb;
  v_mit       jsonb := '[]'::jsonb;
begin
  if p_profile is null then
    return jsonb_build_object('erlaubt', false, 'grund', 'kein_profil');
  end if;

  /* Alle betroffenen Vereine in fester Reihenfolge sperren - sonst koennen
     sich zwei gleichzeitige Loeschungen gegenseitig verklemmen. */
  perform 1 from public.clubs c
   where c.id in (select club_id from public.club_memberships
                   where profile_id = p_profile and status = 'active')
   order by c.id
   for update;

  for v_lage in select * from public.konto_loeschung_lage(p_profile) loop
    if v_lage.ist_admin and v_lage.andere_admins = 0 and v_lage.andere_nutzer > 0 then
      v_blockiert := v_blockiert || jsonb_build_object('id', v_lage.club_id, 'name', v_lage.club_name);
    elsif v_lage.andere_nutzer = 0 then
      v_mit := v_mit || jsonb_build_object('id', v_lage.club_id, 'name', v_lage.club_name,
                                           'verwaltete', v_lage.verwaltete, 'abo', v_lage.aktives_abo);
    end if;
  end loop;

  if jsonb_array_length(v_blockiert) > 0 then
    return jsonb_build_object('erlaubt', false, 'grund', 'letzter_admin', 'blockiert', v_blockiert);
  end if;

  if jsonb_array_length(v_mit) > 0 and not p_vereine_bestaetigt then
    /* Bestaetigung fehlt. Die Einwilligung des Nutzers wird als EINWILLIGUNG
       gewertet, nie als Anweisung: Welche Vereine mitgehen, entscheidet
       ausschliesslich diese Funktion. */
    return jsonb_build_object('erlaubt', false, 'grund', 'verein_geht_mit', 'vereine', v_mit);
  end if;

  /* Spur hinterlassen, SOLANGE es den Verein noch gibt. Danach ist niemand
     mehr da, der sagen koennte, was verschwunden ist. */
  insert into public.konto_loeschungen (profile_id, club_id, club_name)
  select p_profile, (e ->> 'id')::uuid, e ->> 'name'
  from jsonb_array_elements(v_mit) e;

  insert into public.betreiber_protokoll (aktion, club_id, club_name, einzelheiten, herkunft)
  select 'verein_mit_konto_geloescht', (e ->> 'id')::uuid, e ->> 'name',
         jsonb_build_object(
           'profil', p_profile,
           'verwaltete_profile', e -> 'verwaltete',
           'aktives_abo', e -> 'abo',
           'mitgliedschaften', (select count(*) from public.club_memberships m where m.club_id = (e ->> 'id')::uuid),
           'zugangsanfragen', (select count(*) from public.club_access_requests a where a.club_id = (e ->> 'id')::uuid)),
         'kontoloeschung'
  from jsonb_array_elements(v_mit) e;

  return jsonb_build_object('erlaubt', true, 'vereine', v_mit);
end;
$$;

-- ---------------------------------------------- Abschliessen (Schritt zwei)
--
-- Laeuft NACH der Loeschung des Kontos. Die Mitgliedschaften sind ueber die
-- Kaskade bereits weg; hier fallen nur noch die vorgemerkten Vereine. Bewusst
-- wiederholbar: Ein zweiter Aufruf findet nichts Offenes mehr und meldet 0.
create or replace function public.konto_loeschung_abschliessen(p_profile uuid)
returns integer language plpgsql security definer set search_path = 'public' as $$
declare v_anzahl integer := 0;
begin
  with offen as (
    select id, club_id from public.konto_loeschungen
     where profile_id = p_profile and erledigt_am is null
     for update
  ), weg as (
    delete from public.clubs c using offen o where c.id = o.club_id returning c.id
  )
  update public.konto_loeschungen k set erledigt_am = now()
   where k.id in (select id from offen);
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

-- ------------------------------- Die Vorstufe: die eigene Rolle ablegen
--
-- Ohne diesen Waechter ist die ganze Sperre in zwei Schritten umgangen: Die
-- Regel "admins manage roles" gilt FOR ALL, ein Vereinsadmin darf also seine
-- EIGENE Rollenzeile loeschen. Danach ist er kein Admin mehr, die Pruefung
-- findet keinen und winkt durch.
create or replace function public.letzten_vereinsadmin_schuetzen()
returns trigger language plpgsql security definer set search_path = 'public' as $$
declare v_club uuid; v_andere int; v_nutzer int;
begin
  if old.role <> 'vereinsadmin' then return old; end if;

  select club_id into v_club from public.club_memberships where id = old.membership_id;
  if v_club is null then return old; end if;

  select count(distinct m.profile_id) into v_andere
    from public.club_memberships m
    join public.membership_roles r on r.membership_id = m.id
   where m.club_id = v_club and m.status = 'active'
     and m.profile_id is not null and coalesce(m.is_managed_profile, false) = false
     and r.role = 'vereinsadmin' and m.id <> old.membership_id;

  select count(*) into v_nutzer
    from public.club_memberships m
   where m.club_id = v_club and m.status = 'active'
     and m.profile_id is not null and coalesce(m.is_managed_profile, false) = false
     and m.id <> old.membership_id;

  /* Allein im Verein? Dann darf die Rolle fallen - dort gibt es niemanden,
     den man fuehrungslos zuruecklassen koennte. */
  if v_andere = 0 and v_nutzer > 0 then
    raise exception 'letzter_vereinsadmin'
      using hint = 'Bestimme zuerst einen weiteren Vereinsadministrator.';
  end if;
  return old;
end;
$$;

drop trigger if exists membership_roles_letzter_admin on public.membership_roles;
create trigger membership_roles_letzter_admin
  before delete on public.membership_roles
  for each row execute function public.letzten_vereinsadmin_schuetzen();

-- ------------------------------------------------------------------ Rechte
--
-- Postgres vergibt bei jeder neuen Funktion EXECUTE an PUBLIC. Ein Loeschpfad
-- ist die gefaehrlichste Funktion, die man anlegen kann - hier faellt das
-- Recht sofort wieder weg. Genau dieser Fehler ist heute frueh schon einmal
-- passiert (notify_uebersetzt).
revoke execute on function public.konto_loeschung_lage(uuid)              from public, anon, authenticated;
revoke execute on function public.konto_loeschung_vormerken(uuid, boolean) from public, anon, authenticated;
revoke execute on function public.konto_loeschung_abschliessen(uuid)      from public, anon, authenticated;
/* Nur die Vorschau darf der angemeldete Nutzer selbst holen - und auch die
   nur fuer sich, was die Route ohnehin erzwingt. */
revoke execute on function public.konto_loeschung_pruefen(uuid) from public, anon;

grant execute on function public.konto_loeschung_lage(uuid)               to service_role;
grant execute on function public.konto_loeschung_vormerken(uuid, boolean) to service_role;
grant execute on function public.konto_loeschung_abschliessen(uuid)       to service_role;
grant execute on function public.konto_loeschung_pruefen(uuid)            to service_role, authenticated;

-- ---------------------------------------------------------------- Nachweis
select
  (select count(*) from information_schema.tables
    where table_schema='public' and table_name='konto_loeschungen') as vormerktabelle,
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='membership_roles' and t.tgname='membership_roles_letzter_admin') as rollenwaechter,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'konto_loeschung%'
      and has_function_privilege('anon', p.oid, 'EXECUTE')) as fuer_anon_offen;
