/* Zwei Dinge an den Meldungen in der Glocke.
 *
 * 1. DER UMFRAGE-TRIGGER MELDETE AUCH CHAT-ABSTIMMUNGEN - AN DEN GANZEN VEREIN
 *
 * umfrage_melden haengt an polls und schrieb bisher jedem aktiven Mitglied des
 * Vereins eine Meldung, sobald dort eine Zeile entsteht. Seit es
 * Chat-Abstimmungen gibt, entstehen solche Zeilen auch fuer eine Frage im
 * Mannschaftschat - und dann bekam sie der ganze Verein, einschliesslich
 * derer, die den Kanal gar nicht sehen duerfen.
 *
 * Der Fragetext bleibt dabei zwar drin (die Meldung ist ein fester Satz aus
 * meldungstexte, nicht der Titel der Umfrage), es ist also kein Leck von
 * Inhalten. Aber es sind Meldungen ueber etwas, das die Empfaenger nicht
 * finden koennen: Angetippt fuehrten sie auf die Startseite, wo keine
 * Chat-Abstimmung steht. Genau das war zu sehen.
 *
 * Der Chat verschickt seine eigene Meldung an die Leute des Kanals - siehe
 * benachrichtigen() in ChatView. Hier wird deshalb nur noch gemeldet, was
 * wirklich eine Vereinsumfrage ist.
 *
 * 2. CHAT-MELDUNGEN HATTEN KEIN ZIEL
 *
 * Sie waren damit nicht antippbar: In der Glocke stand "Neue Nachricht", und
 * ein Tipp darauf tat nichts. Fuer eine Abstimmung im Chat ist das besonders
 * schlecht - sie ist genau das, was man sofort oeffnen will.
 *
 * notify_many bleibt unveraendert. Ein zusaetzlicher Parameter mit Vorgabewert
 * waere eine zweite Funktion gleichen Namens, und PostgREST loest Aufrufe ueber
 * die Namen der Argumente auf: Ein Aufruf mit den bisherigen vier Argumenten
 * passte dann auf beide und waere mehrdeutig. Deshalb ein eigener Name.
 */

-- ------------------------------------------- 1. Nur noch Vereinsumfragen

create or replace function public.umfrage_melden()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not new.active then return new; end if;
  /* Chat-Abstimmungen melden sich selbst, an die Leute ihres Kanals. */
  if new.channel_id is not null then return new; end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select m.profile_id, new.club_id, 'polls',
         public.meldungstext('umfrage.titel', p.language),
         public.meldungstext('umfrage.text', p.language),
         'umfrage', new.id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and public.meldung_erlaubt(m.profile_id, 'polls');

  return new;
end;
$$;

-- ------------------------------------------------ 2. Meldungen mit Ziel

create or replace function public.notify_many_ziel(
  target_memberships uuid[],
  p_notif_type text,
  p_title text,
  p_body text,
  p_ziel_art text default null,
  p_ziel_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  ziel uuid;
begin
  foreach ziel in array coalesce(target_memberships, '{}'::uuid[]) loop
    /* Wortgleich zu notify_many: Nur wer zum selben Verein gehoert, darf ihn
       anschreiben. Fremde Kennungen werden still uebergangen, damit eine
       Nachricht an dreissig Leute nicht an einer veralteten Kennung
       scheitert. */
    if auth.uid() is null
       or exists (select 1 from public.club_memberships m
                   where m.id = ziel and public.is_club_member(m.club_id))
    then
      perform public.notify(ziel, p_notif_type, p_title, p_body,
        case when p_ziel_art is null then '{}'::jsonb
             else jsonb_build_object('ziel_art', p_ziel_art, 'ziel_id', p_ziel_id) end);
    end if;
  end loop;
end;
$$;

/* Postgres vergibt EXECUTE auf neue Funktionen an PUBLIC - also auch an den
   nicht angemeldeten Zugriff. Bei security definer heisst das: Sie liefe mit
   den Rechten des Eigentuemers, angestossen von irgendwem. */
revoke all on function public.notify_many_ziel(uuid[],text,text,text,text,uuid) from public, anon;
grant execute on function public.notify_many_ziel(uuid[],text,text,text,text,uuid) to authenticated;
