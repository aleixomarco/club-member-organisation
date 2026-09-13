-- Ergebnismeldungen in Heim : Gast (Betreiberentscheidung 13.09.2026, Punkt 1:
-- ueberall Heimmannschaft zuerst).
--
-- event_results speichert weiter wir : Gegner. Bisher gingen diese Rohwerte
-- direkt in die Texte: tipp.text zeigte wir:Gegner, die ergebnis.*-Texte
-- stellten die hoehere Zahl nach vorn (20260905070000:47-50; *.verloren mit
-- {auswaerts}:{heim}). Ab jetzt rechnet ergebnis_meldewerte genau einmal um -
-- heim = Tore der Heimmannschaft, auswaerts = Tore der Gastmannschaft - und
-- alle 42 Texte enden auf Endstand {heim}:{auswaerts}. Sieg, Unentschieden
-- und Niederlage bleiben der Vergleich unserer Tore mit denen des Gegners.
-- tipp.text ({titel} · {heim}:{auswaerts}) bleibt unveraendert und zeigt damit
-- automatisch Heim:Gast.
--
-- Neu: Abgesagte Spiele melden nichts (vorher nur die Typpruefung,
-- 20260907120000:48). Unbekannter Spielort: keine Mannschaftsmeldung (vorher
-- galt null als auswaerts, 20260907120000:74); der Ausloeser aus
-- 20260914100000 laesst solche Ergebnisse ohnehin nicht mehr zu.

create or replace function public.ergebnis_meldewerte(p_ort text, p_wir integer, p_gegner integer)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object(
    'heim',      case when p_ort = 'auswaerts' then p_gegner else p_wir end,
    'auswaerts', case when p_ort = 'auswaerts' then p_wir else p_gegner end,
    'ort',       case when p_ort in ('heim', 'auswaerts') then p_ort end,
    'ausgang',   case when p_wir > p_gegner then 'gewonnen'
                      when p_wir = p_gegner then 'unentschieden'
                      else 'verloren' end);
$$;
revoke all on function public.ergebnis_meldewerte(text, integer, integer) from public, anon, authenticated;
grant execute on function public.ergebnis_meldewerte(text, integer, integer) to service_role;

comment on function public.ergebnis_meldewerte(text, integer, integer) is
  'Einziger Umrechner der Datenbank: aus gespeichertem wir:Gegner und events.home_away werden heim/auswaerts als Heim:Gast, dazu ort (null = unbekannt) und ausgang (gewonnen/unentschieden/verloren aus unserer Sicht). Gegenstueck in der App: lib/ergebnis.mjs zuHeimGast/ausgang.';

-- Rumpf aus 20260907120000:27-107, geaendert: status-Pruefung, v_werte und der
-- leere Suchpfad. Jeder Name im Rumpf ist voll qualifiziert, und jede gerufene
-- Hilfsfunktion setzt ihren eigenen (20260907040000, 20260907060000).
create or replace function public.ergebnis_melden()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_event       record;
  v_vereinsname text;
  v_mannschaft  text;
  v_schluessel  text;
  v_tipper      record;
  v_sprache     text;
  v_werte       jsonb;
begin
  if tg_op = 'UPDATE'
     and new.heim is not distinct from old.heim
     and new.auswaerts is not distinct from old.auswaerts then
    return new;
  end if;

  select e.team_id, e.home_away, e.club_id, e.title, e.type, e.status
    into v_event
    from public.events e
   where e.id = new.event_id;
  if not found then return new; end if;
  if v_event.type is distinct from 'spiel' then return new; end if;
  if v_event.status = 'cancelled' then return new; end if;

  v_werte := public.ergebnis_meldewerte(v_event.home_away, new.heim, new.auswaerts);

  select c.name into v_vereinsname from public.clubs c where c.id = new.club_id;
  select t.name into v_mannschaft from public.teams t where t.id = v_event.team_id;

  /* Tippspiel zuerst - getippt wird auch auf Begegnungen ohne Mannschaft. */
  for v_tipper in
    select m.id
      from public.predictions pr
      join public.club_memberships m
        on m.profile_id = pr.profile_id and m.club_id = new.club_id
     where pr.event_id = new.event_id and m.status = 'active'
  loop
    v_sprache := public.sprache_der_mitgliedschaft(v_tipper.id);
    perform public.notify_uebersetzt(v_tipper.id, 'tipp',
      'tipp.titel', 'tipp.text',
      jsonb_build_object(
        'titel', coalesce(v_event.title, public.meldungstext('allg.begegnung', v_sprache)),
        'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts'));
  end loop;

  if v_mannschaft is null or (v_werte ->> 'ort') is null then return new; end if;

  v_schluessel := 'ergebnis.' || (v_werte ->> 'ort') || '.' || (v_werte ->> 'ausgang');

  insert into public.user_notifications (profile_id, club_id, kind, title, body, ziel_art, ziel_id)
  select distinct m.profile_id, new.club_id, 'results',
         public.meldungstext(v_schluessel, p.language, jsonb_build_object(
           'verein', coalesce(v_vereinsname, public.meldungstext('allg.verein', p.language)),
           'mannschaft', v_mannschaft,
           'heim', v_werte -> 'heim', 'auswaerts', v_werte -> 'auswaerts')),
         '',
         'termin', new.event_id
  from public.club_memberships m
  left join public.profiles p on p.id = m.profile_id
  left join public.team_members tm
         on tm.membership_id = m.id and tm.team_id = v_event.team_id
  left join public.team_benachrichtigungen tb
         on tb.membership_id = m.id and tb.team_id = v_event.team_id
  where m.club_id = new.club_id and m.status = 'active' and m.profile_id is not null
    and (tm.membership_id is not null or tb.aktiv)
    and public.team_meldung_erlaubt(m.id, v_event.team_id, 'ergebnisse')
    and public.meldung_erlaubt(m.profile_id, 'results');

  return new;
