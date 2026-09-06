-- Fünf Tabellen bekommen ihren eigenen Verein.
--
-- DAS PROBLEM
-- predictions, poll_options, poll_votes, duty_assignments und protocol_tasks
-- werden von der App OHNE Vereinsfilter geholt - sie verlassen sich allein
-- auf die Zeilenregeln. Die entscheiden zuverlaessig, wer was sehen darf,
-- aber sie muessen dafuer JEDE Zeile ansehen, auch die fremder Vereine:
--
--   EXISTS (select 1 from polls p where p.id = poll_votes.poll_id
--                                  and is_club_member(p.club_id))
--
-- Fuer jede Stimme in der Tabelle ein Nachschlagen in polls. Der Aufwand
-- waechst damit nicht mit der Groesse des eigenen Vereins, sondern mit der
-- Summe aller. Bei zwei Vereinen misst das niemand. Bei fuenfhundert liest
-- die Datenbank Hunderttausende Zeilen, um ein paar Dutzend zu finden - und
-- zwar bei jedem Start der App, bei jedem Nutzer.
--
-- DIE LOESUNG
-- Der Verein steht kuenftig direkt an der Zeile. Die App kann dann
-- .eq("club_id", ...) mitgeben, die Datenbank sucht ueber den Index statt zu
-- lesen, und die Zeilenregel prueft nur noch die paar Zeilen, die uebrig
-- bleiben.
--
-- WARUM EINE DOPPELTE ANGABE VERTRETBAR IST
-- Der Verein steht danach zweimal da: einmal am Elternteil, einmal an der
-- Zeile. Das ist Redundanz, und Redundanz kann auseinanderlaufen. Hier nicht:
-- Ein Trigger setzt den Wert beim Schreiben aus dem Elternteil, die Spalte
-- ist NOT NULL, und ein Tipp einer anderen Person kann nicht zu einem
-- anderen Verein wandern - Termine wechseln den Verein nicht.
--
-- DIE ZEILENREGELN BLEIBEN, WIE SIE SIND
-- Sie liessen sich mit der neuen Spalte vereinfachen, und das waere noch
-- schneller. Aber eine Regel zu aendern heisst, die Sicherheit anzufassen,
-- und der Gewinn liegt woanders: Wenn die App nur noch die eigenen Zeilen
-- anfordert, laeuft die alte Regel ohnehin nur ueber eine Handvoll davon.

-- ---------------------------------------------------------------- Spalten
alter table public.predictions      add column if not exists club_id uuid references public.clubs(id) on delete cascade;
alter table public.poll_options     add column if not exists club_id uuid references public.clubs(id) on delete cascade;
alter table public.poll_votes       add column if not exists club_id uuid references public.clubs(id) on delete cascade;
alter table public.duty_assignments add column if not exists club_id uuid references public.clubs(id) on delete cascade;
alter table public.protocol_tasks   add column if not exists club_id uuid references public.clubs(id) on delete cascade;

-- ------------------------------------------------------------ Nachtragen
update public.predictions p      set club_id = e.club_id  from public.events e     where e.id = p.event_id      and p.club_id is null;
update public.poll_options o     set club_id = x.club_id  from public.polls x      where x.id = o.poll_id       and o.club_id is null;
update public.poll_votes v       set club_id = x.club_id  from public.polls x      where x.id = v.poll_id       and v.club_id is null;
update public.duty_assignments d set club_id = e.club_id  from public.events e     where e.id = d.event_id      and d.club_id is null;
update public.protocol_tasks t   set club_id = pr.club_id from public.protocols pr where pr.id = t.protocol_id  and t.club_id is null;

-- ---------------------------------------------------- Pflicht ab jetzt
-- Bleibt hier etwas leer, gibt es eine verwaiste Zeile, und dann soll diese
-- Migration abbrechen statt eine Luecke zu hinterlassen, die spaeter still
-- den Zugriff verweigert.
alter table public.predictions      alter column club_id set not null;
alter table public.poll_options     alter column club_id set not null;
alter table public.poll_votes       alter column club_id set not null;
alter table public.duty_assignments alter column club_id set not null;
alter table public.protocol_tasks   alter column club_id set not null;

-- --------------------------------------------------------------- Fuellen
-- Der Wert kommt aus dem Elternteil, nicht vom Aufrufer. Sonst koennte
-- jemand eine Zeile mit einem fremden club_id schreiben und sie damit in
-- einem Verein sichtbar machen, zu dem sie nicht gehoert - die Zeilenregeln
-- pruefen weiterhin ueber das Elternteil, aber die Abfragen der App
-- filtern ueber diese Spalte.
create or replace function public.club_id_aus_elternteil()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  if tg_table_name = 'predictions' or tg_table_name = 'duty_assignments' then
    select e.club_id into new.club_id from public.events e where e.id = new.event_id;
  elsif tg_table_name = 'poll_options' or tg_table_name = 'poll_votes' then
    select p.club_id into new.club_id from public.polls p where p.id = new.poll_id;
  elsif tg_table_name = 'protocol_tasks' then
    select pr.club_id into new.club_id from public.protocols pr where pr.id = new.protocol_id;
  end if;
  if new.club_id is null then
    raise exception 'Zugehoeriger Verein nicht gefunden';
  end if;
  return new;
end;
$$;

drop trigger if exists predictions_club_id      on public.predictions;
drop trigger if exists poll_options_club_id     on public.poll_options;
drop trigger if exists poll_votes_club_id       on public.poll_votes;
drop trigger if exists duty_assignments_club_id on public.duty_assignments;
drop trigger if exists protocol_tasks_club_id   on public.protocol_tasks;

create trigger predictions_club_id      before insert or update on public.predictions      for each row execute function public.club_id_aus_elternteil();
create trigger poll_options_club_id     before insert or update on public.poll_options     for each row execute function public.club_id_aus_elternteil();
create trigger poll_votes_club_id       before insert or update on public.poll_votes       for each row execute function public.club_id_aus_elternteil();
create trigger duty_assignments_club_id before insert or update on public.duty_assignments for each row execute function public.club_id_aus_elternteil();
create trigger protocol_tasks_club_id   before insert or update on public.protocol_tasks   for each row execute function public.club_id_aus_elternteil();

-- --------------------------------------------------------------- Indizes
create index if not exists predictions_club_id_idx      on public.predictions (club_id);
create index if not exists poll_options_club_id_idx     on public.poll_options (club_id);
create index if not exists poll_votes_club_id_idx       on public.poll_votes (club_id);
create index if not exists duty_assignments_club_id_idx on public.duty_assignments (club_id);
create index if not exists protocol_tasks_club_id_idx   on public.protocol_tasks (club_id);

analyze public.predictions;
analyze public.poll_options;
analyze public.poll_votes;
analyze public.duty_assignments;
analyze public.protocol_tasks;

select
  (select count(*) from information_schema.columns
    where table_schema='public' and column_name='club_id'
      and table_name in ('predictions','poll_options','poll_votes','duty_assignments','protocol_tasks')) as spalten,
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_club\_id') as ausloeser,
  (select count(*) from pg_indexes where schemaname='public'
    and indexname in ('predictions_club_id_idx','poll_options_club_id_idx','poll_votes_club_id_idx',
                      'duty_assignments_club_id_idx','protocol_tasks_club_id_idx')) as indizes;
