/* Abstimmungen im Chat.
 *
 * Eine Abstimmung ist hier kein eigener Bildschirm, sondern eine Nachricht:
 * Sie steht im Verlauf an der Stelle, an der sie geschrieben wurde, und man
 * stimmt ab, ohne den Chat zu verlassen.
 *
 * WARUM DIE BESTEHENDEN TABELLEN UND KEINE NEUEN
 * polls/poll_options/poll_votes gibt es schon - fuer die Vereinsumfragen. Frage,
 * Antworten und Stimmen haben dieselbe Form; ein zweiter Satz Tabellen haette
 * denselben Inhalt zweimal modelliert, zweimal abgesichert und zweimal in die
 * Echtzeituebertragung eingehaengt. Unterschieden wird an einer Spalte:
 * channel_id gesetzt = Abstimmung im Chat, channel_id leer = Vereinsumfrage.
 *
 * DER PRIMAERSCHLUESSEL MUSSTE SICH AENDERN - UND DAS IST DER HEIKLE TEIL
 * poll_votes hatte den Schluessel (poll_id, profile_id): eine Stimme je Person
 * und Umfrage. Mehrfachauswahl ist damit nicht moeglich, nicht einmal
 * versehentlich. Der Schluessel heisst jetzt (poll_id, profile_id, option_id).
 *
 * Damit faellt aber die Zusicherung weg, die die Einfachauswahl bisher
 * kostenlos hatte: Der Upsert der Vereinsumfragen ersetzte die alte Stimme,
 * weil sie im Schluessel kollidierte. Mit dem neuen Schluessel kollidiert
 * nichts mehr - derselbe Aufruf wuerde eine ZWEITE Zeile anlegen und die
 * Person doppelt zaehlen. Deshalb laeuft das Abstimmen ab jetzt ueber
 * abstimmung_stimmen(); die Funktion raeumt bei Einfachauswahl die vorherige
 * Stimme selbst weg, unter einer Sperre auf der Umfragezeile. Der Client darf
 * poll_votes nicht mehr direkt beschreiben - siehe die Regeln unten.
 *
 * WARUM UEBERHAUPT EINE FUNKTION UND NICHT DIREKTE SCHREIBZUGRIFFE
 * Vier Dinge muessen zusammen und unteilbar passieren: pruefen ob die
 * Abstimmung noch laeuft, pruefen ob die Person abstimmen darf, bei
 * Einfachauswahl die alte Stimme entfernen, die neue setzen. Getrennt
 * ausgefuehrt liegt zwischen jedem Schritt ein Moment, in dem die Abstimmung
 * enden oder eine zweite Stimme desselben Nutzers eintreffen kann - der Fall
 * "Abstimmung endet genau waehrend einer Stimmabgabe" ist sonst nicht
 * entscheidbar, sondern Zufall.
 */

-- ---------------------------------------------------------------- Schema

alter table public.polls
  add column if not exists channel_id uuid references public.channels(id) on delete cascade,
  /* Die Einstellungen einzeln als Spalten, nicht als jsonb: Sie werden in
     Regeln und Funktionen abgefragt, und eine Bedingung ueber einer
     jsonb-Eigenschaft laesst sich weder indizieren noch beim Lesen der
     Migration verstehen. Neue Regeln kommen als neue Spalte dazu. */
  add column if not exists allow_multiple boolean not null default false,
  add column if not exists anonymous boolean not null default false,
  add column if not exists results_before_vote boolean not null default true,
  add column if not exists results_before_end boolean not null default true,
  add column if not exists allow_vote_change boolean not null default true,
  add column if not exists ends_at timestamptz;

create index if not exists polls_channel_idx on public.polls(channel_id) where channel_id is not null;

/* Die Abstimmung IST eine Nachricht. Ueber diese Spalte findet der Chat sie;
   der Fragetext steht zusaetzlich als body, damit eine Abstimmung auch dort
   lesbar bleibt, wo die Karte nicht gezeichnet wird - in der Mitteilung auf
   dem Sperrbildschirm zum Beispiel. */
alter table public.messages
  add column if not exists poll_id uuid references public.polls(id) on delete cascade;

create index if not exists messages_poll_idx on public.messages(poll_id) where poll_id is not null;

