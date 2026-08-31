-- Datenbankfunktionen sind nicht für jeden da.
--
-- In PostgreSQL darf standardmäßig JEDER eine neu angelegte Funktion
-- ausführen — auch die Rolle `anon`, unter der jede Anfrage mit dem
-- öffentlichen Schlüssel läuft. Dieser Schlüssel steckt in jeder installierten
-- App und ist damit öffentlich; er soll das auch sein, denn erst die
-- Sicherheitsregeln entscheiden, wer was sieht.
--
-- Bei Funktionen greifen diese Regeln aber nicht: `security definer` heißt, die
-- Funktion läuft mit den Rechten ihres Eigentümers. Wer sie aufrufen darf,
-- entscheidet allein das Ausführungsrecht.
--
-- Aufgefallen beim Abgleich der Datenbank gegen die Migrationen. Das
-- deutlichste Beispiel ist notify_club(): Die Funktion schickt jedem aktiven
-- Mitglied eines Vereins eine Benachrichtigung, prüft dabei aber nirgends, wer
-- sie aufruft. Mit dem öffentlichen Schlüssel und einer Vereins-Kennung hätte
-- jeder Fremde jedem Verein beliebigen Text schicken können — als
-- Push-Nachricht auf die Telefone der Mitglieder. Dasselbe gilt für
-- notify_many() und für die run_*-Funktionen, die eigentlich nur der Zeitplan
-- aufrufen soll.
--
-- Die meisten anderen Funktionen prüfen selbst auf auth.uid() und wären
-- unangemeldet wirkungslos. Sich darauf zu verlassen, wäre trotzdem falsch:
-- Die nächste Funktion, die jemand hinzufügt, erbt wieder das offene Recht.
--
-- Deshalb einmal grundsätzlich: Ausführungsrecht weg von "jeder" und von anon,
-- hin zu authenticated. Triggerfunktionen bleiben unberührt — sie lassen sich
-- ohnehin nicht über die Schnittstelle aufrufen.

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as signatur
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      join pg_type t on t.oid = p.prorettype
     where n.nspname = 'public'
       and t.typname <> 'trigger'
  loop
    execute format('revoke all on function %s from public, anon', f.signatur);
    execute format('grant execute on function %s to authenticated', f.signatur);
    execute format('grant execute on function %s to service_role', f.signatur);
  end loop;
end $$;

-- Zwei Ausnahmen zurück: Freischalten und Sperren eines Vereins gehören
-- ausschliesslich dem Betreiber, der mit dem Dienstschlüssel arbeitet. Ein
-- Vereinsadmin, der sich selbst freischaltet, waere genau das, was diese
-- Trennung verhindern soll.
revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean) from public, anon, authenticated;
revoke all on function public.verein_sperren(uuid) from public, anon, authenticated;

/* notify_club und notify_many pruefen nicht, wer sie aufruft.
 *
 * Das Ausfuehrungsrecht allein genuegt hier nicht: Auch ein angemeldetes
 * Mitglied eines FREMDEN Vereins koennte damit dessen Mitglieder anschreiben.
 * Die Funktionen werden aus der App an vielen Stellen gerufen - nach einer
 * neuen News, einem neuen Termin, einem Tippergebnis -, immer von jemandem,
 * der zu diesem Verein gehoert. Genau das wird jetzt verlangt. */
create or replace function public.notify_club(
  target_club uuid, p_notif_type text, p_title text, p_body text, exclude_profile uuid default null
)
returns void
language plpgsql security definer set search_path = 'public' as $function$
declare
  member record;
begin
  -- Der Zeitplan und der Betreiber duerfen weiterhin ohne Mitgliedschaft.
  if auth.uid() is not null and not public.is_club_member(target_club) then
    raise exception 'Not authorized';
  end if;

  for member in
    select m.id from public.club_memberships m
    where m.club_id = target_club and m.status = 'active'
      and (exclude_profile is null or m.profile_id is distinct from exclude_profile)
  loop
    perform public.notify(member.id, p_notif_type, p_title, p_body);
  end loop;
end;
$function$;

create or replace function public.notify_many(
  target_memberships uuid[], p_notif_type text, p_title text, p_body text
)
returns void
language plpgsql security definer set search_path = 'public' as $function$
declare
  ziel uuid;
begin
  foreach ziel in array coalesce(target_memberships, '{}'::uuid[]) loop
    -- Je Empfaenger pruefen: Nur wer zum selben Verein gehoert, darf ihn
    -- anschreiben. Fremde Kennungen werden still uebergangen statt den ganzen
    -- Aufruf abzubrechen - eine Nachricht an dreissig Leute soll nicht an einer
    -- veralteten Kennung scheitern.
    if auth.uid() is null
       or exists (select 1 from public.club_memberships m
                   where m.id = ziel and public.is_club_member(m.club_id))
    then
      perform public.notify(ziel, p_notif_type, p_title, p_body);
    end if;
  end loop;
end;
$function$;

grant execute on function public.notify_club(uuid, text, text, text, uuid) to authenticated, service_role;
grant execute on function public.notify_many(uuid[], text, text, text) to authenticated, service_role;
revoke all on function public.notify_club(uuid, text, text, text, uuid) from public, anon;
revoke all on function public.notify_many(uuid[], text, text, text) from public, anon;
