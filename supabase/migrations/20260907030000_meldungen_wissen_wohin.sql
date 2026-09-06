-- Eine Benachrichtigung weiss jetzt, wohin sie zeigt.
--
-- DAS PROBLEM
-- In der Glocke steht "Neue Aufgabe - Marco hat dir eine Aufgabe
-- zugewiesen." Tippt man darauf, passiert nichts: Die Zeilen sind nicht
-- einmal anklickbar. Und selbst wenn sie es waeren, wuesste die App nicht,
-- WELCHE Aufgabe gemeint ist - in der Meldung steht kein Verweis darauf.
--
-- Der Empfaenger muss also selbst zu den Aufgaben gehen und suchen. Bei
-- einer Aufgabe geht das. Bei einer Absage, die man morgens um sieben liest,
-- nicht.
--
-- DIE LOESUNG
-- Zwei Spalten: ziel_art sagt, um welche Art Datensatz es geht, ziel_id
-- welchen genau. Die App kann damit direkt dorthin springen und den
-- Datensatz aufschlagen.
--
-- WARUM NICHT source_event_id ERWEITERN
-- Die Spalte gibt es schon, sie meint aber ausschliesslich Termine und ist
-- als Fremdschluessel auf events festgenagelt. Eine Aufgabe passt dort
-- nicht hinein. Die neuen Spalten tragen deshalb bewusst KEINEN
-- Fremdschluessel: Sie zeigen je nach Art auf verschiedene Tabellen. Der
-- Preis dafuer ist, dass ein geloeschter Datensatz eine tote Kennung
-- hinterlaesst - die App muss also damit rechnen, nichts zu finden, und
-- darf daran nicht scheitern.

alter table public.user_notifications add column if not exists ziel_art text;
alter table public.user_notifications add column if not exists ziel_id  uuid;

comment on column public.user_notifications.ziel_art is
  'Worauf die Meldung zeigt: aufgabe, termin, umfrage, news, fahrzeug, helferaufgabe. Leer heisst: kein Ziel.';
comment on column public.user_notifications.ziel_id is
  'Kennung des Datensatzes. Bewusst ohne Fremdschluessel, weil die Art die Tabelle bestimmt.';

create index if not exists user_notifications_ziel_idx
  on public.user_notifications (ziel_art, ziel_id) where ziel_art is not null;

-- ------------------------------------------------ Vereinsaufgabe zugewiesen
create or replace function public.vereinsaufgabe_zuweisung_melden()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare v_profil uuid; v_club uuid; v_titel text; v_wer text;
begin
  select t.club_id, t.title into v_club, v_titel from public.club_tasks t where t.id = new.task_id;
  select profile_id into v_profil from public.club_memberships where id = new.membership_id;
  if v_profil is null or v_profil = auth.uid() then return new; end if;

  select display_name into v_wer from public.club_memberships
   where profile_id = auth.uid() and club_id = v_club limit 1;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  values (v_profil, v_club, 'task', 'Neue Aufgabe',
          coalesce(v_wer, 'Die Vereinsleitung') || ' hat dir eine Aufgabe zugewiesen: ' || coalesce(v_titel, ''),
          'aufgabe', new.task_id);
  return new;
end;
$function$;

-- ---------------------------------------------------------------- Umfragen
create or replace function public.umfrage_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  if not new.active then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select m.profile_id, new.club_id, 'polls',
         public.meldungstext('umfrage.titel', p.language),
         public.meldungstext('umfrage.text', p.language),
         'umfrage', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null;

  return new;
end;
$$;

/* Termine tragen ihr Ziel ebenfalls mit. Die Funktion ist sonst Wort fuer
   Wort die aus der Produktionsdatenbank - geaendert ist nur die
   Spaltenliste des insert und der Wert dahinter. */
create or replace function public.notify_event_audience()
 returns trigger language plpgsql security definer set search_path to 'public'
as $function$
declare
  v_titel text;
  v_text  text;
  v_art   text;
begin
  v_art := case new.type when 'training' then 'Training' when 'spiel' then 'Spiel' else 'Event' end;

  if tg_op = 'INSERT' then
    v_titel := v_art || ' angelegt';
    v_text  := 'Das ' || v_art || ' wurde angelegt.';
  elsif new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    v_titel := v_art || ' abgesagt';
    v_text  := 'Das ' || v_art || ' wurde abgesagt.'
               || coalesce(' Grund: ' || nullif(trim(new.cancel_reason), ''), '');
  elsif tg_op = 'UPDATE' then
    v_titel := v_art || ' geändert';
    v_text  := 'Das ' || v_art || ' wurde geändert.';
  else
    return new;
  end if;

  v_text := v_text || ' ' || coalesce(new.title, '')
            || coalesce(' · ' || to_char(new.starts_at, 'DD.MM. HH24:MI'), '')
            || coalesce(' · ' || new.location, '');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id,
         case new.type when 'training' then 'training' when 'spiel' then 'match' else 'event' end,
         v_titel, v_text, 'termin', new.id
  from public.club_memberships m
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = new.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (new.team_id is null or tm.membership_id is not null);

  return new;
end;
$function$;

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='user_notifications'
      and column_name in ('ziel_art','ziel_id')) as spalten,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosrc like '%ziel_art%') as ausloeser_mit_ziel;
