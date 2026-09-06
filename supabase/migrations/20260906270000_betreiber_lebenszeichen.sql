-- Was das Betreiber-Board bisher nicht zeigen konnte: ob ein Verein lebt.
--
-- DAS PROBLEM
-- Die Uebersicht sagt, welchen Tarif ein Verein hat, wie viele Zugaenge
-- vereinbart sind und wer der Ansprechpartner ist. Sie sagt nicht, ob
-- ueberhaupt jemand die App benutzt. Ein Verein kann bezahlen und trotzdem
-- still sein - niemand traegt Termine ein, im Chat steht nichts, auf
-- Umfragen antwortet keiner. Das ist der Verein, der in drei Monaten
-- kuendigt, und man erfaehrt es erst, wenn die Kuendigung da ist.
--
-- WARUM AKTIVITAET UND NICHT ANMELDUNG
-- Naheliegend waere der Zeitpunkt der letzten Anmeldung. Der sagt aber
-- weniger, als er verspricht: Wer die App einmal geoeffnet und sofort
-- wieder geschlossen hat, zaehlt darin genauso wie jemand, der den halben
-- Spielplan eingetragen hat. Gezaehlt wird deshalb, was jemand GETAN hat -
-- eine Nachricht geschrieben, einen Termin angelegt, zu- oder abgesagt,
-- abgestimmt, ein Ergebnis eingetragen. Das steht alles im oeffentlichen
-- Schema; der Anmeldebereich der Datenbank wird dafuer nicht gebraucht.
--
-- VIER ZAHLEN, DIE ES VERRATEN
-- letzte_aktivitaet  Wann hat zuletzt IRGENDJEMAND etwas getan?
-- aktive_30          Wie viele verschiedene Menschen waren es im letzten Monat?
-- termine_30         Wurde etwas eingetragen, oder ist der Kalender leer?
-- nachrichten_30     Wird im Verein geredet?
--
-- Zusammen erzaehlen sie eine Geschichte, die einzeln keine erzaehlt: Ein
-- Verein mit 80 Mitgliedern und drei aktiven Nutzern ist ein anderer Fall
-- als einer mit 80 Mitgliedern und 60 aktiven - auch wenn beide denselben
-- Tarif zahlen.
--
-- WARUM IN DER SICHT UND NICHT IN DER OBERFLAECHE
-- Die Oberflaeche muesste sonst fuer jeden Verein vier weitere Abfragen
-- schicken. Bei zwanzig Vereinen sind das achtzig Abfragen fuer eine
-- Tabelle, die auf einen Bildschirm passt.

/* Wer hat in diesem Verein zuletzt etwas getan - und wer war es?
   Eine Hilfssicht, damit die Uebersichts-Sicht und die Kennzahlen
   dieselbe Definition von "aktiv" benutzen und nicht auseinanderlaufen. */
create or replace view public.vereins_aktivitaet as
  select ch.club_id, m.author_id as membership_id, m.created_at
    from public.messages m
    join public.channels ch on ch.id = m.channel_id
  union all
  select e.club_id, null::uuid, e.created_at from public.events e
  union all
  select e.club_id, a.membership_id, a.updated_at
    from public.event_attendance a
    join public.events e on e.id = a.event_id
  union all
  select e.club_id, d.membership_id, d.created_at
    from public.duty_assignments d
    join public.events e on e.id = d.event_id
  union all
  select r.club_id, null::uuid, r.created_at from public.event_results r;

create or replace view public.betreiber_uebersicht as
 select c.id,
    c.name,
    c.short_name,
    c.city,
    c.sport::text as sport,
    c.created_at,
    c.vereinbarte_zugaenge,
    c.sponsoring_freigeschaltet,
    c.referral_credit_months,
    public.club_subscription_tier(c.id) as tarif,
    public.club_account_limit(c.id) as grenze,
    public.club_account_count(c.id) as konten,
    (select max(s.current_period_end) from public.club_subscriptions s
      where s.club_id = c.id and s.status = 'active') as laeuft_bis,
    (select s.provider_subscription_id from public.club_subscriptions s
      where s.club_id = c.id and s.status = 'active'
      order by s.current_period_end desc nulls last limit 1) as beleg,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.status = 'active') as mitglieder,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.status = 'pending') as offene_aufnahmen,
    (select count(*) from public.anzeigen a
      where a.club_id = c.id and a.aktiv) as eigene_sponsoren,
    (select ((m.display_name || ' <') || coalesce(m.email, '—')) || '>'
       from public.club_memberships m
       join public.membership_roles r on r.membership_id = m.id
      where m.club_id = c.id and m.status = 'active' and r.role = 'vereinsadmin'
      order by m.created_at limit 1) as ansprechpartner,
    /* --- ab hier neu --- */
    c.hidden,
    (select max(v.created_at) from public.vereins_aktivitaet v
      where v.club_id = c.id) as letzte_aktivitaet,
    (select count(distinct v.membership_id) from public.vereins_aktivitaet v
      where v.club_id = c.id and v.membership_id is not null
        and v.created_at > now() - interval '30 days') as aktive_30,
    (select count(*) from public.events e
      where e.club_id = c.id and e.created_at > now() - interval '30 days') as termine_30,
    (select count(*) from public.messages n
      join public.channels ch on ch.id = n.channel_id
      where ch.club_id = c.id and n.created_at > now() - interval '30 days') as nachrichten_30
   from public.clubs c;

