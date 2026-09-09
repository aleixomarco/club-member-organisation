/* Der Rollenabgleich darf die Vereinsleitung nicht mit aussperren.

 * WAS PASSIERT WAERE
 * sync_club_role_entitlement raeumt die Rollen auf, wenn ein Verein keinen
 * Tarif (mehr) hat - gedacht als Sperre der bezahlten Funktionen. Sie loeschte
 * dabei ALLES ausser "mitglied":
 *     delete from public.membership_roles where role <> 'mitglied' ...
 *
 * register_new_club legt aber KEINE Zeile in club_subscriptions an. Ein frisch
 * gegruendeter Verein steht damit auf Tarif 'none', und die App ruft den
 * Abgleich beim ersten Laden von selbst auf (app/page.tsx, useEntitlement).
 * Der Gruender - der Sekunden zuvor mitglied, vereinsadmin UND sysadmin
 * bekommen hat - stand danach als einfaches Mitglied da.
 *
 * Und zwar endgueltig: Rollen vergeben darf nur ein Vereinsadministrator, und
 * den Bildschirm "Zugang & Empfehlungen", ueber den der Verein freigeschaltet
 * wird, sieht auch nur er. Wer seinen Verein anlegt, haette sich also selbst
 * ausgesperrt und dazu niemanden mehr, der es zuruecknehmen koennte.
 *
 * Die beiden bestehenden Vereine haben ein Abo (basic und pro) - dort ist es
 * nie eingetreten. Getroffen haette es jeden NEUEN Verein, also genau den
 * Weg, ueber den die App wachsen soll.
 *
 * DIE BEHEBUNG
 * vereinsadmin und sysadmin bleiben stehen. Das widerspricht dem Zweck nicht,
 * sondern stellt ihn her: Gesperrt werden sollen die bezahlten Funktionen -
 * Trainer, Redaktion, Sponsoring, Organisation. Wer den Verein verwaltet,
 * muss erreichbar bleiben, sonst kann niemand den Tarif wieder in Ordnung
 * bringen. Eine Sperre, die den einzigen Menschen aussperrt, der sie
 * aufheben koennte, ist keine Sperre, sondern ein Ausfall.
 *
 * Der uebrige Rumpf bleibt woertlich, einschliesslich der Einschraenkung auf
 * den eigenen Verein aus 20260907130000.
 */
create or replace function public.sync_club_role_entitlement(target_club uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier text;
begin
  v_tier := public.club_subscription_tier(target_club);

  /* Nur im eigenen Verein aufraeumen. Der Tarif darf jeder erfragen - das
     verraet nichts, was nicht ohnehin sichtbar waere -, aber loeschen nur,
     wer dazugehoert. */
  if v_tier = 'none' and public.is_club_member(target_club) then
    delete from public.membership_roles
    where role not in ('mitglied', 'vereinsadmin', 'sysadmin')
      and membership_id in (select id from public.club_memberships where club_id = target_club);
  end if;
  return v_tier;
end;
$$;
