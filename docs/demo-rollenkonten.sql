-- Demo-Zugaenge fuer Vorfuehrungen: je ein Konto pro Rolle im Demo-Verein.
--
-- WOFUER: Um jede Rolle einzeln zu zeigen, braucht es je einen Login. Diese
-- Datei legt im Verein "SV Musterstadt" (Demo, Pro-Tarif) elf Konten an -
-- eines fuer jede Rolle, die es heute noch gibt.
--
-- KEIN PASSWORT IN DIESER DATEI. Die Datei enthaelt den Platzhalter
-- __PASSWORT__. Es wird erst beim Ausfuehren ersetzt, damit kein Geheimnis
-- im Repo landet:
--
--   cd ~/Projekte/club-member-organisation
--   supabase db query --linked "$(sed 's/__PASSWORT__/DEIN-PASSWORT/' docs/demo-rollenkonten.sql)"
--
-- NUR IM DEMO-VEREIN. Die Verein-ID steht fest auf
-- d0000000-0000-4000-a000-000000000001 (SV Musterstadt). ERG Iserlohn wird
-- nicht angefasst.
--
-- ABGESCHAFFTE ROLLEN fehlen bewusst: vorstand, geschaeftsfuehrung,
-- finanzmanager und eltern weist die Datenbank selbst ab
-- (abgeschaffte_rolle_ablehnen) - Vorstand, Geschaeftsfuehrung und
-- Finanzmanager sind im Vereins-Administrator aufgegangen.
--
-- MANNSCHAFTSROLLEN liegen in der U11: Herren 1 und Damen 1 haben bereits
-- eine Trainerin oder einen Trainer, und davon laesst nur_ein_trainer nur
-- eine je Mannschaft zu.
--
-- Ein zweiter Lauf legt nichts doppelt an: Konten, deren Adresse schon
-- existiert, werden uebersprungen.
--
-- WIEDER WEG: docs/demo-rollenkonten-loeschen.sql

do $$
declare
  v_klub uuid := 'd0000000-0000-4000-a000-000000000001';
  v_pw   text := '__PASSWORT__';
  v_team uuid;
  v_user uuid;
  v_mit  uuid;
  v_mail text;
  v_nr   integer := 0;
  r record;
begin
  /* Die Pruefung setzt den Platzhalter aus zwei Stuecken zusammen, damit das
     sed beim Aufruf sie nicht miterwischt. */
  if v_pw = '__PASS' || 'WORT__' or length(v_pw) < 8 then
    raise exception 'Bitte beim Aufruf einen eigenen Wert einsetzen (siehe Kopf der Datei), mindestens acht Zeichen.';
  end if;

  select id into v_team from public.teams where club_id = v_klub and name = 'U11' limit 1;

  for r in
    select * from (values
      ('fan',              'Demo Fan',          'Fan',          null::text),
      ('mitglied',         'Demo Mitglied',     'Mitglied',     null),
      ('spieler',          'Demo Spieler',      'Spieler',      'spieler'),
      ('trainer',          'Demo Trainer',      'Trainer',      'trainer'),
      ('kapitaen',         'Demo Kapitaen',     'Kapitaen',     'spieler'),
      ('teammanager',      'Demo Teammanager',  'Teammanager',  'teammanager'),
      ('organisator',      'Demo Organisation', 'Organisation', null),
      ('vereinsadmin',     'Demo Vereinsadmin', 'Vereinsadmin', null),
      ('sysadmin',         'Demo Sysadmin',     'Sysadmin',     null),
      ('redakteur',        'Demo Redaktion',    'Redaktion',    null),
      ('sponsorenmanager', 'Demo Sponsoren',    'Sponsoren',    null)
    ) as t(rolle, anzeige, nachname, teamfunktion)
  loop
    v_mail := 'demo.' || r.rolle || '@idbranding.de';
    continue when exists (select 1 from auth.users u where u.email = v_mail);

    v_user := gen_random_uuid();

    /* Das Konto. email_confirmed_at ist gesetzt, damit keine Bestaetigungsmail
       noetig ist - an diese Adressen geht ohnehin nichts hinaus. */
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                            email_confirmed_at, created_at, updated_at,
                            raw_app_meta_data, raw_user_meta_data)
    values ('00000000-0000-0000-0000-000000000000', v_user, 'authenticated', 'authenticated',
            v_mail, extensions.crypt(v_pw, extensions.gen_salt('bf')), now(), now(), now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('first_name', 'Demo', 'last_name', r.nachname, 'language', 'de'));

    /* Ohne diese Zeile kennt die Anmeldung das Konto nicht: Der Login sucht
       ueber auth.identities, nicht ueber auth.users. */
    insert into auth.identities (provider_id, user_id, identity_data, provider, created_at, updated_at)
    values (v_user::text, v_user,
            jsonb_build_object('sub', v_user::text, 'email', v_mail,
                               'email_verified', true, 'phone_verified', false),
            'email', now(), now());

    /* Das Profil legt der Ausloeser handle_new_user selbst an; hier kommt nur
       noch die Telefonnummer dazu. Ohne eine hinterlegte Nummer laesst die App
       keine Fahrzeugbuchung zu (hasPhone in VehiclesView), und die Vorfuehrung
       bliebe an dieser Stelle stehen.
       Die Nummern sind erfunden: Der Block 0151 0000 00xx ist nicht vergeben,
       es klingelt also bei niemandem. */
    v_nr := v_nr + 1;
    update public.profiles
       set contact_phones = array['+49 151 000000' || lpad(v_nr::text, 2, '0')]
     where id = v_user;

    insert into public.club_memberships (club_id, profile_id, display_name, status,
                                         is_managed_profile, email, member_since)
    values (v_klub, v_user, r.anzeige, 'active', false, v_mail, 2026)
    returning id into v_mit;

    /* Ein reiner Fan hat genau eine Rolle - fan_exklusiv_pruefen laesst
       nichts anderes daneben zu. Alle uebrigen bekommen mitglied als Sockel
       und darauf die Rolle, die vorgefuehrt werden soll. */
    if r.rolle = 'fan' then
      insert into public.membership_roles (membership_id, role) values (v_mit, 'fan');
    elsif r.rolle = 'mitglied' then
      insert into public.membership_roles (membership_id, role) values (v_mit, 'mitglied');
    else
      insert into public.membership_roles (membership_id, role)
      values (v_mit, 'mitglied'), (v_mit, r.rolle::public.club_role);
    end if;

    if r.teamfunktion is not null and v_team is not null then
      insert into public.team_members (team_id, membership_id, function)
      values (v_team, v_mit, r.teamfunktion::public.club_role);
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------- Kontrolle
select m.display_name                                           as konto,
       m.email                                                  as anmeldung,
       (select string_agg(mr.role::text, ' + ' order by mr.role::text)
          from public.membership_roles mr where mr.membership_id = m.id) as rollen,
       (select count(*) from public.profiles p where p.id = m.profile_id)        as profil,
       (select count(*) from auth.identities i where i.user_id = m.profile_id)   as anmeldbar,
       (select array_to_string(p.contact_phones, ', ') from public.profiles p
         where p.id = m.profile_id)                                              as telefon,
       (select coalesce(string_agg(t.name, ', '), '-') from public.team_members tm
          join public.teams t on t.id = tm.team_id where tm.membership_id = m.id) as mannschaft
  from public.club_memberships m
 where m.club_id = 'd0000000-0000-4000-a000-000000000001'
   and m.email like 'demo.%@idbranding.de'
 order by m.display_name;
