-- Voraussetzung dafür, dass der 1.2-Nachweis im Chat sichtbar werden kann.
--
-- Das Problem ist kein kosmetisches:
--
-- Richtlinie 1.2 verlangt für nutzergenerierte Inhalte eine Melde- und eine
-- Blockiermöglichkeit. Die App hat beides — aber app/page.tsx:3227 rendert
-- "Melden" und "Blockieren" nur unter FREMDEN Nachrichten (`!mine`). Im
-- gesamten System stand genau eine Chat-Nachricht, im Demo-Verein keine
-- einzige. Der Prüfer öffnet den Chat, sieht eine leere Fläche und kann den
-- geforderten Nachweis nirgends finden — auch dann nicht, wenn er selbst
-- schreibt, denn unter der eigenen Nachricht erscheinen die Knöpfe nicht.
--
-- Dazu kommt: Es gibt keinen vereinsweiten Kanal, weder hier noch im anderen
-- Verein. Die Leseregel (20260825230000_chat_je_mannschaft.sql) gibt einen
-- Mannschaftskanal nur an Mitglieder dieser Mannschaft — ohne Ausnahme für
-- Admins, obwohl die App in app/page.tsx:3037 mit `isAdmin(user) || …`
-- filtert und für Admins alle Kanäle erwartet. Der Prüfzugang ist in genau
-- einer Mannschaft und sieht deshalb genau einen Kanal.
--
-- Was hier NICHT passiert:
--
-- 1. Die Leseregel wird nicht aufgeweicht. Wer welche Chats lesen darf, ist
--    eine Datenschutzentscheidung und nichts, was man vor einer Einreichung
--    nebenbei umstellt.
--
-- 2. Es werden keine Nachrichten eingetragen. Der Verein hat nur zwei echte
--    Profile, beide gehören realen Personen; ihnen Sätze in den Mund zu
--    legen, die sie nie geschrieben haben, wäre eine Fälschung — auch im
--    eigenen Demo-Verein. Ein drittes, erfundenes Profil bräuchte einen von
--    Hand zusammengesetzten Zugang in auth.users, und das ist kurz vor einer
--    Einreichung das Letzte, was in eine Produktionsdatenbank gehört.
--
-- Was hier passiert: Das zweite vorhandene Konto des Vereins wird der
-- Mannschaft zugeordnet, in deren Kanal der Prüfzugang liest. Erst dadurch
-- darf es diesen Kanal überhaupt sehen und darin schreiben. Die eigentlichen
-- Nachrichten schreibt der Betreiber danach selbst in der App — dann stehen
-- dort echte Sätze von einem echten Menschen, und der Prüfer findet unter
-- ihnen "Melden" und "Blockieren".

do $$
declare
  verein constant uuid := 'd0000000-0000-4000-a000-000000000001';
  mannschaft uuid;
  zweites_konto uuid;
  name_zweites text;
begin
  /* Die Mannschaft, in deren Kanal der Prüfzugang liest. */
  select ch.team_id into mannschaft
    from public.channels ch
   where ch.club_id = verein and ch.team_id is not null
     and exists (select 1 from public.team_members tm
                  join public.club_memberships m on m.id = tm.membership_id
                 where tm.team_id = ch.team_id and m.club_id = verein
                   and m.display_name = 'Demo Vereinsadmin')
   limit 1;

  select m.id, m.display_name into zweites_konto, name_zweites
    from public.club_memberships m
   where m.club_id = verein and m.profile_id is not null
     and m.display_name is distinct from 'Demo Vereinsadmin'
   order by m.created_at
   limit 1;

  if mannschaft is null or zweites_konto is null then
    raise notice 'Voraussetzungen fehlen - nichts zu tun.';
    return;
  end if;

  insert into public.team_members (team_id, membership_id, function)
  values (mannschaft, zweites_konto, 'teammanager')
  on conflict do nothing;

  raise notice '% kann jetzt im Mannschaftskanal schreiben.', name_zweites;
end $$;
