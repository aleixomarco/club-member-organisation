-- Ziel im Repo: supabase/migrations/20260924100000_fan_kontingent.sql
--
-- Getrennte Kontingente: Mitglieder und Fans haben ab hier eigene Zahlen.
--   Basic 100 Mitglieder + 100 Fans
--   Plus  350 Mitglieder + 200 Fans   (Plus faellt von 450 auf 350 - die Zahl,
--                                      die auf der Website immer stand)
--   Pro  1000 Mitglieder + 500 Fans
--   ohne Abo: unveraendert 3 Zugaenge INSGESAMT, Fans zaehlen dagegen.
--
-- Warum ueberhaupt: heute zaehlt club_account_count jede aktive Mitgliedschaft
-- mit eigenem Login - ein reiner Fan belegt denselben Platz wie ein
-- Vorstandsmitglied. Ein 100er-Paket ist damit faktisch "100 Mitglieder ODER
-- Fans". Das verkauft sich nicht und es stimmt auch nicht mit dem ueberein,
-- was aussen kommuniziert wird.
--
-- Wer ist ein Fan: eine Mitgliedschaft, deren Rollen genau {fan} oder
-- {fan, mitglied} sind - dieselbe Regel wie istNurFan in app/page.tsx:1154.
-- {fan, mitglied} kann es heute wegen fan_exklusiv_pruefen gar nicht geben;
-- die Regel nimmt den Fall trotzdem mit, damit DB und App nie auseinander
-- laufen, falls die Exklusivregel einmal gelockert wird.
--
-- Wer ist ein Mitglied: alles andere, was zaehlt - ausdruecklich AUCH eine
-- Mitgliedschaft ganz OHNE Rollen. Das ist wichtig, weil Rollen und Status in
-- zwei Schritten geschrieben werden (beitritt_entscheiden setzt erst die
-- Rollen, dann den Status; register_for_club legt den allerersten Zugang eines
-- Vereins sogar aktiv OHNE Rollen an). "Noch keine Rollen" als Mitglied zu
-- werten ist die sichere Richtung: der teurere Topf wird belastet, niemand
-- rutscht ueber eine Luecke ins guenstigere Kontingent.
--
-- Bestandsvereine verlieren nichts: die Fans verlassen das Mitglieder-
-- kontingent und bekommen ihr eigenes obendrauf. In PROD heisst das fuer
-- ERG Iserlohn 13 belegte Zugaenge -> 9 Mitglieder + 4 Fans bei 100 + 100.
--
-- Nicht Teil dieser Migration (bewusst): die Preise selbst. subscription_plans
-- traegt nur code/name/interval/price_cents - die 15 EUR im Monat bzw. 180 EUR
-- im Jahr fuer den Sponsorenzusatz stehen aussen (lib/preise.ts, Website) und
-- werden dort gepflegt. Hinweis: der Zusatz ist in PROD in Gebrauch.

-- ---------------------------------------------------------------------------
-- 0) Schutzpruefung VOR jeder Aenderung: sperrt die Absenkung 450 -> 350
--    jemanden aus?
-- ---------------------------------------------------------------------------
-- Die Absenkung ist die einzige Stelle, an der diese Migration nach UNTEN
-- geht. Sie darf niemals einen Verein zuruecklassen, der heute im Rahmen ist
-- und morgen darueber liegt - so ein Verein koennte niemanden mehr aufnehmen
-- und wuerde es erst merken, wenn jemand vor der Tuer steht.
-- Die Pruefung rechnet die NEUEN Regeln haendisch nach (ohne die neuen
-- Funktionen, die es hier noch nicht gibt) und vergleicht mit den ALTEN.
do $$
declare
  v_betroffen text;
  v_schon_drueber text;
