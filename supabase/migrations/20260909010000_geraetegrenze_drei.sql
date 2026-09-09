/* Geraetegrenze von zwei auf drei.
 *
 * Zwei war zu knapp fuer die Art, wie die App benutzt wird: Telefon, Rechner
 * im Verein und ein zweiter Browser sind drei - und beim dritten Anmelden
 * wurde das aelteste Geraet stillschweigend abgemeldet. Beim naechsten Start
 * stand dort "Dieses Geraet wurde abgemeldet, weil dein Konto inzwischen auf
 * zwei anderen Geraeten angemeldet ist."
 *
 * In den Daten war das zu sehen: Der Pruefzugang lag bei fuenf Geraeten, ein
 * weiteres Konto bei drei - beide wurden also reihum hinausgeworfen.
 *
 * Geaendert wird EINE Zahl. Der Rest der Funktion bleibt wortgleich; die
 * Ausnahme ueber profiles.geraetegrenze_aus gilt unveraendert, ebenso die
 * Reihenfolge (juengste zuerst, aelteste fliegen raus).
 *
 * Warum ueberhaupt eine Grenze: Sie ist der Schutz davor, dass ein Konto
 * herumgereicht wird - ein Verein zahlt nach Zahl der Zugaenge. Drei ist
 * grosszuegig genug fuer eine Person mit mehreren Geraeten und immer noch zu
 * wenig fuer eine ganze Mannschaft.
 */

create or replace function public.geraet_anmelden(kennung text, bezeichnung text default null)
returns table(erlaubt boolean, geraete integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  grenze constant integer := 3;
  wer uuid := auth.uid();
  ausgenommen boolean;
begin
  if wer is null then raise exception 'Authentication required'; end if;
  if nullif(trim(kennung), '') is null then raise exception 'Geraetekennung fehlt'; end if;

  insert into public.user_devices (profile_id, device_id, device_name)
  values (wer, trim(kennung), nullif(trim(bezeichnung), ''))
  on conflict (profile_id, device_id) do update
    set last_seen = now(),
        device_name = coalesce(excluded.device_name, public.user_devices.device_name);

  select coalesce(p.geraetegrenze_aus, false) into ausgenommen
    from public.profiles p where p.id = wer;

  if not ausgenommen then
    delete from public.user_devices d
     where d.profile_id = wer
       and d.id not in (
         select d2.id from public.user_devices d2
          where d2.profile_id = wer
          order by d2.last_seen desc
          limit grenze
       );
  end if;

  return query
    select exists (
      select 1 from public.user_devices d
       where d.profile_id = wer and d.device_id = trim(kennung)
    ),
    (select count(*)::integer from public.user_devices d where d.profile_id = wer);
end;
$$;

revoke all on function public.geraet_anmelden(text, text) from public, anon;
grant execute on function public.geraet_anmelden(text, text) to authenticated;
