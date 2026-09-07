/* Vater, Mutter, Sohn, Tochter, Oma, Opa.
 *
 * Bisher gab es zwei Woerter: "eltern" und "kind". Leute sagen aber nicht
 * "ich stehe zu ihm in der Beziehung eltern", sondern "ich bin sein Vater".
 *
 * WARUM DIE AUFZAEHLUNG NICHT ERWEITERT WIRD
 * family_relation traegt nicht nur Text, sondern Rechte. gehoert_zu_mannschaft
 * bestimmt darueber, welche Mannschaften jemand sehen darf:
 *
 *   when f.first_to_second = 'eltern' then f.second_membership_id
 *
 * Ein Elternteil sieht die Mannschaft seines Kindes - Chat, Termine,
 * Zu- und Absagen. Stuende dort kuenftig 'vater' statt 'eltern', faende diese
 * Bedingung ihn nicht mehr, und er verlöre den Zugang zur Mannschaft seines
 * Kindes. Still, ohne Fehlermeldung, und niemand wuesste warum.
 *
 * Denselben Wert tragen ausserdem create_managed_child und die Leseregeln auf
 * family_links. Fuer eine schoenere Bezeichnung ist mir dieser Weg zu teuer.
 *
 * Deshalb: Der Grad bleibt, wie er ist, und bekommt ein Wort daneben. Die
 * Aufzaehlung entscheidet weiter ueber Rechte, die Bezeichnung steht nur da,
 * damit im Profil "Vater" steht und nicht "Elternteil". Beides kann nicht
 * auseinanderlaufen, weil die Bezeichnung nirgends ausgewertet wird.
 */

alter table public.family_links
  add column if not exists first_label text,
  add column if not exists second_label text;

/* Freier Text waere hier ein offenes Feld in einer Tabelle, die jeder
   Vereinsangehoerige beschreiben darf. Die Pruefung haelt es bei dem, was die
   Auswahl anbietet. */
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'family_links_bezeichnungen') then
    alter table public.family_links add constraint family_links_bezeichnungen check (
      (first_label is null or first_label in ('vater','mutter','sohn','tochter','opa','oma'))
      and (second_label is null or second_label in ('vater','mutter','sohn','tochter','opa','oma'))
    );
  end if;
end $$;

/* create_family_link bekommt die Bezeichnung dazu.
 *
 * Die alte Fassung wird geloescht statt ergaenzt: Ein zusaetzlicher Parameter
 * mit Vorgabewert waere eine zweite Funktion gleichen Namens, und PostgREST
 * loest Aufrufe ueber die Namen der Argumente auf - ein Aufruf mit den
 * bisherigen vier passte dann auf beide und waere mehrdeutig. */
drop function if exists public.create_family_link(uuid, uuid, uuid, public.family_relation);

create or replace function public.create_family_link(
  target_club uuid,
  acting_membership uuid,
  related_membership uuid,
  acting_relation public.family_relation,
  acting_label text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  acting_is_owner boolean;
  acting_is_sysadmin boolean;
  opposite_relation public.family_relation;
  first_id uuid;
  second_id uuid;
  first_relation public.family_relation;
  second_relation public.family_relation;
  first_lab text;
  second_lab text;
  result_id uuid;
begin
  if auth.uid() is null or acting_membership = related_membership then
    raise exception 'Not authorized';
  end if;

  select exists (
    select 1 from public.club_memberships m
    where m.id = acting_membership and m.club_id = target_club and m.profile_id = auth.uid()
  ) into acting_is_owner;
  select public.has_club_role(target_club, array['sysadmin']::public.club_role[]) into acting_is_sysadmin;

  if not acting_is_owner and not acting_is_sysadmin then raise exception 'Not authorized'; end if;
  if not exists (
    select 1 from public.club_memberships m
    where m.id = related_membership and m.club_id = target_club and m.status in ('active', 'pending')
  ) then raise exception 'Related membership not found'; end if;

  opposite_relation := case acting_relation
    when 'eltern' then 'kind'::public.family_relation
    when 'kind' then 'eltern'::public.family_relation
    when 'partner' then 'partner'::public.family_relation
    when 'grosseltern' then 'kind'::public.family_relation
    else 'sonstige'::public.family_relation
  end;

  /* Die Bezeichnung gilt nur fuer die Seite, die sie angegeben hat. Was die
     andere Person fuer einen ist, weiss man daraus nicht: Der Vater eines
     Kindes hat einen Sohn ODER eine Tochter, und welches von beidem, sagt
     seine eigene Angabe nicht. Die andere Seite bleibt deshalb leer und zeigt
     den allgemeinen Grad, bis diese Person selbst etwas eintraegt. */
  if acting_label is not null and acting_label not in ('vater','mutter','sohn','tochter','opa','oma') then
    acting_label := null;
  end if;

  /* Die Reihenfolge im Datensatz ist willkuerlich, aber fest: Bezeichnung und
     Grad muessen zur selben Seite gehoeren. */
  /* Verglichen wird als TEXT, nicht als uuid - wortgleich zum Original.
     Beide Ordnungen sind fuer sich genommen richtig, aber sie sind nicht
     dieselbe: Waehlte diese Fassung eine andere, landete dasselbe Paar in
     einer zweiten Zeile statt in der vorhandenen, und die Verknuepfung
     stuende doppelt da. */
  if acting_membership::text < related_membership::text then
    first_id := acting_membership;  second_id := related_membership;
    first_relation := acting_relation; second_relation := opposite_relation;
    first_lab := acting_label; second_lab := null;
  else
    first_id := related_membership; second_id := acting_membership;
    first_relation := opposite_relation; second_relation := acting_relation;
    first_lab := null; second_lab := acting_label;
  end if;

  insert into public.family_links (club_id, first_membership_id, second_membership_id,
      first_to_second, second_to_first, first_label, second_label, created_by)
  values (target_club, first_id, second_id, first_relation, second_relation,
      first_lab, second_lab, auth.uid())
  on conflict (club_id, first_membership_id, second_membership_id) do update
    set first_to_second = excluded.first_to_second,
        second_to_first = excluded.second_to_first,
        /* Eine vorhandene Bezeichnung der GEGENseite bleibt stehen: Wer seine
           eigene eintraegt, soll nicht loeschen, was der andere angegeben
           hat. */
        first_label = coalesce(excluded.first_label, family_links.first_label),
        second_label = coalesce(excluded.second_label, family_links.second_label)
  returning id into result_id;

  return result_id;
end;
$$;

revoke all on function public.create_family_link(uuid,uuid,uuid,public.family_relation,text) from public, anon;
grant execute on function public.create_family_link(uuid,uuid,uuid,public.family_relation,text) to authenticated;