/* Wird die Nachricht geloescht, geht die Abstimmung mit. Die Gegenrichtung
   erledigt der Fremdschluessel oben. Ohne diesen Ausloeser bliebe eine
   Abstimmung ohne Nachricht zurueck: unsichtbar, aber weiter abstimmbar. */
create or replace function public.nachricht_abstimmung_aufraeumen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.poll_id is not null then
    delete from public.polls where id = old.poll_id;
  end if;
  return old;
end;
$$;

drop trigger if exists messages_poll_cleanup on public.messages;
create trigger messages_poll_cleanup
  after delete on public.messages
  for each row execute function public.nachricht_abstimmung_aufraeumen();

-- ------------------------------------------------- Schluessel auf poll_votes

/* Erst pruefen, dann tauschen. Gaebe es schon Zeilen, die unter dem neuen
   Schluessel kollidieren, waere das ein Datenfehler, den diese Migration
   sichtbar machen soll statt ihn zu ueberschreiben. */
do $$
declare
  v_doppelt integer;
begin
  select count(*) into v_doppelt from (
    select poll_id, profile_id, option_id from public.poll_votes
    group by poll_id, profile_id, option_id having count(*) > 1
  ) d;
  if v_doppelt > 0 then
    raise exception 'poll_votes enthaelt % mehrfach vorhandene Stimmen - bitte vor der Migration klaeren', v_doppelt;
  end if;
end $$;

alter table public.poll_votes drop constraint if exists poll_votes_pkey;
alter table public.poll_votes add constraint poll_votes_pkey
  primary key (poll_id, profile_id, option_id);

/* "Ein Benutzer darf pro Option maximal eine aktive Stimme besitzen" steht
   damit im Schluessel selbst. Ein doppelter Klick auf dieselbe Option kann
   keine zweite Zeile erzeugen - auch dann nicht, wenn beide Anfragen
   gleichzeitig ankommen und beide die Pruefung im Code passieren. */

create index if not exists poll_votes_option_idx on public.poll_votes(option_id);

-- --------------------------------------------------------- Sichtbarkeit

/* Wer einen Kanal sehen bzw. darin schreiben darf - wortgleich zu den Regeln
   auf messages. Als Funktion, damit die Bedingung an fuenf Stellen dieselbe
   ist und nicht fuenfmal abgeschrieben wird. */
create or replace function public.darf_kanal_sehen(p_channel uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1 from public.channels c
    where c.id = p_channel
      and public.is_club_member(c.club_id)
      and (
        (c.team_id is not null and public.gehoert_zu_mannschaft(c.team_id))
        or (c.team_id is null and (cardinality(c.visible_roles) = 0
             or public.has_club_role(c.club_id, c.visible_roles)))
      )
  );
$$;

create or replace function public.darf_in_kanal_schreiben(p_channel uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select public.darf_kanal_sehen(p_channel)
    and exists (
      select 1 from public.channels c
      where c.id = p_channel
        and (cardinality(c.write_roles) = 0 or public.has_club_role(c.club_id, c.write_roles))
    );
$$;

/* Abstimmungen im Chat gehoeren dem Kanal, nicht dem ganzen Verein. Die alte
   Regel gab jede Umfrage jedem Vereinsmitglied frei - fuer eine Abstimmung im
   Mannschaftschat waere das ein Leck: Die Frage stuende jedem offen, der die
   Nachricht daneben nicht lesen darf. */
drop policy if exists "members read polls" on public.polls;
create policy "members read polls" on public.polls for select
  using (
    case when channel_id is null
      then public.is_club_member(club_id)
      else public.darf_kanal_sehen(channel_id)
    end
  );

drop policy if exists "members read poll options" on public.poll_options;
create policy "members read poll options" on public.poll_options for select
  using (exists (
    select 1 from public.polls p
    where p.id = poll_options.poll_id
      and (case when p.channel_id is null
             then public.is_club_member(p.club_id)
             else public.darf_kanal_sehen(p.channel_id) end)
  ));

/* Stimmen: die eigenen immer. Bei Vereinsumfragen bleibt es beim bisherigen
   offenen Lesen - die Auswertung dort zeigt ohnehin, wer wie gestimmt hat.
   Bei Chat-Abstimmungen NICHT: Dort entscheidet die Einstellung "anonymous",
   und ob das Ergebnis vor der eigenen Stimme oder vor dem Ende sichtbar ist.
   Diese Regeln lassen sich in einer Zeilenregel nicht sinnvoll ausdruecken -
   deshalb liest der Client Ergebnisse ueber abstimmung_ergebnis(), und der
   direkte Zugriff bleibt auf die eigene Zeile beschraenkt. Waere er offen,
   koennte man die Anonymitaet mit einem einzigen API-Aufruf umgehen. */
drop policy if exists "members read votes" on public.poll_votes;
create policy "members read votes" on public.poll_votes for select
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.polls p
      where p.id = poll_votes.poll_id
        and p.channel_id is null
        and public.is_club_member(p.club_id)
    )
  );

