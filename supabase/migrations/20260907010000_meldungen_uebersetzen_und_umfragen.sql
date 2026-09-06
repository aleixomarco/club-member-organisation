-- Benachrichtigungen in der Sprache des Empfaengers - und eine fuer Umfragen.
--
-- DIE FRAGE WAR: Werden Push-Meldungen uebersetzt?
-- Nein. Sie entstehen als fertige deutsche Saetze in der Datenbank und
-- werden so verschickt. Wer die App auf Tuerkisch stellt, bekommt eine
-- tuerkische Oberflaeche - und deutsche Mitteilungen auf den
-- Sperrbildschirm.
--
-- WARUM DAS NICHT IN DER APP ZU LOESEN IST
-- Die Uebersetzung der Oberflaeche steckt in lib/sprachen.ts und laeuft im
-- Browser. Eine Push-Meldung wird aber verschickt, waehrend die App
-- geschlossen ist - da laeuft nichts, was uebersetzen koennte. Der Text muss
-- also schon fertig sein, wenn er die Datenbank verlaesst.
--
-- DER WEG: BEIM SCHREIBEN UEBERSETZEN
-- Der Ausloeser kennt den Empfaenger, und der Empfaenger hat eine Sprache
-- (profiles.language). Also wird die Zeile gleich in der richtigen Sprache
-- geschrieben. Jede Zeile ist damit fuer genau einen Menschen gemacht - was
-- ohnehin stimmt, denn user_notifications hat eine Zeile je Person.
--
-- Das hat einen angenehmen Nebeneffekt: Glocke und Push zeigen automatisch
-- dasselbe, weil beide dieselbe Zeile lesen.

create table if not exists public.meldungstexte (
  schluessel text not null,
  sprache    text not null,
  text       text not null,
  primary key (schluessel, sprache)
);

alter table public.meldungstexte enable row level security;

/* Lesen darf jeder Angemeldete - es sind Textbausteine, keine Daten.
   Schreiben darf niemand ueber die App; das passiert nur ueber Migrationen. */
drop policy if exists "angemeldete lesen meldungstexte" on public.meldungstexte;
create policy "angemeldete lesen meldungstexte" on public.meldungstexte
  for select to authenticated using (true);

comment on table public.meldungstexte is
  'Textbausteine fuer Benachrichtigungen, je Sprache. Wird beim Schreiben einer Meldung ausgewertet, damit Push und Glocke in der Sprache des Empfaengers ankommen.';

/* Ein Baustein in der gewuenschten Sprache - mit Rueckfall auf Deutsch.
   Fehlt auch der, kommt der Schluessel zurueck. Das ist haesslich, aber
   sichtbar; eine leere Mitteilung waere schlimmer, weil sie wie ein Fehler
   im Versand aussieht. */
create or replace function public.meldungstext(p_schluessel text, p_sprache text)
returns text language sql stable security definer set search_path = 'public' as $$
  select coalesce(
    (select text from public.meldungstexte where schluessel = p_schluessel and sprache = coalesce(p_sprache, 'de')),
    (select text from public.meldungstexte where schluessel = p_schluessel and sprache = 'de'),
    p_schluessel
  );
$$;

grant execute on function public.meldungstext(text, text) to authenticated, service_role;

insert into public.meldungstexte (schluessel, sprache, text) values
  ('umfrage.titel','de','Neue Umfrage'),
  ('umfrage.titel','en','New poll'),
  ('umfrage.titel','es','Nueva encuesta'),
  ('umfrage.titel','pt','Nova sondagem'),
  ('umfrage.titel','it','Nuovo sondaggio'),
  ('umfrage.titel','tr','Yeni anket'),
  ('umfrage.titel','fr','Nouveau sondage'),
  ('umfrage.text','de','Eine neue Umfrage wurde gestartet. Jetzt teilnehmen!'),
  ('umfrage.text','en','A new poll has started. Take part now!'),
  ('umfrage.text','es','Se ha iniciado una nueva encuesta. ¡Participa ahora!'),
  ('umfrage.text','pt','Foi iniciada uma nova sondagem. Participa agora!'),
  ('umfrage.text','it','È iniziato un nuovo sondaggio. Partecipa ora!'),
  ('umfrage.text','tr','Yeni bir anket başladı. Hemen katıl!'),
  ('umfrage.text','fr','Un nouveau sondage a démarré. Participe maintenant !')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- ------------------------------------------------- Umfragen benachrichtigen
--
-- Bisher rief die APP beim Anlegen notify_club auf. Das funktioniert, solange
-- eine Umfrage nur ueber diesen einen Knopf entsteht - bei jedem anderen Weg
-- (Import, spaetere Automatik, Betreiber-Board) passiert nichts. Bei Terminen
-- und News sitzt der Ausloeser deshalb laengst in der Datenbank; Umfragen
-- waren die Ausnahme.
create or replace function public.umfrage_melden()
returns trigger language plpgsql security definer set search_path = 'public' as $$
begin
  if not new.active then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select m.profile_id, new.club_id, 'polls',
         public.meldungstext('umfrage.titel', p.language),
         public.meldungstext('umfrage.text', p.language)
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null;

  return new;
end;
$$;

drop trigger if exists polls_melden on public.polls;
create trigger polls_melden after insert on public.polls
  for each row execute function public.umfrage_melden();

select
  (select count(*) from public.meldungstexte) as bausteine,
  (select count(*) from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='polls' and not t.tgisinternal) as ausloeser;
