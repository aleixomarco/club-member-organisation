-- Der Weg von der Anfrage bis zur Freischaltung.
--
-- Bisher kannte eine Anfrage vier Zustände: offen, berechnet, freigeschaltet,
-- abgelehnt. „Berechnet" musste dabei alles abdecken, was zwischen der Anfrage
-- und dem Geld liegt — und ob das Geld überhaupt da war, stand nirgends. Ein
-- Verein liess sich freischalten, ohne dass jemand die Zahlung gesehen hatte.
--
-- Jetzt ein Ablauf, der die Wirklichkeit abbildet:
--
--   offen              die Anfrage liegt da
--   rechnung_erstellt  Rechnung geschrieben, noch nicht raus
--   rechnung_versendet beim Verein
--   rechnung_bezahlt   Geld da  ->  ERST JETZT ist Freischalten möglich
--   freigeschaltet     der Verein hat seinen Zugang
--   abgelehnt          mit Grund, damit man in einem halben Jahr noch weiss warum
--
-- Jeder Schritt bekommt seinen Zeitpunkt. Das ist keine Bürokratie: Wenn ein
-- Verein anruft und fragt, wo seine Freischaltung bleibt, ist der Unterschied
-- zwischen „Rechnung ist seit drei Wochen raus" und „wir haben sie nie
-- geschickt" die ganze Auskunft.

alter table public.club_access_requests
  add column if not exists rechnungsnummer text,
  add column if not exists betrag numeric(10,2) check (betrag is null or betrag >= 0),
  add column if not exists zahlweise text check (zahlweise is null or zahlweise in ('monatlich', 'jaehrlich')),
  add column if not exists rechnung_erstellt_am timestamptz,
  add column if not exists rechnung_versendet_am timestamptz,
  add column if not exists bezahlt_am timestamptz,
  add column if not exists freigeschaltet_am timestamptz,
  add column if not exists bestaetigung_versendet_am timestamptz,
  add column if not exists ablehnungsgrund text;

-- Der alte Zustand "berechnet" hiess in der Sache "Rechnung ist raus".
update public.club_access_requests
   set status = 'rechnung_versendet',
       rechnung_versendet_am = coalesce(rechnung_versendet_am, handled_at, updated_at)
 where status = 'berechnet';

alter table public.club_access_requests drop constraint if exists club_access_requests_status_check;
alter table public.club_access_requests
  add constraint club_access_requests_status_check
  check (status in ('offen', 'rechnung_erstellt', 'rechnung_versendet', 'rechnung_bezahlt',
                    'freigeschaltet', 'abgelehnt'));

/* Einen Schritt weitergehen.
 *
 * Die Reihenfolge steht hier und nicht in der Oberfläche: Eine Regel, die nur
 * im Browser gilt, ist keine Regel. Zurück geht es bewusst auch — wer versehentlich
 * „bezahlt" geklickt hat, muss das zurücknehmen können, ohne in die Datenbank
 * zu greifen. */
create or replace function public.anfrage_weiter(
  ziel_anfrage uuid,
  neuer_status text,
  nummer text default null,
  summe numeric default null,
  art text default null,
  grund text default null
)
returns table (status text, verein text, seit timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  jetziger text;
  erlaubt text[];
begin
  select r.status into jetziger from public.club_access_requests r where r.id = ziel_anfrage;
  if jetziger is null then raise exception 'Anfrage % existiert nicht', ziel_anfrage; end if;

  -- Was von wo aus möglich ist. Abgelehnt geht von überall, zurück auch.
  erlaubt := case jetziger
    when 'offen'              then array['rechnung_erstellt','abgelehnt']
    when 'rechnung_erstellt'  then array['rechnung_versendet','offen','abgelehnt']
    when 'rechnung_versendet' then array['rechnung_bezahlt','rechnung_erstellt','abgelehnt']
    when 'rechnung_bezahlt'   then array['freigeschaltet','rechnung_versendet','abgelehnt']
    when 'freigeschaltet'     then array['rechnung_bezahlt']
    when 'abgelehnt'          then array['offen']
    else array[]::text[]
  end;

  if not (neuer_status = any(erlaubt)) then
    raise exception 'Von "%" aus geht "%" nicht. Möglich wäre: %', jetziger, neuer_status, array_to_string(erlaubt, ', ')
      using errcode = 'P0001';
  end if;

  update public.club_access_requests r
     set status = neuer_status,
         rechnungsnummer = coalesce(nullif(trim(nummer), ''), r.rechnungsnummer),
         betrag = coalesce(summe, r.betrag),
         zahlweise = coalesce(nullif(trim(art), ''), r.zahlweise),
         ablehnungsgrund = case when neuer_status = 'abgelehnt'
                                then coalesce(nullif(trim(grund), ''), r.ablehnungsgrund)
                                else r.ablehnungsgrund end,
         rechnung_erstellt_am  = case when neuer_status = 'rechnung_erstellt'  then now() else r.rechnung_erstellt_am end,
         rechnung_versendet_am = case when neuer_status = 'rechnung_versendet' then now() else r.rechnung_versendet_am end,
         bezahlt_am            = case when neuer_status = 'rechnung_bezahlt'   then now() else r.bezahlt_am end,
         handled_at = now()
   where r.id = ziel_anfrage;

  return query
    select r.status, coalesce(c.name, r.club_name), r.handled_at
      from public.club_access_requests r
      left join public.clubs c on c.id = r.club_id
     where r.id = ziel_anfrage;
end;
$$;

revoke all on function public.anfrage_weiter(uuid, text, text, numeric, text, text) from public, anon, authenticated;

/* Die Bestätigung ist raus. Ein eigener Schritt, weil er nach dem
   Freischalten kommt und nicht Teil davon ist - die Mail schreibt ein Mensch. */
create or replace function public.bestaetigung_vermerken(ziel_anfrage uuid)
returns timestamptz
language sql volatile security definer set search_path = '' as $$
  update public.club_access_requests
     set bestaetigung_versendet_am = now()
   where id = ziel_anfrage and status = 'freigeschaltet'
  returning bestaetigung_versendet_am;
$$;

revoke all on function public.bestaetigung_vermerken(uuid) from public, anon, authenticated;
