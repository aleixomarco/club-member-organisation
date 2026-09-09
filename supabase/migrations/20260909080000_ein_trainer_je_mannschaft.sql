/* Eine Mannschaft hat einen Trainer.

 * WARUM EIN AUSLOESER UND KEIN EINDEUTIGER INDEX
 * Ein "unique index ... where function = 'trainer'" waere die knappere
 * Schreibweise - er liesse sich heute aber gar nicht anlegen: In Herren 1
 * stehen ZWEI Trainer. Der Index wuerde beim Einspielen scheitern, und der
 * einzige Weg daran vorbei waere, einen der beiden ungefragt zu entfernen.
 * Wen es trifft, entscheidet der Verein, nicht diese Migration.
 *
 * Der Ausloeser wirkt deshalb nur nach vorn: Ein ZWEITER Trainer laesst sich
 * ab jetzt nicht mehr eintragen, der bestehende Doppelfall bleibt stehen und
 * bleibt sichtbar. Ist er aufgeloest, kann der Index nachgereicht werden.
 *
 * Bewusst eine Ausnahme statt stillem Verwerfen: Wer einen zweiten Trainer
 * einträgt, soll den Grund lesen. Stilles Verwerfen erzeugt genau die Sorte
 * Fehler, bei der die App Erfolg meldet und nichts passiert.
 *
 * Teammanager sind ausdruecklich NICHT betroffen - von denen darf es mehrere
 * geben; das ist eine andere Funktion.
 */

create or replace function public.nur_ein_trainer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_vorhanden int;
begin
  if new.function is distinct from 'trainer' then return new; end if;

  select count(*) into v_vorhanden
  from public.team_members tm
  where tm.team_id = new.team_id
    and tm.function = 'trainer'
    /* Der Schluessel der Tabelle ist (team_id, membership_id) - eine Spalte
       "id" gibt es nicht. Ohne diesen Ausschluss wuerde ein UPDATE auf die
       eigene Zeile sich selbst als zweiten Trainer zaehlen. */
    and tm.membership_id is distinct from new.membership_id;

  if v_vorhanden > 0 then
    raise exception 'Diese Mannschaft hat bereits eine Trainerin oder einen Trainer.'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists team_members_ein_trainer on public.team_members;
create trigger team_members_ein_trainer
  before insert or update of function, team_id on public.team_members
  for each row execute function public.nur_ein_trainer();

revoke all on function public.nur_ein_trainer() from public, anon, authenticated;