begin
  with stand as (
    select c.id,
           c.name,
           c.vereinbarte_zugaenge,
           public.club_subscription_tier(c.id) as tarif,
           (select count(*) from public.club_memberships m
             where m.club_id = c.id
               and m.status = 'active'
               and m.profile_id is not null
               and m.is_managed_profile = false) as alt_belegt,
           (select count(*) from public.club_memberships m
             where m.club_id = c.id
               and m.status = 'active'
               and m.profile_id is not null
               and m.is_managed_profile = false
               /* kein reiner Fan = zaehlt kuenftig als Mitglied */
               and not (
                 exists (select 1 from public.membership_roles r
                          where r.membership_id = m.id
                            and r.role = 'fan'::public.club_role)
                 and not exists (select 1 from public.membership_roles r
                                  where r.membership_id = m.id
                                    and r.role not in ('fan'::public.club_role,
                                                       'mitglied'::public.club_role))
               )) as neu_mitglieder
      from public.clubs c
  ), gerechnet as (
    select s.*,
           case when s.tarif = 'none' then 3
                else coalesce(s.vereinbarte_zugaenge,
                       case s.tarif when 'basic' then 100
                                    when 'plus'  then 450
                                    when 'pro'   then 1000
                                    else 3 end)
           end as alt_grenze,
           case when s.tarif = 'none' then 3
                else coalesce(s.vereinbarte_zugaenge,
                       case s.tarif when 'basic' then 100
                                    when 'plus'  then 350
                                    when 'pro'   then 1000
                                    else 3 end)
           end as neu_grenze
      from stand s
  )
  /* Beide Auswertungen in EINER Anweisung: Die Zwischentabelle gerechnet gilt
     nur fuer die Abfrage, an der sie haengt - ein zweites select darunter fand
     sie nicht mehr (42P01). */
  select string_agg(format('%s (Tarif %s): %s Mitglieder, neue Grenze %s',
                           g.name, g.tarif, g.neu_mitglieder, g.neu_grenze), '; '
                    order by g.name)
           /* Wer heute schon ueber seiner Grenze liegt (z. B. abgelaufenes
              Abo), wird durch diese Migration nicht schlechter gestellt - den
              melden wir nur, abbrechen waere falsch. */
           filter (where g.neu_mitglieder > g.neu_grenze and g.alt_belegt <= g.alt_grenze),
         string_agg(format('%s (%s von %s)', g.name, g.alt_belegt, g.alt_grenze), '; '
                    order by g.name)
           filter (where g.alt_belegt > g.alt_grenze)
    into v_betroffen, v_schon_drueber
    from gerechnet g;

  if v_betroffen is not null then
    raise exception 'Absenkung Plus 450 -> 350 wuerde Vereine aussperren: %', v_betroffen
      using hint = 'Diesen Vereinen zuerst clubs.vereinbarte_zugaenge setzen, dann erneut migrieren.';
  end if;

  if v_schon_drueber is not null then
    raise notice 'Hinweis: diese Vereine lagen schon vorher ueber ihrer Grenze: %', v_schon_drueber;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Individuell vereinbarte Fan-Zahl
-- ---------------------------------------------------------------------------
-- Spiegelbild zu clubs.vereinbarte_zugaenge: nur der Betreiber setzt sie, und
-- sie schlaegt die Staffel. Dieselbe CHECK-Regel (> 0 oder NULL), damit "keine
-- Sondervereinbarung" genau einen Ausdruck hat: NULL.
alter table public.clubs
  add column if not exists vereinbarte_fans integer;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.clubs'::regclass
                    and conname = 'clubs_vereinbarte_fans_check') then
    alter table public.clubs
      add constraint clubs_vereinbarte_fans_check
      check (vereinbarte_fans is null or vereinbarte_fans > 0);
  end if;
end $$;

comment on column public.clubs.vereinbarte_fans is
  'Individuell vereinbarte Zahl der Fan-Plaetze. NULL = Staffel des Tarifs. Nur der Betreiber setzt sie (betreiberfelder_schuetzen).';

-- Die neue Spalte gehoert dem Betreiber, genau wie vereinbarte_zugaenge.
-- Ohne diesen Block koennte eine Vereinsleitung sich selbst Fan-Plaetze
-- schreiben - die Grenze waere dekorativ.
create or replace function public.betreiberfelder_schuetzen()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  if auth.role() = 'service_role' or auth.uid() is null then
    return new;
  end if;

  if new.vereinbarte_zugaenge is distinct from old.vereinbarte_zugaenge then
    raise exception 'Die Zahl der Zugaenge wird vom Betreiber vereinbart.' using errcode = 'P0001';
  end if;
  if new.vereinbarte_fans is distinct from old.vereinbarte_fans then
    raise exception 'Die Zahl der Fan-Plaetze wird vom Betreiber vereinbart.' using errcode = 'P0001';
  end if;
  if new.sponsoring_freigeschaltet is distinct from old.sponsoring_freigeschaltet then
    raise exception 'Der Sponsorenzusatz wird vom Betreiber freigeschaltet.' using errcode = 'P0001';
  end if;

  if new.referral_credit_months is distinct from old.referral_credit_months
     and public.has_club_role(new.id, array['sysadmin','vereinsadmin']::public.club_role[]) then
    new.referral_credit_months := old.referral_credit_months;
  end if;

  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 2) Eine einzige Stelle, die "ist das ein Fan?" beantwortet
-- ---------------------------------------------------------------------------
-- Diese Frage wird an fuenf Stellen gebraucht (zwei Zaehler, zwei Trigger,
-- Reporting). Steht sie fuenfmal da, laufen die Fassungen irgendwann
-- auseinander und ein Konto zaehlt in beiden Toepfen oder in keinem.
create or replace function public.rollensatz_ist_fan(rollen public.club_role[])
 returns boolean
 language sql
 immutable
as $function$
  select rollen is not null
     and 'fan'::public.club_role = any(rollen)
     and not exists (
           select 1 from unnest(rollen) x
            where x not in ('fan'::public.club_role, 'mitglied'::public.club_role));
$function$;

comment on function public.rollensatz_ist_fan(public.club_role[]) is
  'Reiner Fan: Rollen sind genau {fan} oder {fan,mitglied}. Gleiche Regel wie istNurFan in der App. Leerer Rollensatz ist KEIN Fan.';

