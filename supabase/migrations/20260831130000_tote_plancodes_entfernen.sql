-- Tote Plancodes entfernen.
--
-- In subscription_plans lagen achtzehn Einträge, benutzt war genau einer.
-- Der Rest stammt aus Modellen, die es nicht mehr gibt:
--
--   club_addon_*    aus dem verworfenen Zusatzpaket-Modell (Aufstockung in
--                   Hunderterschritten), nie verkauft
--   club_monthly    aus der Zeit vor der Größenstaffel, als es nur einen
--   club_yearly     einzigen Vereinstarif gab
--   member_*        der persönliche Zugang für Mitglieder. Mitglieder zahlen
--                   seit dem Umbau auf die Größenstaffel nichts mehr, und
--                   member_has_access() liefert seither immer wahr.
--
-- Solche Reste sind nicht bloß unordentlich. Am 30.08. kam ein Store-Ereignis
-- für member_monthly herein und wurde abgewiesen, weil das Produkt zwar noch
-- existierte, aber unter einer Vereins-Kennung gemeldet wurde. Was es nicht
-- mehr gibt, kann auch nicht mehr für Verwirrung sorgen.
--
-- Bleiben: basic, plus und pro in monatlich und jährlich - die drei Stufen, mit
-- denen verein_freischalten() arbeitet - sowie club_premium_*, an dem die drei
-- bestehenden manuellen Freischaltungen hängen.

delete from public.subscription_plans p
 where p.code in (
   'club_addon_100_monthly', 'club_addon_250_monthly', 'club_addon_500_monthly',
   'club_addon_1000_monthly', 'club_addon_1500_monthly', 'club_addon_2000_monthly',
   'club_monthly', 'club_yearly',
   'member_monthly', 'member_yearly'
 )
 -- Sicherheitsnetz: Was wider Erwarten doch benutzt wird, bleibt stehen.
 and not exists (select 1 from public.club_subscriptions s where s.plan_id = p.id)
 and not exists (select 1 from public.user_subscriptions u where u.plan_id = p.id);

-- Kontrolle: Welche Codes bleiben, und hängt an jedem noch etwas?
select p.code,
       (select count(*) from public.club_subscriptions s where s.plan_id = p.id) as vereins_abos
  from public.subscription_plans p
 order by p.code;
