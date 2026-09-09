/* Drei Fehler aus der systemweiten Pruefung, alle am Original nachgewiesen.

 * 1) chatnachricht_melden verwechselte zwei Kennungen
 *    messages.author_id zeigt auf profiles(id) - nachgeprueft am
 *    Fremdschluessel. Die Funktion behandelte sie aber als
 *    club_memberships(id):
 *      select display_name into v_wer from club_memberships where id = new.author_id;
 *      ... and m.id is distinct from new.author_id
 *    Beides trifft nie zu. Folgen im Betrieb:
 *      - v_wer bleibt NULL, in jeder Chat-Meldung stand "Jemand: ..." statt
 *        des Absendernamens
 *      - der Absender wurde NICHT ausgeschlossen und bekam jede eigene
 *        Nachricht als Meldung und als Push zurueck
 *    Der Verein hat vier Mitglieder mit Push; jede Chatnachricht ging also
 *    einmal zu viel hinaus, und zwar an den, der sie gerade geschrieben hat.
 *
 * 2) Die UPDATE-Regel auf club_tasks hatte kein "with check"
 *    Ohne das prueft Postgres nur, welche Zeile man ANFASSEN darf - nicht,
 *    wie sie danach aussieht. Der Ersteller einer Aufgabe konnte sie deshalb
 *    per club_id in einen fremden Verein schieben. Die Bedingung ist jetzt
 *    beidseitig dieselbe.
 *
 * 3) service_role fehlte EXECUTE auf drei Funktionen des Rechnungsablaufs
 *    anfrage_weiter, bestaetigung_vermerken und guthaben_einloesen werden
 *    ausschliesslich aus der Betreiberkonsole ueber den Dienstschluessel
 *    gerufen (app/api/betreiber/aktion/route.ts). 20260902210000 hat allen
 *    damals vorhandenen Funktionen die Rechte entzogen und sie danach gezielt
 *    wieder vergeben - diese drei sind dabei durchgefallen. Jeder Schritt im
 *    Rechnungsablauf scheiterte seitdem mit "permission denied for function".
 *    Nachgeprueft: has_function_privilege('service_role', ..., 'EXECUTE')
 *    war fuer genau diese drei false, fuer alle uebrigen Betreiber-Funktionen
 *    true.
 */

create or replace function public.chatnachricht_melden()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_club  uuid;
  v_team  uuid;
  v_wer   text;
  v_text  text;
begin
  select c.club_id, c.team_id into v_club, v_team from public.channels c where c.id = new.channel_id;
  if v_club is null then return new; end if;

  /* Ueber profile_id UND club_id: Dieselbe Person kann in mehreren Vereinen
     Mitglied sein, und der Name soll der aus DIESEM Verein sein. */
  select m.display_name into v_wer
    from public.club_memberships m
   where m.profile_id = new.author_id and m.club_id = v_club
   order by (m.status = 'active') desc
   limit 1;

  v_text := case when length(new.body) > 90 then left(new.body, 90) || ' …' else new.body end;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, v_club, 'chat',
         coalesce(v_wer, public.meldungstext('chat.titel', p.language)),
         coalesce(v_wer, public.meldungstext('allg.jemand', p.language)) || ': ' || v_text
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm on tm.membership_id = m.id and tm.team_id = v_team
  where m.club_id = v_club and m.status = 'active' and m.profile_id is not null
    /* Der Absender bekommt seine eigene Nachricht nicht gemeldet. Verglichen
       wird jetzt Profil mit Profil - vorher stand hier m.id, eine
       Mitgliedschaftskennung, und der Vergleich ging immer aus. */
    and m.profile_id is distinct from new.author_id
    and (v_team is null or tm.membership_id is not null)
    and public.team_meldung_erlaubt(m.id, v_team, 'chat')
    and public.meldung_erlaubt(m.profile_id, 'chat');
  return new;
end;
$function$;

drop policy if exists "authorized members update tasks" on public.club_tasks;
create policy "authorized members update tasks" on public.club_tasks
  for update
  using (
    created_by in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
    or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  )
  with check (
    created_by in (select m.id from public.club_memberships m where m.profile_id = auth.uid())
    or public.has_club_role(club_id, array['vereinsadmin','sysadmin','organisator']::public.club_role[])
    or (team_id is not null and public.can_manage_team(team_id))
  );

grant execute on function public.anfrage_weiter(uuid, text, text, numeric, text, text) to service_role;
grant execute on function public.bestaetigung_vermerken(uuid) to service_role;
grant execute on function public.guthaben_einloesen(uuid, integer) to service_role;