create or replace function public.mitgliedschaft_ist_fan(target_membership uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to ''
as $function$
  select public.rollensatz_ist_fan(
           (select coalesce(array_agg(r.role), '{}'::public.club_role[])
              from public.membership_roles r
             where r.membership_id = target_membership));
$function$;

-- ---------------------------------------------------------------------------
-- 3) Zaehlen: Mitglieder und Fans getrennt
-- ---------------------------------------------------------------------------
-- Unveraendert bleibt, WER ueberhaupt zaehlt: aktiv, eigener Login, kein
-- verwaltetes Profil. Kinder und Teamspieler ohne Login kosten weiterhin
-- nichts, Beitrittsanfragen (status 'pending') auch nicht.
create or replace function public.club_account_count(target_club uuid)
 returns integer
 language sql
 stable security definer
 set search_path to ''
as $function$
  select count(*)::integer
  from public.club_memberships m
  where m.club_id = target_club
    and m.status = 'active'
    and m.profile_id is not null
    and m.is_managed_profile = false
    /* Reine Fans haben seit dieser Migration ihren eigenen Topf. */
    and not public.mitgliedschaft_ist_fan(m.id);
$function$;

comment on function public.club_account_count(uuid) is
  'Zaehlt die Mitglieds-Zugaenge eines Vereins (reine Fans NICHT - dafuer club_fan_count). Eine Mitgliedschaft ohne Rollen zaehlt als Mitglied.';

create or replace function public.club_fan_count(target_club uuid)
 returns integer
 language sql
 stable security definer
 set search_path to ''
as $function$
  select count(*)::integer
  from public.club_memberships m
  where m.club_id = target_club
    and m.status = 'active'
    and m.profile_id is not null
    and m.is_managed_profile = false
    and public.mitgliedschaft_ist_fan(m.id);
$function$;

comment on function public.club_fan_count(uuid) is
  'Zaehlt die reinen Fan-Zugaenge eines Vereins. Gegenstueck zu club_account_count, gleiche Bedingungen.';

-- ---------------------------------------------------------------------------
-- 4) Grenzen: Mitglieder (Plus jetzt 350) und Fans (neu)
-- ---------------------------------------------------------------------------
create or replace function public.club_account_limit(target_club uuid)
 returns integer
 language sql
 stable security definer
 set search_path to ''
as $function$
  select case
    -- Ohne Freischaltung bleibt es bei der kostenlosen Stufe, auch wenn eine
    -- Zahl vereinbart wurde. Sonst liesse sich die Grenze durch einen Eintrag
    -- aushebeln, den niemand bezahlt hat.
    -- Achtung: auf dieser Stufe sind es 3 Zugaenge INSGESAMT, Fans
    -- eingerechnet - siehe club_kontingent_pruefen.
    when public.club_subscription_tier(target_club) = 'none' then 3
    else coalesce(
      (select c.vereinbarte_zugaenge from public.clubs c where c.id = target_club),
      case public.club_subscription_tier(target_club)
        when 'basic' then 100
        -- Plus faellt von 450 auf 350. 350 ist die Zahl, die in lib/preise.ts
        -- und in der Betreiberkonsole immer stand; die 450 in der Datenbank
        -- waren der Ausreisser.
        when 'plus'  then 350
        when 'pro'   then 1000
        else 3
      end
    )
  end;
$function$;

create or replace function public.club_fan_limit(target_club uuid)
 returns integer
 language sql
 stable security definer
 set search_path to ''
as $function$
  select case
    -- Kostenlose Stufe: KEIN eigenes Fan-Kontingent. Dort gibt es genau einen
    -- Topf mit 3 Zugaengen, und Fans zaehlen dagegen - sonst bekaeme ein
    -- Verein ohne Abo aus Versehen 3 Mitglieder PLUS Fans.
    when public.club_subscription_tier(target_club) = 'none' then 0
    else coalesce(
      (select c.vereinbarte_fans from public.clubs c where c.id = target_club),
      case public.club_subscription_tier(target_club)
        when 'basic' then 100
        when 'plus'  then 200
        when 'pro'   then 500
        else 0
      end
    )
  end;
$function$;

comment on function public.club_fan_limit(uuid) is
  'Fan-Plaetze: clubs.vereinbarte_fans schlaegt die Staffel basic 100 / plus 200 / pro 500. Ohne Abo 0 - dort gilt der gemeinsame Topf aus club_account_limit.';

-- ---------------------------------------------------------------------------
-- 5) Die Pruefung selbst - an einer Stelle, von zwei Triggern benutzt
-- ---------------------------------------------------------------------------
-- zusaetzlich = 1 heisst "die Zeile ist noch nicht mitgezaehlt" (BEFORE-Trigger
-- auf club_memberships), zusaetzlich = 0 heisst "sie ist schon drin"
-- (AFTER-Trigger auf membership_roles).
create or replace function public.club_kontingent_pruefen(
  target_club uuid,
  ist_fan boolean,
  zusaetzlich integer default 0)
 returns void
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_tarif text;
  grenze integer;
  belegt integer;