grant select on public.betreiber_uebersicht to service_role;

-- Die Zahlen ueber alle Vereine hinweg.
--
-- Ohne sie sieht der Betreiber jeden Verein einzeln, aber nie das Ganze:
-- Wachsen wir? Wie verteilen sich die Tarife? Wie viele Konten haben wir
-- insgesamt zu tragen? Das ist die Zeile, die man morgens ansieht.
create or replace function public.betreiber_kennzahlen()
returns table (
  vereine bigint, freigeschaltet bigint, gesperrt bigint, neu_30 bigint,
  konten bigint, mitglieder bigint, basic bigint, plus bigint, pro bigint,
  ohne_tarif bigint, still_30 bigint, fast_voll bigint
)
language sql stable security definer set search_path = 'public' as $$
  with v as (
    select c.id, c.created_at, c.hidden,
           public.club_subscription_tier(c.id) as tarif,
           public.club_account_limit(c.id) as grenze,
           public.club_account_count(c.id) as konten,
           (select count(*) from public.club_memberships m
             where m.club_id = c.id and m.status = 'active') as mitglieder,
           (select max(a.created_at) from public.vereins_aktivitaet a
             where a.club_id = c.id) as letzte_aktivitaet
    from public.clubs c
  )
  select count(*),
         count(*) filter (where tarif is not null),
         count(*) filter (where hidden),
         count(*) filter (where created_at > now() - interval '30 days'),
         coalesce(sum(konten), 0),
         coalesce(sum(mitglieder), 0),
         count(*) filter (where tarif = 'basic'),
         count(*) filter (where tarif = 'plus'),
         count(*) filter (where tarif = 'pro'),
         count(*) filter (where tarif is null),
         /* Still: seit 30 Tagen ist nichts passiert - oder noch nie etwas. */
         count(*) filter (where letzte_aktivitaet is null
                             or letzte_aktivitaet < now() - interval '30 days'),
         /* Fast voll: 90 Prozent der Zugaenge belegt. Das ist ein Gespraech,
            kein Alarm - aber eines, das man fuehren will, BEVOR jemand
            anruft, weil niemand mehr beitreten kann. */
         count(*) filter (where grenze > 0 and konten >= grenze * 0.9)
  from v;
$$;

grant execute on function public.betreiber_kennzahlen() to service_role;

-- Der Betreiber schreibt der Vereinsleitung.
--
-- Bisher gab es genau zwei Wege, auf einen Verein einzuwirken: freischalten
-- oder sperren. Sperren ist der Holzhammer - der Verein steht still, und
-- niemand weiss warum. Meistens will man vorher etwas sagen: "Eure Zugaenge
-- sind fast voll", "die Rechnung ist offen", "wir schalten am Montag ab".
--
-- Die Nachricht landet in derselben Glocke wie jede andere und loest
-- dieselbe Push-Meldung aus - es gibt keinen zweiten Kanal, den man
-- pflegen muesste.
create or replace function public.betreiber_nachricht_senden(
  target_club uuid, p_titel text, p_text text, p_nur_leitung boolean default true
) returns integer
language plpgsql security definer set search_path = 'public' as $$
declare v_anzahl integer := 0;
begin
  if coalesce(btrim(p_titel), '') = '' or coalesce(btrim(p_text), '') = '' then
    raise exception 'Titel und Text duerfen nicht leer sein';
  end if;

  insert into public.user_notifications (profile_id, club_id, kind, title, body)
  select distinct m.profile_id, target_club, 'betreiber', btrim(p_titel), btrim(p_text)
  from public.club_memberships m
  where m.club_id = target_club and m.status = 'active' and m.profile_id is not null
    and (
      not p_nur_leitung
      or exists (select 1 from public.membership_roles r
                  where r.membership_id = m.id
                    and r.role in ('vereinsadmin', 'sysadmin'))
    );
  get diagnostics v_anzahl = row_count;
  return v_anzahl;
end;
$$;

grant execute on function public.betreiber_nachricht_senden(uuid, text, text, boolean) to service_role;

select
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='betreiber_uebersicht'
      and column_name in ('letzte_aktivitaet','aktive_30','termine_30','nachrichten_30','hidden')) as neue_spalten,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('betreiber_kennzahlen','betreiber_nachricht_senden')) as funktionen;