/* Geschrieben wird nur noch ueber abstimmung_stimmen(). Der Grund steht oben
   im Kopf: Mit dem neuen Schluessel wuerde ein direkter Upsert bei
   Einfachauswahl doppelt zaehlen statt zu ersetzen. */
drop policy if exists "members cast own vote" on public.poll_votes;
drop policy if exists "members change own vote" on public.poll_votes;

-- ------------------------------------------------------------- Anlegen

create or replace function public.chat_abstimmung_anlegen(
  p_channel uuid,
  p_frage text,
  p_optionen text[],
  p_mehrfach boolean default false,
  p_anonym boolean default false,
  p_ergebnis_vor_stimme boolean default true,
  p_ergebnis_vor_ende boolean default true,
  p_stimme_aenderbar boolean default true,
  p_endet_am timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club uuid;
  v_poll uuid;
  v_nachricht uuid;
  v_frage text := nullif(trim(p_frage), '');
  v_optionen text[];
  v_anzahl integer;
begin
  if auth.uid() is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;
  if not public.darf_in_kanal_schreiben(p_channel) then
    raise exception 'In diesem Kanal darfst du nicht schreiben' using errcode = '42501';
  end if;
  if v_frage is null then
    raise exception 'Die Frage fehlt' using errcode = '22023';
  end if;

  /* Leere Optionen fliegen raus, doppelte auch - und zwar unabhaengig von
     Gross- und Kleinschreibung und umgebenden Leerzeichen. "Montag" und
     "montag " sind fuer den Abstimmenden dieselbe Antwort; stuenden beide da,
     verteilten sich die Stimmen auf zwei Zeilen und das Ergebnis waere
     falsch, ohne dass es jemandem auffiele. Die Reihenfolge bleibt die des
     Erstellers. */
  select array_agg(o.wert order by o.nr) into v_optionen
  from (
    select distinct on (lower(trim(wert))) trim(wert) as wert, nr
    from unnest(p_optionen) with ordinality as u(wert, nr)
    where nullif(trim(wert), '') is not null
    order by lower(trim(wert)), nr
  ) o;

  v_anzahl := coalesce(array_length(v_optionen, 1), 0);
  if v_anzahl < 2 then
    raise exception 'Eine Abstimmung braucht mindestens zwei verschiedene Antworten' using errcode = '22023';
  end if;
  if v_anzahl > 20 then
    raise exception 'Mehr als 20 Antwortmoeglichkeiten sind nicht vorgesehen' using errcode = '22023';
  end if;
  if p_endet_am is not null and p_endet_am <= now() then
    raise exception 'Das Ende liegt in der Vergangenheit' using errcode = '22023';
  end if;

  select c.club_id into v_club from public.channels c where c.id = p_channel;

  insert into public.polls (club_id, channel_id, title, active, created_by,
      allow_multiple, anonymous, results_before_vote, results_before_end,
      allow_vote_change, ends_at)
  values (v_club, p_channel, left(v_frage, 300), true, auth.uid(),
      coalesce(p_mehrfach, false), coalesce(p_anonym, false),
      coalesce(p_ergebnis_vor_stimme, true), coalesce(p_ergebnis_vor_ende, true),
      coalesce(p_stimme_aenderbar, true), p_endet_am)
  returning id into v_poll;

  insert into public.poll_options (poll_id, club_id, label, position)
  select v_poll, v_club, left(wert, 200), nr - 1
  from unnest(v_optionen) with ordinality as u(wert, nr);

  /* Der Fragetext steht auch im Nachrichtenrumpf - siehe Kopf. */
  insert into public.messages (channel_id, author_id, body, poll_id)
  values (p_channel, auth.uid(), left(v_frage, 300), v_poll)
  returning id into v_nachricht;

  return jsonb_build_object('poll_id', v_poll, 'message_id', v_nachricht);
end;
$$;

-- ------------------------------------------------------------ Abstimmen

create or replace function public.abstimmung_stimmen(
  p_option uuid,
  p_gewaehlt boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll   public.polls%rowtype;
  v_club   uuid;
  v_darf   boolean;
  v_hatte  boolean;
begin
  if auth.uid() is null then
    raise exception 'Nicht angemeldet' using errcode = '42501';
  end if;

  /* Die Umfragezeile sperren, BEVOR irgendetwas geprueft wird. Alles, was
     danach kommt - laeuft sie noch, darf ich, alte Stimme weg, neue rein -
     sieht damit einen Stand, den in diesem Moment niemand sonst veraendert.
     Ohne die Sperre koennten zwei gleichzeitige Stimmen derselben Person bei
     Einfachauswahl beide die Pruefung passieren und zwei Zeilen hinterlassen. */
  select p.* into v_poll
  from public.polls p
  join public.poll_options o on o.poll_id = p.id
  where o.id = p_option
  for update of p;

  if not found then
    raise exception 'Diese Antwort gibt es nicht' using errcode = '42704';
  end if;

  if v_poll.channel_id is null then
    v_darf := public.is_club_member(v_poll.club_id);
  else
    /* Sehen genuegt zum Abstimmen. Die Schreibrechte eines Kanals regeln, wer
       Nachrichten VERFASST - eine Ansage des Trainers bleibt so seine Ansage.
       Beim Abstimmen ist die Beteiligung der ganze Zweck: "jeder
       Teamteilnehmer kann mitmachen". Wer den Kanal nur mitliest, soll
       trotzdem antworten duerfen. */
    v_darf := public.darf_kanal_sehen(v_poll.channel_id);
  end if;
  if not v_darf then
    raise exception 'Du darfst hier nicht abstimmen' using errcode = '42501';
  end if;

  if not v_poll.active then
    raise exception 'Diese Abstimmung ist beendet' using errcode = '22023';
  end if;
  if v_poll.ends_at is not null and v_poll.ends_at <= now() then
    raise exception 'Diese Abstimmung ist beendet' using errcode = '22023';
  end if;

  select exists (
    select 1 from public.poll_votes v
    where v.poll_id = v_poll.id and v.profile_id = auth.uid()
  ) into v_hatte;

  /* Stimme aendern verboten? Dann zaehlt nur die erste Abgabe. Geprueft wird
     gegen die gesamte Umfrage, nicht gegen die einzelne Option - sonst
     koennte man bei Mehrfachauswahl beliebig nachlegen. */
  if v_hatte and not v_poll.allow_vote_change then
    raise exception 'Deine Stimme laesst sich nicht mehr aendern' using errcode = '42501';
  end if;

  select club_id into v_club from public.poll_options where id = p_option;

  if coalesce(p_gewaehlt, true) then
    if not v_poll.allow_multiple then
      /* Einfachauswahl: Was vorher gewaehlt war, faellt weg. Genau das tat
         frueher der Upsert ueber den Primaerschluessel; seit der Schluessel
         die Option enthaelt, muss es hier stehen. */
      delete from public.poll_votes
      where poll_id = v_poll.id and profile_id = auth.uid() and option_id <> p_option;
    end if;
    insert into public.poll_votes (poll_id, option_id, profile_id, club_id)
    values (v_poll.id, p_option, auth.uid(), v_club)
    on conflict (poll_id, profile_id, option_id) do nothing;
  else
    delete from public.poll_votes
    where poll_id = v_poll.id and profile_id = auth.uid() and option_id = p_option;
  end if;

  return public.abstimmung_ergebnis(v_poll.id);
end;
$$;

-- ------------------------------------------------------------- Ergebnis

create or replace function public.abstimmung_ergebnis(p_poll uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll        public.polls%rowtype;
  v_darf        boolean;
  v_offen       boolean;
  v_hat_gewaehlt boolean;
  v_sichtbar    boolean;
  v_grund       text := null;
  v_teilnehmer  integer;
  v_auswahlen   integer;
  v_optionen    jsonb;
  v_meine       jsonb;
begin
  select * into v_poll from public.polls where id = p_poll;
  if not found then
    raise exception 'Diese Abstimmung gibt es nicht' using errcode = '42704';
  end if;

  if v_poll.channel_id is null then
    v_darf := public.is_club_member(v_poll.club_id);
  else
    v_darf := public.darf_kanal_sehen(v_poll.channel_id);
  end if;
  if not v_darf then
    raise exception 'Kein Zugriff' using errcode = '42501';
  end if;

  v_offen := v_poll.active and (v_poll.ends_at is null or v_poll.ends_at > now());

  select exists (
    select 1 from public.poll_votes v where v.poll_id = p_poll and v.profile_id = auth.uid()
  ) into v_hat_gewaehlt;

  /* Die beiden Sichtbarkeitsregeln. Sie gelten NICHT fuer den Ersteller -
     wer die Abstimmung gestellt hat, soll sie auch verfolgen koennen, ohne
     selbst mitstimmen zu muessen. */
  v_sichtbar := true;
  if v_poll.created_by is distinct from auth.uid() then
    if not v_poll.results_before_vote and not v_hat_gewaehlt then
      v_sichtbar := false; v_grund := 'erst_abstimmen';
    elsif not v_poll.results_before_end and v_offen then
      v_sichtbar := false; v_grund := 'erst_ende';
    end if;
  end if;

  /* Zwei verschiedene Zahlen, und sie werden gern verwechselt:
     teilnehmer  = wie viele PERSONEN abgestimmt haben
     auswahlen   = wie viele Kreuze insgesamt gesetzt wurden
     Bei Mehrfachauswahl ist die zweite groesser. Der Anteil je Option wird
     unten auf die Teilnehmer bezogen, nicht auf die Kreuze - sonst ergaebe
     die Summe zwanghaft 100 %, und "5 von 8 wollen Montag" waere nicht mehr
     ablesbar. */
  select count(distinct profile_id), count(*) into v_teilnehmer, v_auswahlen
  from public.poll_votes where poll_id = p_poll;

  select coalesce(jsonb_agg(z order by z_pos), '[]'::jsonb) into v_optionen
  from (
    select o.position as z_pos,
      jsonb_build_object(
        'id', o.id,
        'label', o.label,
        'position', o.position,
        'stimmen', case when v_sichtbar then coalesce(s.anzahl, 0) else null end,
        'anteil', case when v_sichtbar and v_teilnehmer > 0
                       then round(coalesce(s.anzahl, 0)::numeric * 100 / v_teilnehmer)
                       when v_sichtbar then 0 else null end,
        /* Namen nur, wenn die Abstimmung nicht anonym ist UND das Ergebnis
           ueberhaupt sichtbar ist. Bei anonymer Abstimmung verlaesst die
           Zuordnung Person->Antwort diese Funktion nicht. */
        'waehler', case when v_sichtbar and not v_poll.anonymous then coalesce(s.namen, '[]'::jsonb) else null end
      ) as z
    from public.poll_options o
    left join (
      select v.option_id,
             count(*) as anzahl,
             jsonb_agg(jsonb_build_object('id', v.profile_id,
                       'name', coalesce(pr.full_name, 'Unbekannt'))
                       order by pr.full_name) as namen
      from public.poll_votes v
      left join public.profiles pr on pr.id = v.profile_id
      where v.poll_id = p_poll
      group by v.option_id
    ) s on s.option_id = o.id
    where o.poll_id = p_poll
  ) t;

  select coalesce(jsonb_agg(option_id), '[]'::jsonb) into v_meine
  from public.poll_votes where poll_id = p_poll and profile_id = auth.uid();

  return jsonb_build_object(
    'poll_id', v_poll.id,
    'frage', v_poll.title,
    'offen', v_offen,
    'endet_am', v_poll.ends_at,
    'mehrfach', v_poll.allow_multiple,
    'anonym', v_poll.anonymous,
    'aenderbar', v_poll.allow_vote_change,
    'ersteller', v_poll.created_by,
    'sichtbar', v_sichtbar,
    'grund', v_grund,
    'teilnehmer', v_teilnehmer,
    'auswahlen', v_auswahlen,
    'optionen', v_optionen,
    'meine', v_meine
  );
end;
$$;

-- --------------------------------------------------- Beenden / Bearbeiten

create or replace function public.chat_abstimmung_beenden(p_poll uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll public.polls%rowtype;
begin
  select * into v_poll from public.polls where id = p_poll for update;
  if not found then
    raise exception 'Diese Abstimmung gibt es nicht' using errcode = '42704';
  end if;
  /* Beenden darf, wer sie gestellt hat - und die Vereinsleitung, die auch
     Nachrichten entfernen darf. Trainer und Kapitaene bewusst nicht: sonst
     schliesst der Kapitaen die Abstimmung seines Trainers. Dieselbe
     Aufteilung wie bei der Moderation im Chat. */
  if v_poll.created_by is distinct from auth.uid()
     and not public.has_club_role(v_poll.club_id,
       array['vorstand','geschaeftsfuehrung','vereinsadmin','sysadmin']::club_role[]) then
    raise exception 'Nur wer die Abstimmung gestellt hat, kann sie beenden' using errcode = '42501';
  end if;
  update public.polls set active = false where id = p_poll;
  return public.abstimmung_ergebnis(p_poll);
end;
$$;

create or replace function public.chat_abstimmung_bearbeiten(
  p_poll uuid,
  p_frage text default null,
  p_endet_am timestamptz default null,
  p_ende_entfernen boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_poll public.polls%rowtype;
  v_frage text := nullif(trim(p_frage), '');
begin
  select * into v_poll from public.polls where id = p_poll for update;
  if not found then
    raise exception 'Diese Abstimmung gibt es nicht' using errcode = '42704';
  end if;
  if v_poll.created_by is distinct from auth.uid() then
    raise exception 'Nur wer die Abstimmung gestellt hat, kann sie bearbeiten' using errcode = '42501';
  end if;

  /* Bearbeitet werden duerfen NUR Frage und Endzeitpunkt. Die Antworten
     bleiben, wie sie sind: Wer "Montag" nachtraeglich in "Dienstag" aendert,
     verschiebt damit die bereits abgegebenen Stimmen auf eine Antwort, der
     niemand zugestimmt hat. Das ist kein Bearbeiten mehr, sondern eine
     Faelschung - und sie waere im Verlauf nicht einmal sichtbar. Wer die
     Antworten aendern will, stellt die Abstimmung neu. */
  if v_frage is not null then
    update public.polls set title = left(v_frage, 300) where id = p_poll;
    update public.messages set body = left(v_frage, 300) where poll_id = p_poll;
  end if;

  if p_ende_entfernen then
    update public.polls set ends_at = null where id = p_poll;
  elsif p_endet_am is not null then
    if p_endet_am <= now() then
      raise exception 'Das Ende liegt in der Vergangenheit' using errcode = '22023';
    end if;
    update public.polls set ends_at = p_endet_am where id = p_poll;
  end if;

  return public.abstimmung_ergebnis(p_poll);
end;
$$;

-- ------------------------------------------------------------- Zugriff

/* Postgres vergibt auf jede neue Funktion automatisch EXECUTE an PUBLIC -
   also auch an anon, den nicht angemeldeten Zugriff. Fuer Funktionen mit
   security definer heisst das: Sie liefen mit den Rechten des Eigentuemers,
   angestossen von irgendwem. Deshalb zuruecknehmen und einzeln vergeben. */
do $$
declare f text;
begin
  foreach f in array array[
    'chat_abstimmung_anlegen(uuid,text,text[],boolean,boolean,boolean,boolean,boolean,timestamptz)',
    'abstimmung_stimmen(uuid,boolean)',
    'abstimmung_ergebnis(uuid)',
    'chat_abstimmung_beenden(uuid)',
    'chat_abstimmung_bearbeiten(uuid,text,timestamptz,boolean)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ------------------------------------------------------------ Echtzeit

/* Der Chat abonniert seit jeher Aenderungen an messages - nur stand die
   Tabelle in keiner Publikation, weshalb nie ein Ereignis ankam. Neue
   Nachrichten erschienen erst nach einem Neustart der App. Fuer Abstimmungen
   waere das noch auffaelliger: Man saehe die eigene Stimme, aber nie die der
   anderen.
   replica identity full sorgt dafuer, dass auch beim Loeschen die ganze Zeile
   im Ereignis steht - sonst kaeme nur die Kennung an und der Client wuesste
   nicht, zu welchem Kanal bzw. welcher Abstimmung sie gehoert. */
alter table public.polls       replica identity full;
alter table public.poll_options replica identity full;
alter table public.poll_votes  replica identity full;

do $$
declare
  t text;
begin
  foreach t in array array['messages', 'polls', 'poll_options', 'poll_votes'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