begin
  v_tarif := public.club_subscription_tier(target_club);

  if v_tarif = 'none' then
    /* Freie Stufe unveraendert wie bisher: EIN Topf mit 3 Zugaengen, Fans
       zaehlen mit. Deshalb auch weiterhin die alte Fehlermeldung - was voll
       ist, sind hier tatsaechlich "die Zugaenge", nicht "die Fan-Plaetze". */
    grenze := public.club_account_limit(target_club);
    belegt := public.club_account_count(target_club) + public.club_fan_count(target_club);
    if belegt + zusaetzlich > grenze then
      raise exception 'club_account_limit_reached'
        using detail = format('%s von %s Zugängen belegt', belegt, grenze),
              hint = 'Der Verein braucht einen größeren Tarif.';
    end if;
    return;
  end if;

  if ist_fan then
    grenze := public.club_fan_limit(target_club);
    belegt := public.club_fan_count(target_club);
    if belegt + zusaetzlich > grenze then
      /* Eigener Fehlername und eigener Text: die Vereinsleitung soll nicht
         "Tarif zu klein" lesen, wenn nur die Fan-Plaetze voll sind und die
         Mitgliedsplaetze leer stehen. */
      raise exception 'club_fan_limit_reached'
        using detail = format('%s von %s Fan-Plätzen belegt', belegt, grenze),
              hint = 'Der Verein braucht mehr Fan-Plätze.';
    end if;
  else
    grenze := public.club_account_limit(target_club);
    belegt := public.club_account_count(target_club);
    if belegt + zusaetzlich > grenze then
      raise exception 'club_account_limit_reached'
        using detail = format('%s von %s Zugängen belegt', belegt, grenze),
              hint = 'Der Verein braucht einen größeren Tarif.';
    end if;
  end if;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6) Durchsetzung beim Beitritt / Reaktivieren
-- ---------------------------------------------------------------------------
create or replace function public.enforce_club_account_limit()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  wird_zum_konto boolean;
begin
  -- Nur wenn diese Zeile durch die Änderung neu zu einem zählenden Konto
  -- wird. Bestehende aktive Konten dürfen jederzeit bearbeitet werden.
  wird_zum_konto :=
    new.status = 'active'
    and new.profile_id is not null
    and new.is_managed_profile = false
    and (
      tg_op = 'INSERT'
      or old.status <> 'active'
      or old.profile_id is null
      or old.is_managed_profile = true
    );

  if not wird_zum_konto then
    return new;
  end if;

  /* Welcher Topf: die Rollen stehen zu diesem Zeitpunkt schon
     (beitritt_entscheiden schreibt erst die Rollen, dann den Status). Fehlen
     sie - etwa beim allerersten Zugang eines Vereins aus register_for_club -
     gilt die Zeile als Mitglied. */
  perform public.club_kontingent_pruefen(
            new.club_id,
            public.mitgliedschaft_ist_fan(new.id),
            1);

  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7) Die Luecke: Rollenwechsel fan <-> mitglied
-- ---------------------------------------------------------------------------
-- Bisher kostete ein Rollenwechsel nichts. Mit zwei Toepfen waere das die
-- offene Tuer: jemanden als Fan aufnehmen (Fan-Platz) und ihn danach zum
-- Mitglied machen - das Mitgliederkontingent waere beliebig dehnbar.
--
-- Warum ein Trigger und nicht rollensatz_anwenden: rollensatz_anwenden ist nur
-- EINER der Wege in membership_roles. Es gibt RLS-Policies, mit denen die
-- Vereinsleitung direkt schreibt, es gibt register_for_club, und es wird
-- kuenftige Wege geben. Eine Grenze, die man durch die Wahl des Weges umgehen
-- kann, ist keine Grenze - aus genau demselben Grund haengt auch
-- enforce_club_account_limit an der Tabelle und nicht in beitritt_entscheiden.
--
-- Warum AFTER und nicht BEFORE: rollensatz_anwenden loescht erst die alten
-- Rollen und legt danach die neuen an - zwei Anweisungen. Ein AFTER-Trigger
-- sieht den Stand nach der jeweiligen Anweisung und kann den Topf vorher/
-- nachher sauber vergleichen. Beim Weg Fan -> Mitglied faellt die Entscheidung
-- schon beim LOESCHEN der Fan-Rolle: danach hat die Mitgliedschaft keine
-- Rollen mehr und zaehlt als Mitglied. Genau dort wird geprueft.
create or replace function public.kontingent_bei_rollenwechsel()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_mitgliedschaft uuid;
  v_club uuid;
  v_status public.membership_status;
  v_profil uuid;
  v_verwaltet boolean;
  v_jetzt public.club_role[];
  v_vorher public.club_role[];
  v_fan_jetzt boolean;
  v_fan_vorher boolean;