end;
$$;
-- create or replace behaelt den Ausloeser event_results_melden (20260905070000:126-128).

insert into public.meldungstexte (schluessel, sprache, text) values
  ('ergebnis.heim.gewonnen','de','{verein}: Das Heimspiel der {mannschaft} haben wir gewonnen! Endstand {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','de','{verein}: Das Heimspiel der {mannschaft} endet unentschieden. Endstand {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','de','{verein}: Das Heimspiel der {mannschaft} haben wir verloren. Endstand {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','de','{verein}: Das Auswärtsspiel der {mannschaft} haben wir gewonnen! Endstand {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','de','{verein}: Das Auswärtsspiel der {mannschaft} endet unentschieden. Endstand {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','de','{verein}: Das Auswärtsspiel der {mannschaft} haben wir verloren. Endstand {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','en','{verein}: We won the {mannschaft} home match! Final score {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','en','{verein}: The {mannschaft} home match ended in a draw. Final score {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','en','{verein}: We lost the {mannschaft} home match. Final score {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','en','{verein}: We won the {mannschaft} away match! Final score {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','en','{verein}: The {mannschaft} away match ended in a draw. Final score {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','en','{verein}: We lost the {mannschaft} away match. Final score {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','es','{verein}: ¡Hemos ganado el partido de {mannschaft} en casa! Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','es','{verein}: El partido de {mannschaft} en casa acaba en empate. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','es','{verein}: Hemos perdido el partido de {mannschaft} en casa. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','es','{verein}: ¡Hemos ganado el partido de {mannschaft} fuera de casa! Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','es','{verein}: El partido de {mannschaft} fuera de casa acaba en empate. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','es','{verein}: Hemos perdido el partido de {mannschaft} fuera de casa. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','pt','{verein}: a nossa equipa {mannschaft} ganhou em casa! Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','pt','{verein}: a nossa equipa {mannschaft} empatou em casa. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','pt','{verein}: a nossa equipa {mannschaft} perdeu em casa. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','pt','{verein}: a nossa equipa {mannschaft} ganhou fora! Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','pt','{verein}: a nossa equipa {mannschaft} empatou fora. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','pt','{verein}: a nossa equipa {mannschaft} perdeu fora. Resultado final {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','it','{verein}: la nostra {mannschaft} vince in casa! Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','it','{verein}: la nostra {mannschaft} pareggia in casa. Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','it','{verein}: la nostra {mannschaft} perde in casa. Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','it','{verein}: la nostra {mannschaft} vince in trasferta! Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','it','{verein}: la nostra {mannschaft} pareggia in trasferta. Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','it','{verein}: la nostra {mannschaft} perde in trasferta. Risultato finale {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','tr','{verein}: {mannschaft} takımımız iç saha maçını kazandı! Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','tr','{verein}: {mannschaft} takımımızın iç saha maçı berabere bitti. Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','tr','{verein}: {mannschaft} takımımız iç saha maçını kaybetti. Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','tr','{verein}: {mannschaft} takımımız deplasman maçını kazandı! Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','tr','{verein}: {mannschaft} takımımızın deplasman maçı berabere bitti. Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','tr','{verein}: {mannschaft} takımımız deplasman maçını kaybetti. Maç sonucu {heim}:{auswaerts}.'),
  ('ergebnis.heim.gewonnen','fr','{verein} : victoire à domicile de notre équipe {mannschaft} ! Score final {heim}:{auswaerts}.'),
  ('ergebnis.heim.unentschieden','fr','{verein} : match nul à domicile pour notre équipe {mannschaft}. Score final {heim}:{auswaerts}.'),
  ('ergebnis.heim.verloren','fr','{verein} : défaite à domicile de notre équipe {mannschaft}. Score final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.gewonnen','fr','{verein} : victoire à l''extérieur de notre équipe {mannschaft} ! Score final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.unentschieden','fr','{verein} : match nul à l''extérieur pour notre équipe {mannschaft}. Score final {heim}:{auswaerts}.'),
  ('ergebnis.auswaerts.verloren','fr','{verein} : défaite à l''extérieur de notre équipe {mannschaft}. Score final {heim}:{auswaerts}.')
on conflict (schluessel, sprache) do update set text = excluded.text;

-- Erwartet: zeilen = 42, heim_gast = 42, alte_reihenfolge = 0, und die zwei Beispiele
-- 'V: Das Auswärtsspiel der M haben wir gewonnen! Endstand 1:3.' (wir 3, Gegner 1, auswaerts)
-- 'V: Das Heimspiel der M haben wir verloren. Endstand 3:6.' (wir 3, Gegner 6, heim).
select
  count(*) as zeilen,
  count(*) filter (where text like '%{heim}:{auswaerts}%') as heim_gast,
  count(*) filter (where text like '%{auswaerts}:{heim}%') as alte_reihenfolge
from public.meldungstexte
where schluessel like 'ergebnis.heim.%' or schluessel like 'ergebnis.auswaerts.%';

select public.meldungstext('ergebnis.' || (x.w ->> 'ort') || '.' || (x.w ->> 'ausgang'), 'de',
         jsonb_build_object('verein', 'V', 'mannschaft', 'M',
                            'heim', x.w -> 'heim', 'auswaerts', x.w -> 'auswaerts')) as beispiel
from (values ('auswaerts', 3, 1), ('heim', 3, 6)) as v(ort, wir, gegner)
cross join lateral (select public.ergebnis_meldewerte(v.ort, v.wir, v.gegner) as w) as x;
