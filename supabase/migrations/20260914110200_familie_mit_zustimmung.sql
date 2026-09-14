-- Familienverknuepfungen nur mit Zustimmung (Betreiberentscheidung 13.09.2026, B2).
--
-- Bisher legte create_family_link jede Verknuepfung sofort gueltig an - wer
-- sich selbst zum Elternteil eines beliebigen Mitglieds erklaerte, las danach
-- den Mannschaftschat des "Kindes", stimmte in dessen Abstimmungen ab und
-- bekam seine Termine in den Kalender. Die Einfuege-Regel
-- "users create own family links" pruefte nicht einmal, ob die andere
-- Mitgliedschaft zum selben Verein gehoert.
--
-- Neu:
-- - family_links.bestaetigt (Voreinstellung false), bestaetigt_von,
--   bestaetigt_am, angefragt_von (die anfragende Mitgliedschaft).
-- - create_family_link legt unbestaetigt an; beide Seiten muessen im
--   Zielverein stehen.
-- - family_link_bestaetigen / family_link_ablehnen: die Inhaberin der ANDEREN
--   Mitgliedschaft - oder die Vereinsleitung (vereinsadmin, sysadmin,
--   organisator), wenn die andere Seite ein Kinderprofil ohne Konto ist.
-- - create_managed_child legt die Verknuepfung zum eigenen Kinderprofil
--   bestaetigt an (die Eltern legen das Kind selbst an).
-- - Zugriff gibt nur eine bestaetigte Verknuepfung: gehoert_zu_mannschaft
--   (und damit darf_kanal_sehen, Kanal- und Nachrichtenregeln,
--   abstimmung_stimmen), chatnachricht_melden (20260914110300), der
--   Kalender-Feed und die App. notify_event_audience kennt auf PROD keine
--   Familienverknuepfungen (pg_get_functiondef 14.09.2026) - nichts zu tun.
-- - Die Einfuege-Regel faellt; geschrieben wird nur noch ueber die Funktionen.
-- - Die einzige bestehende Verknuepfung auf PROD (Typ eltern) gilt als
--   bestaetigt.
--
-- Alle Rumpfe aus PROD (pg_get_functiondef, 14.09.2026), Suchpfad jetzt leer.

-- ------------------------------------------------------------------ Spalten
do $$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'family_links'
                    and column_name = 'bestaetigt') then
    alter table public.family_links
      add column bestaetigt boolean not null default false,
      add column bestaetigt_von uuid references public.profiles(id) on delete set null,
      add column bestaetigt_am timestamptz,
      add column angefragt_von uuid;
    -- Nur beim ersten Lauf: Der Bestand galt schon, er bleibt gueltig.
    update public.family_links
       set bestaetigt = true, bestaetigt_am = coalesce(created_at, now());
  end if;
end $$;

comment on column public.family_links.bestaetigt is
  'Erst true gibt Zugriff (Mannschaftschat, Abstimmungen, Meldungen, Kalender). Setzen nur family_link_bestaetigen und create_managed_child.';
comment on column public.family_links.angefragt_von is
  'Die Mitgliedschaft, von der die Anfrage ausging. Bestaetigen muss die andere Seite.';

-- ------------------------------------------------------------------ Regeln
-- Bisher: "users create own family links" INSERT to public
--   with check (is_club_member(club_id) and exists (club_memberships m
--               where m.id in (first, second) and m.profile_id = auth.uid()))
drop policy if exists "users create own family links" on public.family_links;

-- Bisher: "family members read links" SELECT to public
--   using (is_club_member(club_id) and (eigene Seite or has_club_role(club_id, sysadmin/vereinsadmin)))
-- Neu: organisator gehoert zur Leitung und bestaetigt Anfragen an
-- Kinderprofile; offene Anfragen sehen beide Seiten.
drop policy if exists "family members read links" on public.family_links;
create policy "family members read links" on public.family_links
  for select to authenticated
  using (public.is_club_member(club_id) and (
    exists (select 1 from public.club_memberships m
             where m.id = any(array[family_links.first_membership_id, family_links.second_membership_id])
               and m.profile_id = (select auth.uid()))
    or public.has_club_role(club_id, array['sysadmin','vereinsadmin','organisator']::public.club_role[])));