begin
  /* Beim Loeschen gibt es kein new, beim Anlegen kein old - deshalb ueber
     tg_op und nicht ueber coalesce(new..., old...). */
  if tg_op = 'DELETE' then
    v_mitgliedschaft := old.membership_id;
  else
    v_mitgliedschaft := new.membership_id;
  end if;

  select m.club_id, m.status, m.profile_id, coalesce(m.is_managed_profile, false)
    into v_club, v_status, v_profil, v_verwaltet
    from public.club_memberships m
   where m.id = v_mitgliedschaft;

  /* Zaehlt diese Mitgliedschaft ueberhaupt? Eine offene Anfrage oder ein
     verwaltetes Kind darf Rollen bekommen, ohne irgendein Kontingent zu
     beruehren. Beim Freigeben greift dann enforce_club_account_limit. */
  if v_club is null or v_status <> 'active' or v_profil is null or v_verwaltet then
    return null;
  end if;

  /* Ohne Abo gibt es nur EINEN Topf. Ein Rollenwechsel verschiebt dort nichts
     und darf deshalb auch nichts blockieren - sonst koennte ein Verein, der
     schon an seinen 3 Zugaengen klebt, nicht einmal mehr Rollen pflegen. */
  if public.club_subscription_tier(v_club) = 'none' then
    return null;
  end if;

  select coalesce(array_agg(r.role), '{}'::public.club_role[])
    into v_jetzt
    from public.membership_roles r
   where r.membership_id = v_mitgliedschaft;

  /* Den Stand VOR dieser Zeilenaenderung rekonstruieren. */
  if tg_op = 'INSERT' then
    v_vorher := array_remove(v_jetzt, new.role);
  elsif tg_op = 'DELETE' then
    v_vorher := v_jetzt || old.role;
  else
    v_vorher := array_remove(v_jetzt, new.role) || old.role;
  end if;

  v_fan_jetzt  := public.rollensatz_ist_fan(v_jetzt);
  v_fan_vorher := public.rollensatz_ist_fan(v_vorher);

  /* Nur der Wechsel des Topfes kostet etwas. Eine Zusatzrolle bei einem
     Mitglied, ein entzogener Trainer - alles das laesst den Topf unberuehrt
     und darf nie an einer vollen Grenze scheitern. Das schuetzt zugleich
     Vereine, die (etwa nach Ablauf eines Abos) ueber ihrer Grenze liegen:
     ihre Rollenpflege laeuft weiter. */
  if v_fan_jetzt = v_fan_vorher then
    return null;
  end if;

  /* Die Zeile ist schon gezaehlt, deshalb zusaetzlich = 0. */
  perform public.club_kontingent_pruefen(v_club, v_fan_jetzt, 0);

  return null;
end;
$function$;

drop trigger if exists membership_roles_kontingent on public.membership_roles;
/* AUFGESCHOBEN bis zum Abschluss der Transaktion, nicht sofort.
   rollensatz_anwenden loescht erst ALLE Rollen und legt sie dann neu an. Ein
   Fan steht dazwischen ohne Rolle da und zaehlt in diesem Moment als Mitglied.
   Ein sofort pruefender Ausloeser haette deshalb schon das blosse Speichern
   derselben Rollen abgelehnt, sobald die Mitgliedsplaetze voll sind - eine
   Grenze, die zuschlaegt, ohne dass sich etwas aendert. Aufgeschoben sieht die
   Funktion den Endstand: bleibt der Topf gleich, passiert nichts. */
create constraint trigger membership_roles_kontingent
  after insert or update or delete on public.membership_roles
  deferrable initially deferred
  for each row execute function public.kontingent_bei_rollenwechsel();

-- Die drei vorhandenen Trigger auf membership_roles bleiben unangetastet und
-- laufen weiter vor diesem: membership_roles_abgeschaffte_sperren (BEFORE
-- INSERT/UPDATE), membership_roles_fan_exklusiv (BEFORE INSERT/UPDATE) und
-- membership_roles_letzter_admin (BEFORE DELETE). Ein BEFORE-Trigger, der
-- abbricht, verhindert die Zeilenaenderung - dann feuert der neue AFTER-
-- Trigger gar nicht erst.

-- ---------------------------------------------------------------------------
-- 8) Reporting
-- ---------------------------------------------------------------------------
-- club_account_usage behaelt Name, Parameter und Rueckgabetyp. Die App, die
-- gerade im Store liegt, ruft sie weiter auf und zeigt weiter "x von y
-- Zugängen belegt" - nur meint x ab jetzt die Mitglieder. Auf der freien Stufe
-- bleibt es die Gesamtzahl, damit dort weiterhin "3 von 3" steht.
create or replace function public.club_account_usage(target_club uuid)
 returns table(used integer, allowed integer, tier text)
 language sql
 stable security definer
 set search_path to ''
as $function$
  select public.club_account_count(target_club)
         + case when public.club_subscription_tier(target_club) = 'none'
                then public.club_fan_count(target_club) else 0 end,
         public.club_account_limit(target_club),
         public.club_subscription_tier(target_club);
$function$;

create or replace function public.club_fan_usage(target_club uuid)
 returns table(used integer, allowed integer, tier text)
 language sql
 stable security definer
 set search_path to ''
as $function$
  select public.club_fan_count(target_club),
         public.club_fan_limit(target_club),
         public.club_subscription_tier(target_club);
$function$;

