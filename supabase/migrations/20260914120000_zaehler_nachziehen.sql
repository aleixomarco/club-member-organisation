-- Die Zahl am App-Symbol auch nach dem Lesen und Loeschen nachziehen.
--
-- Bisher setzte nur der Versand einer NEUEN Mitteilung die Zahl (aps.badge).
-- Zuruecksetzen konnte sie allein die App selbst, ueber das Badge-Plugin - und
-- das steckt erst in den Fassungen ab dem 08.09. Die Fassung 1.2 im App Store
-- hat es nicht: Wer dort alles gelesen hatte, behielt auf dem Symbol die Zahl
-- der letzten Mitteilung, bis die naechste kam. Gemeldet am 14.09.2026: "7
-- oder 2 oder 3" auf dem Symbol, aber nichts Offenes in der Glocke.
--
-- Jetzt geht nach jedem Lesen und Loeschen eine stille Mitteilung ohne Text an
-- die iPhones der Person, nur mit der neuen Zahl (push-versenden, type
-- ZAEHLER). Das wirkt auf jeder installierten Fassung und haelt auch ein
-- zweites Geraet auf demselben Stand.
--
-- Je Anweisung EIN Aufruf je Person, nicht je Zeile: "Alle gelesen" aendert
-- viele Zeilen auf einmal, soll aber nur einmal anklopfen. Deshalb ein
-- Anweisungs-Trigger mit Uebergangstabellen. Die gibt es nur fuer genau ein
-- Ereignis, daher zwei Trigger auf dieselbe Funktion.
--
-- Wie push_anstossen: Faellt der Aufruf aus, darf das NIE das Lesen oder
-- Loeschen verhindern - deshalb der exception-Block.

create or replace function public.push_zaehler_anstossen()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_zeile intern.push_zustellung%rowtype;
  v_profile uuid[];
  v_profil uuid;
begin
  select * into v_zeile from intern.push_zustellung where id;
  if not found or not v_zeile.aktiv then return null; end if;

  /* Nur wer dadurch WENIGER Ungelesene hat. Eine Zeile, die schon gelesen
     war, aendert die Zahl nicht. plpgsql plant jede Abfrage erst, wenn sie
     laeuft - der Verweis auf "nachher" im UPDATE-Zweig stoert den
     DELETE-Trigger also nicht, obwohl es die Tabelle dort nicht gibt. */
  if tg_op = 'UPDATE' then
    select array_agg(distinct v.profile_id) into v_profile
      from vorher v join nachher n on n.id = v.id
     where v.read_at is null and n.read_at is not null;
  else
    select array_agg(distinct v.profile_id) into v_profile
      from vorher v
     where v.read_at is null;
  end if;

  /* Ohne iPhone kein Aufruf - Android zaehlt die Mitteilungen in der Leiste,
     und im Browser gibt es kein Symbol. */
  for v_profil in
    select u.p from unnest(coalesce(v_profile, '{}'::uuid[])) as u(p)
     where exists (select 1 from public.push_subscriptions ps
                     join public.club_memberships m on m.id = ps.membership_id
                    where m.profile_id = u.p and ps.platform = 'ios')
  loop
    perform net.http_post(
      url := v_zeile.ziel_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cmo-signatur', v_zeile.geheimnis
      ),
      body := jsonb_build_object('type', 'ZAEHLER', 'profile_id', v_profil),
      timeout_milliseconds := 30000
    );
  end loop;
  return null;
exception when others then
  raise warning 'Zahl fuer das App-Symbol nicht angestossen: %', sqlerrm;
  return null;
end;
$$;

revoke all on function public.push_zaehler_anstossen() from public, anon, authenticated;

drop trigger if exists user_notifications_zaehler_gelesen on public.user_notifications;
create trigger user_notifications_zaehler_gelesen
after update on public.user_notifications
referencing old table as vorher new table as nachher
for each statement execute function public.push_zaehler_anstossen();

drop trigger if exists user_notifications_zaehler_geloescht on public.user_notifications;
create trigger user_notifications_zaehler_geloescht
after delete on public.user_notifications
referencing old table as vorher
for each statement execute function public.push_zaehler_anstossen();

select
  (select count(*) from pg_trigger
    where tgname in ('user_notifications_zaehler_gelesen', 'user_notifications_zaehler_geloescht')) as zaehler_trigger,
  (select count(*) from pg_trigger where tgname = 'user_notifications_push')                     as push_trigger;
