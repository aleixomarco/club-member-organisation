-- Ziel im Repo: supabase/migrations/20260927160000_beitritte_nur_vereinsadmin.sql
--
-- Beitrittsanfragen gehen nur noch die Vereinsadministration etwas an.
--
-- WUNSCH DES BETREIBERS (27.09.2026): "die Meldung, dass es eine neue
-- Beitrittsanfrage zum Verein gibt, sollen nur die Vereinsadministratoren
-- bekommen und annehmen/ablehnen koennen und die Entitaet sehen".
--
-- BISHER galt an allen drei Stellen derselbe Dreiersatz
-- ('sysadmin', 'vereinsadmin', 'organisator'):
--   1. beitrittsanfrage_melden schickte die Meldung an alle drei,
--   2. beitritt_entscheiden liess alle drei annehmen und ablehnen,
--   3. die Leseregel auf club_memberships zeigte allen dreien die wartenden
--      Zeilen - und nur ueber diese dritte Stelle ist die Anfrage ueberhaupt
--      sichtbar, denn der erste Zweig der Regel deckt nur 'active' und
--      'inactive' ab.
-- Der Organisator kam 11.09. dazu, als die Aufnahme von allen Mitgliedern auf
-- die Leitung eingeengt wurde. Er ist inzwischen die Rolle fuer Helferdienste
-- und Umfragen; wer in den Verein aufgenommen wird, ist eine andere Frage.
--
-- JETZT ueberall nur noch ('sysadmin', 'vereinsadmin'). sysadmin bleibt aus
-- demselben Grund stehen wie in darfVereinVerwalten: register_new_club gibt
-- dem Gruender eines Vereins beide Rollen zugleich, und ein Verein, dessen
-- einziger Zugang der Gruender ist, koennte sonst niemanden mehr aufnehmen.
--
-- WARUM AUCH DIE LESEREGEL
-- Ohne sie bliebe die Anfrage fuer den Organisator sichtbar - die Oberflaeche
-- verstuende sich dann als hoefliche Bitte, nicht als Regel. Wer die Tabelle
-- direkt abfragt, saehe weiterhin, wer einen Beitritt angefragt hat. "Die
-- Entitaet sehen" ist genau diese Regel.
--
-- Die Regel 'admins manage memberships' (ALL) nennt den Organisator schon
-- heute nicht - er konnte also nie selbst schreiben, sondern nur ueber
-- beitritt_entscheiden, das als security definer laeuft. Deshalb genuegt es,
-- die Funktion einzuengen; an der Schreibregel ist nichts zu tun.
--
-- MUSS ZUSAMMEN MIT DER APP AUSGELIEFERT WERDEN: Die App zeigt dem
-- Organisator sonst weiter die Kachel und den Verwaltungsbereich
-- "Mitgliedsantraege", und beide liefen ins Leere.
--
-- Geprueft am 27.09.2026 (nur lesend, PROD): 0 wartende Anfragen, es geht also
-- keine offene Entscheidung verloren. 6 bereits zugestellte Meldungen der Art
-- 'join_requests' liegen bei Organisatoren ohne Adminrolle - sie fuehren ab
-- jetzt auf einen Bereich, den es fuer sie nicht mehr gibt, und werden unten
-- abgeraeumt.

-- ------------------------------------------------- 1. Wer die Meldung bekommt
create or replace function public.beitrittsanfrage_melden()
returns trigger
language plpgsql security definer set search_path to 'public' as $function$
declare
  v_wer   text;
  v_text  text;
  v_werte jsonb;
begin
  if new.status <> 'pending' then return new; end if;
  /* Nur beim UEBERGANG nach pending, nicht bei jeder Aenderung an einer
     bereits wartenden Zeile - sonst meldet jeder Tippfehler im Namen erneut. */
  if tg_op = 'UPDATE' and old.status = 'pending' then return new; end if;

  v_wer := nullif(btrim(coalesce(new.display_name, '')), '');

  /* Rezept (Stufe B): dieselbe Fallunterscheidung wie bisher, nur als
     Schluessel und Werte festgehalten. */
  v_text  := case when v_wer is null then 'beitritt.anfrage.textOhneName'
                  else 'beitritt.anfrage.text' end;
  v_werte := case when v_wer is null then '{}'::jsonb
                  else jsonb_build_object('wer', v_wer) end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id,
                                         titel_schluessel, text_schluessel, werte, sprache)
  select distinct m.profile_id, new.club_id, 'join_requests',
         public.meldung_rendern('beitritt.anfrage.titel', coalesce(p.language, 'de'), v_werte),
         public.meldung_rendern(v_text, coalesce(p.language, 'de'), v_werte),
         'beitritt', new.id,
         'beitritt.anfrage.titel', v_text, v_werte, coalesce(p.language, 'de')
  from public.club_memberships m
  join public.membership_roles r on r.membership_id = m.id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    /* Nur die Vereinsadministration - siehe Kopf. */
    and r.role in ('vereinsadmin', 'sysadmin')
    and m.id is distinct from new.id
    and public.meldung_erlaubt(m.profile_id, 'join_requests');

  return new;