-- Fuer die App und die Betreiberkonsole: beide Zahlen in einem Aufruf. Das ist
-- die Funktion, die neue Oberflaechen benutzen sollen.
-- gemeinsamer_topf = true heisst: freie Stufe, dort gibt es keine getrennten
-- Kontingente. Die Oberflaeche zeigt dann EINE Zahl - mitglieder + fans von
-- mitglieder_grenze - und nicht zwei; fan_grenze ist dort 0 und waere als
-- "0 Fan-Plaetze" gelesen schlicht falsch.
create or replace function public.club_kontingent_uebersicht(target_club uuid)
 returns table(tarif text,
               mitglieder integer, mitglieder_grenze integer,
               fans integer, fan_grenze integer,
               gemeinsamer_topf boolean)
 language sql
 stable security definer
 set search_path to ''
as $function$
  select public.club_subscription_tier(target_club),
         public.club_account_count(target_club),
         public.club_account_limit(target_club),
         public.club_fan_count(target_club),
         public.club_fan_limit(target_club),
         public.club_subscription_tier(target_club) = 'none';
$function$;

-- ---------------------------------------------------------------------------
-- 9) Betreiber-Sichten: die zweite Zahl mitfuehren
-- ---------------------------------------------------------------------------
-- Neue Spalten kommen ans ENDE, damit create or replace view durchgeht und die
-- Rechte erhalten bleiben. Beide Routen lesen mit select("*").
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
    ( select max(s.current_period_end)
        from public.club_subscriptions s
       where s.club_id = c.id and s.status = 'active'::public.subscription_status) as laeuft_bis,
    ( select s.provider_subscription_id
        from public.club_subscriptions s
       where s.club_id = c.id and s.status = 'active'::public.subscription_status
       order by s.current_period_end desc nulls last
       limit 1) as beleg,
    ( select count(*)
        from public.club_memberships m
       where m.club_id = c.id and m.status = 'active'::public.membership_status) as mitglieder,
    ( select count(*)
        from public.club_memberships m
       where m.club_id = c.id and m.status = 'pending'::public.membership_status) as offene_aufnahmen,
    ( select count(*)
        from public.anzeigen a
       where a.club_id = c.id and a.aktiv) as eigene_sponsoren,
    ( select ((m.display_name || ' <'::text) || coalesce(m.email, '—'::text)) || '>'::text
        from public.club_memberships m
          join public.membership_roles r on r.membership_id = m.id
       where m.club_id = c.id and m.status = 'active'::public.membership_status
         and r.role = 'vereinsadmin'::public.club_role
       order by m.created_at
       limit 1) as ansprechpartner,
    c.hidden,
    ( select max(v.created_at)
        from public.vereins_aktivitaet v
       where v.club_id = c.id) as letzte_aktivitaet,
    ( select count(distinct v.membership_id)
        from public.vereins_aktivitaet v
       where v.club_id = c.id and v.membership_id is not null
         and v.created_at > (now() - '30 days'::interval)) as aktive_30,
    ( select count(*)
        from public.events e
       where e.club_id = c.id and e.created_at > (now() - '30 days'::interval)) as termine_30,
    ( select count(*)
        from public.messages n
          join public.channels ch on ch.id = n.channel_id
       where ch.club_id = c.id and n.created_at > (now() - '30 days'::interval)) as nachrichten_30,
    /* neu ab 20260924100000 */
    c.vereinbarte_fans,
    public.club_fan_count(c.id) as fans,
    public.club_fan_limit(c.id) as fan_grenze
   from public.clubs c;

create or replace view public.offene_freischaltungen as
 select r.id,
    r.created_at,
    r.quelle,
    coalesce(c.name, r.club_name) as verein,
    r.club_id,
    r.contact_name,
    r.contact_email,
    r.contact_phone,
    r.expected_accounts,
    r.sponsoring_gewuenscht,
    r.note,
    r.status,
    r.rechnungsnummer,
    r.betrag,
    r.zahlweise,
    r.rechnung_erstellt_am,
    r.rechnung_versendet_am,
    r.bezahlt_am,
    r.freigeschaltet_am,
    r.bestaetigung_versendet_am,
    r.ablehnungsgrund,
    case when c.id is null then null::integer
         else public.club_account_count(c.id) end as konten_jetzt,
    case when c.id is null then null::text
         else public.club_subscription_tier(c.id) end as tarif_jetzt,
    case when c.id is null then null::boolean
         else c.sponsoring_freigeschaltet end as sponsoren_jetzt,
    /* neu ab 20260924100000 */
    case when c.id is null then null::integer
         else public.club_fan_count(c.id) end as fans_jetzt
   from public.club_access_requests r
     left join public.clubs c on c.id = r.club_id
  where r.status <> 'abgelehnt'::text or r.handled_at > (now() - '30 days'::interval)
  order by r.created_at;