-- ------------------------------------------------------------------ Zugehoerigkeit
create or replace function public.gehoert_zu_mannschaft(target_team uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  with meine as (
    select m.id from public.club_memberships m
    where m.profile_id = auth.uid() and m.status = 'active'
  ),
  kinder as (
    select case
             when f.first_membership_id in (select id from meine) and f.first_to_second = 'eltern'
               then f.second_membership_id
             when f.second_membership_id in (select id from meine) and f.second_to_first = 'eltern'
               then f.first_membership_id
           end as id
    from public.family_links f
    where f.bestaetigt
  )
  select exists (
    select 1 from public.team_members tm
    where tm.team_id = target_team
      and (tm.membership_id in (select id from meine)
           or tm.membership_id in (select id from kinder where id is not null))
  );
$$;

-- ------------------------------------------------------------------ Anlegen
create or replace function public.create_family_link(target_club uuid, acting_membership uuid, related_membership uuid, acting_relation public.family_relation, acting_label text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  acting_is_owner boolean;
  acting_is_sysadmin boolean;
  opposite_relation public.family_relation;
  first_id uuid;
  second_id uuid;
  first_relation public.family_relation;
  second_relation public.family_relation;
  first_lab text;
  second_lab text;
  result_id uuid;
begin
  if auth.uid() is null or acting_membership is null or related_membership is null
     or acting_membership = related_membership then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  select exists (
    select 1 from public.club_memberships m
    where m.id = acting_membership and m.club_id = target_club
      and m.profile_id = auth.uid() and m.status = 'active'
  ) into acting_is_owner;
  /* Der Sysadmin handelt fuer eine Mitgliedschaft DIESES Vereins - nicht fuer
     eine beliebige Kennung. */
  select public.has_club_role(target_club, array['sysadmin']::public.club_role[])
         and exists (select 1 from public.club_memberships m
                      where m.id = acting_membership and m.club_id = target_club)
    into acting_is_sysadmin;

  if not acting_is_owner and not acting_is_sysadmin then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.club_memberships m
    where m.id = related_membership and m.club_id = target_club and m.status in ('active', 'pending')
  ) then raise exception 'Related membership not found'; end if;

  opposite_relation := case acting_relation
    when 'eltern' then 'kind'::public.family_relation
    when 'kind' then 'eltern'::public.family_relation
    when 'partner' then 'partner'::public.family_relation
    when 'grosseltern' then 'kind'::public.family_relation
    else 'sonstige'::public.family_relation
  end;

  if acting_label is not null and acting_label not in ('vater','mutter','sohn','tochter','opa','oma') then
    acting_label := null;
  end if;

  /* Reihenfolge als TEXT, wortgleich zum Original - sonst landete dasselbe
     Paar in einer zweiten Zeile. */
  if acting_membership::text < related_membership::text then
    first_id := acting_membership;  second_id := related_membership;
    first_relation := acting_relation; second_relation := opposite_relation;
    first_lab := acting_label; second_lab := null;
  else
    first_id := related_membership; second_id := acting_membership;
    first_relation := opposite_relation; second_relation := acting_relation;
    first_lab := null; second_lab := acting_label;
  end if;

  insert into public.family_links (club_id, first_membership_id, second_membership_id,
      first_to_second, second_to_first, first_label, second_label, created_by,
      bestaetigt, angefragt_von)
  values (target_club, first_id, second_id, first_relation, second_relation,
      first_lab, second_lab, auth.uid(), false, acting_membership)
  on conflict (club_id, first_membership_id, second_membership_id) do update
    set first_to_second = excluded.first_to_second,
        second_to_first = excluded.second_to_first,
        first_label = coalesce(excluded.first_label, family_links.first_label),
        second_label = coalesce(excluded.second_label, family_links.second_label),
        /* Gleicher Grad: Die Zustimmung bleibt, wie sie ist. Anderer Grad:
           Die andere Seite muss erneut zustimmen. */
        bestaetigt = family_links.bestaetigt
          and family_links.first_to_second = excluded.first_to_second
          and family_links.second_to_first = excluded.second_to_first,
        bestaetigt_von = case when family_links.first_to_second = excluded.first_to_second
                               and family_links.second_to_first = excluded.second_to_first
                              then family_links.bestaetigt_von end,
        bestaetigt_am = case when family_links.first_to_second = excluded.first_to_second
                              and family_links.second_to_first = excluded.second_to_first
                             then family_links.bestaetigt_am end,
        angefragt_von = case when family_links.first_to_second = excluded.first_to_second
                              and family_links.second_to_first = excluded.second_to_first
                             then coalesce(family_links.angefragt_von, excluded.angefragt_von)
                             else excluded.angefragt_von end
  returning id into result_id;

  return result_id;
end;
$$;
revoke all on function public.create_family_link(uuid, uuid, uuid, public.family_relation, text) from public, anon;
grant execute on function public.create_family_link(uuid, uuid, uuid, public.family_relation, text) to authenticated;

-- Die Eltern legen das Kinderprofil selbst an - diese Verknuepfung gilt sofort.
create or replace function public.create_managed_child(target_club uuid, parent_membership uuid, child_name text, child_birthdate date default null, child_team text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  parent_is_owner boolean;
  child_id uuid;
  team_id uuid;
  link_id uuid;
begin
  if auth.uid() is null or nullif(trim(child_name), '') is null then raise exception 'Invalid child profile'; end if;
  select exists (
    select 1 from public.club_memberships m
    where m.id = parent_membership and m.club_id = target_club and m.profile_id = auth.uid() and m.status = 'active'
  ) into parent_is_owner;
  if not parent_is_owner and not (
       public.has_club_role(target_club, array['sysadmin']::public.club_role[])
       and exists (select 1 from public.club_memberships m
                    where m.id = parent_membership and m.club_id = target_club and m.status = 'active')) then
    raise exception 'Not authorized';
  end if;

  insert into public.club_memberships (
    club_id, profile_id, display_name, member_since, status, is_managed_profile, created_by
  ) values (
    target_club, null, trim(child_name), extract(year from current_date)::integer, 'active', true, auth.uid()
  ) returning id into child_id;

  insert into public.membership_roles (membership_id, role, granted_by)
  values (child_id, 'mitglied', auth.uid()), (child_id, 'spieler', auth.uid());

  if nullif(trim(child_team), '') is not null then
    select id into team_id from public.teams where club_id = target_club and name = trim(child_team) and active limit 1;
    if team_id is not null then
      insert into public.team_members (team_id, membership_id, function) values (team_id, child_id, 'spieler');
    end if;
  end if;

  /* Gleiche Ordnung wie create_family_link (als Text); der Elternteil ist
     'eltern', das Kind 'kind'. */
  if parent_membership::text < child_id::text then
    insert into public.family_links (club_id, first_membership_id, second_membership_id,
        first_to_second, second_to_first, created_by, bestaetigt, bestaetigt_von, bestaetigt_am, angefragt_von)
    values (target_club, parent_membership, child_id, 'eltern', 'kind', auth.uid(), true, auth.uid(), now(), parent_membership)
    returning id into link_id;
  else
    insert into public.family_links (club_id, first_membership_id, second_membership_id,
        first_to_second, second_to_first, created_by, bestaetigt, bestaetigt_von, bestaetigt_am, angefragt_von)
    values (target_club, child_id, parent_membership, 'kind', 'eltern', auth.uid(), true, auth.uid(), now(), parent_membership)
    returning id into link_id;
  end if;

  return jsonb_build_object('membership_id', child_id, 'family_link_id', link_id, 'birthdate', child_birthdate);
end;
$$;

-- ------------------------------------------------------------------ Entscheiden
-- Wer ueber eine offene Anfrage entscheidet: die Inhaberin der Gegenseite -
-- oder die Leitung, wenn die Gegenseite ein Kinderprofil ohne Konto ist.
create or replace function public.darf_familienanfrage_entscheiden(target_link uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from public.family_links f
      join public.club_memberships o
        on o.id = case when f.angefragt_von = f.first_membership_id then f.second_membership_id
                       when f.angefragt_von = f.second_membership_id then f.first_membership_id end
     where f.id = target_link
       and not f.bestaetigt
       and o.club_id = f.club_id
       /* Wer die Anfrage angelegt hat, bestaetigt sie nie selbst - sonst
          machte sich ein Sysadmin ohne Zustimmung zum Elternteil (Durchsicht). */
       and f.created_by is distinct from auth.uid()
       and ((o.profile_id = auth.uid() and o.status = 'active')
            or (o.profile_id is null and coalesce(o.is_managed_profile, false)
                and public.has_club_role(f.club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[]))));
$$;
revoke all on function public.darf_familienanfrage_entscheiden(uuid) from public, anon, authenticated;

create or replace function public.family_link_bestaetigen(target_link uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not authorized' using errcode = '42501'; end if;
  perform 1 from public.family_links where id = target_link for update;
  if not found then raise exception 'Family link not found' using errcode = 'P0002'; end if;
  if not public.darf_familienanfrage_entscheiden(target_link) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  update public.family_links
     set bestaetigt = true, bestaetigt_von = auth.uid(), bestaetigt_am = now()
   where id = target_link;
end;
$$;
revoke all on function public.family_link_bestaetigen(uuid) from public, anon;
grant execute on function public.family_link_bestaetigen(uuid) to authenticated;

create or replace function public.family_link_ablehnen(target_link uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Not authorized' using errcode = '42501'; end if;
  perform 1 from public.family_links where id = target_link for update;
  if not found then return; end if;
  if not public.darf_familienanfrage_entscheiden(target_link) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  delete from public.family_links where id = target_link;
end;
$$;
revoke all on function public.family_link_ablehnen(uuid) from public, anon;
grant execute on function public.family_link_ablehnen(uuid) to authenticated;

-- ------------------------------------------------------------------ Meldung
-- Bisher meldete jede neue Verknuepfung beiden Seiten "wurde fuer dich
-- hinterlegt". Jetzt: Eine Anfrage geht an die Seite, die zustimmen muss -
-- bei einem Kinderprofil ohne Konto an die Leitung, mit Sprung zum Mitglied.
-- Bestaetigt angelegte Verknuepfungen (Kinderprofil) melden wie bisher.
create or replace function public.notify_family_link_created()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_andere uuid;
  v_profil uuid;
  v_wer    text;
begin
  if new.bestaetigt then
    perform public.notify_uebersetzt(new.first_membership_id,  'family', 'familie.titel', 'familie.text',
      '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
    perform public.notify_uebersetzt(new.second_membership_id, 'family', 'familie.titel', 'familie.text',
      '{}'::jsonb, jsonb_build_object('ziel_art', 'familie'));
    return new;
  end if;

  v_andere := case when new.angefragt_von = new.first_membership_id then new.second_membership_id
                   else new.first_membership_id end;
  select m.profile_id into v_profil from public.club_memberships m where m.id = v_andere;
  select m.display_name into v_wer from public.club_memberships m where m.id = new.angefragt_von;

  if v_profil is not null then
    perform public.notify_uebersetzt(v_andere, 'family', 'familie.anfrage.titel', 'familie.anfrage.text',
      jsonb_build_object('wer', coalesce(v_wer,
        public.meldungstext('allg.jemand', public.sprache_der_mitgliedschaft(v_andere)))),
      jsonb_build_object('ziel_art', 'familie'));
  else
    insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
    select distinct m.profile_id, new.club_id, 'family',
           public.meldungstext('familie.anfrage.titel', p.language),
           public.meldungstext('familie.anfrage.text', p.language,
             jsonb_build_object('wer', coalesce(v_wer, public.meldungstext('allg.jemand', p.language)))),
           'mitglied', v_andere
      from public.membership_roles r
      join public.club_memberships m on m.id = r.membership_id
      left join public.profiles p on p.id = m.profile_id
     where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
       and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
       and m.profile_id is distinct from auth.uid()
       and public.meldung_erlaubt(m.profile_id, 'family');
  end if;
  return new;
exception when others then
  raise warning 'Familienmeldung fehlgeschlagen: %', sqlerrm;
  return new;
end;
$$;

insert into public.meldungstexte (schluessel, sprache, text) values
  ('familie.anfrage.titel', 'de', 'Familienverknüpfung bestätigen'),
  ('familie.anfrage.titel', 'en', 'Confirm family link'),
  ('familie.anfrage.titel', 'es', 'Confirmar vínculo familiar'),
  ('familie.anfrage.titel', 'pt', 'Confirmar ligação familiar'),
  ('familie.anfrage.titel', 'it', 'Conferma collegamento familiare'),
  ('familie.anfrage.titel', 'tr', 'Aile bağlantısını onayla'),
  ('familie.anfrage.titel', 'fr', 'Confirmer le lien familial'),
  ('familie.anfrage.text', 'de', '{wer} möchte eine Familienverknüpfung anlegen. Bitte bestätigen oder ablehnen.'),
  ('familie.anfrage.text', 'en', '{wer} would like to create a family link. Please confirm or decline.'),
  ('familie.anfrage.text', 'es', '{wer} quiere crear un vínculo familiar. Confírmalo o recházalo.'),
  ('familie.anfrage.text', 'pt', '{wer} quer criar uma ligação familiar. Confirma ou recusa, por favor.'),
  ('familie.anfrage.text', 'it', '{wer} vuole creare un collegamento familiare. Confermalo o rifiutalo.'),
  ('familie.anfrage.text', 'tr', '{wer} bir aile bağlantısı oluşturmak istiyor. Lütfen onayla veya reddet.'),
  ('familie.anfrage.text', 'fr', '{wer} souhaite créer un lien familial. Merci de confirmer ou de refuser.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- Erwartet: offene = 0 (der Bestand ist bestaetigt), einfuegeregel = 0,
-- bestaetigen_ausfuehrbar = true, pruefer_offen = false, texte = 14.
select
  (select count(*) from public.family_links where not bestaetigt) as offene,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'family_links' and cmd = 'INSERT') as einfuegeregel,
  has_function_privilege('authenticated', 'public.family_link_bestaetigen(uuid)', 'execute') as bestaetigen_ausfuehrbar,
  has_function_privilege('authenticated', 'public.darf_familienanfrage_entscheiden(uuid)', 'execute') as pruefer_offen,
  (select count(*) from public.meldungstexte where schluessel like 'familie.anfrage.%') as texte;
