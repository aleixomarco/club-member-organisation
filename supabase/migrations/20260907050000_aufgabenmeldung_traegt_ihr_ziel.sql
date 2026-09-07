-- Die Aufgabenmeldung weiss jetzt, welche Aufgabe sie meint.
--
-- WAS MAN SIEHT
-- In der Glocke steht "Eine neue Aufgabe wurde erstellt. ERG Iserlohn: Test ·
-- bis 07.09.2026". Man tippt darauf - und nichts passiert.
--
-- WARUM
-- Die Zeile hat kein Ziel. Die App macht eine Meldung nur dann anklickbar,
-- wenn ziel_art gesetzt ist (sonst waere es ein Zeigefinger, der ins Leere
-- fuehrt), und aufgabe_melden setzt es nicht. Die Funktion geht ueber
-- public.notify, das in notification_queue schreibt; von dort holt
-- warteschlange_in_glocke die Zeile ab. Auf diesem Weg ging das Ziel nicht
-- verloren - es wurde nie mitgegeben.
--
-- notify hat dafuer laengst einen Platz: den Parameter p_data (jsonb), der
-- bisher immer leer blieb. Genau dort gehoert es hin, und zwar allgemein: Ab
-- jetzt kann JEDE Meldung aus der Warteschlange ein Ziel tragen, nicht nur
-- die von Aufgaben.

-- ------------------------------------------------- Warteschlange packt aus
create or replace function public.warteschlange_in_glocke()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_profil uuid;
begin
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null then return new; end if;
  if not public.meldung_erlaubt(v_profil, coalesce(new.notif_type, 'info')) then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, new.club_id, coalesce(new.notif_type, 'info'),
          coalesce(new.title, 'Vereinsmeldung'), coalesce(new.body, ''),
          nullif(new.data ->> 'ziel_art', ''),
          /* Vorsichtig umwandeln: Steht dort etwas, das keine Kennung ist,
             darf die Meldung nicht verloren gehen - sie ist dann eben nicht
             anklickbar. */
          case when (new.data ->> 'ziel_id') ~ '^[0-9a-fA-F-]{36}$'
               then (new.data ->> 'ziel_id')::uuid else null end);
  return new;
end;
$function$;

-- ------------------------------------------------- Aufgabe gibt ihr Ziel mit
create or replace function public.aufgabe_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_mitglied record;
  v_text     text;
begin
  v_text := new.title
    || coalesce(' · bis ' || to_char(new.due_date, 'DD.MM.YYYY'), '');

  for v_mitglied in
    select m.id
      from public.club_memberships m
     where m.club_id = new.club_id
       and m.status = 'active'
       and m.profile_id is not null
       and (new.team_id is null
            or exists (select 1 from public.team_members tm
                        where tm.membership_id = m.id and tm.team_id = new.team_id))
       /* Neu: Wer die Mannschaft abbestellt hat, bekommt auch ihre Aufgaben
          nicht mehr. Ohne Zeile gilt weiterhin: eigene Mannschaft ja. */
       and public.team_meldung_erlaubt(m.id, new.team_id, 'aufgaben')
  loop
    perform public.notify(v_mitglied.id, 'tasks'::text,
      'Eine neue Aufgabe wurde erstellt.'::text, v_text::text,
      jsonb_build_object('ziel_art', 'aufgabe', 'ziel_id', new.id));
  end loop;
  return new;
end;
$$;

-- ------------------------------------------------- Bestehende Meldungen
--
-- Die Zeilen, die schon in der Glocke stehen, bleiben sonst tot.
--
-- Der Text lautet "ERG Iserlohn: Test · bis 07.09.2026" - dem Aufgabentext
-- ist der Vereinsname vorangestellt. Verglichen wird deshalb das ENDE des
-- Textes, und zwar ueber right(), nicht ueber like: Ein Titel darf % oder _
-- enthalten, und like wuerde beides als Platzhalter lesen.
--
-- Zugeordnet wird nur, was EINDEUTIG passt: derselbe Verein, genau eine
-- Aufgabe mit diesem Ende. Bei mehreren Treffern bleibt die Meldung lieber
-- ohne Ziel, als auf die falsche Aufgabe zu zeigen. Und was auf eine
-- geloeschte Aufgabe zeigte, findet gar nichts - richtig so.
with kandidat as (
  select n.id as meldung_id,
         (array_agg(t.id))[1] as treffer,
         count(*)  as anzahl
    from public.user_notifications n
    join public.club_tasks t
      on t.club_id = n.club_id
     and right(n.body, length(t.title || coalesce(' · bis ' || to_char(t.due_date, 'DD.MM.YYYY'), '')))
       = t.title || coalesce(' · bis ' || to_char(t.due_date, 'DD.MM.YYYY'), '')
   where n.ziel_id is null
     and n.title = 'Eine neue Aufgabe wurde erstellt.'
   group by n.id
)
update public.user_notifications n
   set ziel_art = 'aufgabe', ziel_id = k.treffer
  from kandidat k
 where n.id = k.meldung_id and k.anzahl = 1;

select
  (select count(*) from public.user_notifications
    where title = 'Eine neue Aufgabe wurde erstellt.' and ziel_id is not null) as jetzt_anklickbar,
  (select count(*) from public.user_notifications
    where title = 'Eine neue Aufgabe wurde erstellt.' and ziel_id is null) as zeigt_auf_geloeschte_aufgabe;