-- betreiber_kennzahlen bekommt eine Spalte -> Rueckgabetyp aendert sich ->
-- drop + create. Die Rechte werden unten neu gesetzt.
drop function if exists public.betreiber_kennzahlen();
create function public.betreiber_kennzahlen()
 returns table(vereine bigint, freigeschaltet bigint, gesperrt bigint, neu_30 bigint,
               konten bigint, mitglieder bigint, basic bigint, plus bigint, pro bigint,
               ohne_tarif bigint, still_30 bigint, fast_voll bigint, fans bigint)
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  with v as (
    select c.id, c.created_at, c.hidden,
           public.club_subscription_tier(c.id) as tarif,
           public.club_account_limit(c.id) as grenze,
           public.club_account_count(c.id) as konten,
           public.club_fan_limit(c.id) as fan_grenze,
           public.club_fan_count(c.id) as fans,
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
         /* Fast voll: 90 Prozent belegt - jetzt in BEIDEN Toepfen, denn ein
            Verein mit vollen Fan-Plaetzen hat dasselbe Problem wie einer mit
            vollen Mitgliedsplaetzen. */
         count(*) filter (where (grenze > 0 and konten >= grenze * 0.9)
                             or (fan_grenze > 0 and fans >= fan_grenze * 0.9)),
         coalesce(sum(fans), 0)
  from v;
$function$;

-- ---------------------------------------------------------------------------
-- 10) Betreiberfunktionen: Fan-Zahl vereinbaren und zuruecknehmen
-- ---------------------------------------------------------------------------
-- Signatur waechst um einen Parameter am Ende mit Vorgabewert null. Die Route
-- app/api/betreiber/aktion/route.ts ruft mit benannten Parametern auf und
-- laesst den neuen einfach weg - sie bleibt unveraendert lauffaehig.
drop function if exists public.verein_freischalten(uuid, text, integer, interval, text, boolean);
create function public.verein_freischalten(
  target_club uuid,
  stufe text default 'basic'::text,
  zugaenge integer default null::integer,
  laufzeit interval default '1 year'::interval,
  belegnummer text default null::text,
  sponsoring boolean default null::boolean,
  fan_zugaenge integer default null::integer)
 returns table(verein text, tarif text, grenze integer, sponsoren boolean,
               laeuft_bis timestamp with time zone, fan_grenze integer)
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  plan_id uuid;
  plan_code text;
  beleg text;
  bisheriges_ende timestamptz;
  beginn timestamptz;
  offene record;
begin
  if not exists (select 1 from public.clubs where id = target_club) then
    raise exception 'Verein % existiert nicht', target_club;
  end if;

  /* Gibt es eine Anfrage, die noch nicht bezahlt ist? Dann ist hier Schluss. */
  select r.id, r.status into offene
    from public.club_access_requests r
   where r.club_id = target_club
     and r.status in ('offen', 'rechnung_erstellt', 'rechnung_versendet')
   order by r.created_at desc limit 1;

  if offene.id is not null then
    raise exception 'Der Verein hat eine offene Anfrage im Zustand "%". Freischalten geht erst nach "rechnung_bezahlt".', offene.status
      using errcode = 'P0001';
  end if;

  plan_code := 'club_' || lower(trim(stufe)) || '_yearly';
  select id into plan_id from public.subscription_plans where code = plan_code;
  if plan_id is null then
    raise exception 'Unbekannte Stufe "%" - erwartet basic, plus oder pro', stufe;
  end if;

  beleg := coalesce(
    nullif(trim(belegnummer), ''),
    -- Wenn eine bezahlte Anfrage dahintersteht, ist ihre Rechnungsnummer die
    -- richtige Zuordnung.
    (select nullif(trim(r.rechnungsnummer), '') from public.club_access_requests r
      where r.club_id = target_club and r.status = 'rechnung_bezahlt'
      order by r.created_at desc limit 1),
    'rechnung-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS') || '-' || left(target_club::text, 8)
  );

  select max(s.current_period_end) into bisheriges_ende
    from public.club_subscriptions s
   where s.club_id = target_club and s.status = 'active';
  beginn := greatest(now(), coalesce(bisheriges_ende, now()));

  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';

  insert into public.club_subscriptions
    (club_id, plan_id, provider, provider_subscription_id, status,
     current_period_start, current_period_end, last_payment_at)
  values
    (target_club, plan_id, 'manual', beleg,
     'active', now(), beginn + laufzeit, now());

  update public.clubs
     set vereinbarte_zugaenge = case
           when zugaenge is null then vereinbarte_zugaenge
           when zugaenge <= 0 then null
           else zugaenge
         end,
         /* Gleiche Lesart wie oben: null = unveraendert lassen, 0 = zurueck
            auf die Staffel des Tarifs. Ein leeres Feld in der Konsole darf
            eine Sondervereinbarung nicht stillschweigend loeschen. */
         vereinbarte_fans = case
           when fan_zugaenge is null then vereinbarte_fans
           when fan_zugaenge <= 0 then null
           else fan_zugaenge
         end,
         sponsoring_freigeschaltet = coalesce(sponsoring, sponsoring_freigeschaltet)
   where id = target_club;

  update public.club_access_requests r
     set status = 'freigeschaltet', handled_at = now(), freigeschaltet_am = now()
   where r.status = 'rechnung_bezahlt'
     and (
       r.club_id = target_club
       or (r.club_id is null
           and lower(trim(r.club_name)) = (select lower(trim(c.name)) from public.clubs c where c.id = target_club))
     );

  return query
    select c.name,
           public.club_subscription_tier(c.id),
           public.club_account_limit(c.id),
           c.sponsoring_freigeschaltet,
           (select max(s.current_period_end) from public.club_subscriptions s
             where s.club_id = c.id and s.status = 'active'),
           public.club_fan_limit(c.id)
      from public.clubs c where c.id = target_club;
