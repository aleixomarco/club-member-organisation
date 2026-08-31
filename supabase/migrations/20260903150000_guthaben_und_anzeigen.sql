-- Zwei Dinge, die dem Betreiber bisher fehlten.
--
-- 1. Das Empfehlungsguthaben. „Vereine werben Vereine" schreibt dem
--    empfehlenden Verein drei Monate gut (clubs.referral_credit_months), und
--    die App sagt dem Werber ausdrücklich zu, das werde „automatisch
--    berücksichtigt". Berücksichtigt hat es bisher niemand: Die Zahl stand in
--    keiner Übersicht, und verein_freischalten() liest sie nicht. Wer eine
--    Rechnung schreibt, muss sie sehen — sonst ist die Zusage eine Lüge.
--
-- 2. Die Werbeplätze des Betreibers. anzeigen mit club_id = null gelten in
--    jedem Verein, aber es gab keinen Weg, eine anzulegen außer von Hand im
--    SQL-Editor.

drop view if exists public.betreiber_uebersicht;
create view public.betreiber_uebersicht with (security_invoker = true) as
select
  c.id,
  c.name,
  c.short_name,
  c.city,
  c.sport::text as sport,
  c.created_at,
  c.vereinbarte_zugaenge,
  c.sponsoring_freigeschaltet,
  -- Offene Gutschrift aus Empfehlungen, in Monaten.
  c.referral_credit_months,
  public.club_subscription_tier(c.id) as tarif,
  public.club_account_limit(c.id) as grenze,
  public.club_account_count(c.id) as konten,
  (select max(s.current_period_end)
     from public.club_subscriptions s
    where s.club_id = c.id and s.status = 'active') as laeuft_bis,
  (select s.provider_subscription_id
     from public.club_subscriptions s
    where s.club_id = c.id and s.status = 'active'
    order by s.current_period_end desc nulls last limit 1) as beleg,
  (select count(*) from public.club_memberships m
    where m.club_id = c.id and m.status = 'active') as mitglieder,
  (select count(*) from public.club_memberships m
    where m.club_id = c.id and m.status = 'pending') as offene_aufnahmen,
  (select count(*) from public.anzeigen a
    where a.club_id = c.id and a.aktiv) as eigene_sponsoren,
  (select m.display_name || ' <' || coalesce(m.email, '—') || '>'
     from public.club_memberships m
     join public.membership_roles r on r.membership_id = m.id
    where m.club_id = c.id and m.status = 'active' and r.role = 'vereinsadmin'
    order by m.created_at limit 1) as ansprechpartner
from public.clubs c;

revoke all on public.betreiber_uebersicht from anon, authenticated;
grant select on public.betreiber_uebersicht to service_role;

/* Das Guthaben verbrauchen.
 *
 * Ausdrücklich ein eigener Aufruf und kein Automatismus in
 * verein_freischalten(): Ob die drei Monate als Rabatt auf die Rechnung gehen
 * oder als Verlängerung der Laufzeit, entscheidet der Betreiber beim Angebot.
 * Was hier passiert, ist die Verlängerung — und der Verbrauch wird abgezogen,
 * damit dieselben Monate nicht zweimal gutgeschrieben werden. */
create or replace function public.guthaben_einloesen(target_club uuid, monate integer default null)
returns table (verein text, eingeloest integer, rest integer, laeuft_bis timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  offen integer;
  nimm integer;
begin
  select referral_credit_months into offen from public.clubs where id = target_club;
  if offen is null then raise exception 'Verein % existiert nicht', target_club; end if;

  nimm := least(coalesce(monate, offen), offen);
  if nimm <= 0 then
    return query
      select c.name, 0, c.referral_credit_months,
             (select max(s.current_period_end) from public.club_subscriptions s
               where s.club_id = c.id and s.status = 'active')
        from public.clubs c where c.id = target_club;
    return;
  end if;

  update public.club_subscriptions
     set current_period_end = current_period_end + (nimm || ' months')::interval
   where club_id = target_club and status = 'active';

  update public.clubs
     set referral_credit_months = referral_credit_months - nimm
   where id = target_club;

  return query
    select c.name, nimm, c.referral_credit_months,
           (select max(s.current_period_end) from public.club_subscriptions s
             where s.club_id = c.id and s.status = 'active')
      from public.clubs c where c.id = target_club;
end;
$$;

revoke all on function public.guthaben_einloesen(uuid, integer) from public, anon, authenticated;
