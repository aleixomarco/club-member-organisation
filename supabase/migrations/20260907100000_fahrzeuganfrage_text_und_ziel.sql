-- Die Buchungsanfrage sagt, wer sie stellt - und laesst sich antippen.
--
-- WAS SCHON DA WAR
-- Der ganze Ablauf steht seit Langem und ist richtig gebaut:
--   * Jedes aktive Mitglied darf eine Buchung einfuegen (Regel "members
--     request bookings").
--   * fahrzeugbuchung_status_setzen entscheidet VOR dem Einfuegen: Wer
--     entscheiden darf (vereinsadmin, sysadmin, organisator), bucht direkt
--     ("bestaetigt"); alle anderen stellen eine Anfrage ("angefragt").
--   * fahrzeuganfrage_melden meldet NUR bei "angefragt" - eine Direktbuchung
--     loest also von selbst keine Nachricht aus.
--   * entscheide_fahrzeug_anfrage benachrichtigt die anfragende Person ueber
--     Zusage oder Absage.
-- Gefehlt hat nichts davon. Geaendert wird nur, was in der Meldung steht und
-- wohin sie fuehrt.
--
-- DER TEXT
-- Bisher: "Neue Buchungsanfrage für das Vereinsfahrzeug von Marco Aleixo."
-- Jetzt:  "Marco Aleixo möchte ein Fahrzeug buchen. Jetzt genehmigen oder
--          ablehnen." - der Name steht vorn, und der Satz sagt, was zu tun ist.
--
-- WARUM EIN ZWEITER SATZ FUER DEN FALL OHNE NAMEN
-- Der Name steht jetzt am Satzanfang. Das alte Ersatzwort "einem Mitglied"
-- passte hinter "von" und stand im Dativ - vorn ergaebe es "einem Mitglied
-- möchte ein Fahrzeug buchen." Statt ein Wort in den Satz zu setzen, gibt es
-- fuer diesen Fall einen eigenen Satz. Dieselbe Falle wie bei den Strafen,
-- wo auf Franzoesisch "Tu as reçu une sanction : Une sanction." entstand.
--
-- DAS ZIEL
-- Die Meldung trug keine ziel_art und war deshalb nicht anklickbar - die
-- Vereinsleitung musste die Fahrzeugansicht selbst suchen, um zu entscheiden.

insert into public.meldungstexte (schluessel, sprache, text) values
  ('fahrzeug.anfrage.titel','de','Vereinsfahrzeug Buchungsanfrage'),
  ('fahrzeug.anfrage.text','de','{wer} möchte ein Fahrzeug buchen. Jetzt genehmigen oder ablehnen.'),
  ('fahrzeug.anfrage.text','en','{wer} would like to book a vehicle. Approve or decline now.'),
  ('fahrzeug.anfrage.text','es','{wer} quiere reservar un vehículo. Apruébalo o recházalo ahora.'),
  ('fahrzeug.anfrage.text','pt','{wer} quer reservar um veículo. Aprova ou recusa agora.'),
  ('fahrzeug.anfrage.text','it','{wer} vuole prenotare un veicolo. Approva o rifiuta ora.'),
  ('fahrzeug.anfrage.text','tr','{wer} bir araç ayırtmak istiyor. Şimdi onayla ya da reddet.'),
  ('fahrzeug.anfrage.text','fr','{wer} souhaite réserver un véhicule. Approuve ou refuse maintenant.'),
  ('fahrzeug.anfrage.textOhneName','de','Ein Mitglied möchte ein Fahrzeug buchen. Jetzt genehmigen oder ablehnen.'),
  ('fahrzeug.anfrage.textOhneName','en','A member would like to book a vehicle. Approve or decline now.'),
  ('fahrzeug.anfrage.textOhneName','es','Un socio quiere reservar un vehículo. Apruébalo o recházalo ahora.'),
  ('fahrzeug.anfrage.textOhneName','pt','Um sócio quer reservar um veículo. Aprova ou recusa agora.'),
  ('fahrzeug.anfrage.textOhneName','it','Un socio vuole prenotare un veicolo. Approva o rifiuta ora.'),
  ('fahrzeug.anfrage.textOhneName','tr','Bir üye araç ayırtmak istiyor. Şimdi onayla ya da reddet.'),
  ('fahrzeug.anfrage.textOhneName','fr','Un membre souhaite réserver un véhicule. Approuve ou refuse maintenant.')
on conflict (schluessel, sprache) do update set text = excluded.text;

create or replace function public.fahrzeuganfrage_melden()
 returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_name text;
begin
  /* Nur Anfragen. Wer direkt buchen darf, hat den Status schon auf
     "bestaetigt" - da gibt es nichts zu genehmigen und niemanden zu stoeren. */
  if new.status <> 'angefragt' then return new; end if;

  select display_name into v_name from public.club_memberships where id = new.membership_id;

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'vehicle',
         public.meldungstext('fahrzeug.anfrage.titel', p.language),
         case when v_name is null
              then public.meldungstext('fahrzeug.anfrage.textOhneName', p.language)
              else public.meldungstext('fahrzeug.anfrage.text', p.language,
                     jsonb_build_object('wer', v_name)) end,
         'fahrzeug', new.id
  from public.membership_roles r
  join public.club_memberships m on m.id = r.membership_id
  left join public.profiles p on p.id = m.profile_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and r.role in ('vereinsadmin', 'sysadmin', 'organisator')
    and public.meldung_erlaubt(m.profile_id, 'vehicle');

  return new;
end;
$function$;

select
  (select count(*) from public.meldungstexte where schluessel like 'fahrzeug.anfrage%') as bausteine,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and proname='fahrzeuganfrage_melden' and prosrc like '%ziel_art%') as traegt_ziel;