end;
$function$;

-- ------------------------------------------------- 2. Wer entscheiden darf
create or replace function public.beitritt_entscheiden(target_membership uuid, approve boolean, stufe public.club_role default 'mitglied'::public.club_role, zusatzrollen public.club_role[] default '{}'::public.club_role[])
returns void
language plpgsql security definer set search_path to '' as $function$
declare
  v_club uuid;
  v_status public.membership_status;
  v_team text;
  v_bisher public.club_role[];
  v_neu public.club_role[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select m.club_id, m.status, m.requested_team into v_club, v_status, v_team
    from public.club_memberships m where m.id = target_membership
     for update;
  if v_club is null then raise exception 'Membership request not found'; end if;
  /* Nur die Vereinsadministration - siehe Kopf. */
  if not public.has_club_role(v_club, array['sysadmin', 'vereinsadmin']::public.club_role[]) then
    raise exception 'Not authorized to review join requests' using errcode = 'insufficient_privilege';
  end if;
  if v_status <> 'pending' then raise exception 'This request has already been handled'; end if;

  if not coalesce(approve, false) then
    update public.club_memberships m
       set status = 'inactive',
           rejection_count = coalesce(m.rejection_count, 0) + 1,
           blocked_until = null,
           updated_at = now()
     where m.id = target_membership;
    return;
  end if;

  select coalesce(array_agg(r.role), '{}') into v_bisher
    from public.membership_roles r where r.membership_id = target_membership;
  v_neu := public.rollensatz_bilden(v_club, stufe, zusatzrollen, v_bisher);
  perform public.rollensatz_anwenden(target_membership, v_neu);

  /* Die Mannschaftszuordnung aus der Anfrage - bisher ein zweiter, nicht
     atomarer Aufruf der App nach dem Freigeben. */
  if 'spieler' = any(v_neu) and nullif(trim(v_team), '') is not null then
    insert into public.team_members (team_id, membership_id, function)
    select t.id, target_membership, 'spieler'
      from public.teams t
     where t.club_id = v_club and t.active and t.name = trim(v_team)
    on conflict do nothing;
  end if;

  update public.club_memberships m
     set status = 'active', blocked_until = null, updated_at = now()
   where m.id = target_membership;
end;
$function$;

-- ------------------------------------------------- 3. Wer die Anfrage sieht
drop policy if exists "members read club memberships" on public.club_memberships;
create policy "members read club memberships" on public.club_memberships
  for select using (
    (public.is_club_member(club_id) and status = any (array['active'::public.membership_status, 'inactive'::public.membership_status]))
    or profile_id = (select auth.uid())
    /* Wartende Anfragen sieht nur die Vereinsadministration - siehe Kopf. */
    or public.has_club_role(club_id, array['vereinsadmin'::public.club_role, 'sysadmin'::public.club_role])
  );

-- ------------------------------------------------- 4. Alte Meldungen abraeumen
/* Sie fuehren auf einen Bereich, den es fuer den Organisator ab jetzt nicht
   mehr gibt - eine Glocke, die ins Leere zeigt, ist schlimmer als keine.
   Betroffen sind nur Meldungen der Art 'join_requests' bei Mitgliedern, die
   im selben Verein weder vereinsadmin noch sysadmin sind. */
delete from public.user_notifications n
 where n.kind = 'join_requests'
   and not exists (
     select 1 from public.club_memberships m
      join public.membership_roles r on r.membership_id = m.id
     where m.profile_id = n.profile_id and m.club_id = n.club_id
       and r.role in ('vereinsadmin', 'sysadmin'));

notify pgrst, 'reload schema';

-- -------------------------------------------------------------- Kontrolle
-- Erwartet: melden_ohne_organisator = true, entscheiden_ohne_organisator = true,
-- leseregel_ohne_organisator = true, meldungen_bei_nichtadmins = 0,
-- wartende_anfragen_unberuehrt = 0.
select
  (select pg_get_functiondef(p.oid) not like '%organisator%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'beitrittsanfrage_melden') as melden_ohne_organisator,
  (select pg_get_functiondef(p.oid) not like '%organisator%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'beitritt_entscheiden') as entscheiden_ohne_organisator,
  (select qual not like '%organisator%' from pg_policies
    where schemaname = 'public' and tablename = 'club_memberships'
      and policyname = 'members read club memberships') as leseregel_ohne_organisator,
  (select count(*) from public.user_notifications n
    where n.kind = 'join_requests'
      and not exists (select 1 from public.club_memberships m
                       join public.membership_roles r on r.membership_id = m.id
                      where m.profile_id = n.profile_id and m.club_id = n.club_id
                        and r.role in ('vereinsadmin','sysadmin'))) as meldungen_bei_nichtadmins,
  (select count(*) from public.club_memberships where status = 'pending') as wartende_anfragen_unberuehrt;
