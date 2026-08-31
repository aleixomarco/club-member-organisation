-- Das Postfach: Benachrichtigungen, die bisher niemand lesen konnte.
--
-- user_notifications füllt sich seit Wochen. Jeder angelegte oder geänderte
-- Termin schreibt für den ganzen betroffenen Kreis eine Zeile, dazu kommen
-- News, Protokolle, Umfragen, Strafen und Fahrgemeinschaften. In der App gibt
-- es keine einzige Stelle, die diese Tabelle liest.
--
-- Das ist doppelt unangenehm: In den Einstellungen kann jemand auswählen,
-- worüber er benachrichtigt werden möchte — und wird es nie. Und die Tabelle
-- wächst unbegrenzt weiter.
--
-- Hier die Datenbankseite dazu: Rechte, ein Aufräumen und eine Zählung.

grant select, update, delete on public.user_notifications to authenticated;

-- Gelesenes darf man wegräumen.
drop policy if exists "users delete own notifications" on public.user_notifications;
create policy "users delete own notifications" on public.user_notifications
for delete to authenticated using (profile_id = auth.uid());

create index if not exists user_notifications_postfach_idx
  on public.user_notifications(profile_id, created_at desc);

/* Wie viele ungelesen sind. Eine eigene Abfrage dafür, weil die Kopfzeile die
   Zahl bei jedem Öffnen braucht und nicht die ganze Liste laden soll. */
create or replace function public.ungelesene_benachrichtigungen(target_club uuid default null)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.user_notifications n
   where n.profile_id = auth.uid()
     and n.read_at is null
     and (target_club is null or n.club_id = target_club);
$$;

grant execute on function public.ungelesene_benachrichtigungen(uuid) to authenticated;

/* Alles als gelesen markieren - ein Knopf, eine Abfrage. */
create or replace function public.benachrichtigungen_gelesen(target_club uuid default null)
returns integer language sql volatile security definer set search_path = '' as $$
  with erledigt as (
    update public.user_notifications n set read_at = now()
     where n.profile_id = auth.uid() and n.read_at is null
       and (target_club is null or n.club_id = target_club)
    returning 1
  )
  select count(*)::integer from erledigt;
$$;

grant execute on function public.benachrichtigungen_gelesen(uuid) to authenticated;

/* Aufräumen. Gelesenes nach 90 Tagen, Ungelesenes nach einem Jahr - wer ein
   Jahr nicht hineingeschaut hat, braucht die Meldung von damals nicht mehr.
   Ohne das wächst die Tabelle für immer. */
create or replace function public.run_benachrichtigungen_aufraeumen()
returns integer language sql volatile security definer set search_path = '' as $$
  with weg as (
    delete from public.user_notifications
     where (read_at is not null and read_at < now() - interval '90 days')
        or created_at < now() - interval '365 days'
    returning 1
  )
  select count(*)::integer from weg;
$$;

revoke all on function public.run_benachrichtigungen_aufraeumen() from public, anon, authenticated;

select cron.schedule('benachrichtigungen-aufraeumen', '30 4 * * 0',
                     'select public.run_benachrichtigungen_aufraeumen();');