end;
$function$;

-- verein_sperren behaelt Signatur und Rueckgabetyp - nur die neue Spalte muss
-- mit zurueckgesetzt werden, sonst ueberlebte eine Sondervereinbarung ueber
-- Fan-Plaetze die Sperre.
create or replace function public.verein_sperren(target_club uuid)
 returns table(verein text, tarif text, grenze integer)
 language plpgsql
 security definer
 set search_path to ''
as $function$
begin
  update public.club_subscriptions
     set status = 'expired', cancelled_at = now()
   where club_id = target_club and status = 'active';
  update public.clubs
     set vereinbarte_zugaenge = null,
         vereinbarte_fans = null,
         sponsoring_freigeschaltet = false
   where id = target_club;

  return query
    select c.name, public.club_subscription_tier(c.id), public.club_account_limit(c.id)
      from public.clubs c where c.id = target_club;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 11) Rechte
-- ---------------------------------------------------------------------------
-- Gleiche Verteilung wie bei den vorhandenen Geschwistern: was die App liest,
-- darf 'authenticated'; was nur der Betreiber ausloest, bleibt beim
-- Dienstschluessel. Erst alles von PUBLIC nehmen, dann gezielt geben.
revoke all on function public.rollensatz_ist_fan(public.club_role[]) from public;
revoke all on function public.mitgliedschaft_ist_fan(uuid) from public;
revoke all on function public.club_fan_count(uuid) from public;
revoke all on function public.club_fan_limit(uuid) from public;
revoke all on function public.club_fan_usage(uuid) from public;
revoke all on function public.club_kontingent_uebersicht(uuid) from public;
revoke all on function public.club_kontingent_pruefen(uuid, boolean, integer) from public;
revoke all on function public.betreiber_kennzahlen() from public;
revoke all on function public.verein_freischalten(uuid, text, integer, interval, text, boolean, integer) from public;

grant execute on function public.rollensatz_ist_fan(public.club_role[]) to authenticated, service_role;
grant execute on function public.mitgliedschaft_ist_fan(uuid) to authenticated, service_role;
grant execute on function public.club_fan_count(uuid) to authenticated, service_role;
grant execute on function public.club_fan_limit(uuid) to authenticated, service_role;
grant execute on function public.club_fan_usage(uuid) to authenticated, service_role;
grant execute on function public.club_kontingent_uebersicht(uuid) to authenticated, service_role;
-- club_kontingent_pruefen ist Innenleben der beiden Trigger. Trigger brauchen
-- kein EXECUTE-Recht, also bekommt sie niemand von aussen.
grant execute on function public.club_kontingent_pruefen(uuid, boolean, integer) to service_role;
grant execute on function public.betreiber_kennzahlen() to service_role;
grant execute on function public.verein_freischalten(uuid, text, integer, interval, text, boolean, integer) to service_role;

-- ---------------------------------------------------------------------------
-- 12) Nachweis
-- ---------------------------------------------------------------------------
-- Was hier steht, muss nach dem Einspielen stimmen:
--   * je Verein Mitglieder + Fans = die alte Gesamtzahl (nichts verschwindet),
--   * kein Verein ueber einer der beiden Grenzen,
--   * die Staffel liefert 100/350/1000 und 100/200/500,
--   * beide Trigger haengen.
select c.name                                            as verein,
       public.club_subscription_tier(c.id)               as tarif,
       c.vereinbarte_zugaenge,
       c.vereinbarte_fans,
       public.club_account_count(c.id)                   as mitglieder,
       public.club_account_limit(c.id)                   as mitglieder_grenze,
       public.club_fan_count(c.id)                       as fans,
       public.club_fan_limit(c.id)                       as fan_grenze,
       public.club_account_count(c.id) + public.club_fan_count(c.id) as summe_konten,
       (select count(*) from public.club_memberships m
         where m.club_id = c.id and m.status = 'active'
           and m.profile_id is not null and m.is_managed_profile = false) as summe_vorher,
       case when public.club_account_count(c.id) <= public.club_account_limit(c.id)
             and (public.club_subscription_tier(c.id) = 'none'
                  or public.club_fan_count(c.id) <= public.club_fan_limit(c.id))
            then 'ok' else 'PRUEFEN' end                 as stand,
       (select count(*) from pg_trigger t
         where t.tgrelid = 'public.membership_roles'::regclass
           and t.tgname = 'membership_roles_kontingent'
           and not t.tgisinternal)                       as trigger_rollen,
       (select count(*) from pg_trigger t
         where t.tgrelid = 'public.club_memberships'::regclass
           and t.tgname = 'club_memberships_account_limit'
           and not t.tgisinternal)                       as trigger_beitritt
  from public.clubs c
 order by c.name;
