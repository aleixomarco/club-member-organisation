/* Rollenmodell: Jede Mitgliedschaft ist entweder Mitglied oder Fan.

 * DAS MODELL
 * Stufe 1 einer Mitgliedschaft ist genau EINES von beiden: 'mitglied' oder
 * 'fan'. Beide bleiben Zeilen in membership_roles - eine eigene Spalte haette
 * jede Rechtefunktion umgeschrieben, die heute auf die Rollenzeilen schaut.
 *   Mitglied: dazu beliebig viele weitere Rollen (Athlet/in, Trainer/in, ...).
 *   Fan:      nur 'fan'. Ein Fan hat NIE weitere Rechte oder Rollen und steht
 *             in keiner Mannschaft.
 *
 * WARUM DAS IN DIE DATENBANK GEHOERT
 * Bisher war 'fan' nur eine Rolle unter vielen. Jeder Weg konnte eine zweite
 * daneben legen: respond_to_join_request fuegte die gewaehlte Rolle hinzu, die
 * Rollenvergabe der App schrieb die Differenz direkt in die Tabelle,
 * claim_managed_membership vereinigte Rollensaetze, und register_for_club gab
 * dem ersten Mitglied eines Vereins vereinsadmin und sysadmin - auch wenn es
 * "Fan" gewaehlt hatte. In der Produktion stehen deshalb vier Fans mit
 * weiteren Rollen da. Dieselbe Lehre wie bei den abgeschafften Rollen
 * (20260905180000): Ein Filter in der App wirkt erst, wenn jedes Geraet die
 * neue Fassung hat. Die Datenbank ist die einzige Stelle, die es fuer alle
 * zugleich durchsetzt - auch fuer die ausgelieferte Store-App.
 *
 * WARUM EIN AUSLOESER UND KEIN EXCLUDE-CONSTRAINT
 * Fast alle Einfuegungen in membership_roles enden mit "on conflict do
 * nothing". Dieses ON CONFLICT nimmt auch einen Ausschluss-Constraint als
 * Schiedsrichter: Ein fan+trainer-Einfuegen waere STILL verworfen worden, und
 * die App haette Erfolg gemeldet. Ein Ausloeser wirft dagegen immer. Die
 * Hausregel gilt weiter: Ausnahme statt stillem Verwerfen.
 *
 * WARUM DIE SPERRE AUF DIE MITGLIEDSCHAFT
 * "Gibt es schon eine andere Rolle?" ist eine Frage an andere Zeilen. Zwei
 * gleichzeitige Transaktionen - die eine legt 'fan' an, die andere 'trainer' -
 * saehen jeweils die Zeile der anderen nicht und kaemen beide durch. Die
 * Waechter sperren deshalb zuerst die Zeile in club_memberships (SELECT ...
 * FOR UPDATE); die zweite Transaktion wartet, bis die erste fertig ist, und
 * sieht dann deren Zeile.
 *
 * WAS SICH SONST AENDERT
 *   beitritt_entscheiden     neu: Aufnahme mit Stufe und Zusatzrollen in
 *                            EINER Transaktion; Ablehnen setzt 'inactive'
 *   mitgliedsrollen_setzen   neu: Rollen einer Mitgliedschaft als Ganzes setzen
 *   respond_to_join_request  alte Signatur bleibt aufrufbar (aeltere App-
 *                            Staende), laeuft aber ueber beitritt_entscheiden.
 *                            Damit verschwinden zwei bestehende Fehler: Der
 *                            Ablehnen-Zweig schrieb einen Status, den das
 *                            Enum nicht kennt, und ein Organisator konnte
 *                            vereinsadmin und sysadmin vergeben.
 *   register_for_club        Signatur UNVERAENDERT; nur drei Stellen im Rumpf
 *   sync_club_role_entitlement  behaelt 'fan'
 *   claim_managed_membership ein Fan, der ein Spielerprofil uebernimmt, wird
 *                            Mitglied
 *
 * WER ENTSCHEIDET
 * Beitrittsanfragen und Rollen: vereinsadmin, sysadmin und organisator - so,
 * wie die Oberflaeche es seit 20260909060000 zeigt. vereinsadmin und sysadmin
 * vergeben oder nehmen darf aber nur, wer selbst eine der beiden Rollen hat.
 */

-- ====================================================================
-- DATENBEREINIGUNG (vom Product Owner zu bestaetigen)
-- ====================================================================
-- Muss VOR den Waechtern laufen: Ein Ausloeser prueft nur, was neu
-- geschrieben wird - die bestehenden Mischfaelle blieben sonst stehen und
-- liessen sich ueber die App nicht mehr aufloesen, weil jeder Speicherversuch
-- an ihnen scheitert.
--
-- Stand der Produktion vor dieser Migration: vier Mitgliedschaften tragen
-- 'fan' neben anderen Rollen. Zwei davon halten saemtliche Leitungsrollen
-- einschliesslich sysadmin, zwei nur 'fan' und 'mitglied'.
--
-- NIE werden hier Leitungsrollen geloescht. Der Waechter letzter_vereinsadmin
-- wuerde die ganze Migration abbrechen, und wer den Verein fuehrt, soll ihn
-- nach dem Einspielen weiter fuehren koennen.

-- (a) Fan PLUS eine Rolle ausser 'mitglied' -> die Person ist Mitglied.
--     Sie fuehrt, trainiert oder spielt; 'fan' ist hier das Versehen, nicht
--     die Rechte. Zuerst 'mitglied' sicherstellen, dann 'fan' entfernen -
--     damit hat jede dieser Mitgliedschaften danach genau eine Stufe.
insert into public.membership_roles (membership_id, role)
select distinct f.membership_id, 'mitglied'::public.club_role
  from public.membership_roles f
 where f.role = 'fan'
   and exists (select 1 from public.membership_roles x
                where x.membership_id = f.membership_id
                  and x.role not in ('fan', 'mitglied'))
on conflict (membership_id, role) do nothing;

delete from public.membership_roles f
 where f.role = 'fan'
   and exists (select 1 from public.membership_roles x
                where x.membership_id = f.membership_id
                  and x.role not in ('fan', 'mitglied'));

-- (b) GENAU {'fan', 'mitglied'} -> die Person bleibt Fan, 'mitglied' faellt.
--     OFFEN - wartet auf die Bestaetigung des Product Owners. Die App hat
--     diese Faelle bisher schon als Fan behandelt (istNurFan), deshalb ist das
--     die Voreinstellung. Entscheidet er "bleibt Mitglied", wird diese
--     Anweisung durch die auskommentierte darunter ERSETZT (nicht ergaenzt).
delete from public.membership_roles m
 where m.role = 'mitglied'
   and exists (select 1 from public.membership_roles f
                where f.membership_id = m.membership_id and f.role = 'fan')
   and not exists (select 1 from public.membership_roles x
                    where x.membership_id = m.membership_id
                      and x.role not in ('fan', 'mitglied'));
-- Umgekehrte Fassung ("bleibt Mitglied"):
-- delete from public.membership_roles f
--  where f.role = 'fan'
--    and exists (select 1 from public.membership_roles m
--                 where m.membership_id = f.membership_id and m.role = 'mitglied')
--    and not exists (select 1 from public.membership_roles x
--                     where x.membership_id = f.membership_id
--                       and x.role not in ('fan', 'mitglied'));

-- (c) Wer danach Fan ist, steht in keiner Mannschaft. Erwartet: keine Zeile.
delete from public.team_members tm
 where exists (select 1 from public.membership_roles r
                where r.membership_id = tm.membership_id and r.role = 'fan');

-- ====================================================================
-- 1) Waechter: 'fan' steht allein
-- ====================================================================
/* SECURITY DEFINER, weil die Sperre auf club_memberships UPDATE-Rechte
   verlangt. Ohne sie haenge der Waechter davon ab, wer gerade schreibt -
   ein Organisator ueber eine RPC, ein Admin direkt ueber die Tabellenregel. */
create or replace function public.fan_exklusiv_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alte_rolle public.club_role;
begin
  perform 1 from public.club_memberships where id = new.membership_id for update;

  /* Bei einem UPDATE steht die alte Zeile noch in der Tabelle. Ohne diesen
     Ausschluss zaehlte "mitglied -> fan" die eigene alte Zeile als zweite
     Rolle. */
  if tg_op = 'UPDATE' then
    if old.membership_id = new.membership_id then
      v_alte_rolle := old.role;
    end if;
  end if;

  if new.role = 'fan' then
    if exists (select 1 from public.membership_roles r
                where r.membership_id = new.membership_id
                  and r.role <> 'fan'
                  and r.role is distinct from v_alte_rolle) then
      raise exception 'fan_exklusiv'
        using errcode = 'check_violation',
              detail = 'Ein Fan hat keine weiteren Rollen. Diese Mitgliedschaft hat bereits andere Rollen.',
              hint = 'Erst die anderen Rollen entfernen oder die Stufe ueber mitgliedsrollen_setzen wechseln.';
    end if;
  elsif exists (select 1 from public.membership_roles r
                 where r.membership_id = new.membership_id
                   and r.role = 'fan'
                   and r.role is distinct from v_alte_rolle) then
    raise exception 'fan_exklusiv'
      using errcode = 'check_violation',
            detail = format('Ein Fan hat keine weiteren Rollen - %s laesst sich nicht vergeben.', new.role),
            hint = 'Erst die Stufe auf Mitglied wechseln (mitgliedsrollen_setzen).';
  end if;
  return new;
end;
$$;

drop trigger if exists membership_roles_fan_exklusiv on public.membership_roles;
create trigger membership_roles_fan_exklusiv
  before insert or update on public.membership_roles
  for each row execute function public.fan_exklusiv_pruefen();

-- ====================================================================
-- 2) Waechter: kein Fan in einer Mannschaft
-- ====================================================================
/* Mannschaftszeilen tragen Rechte - Chat, Termine, Aufstellung. Die Tabelle
   kennt membership_roles nicht; ein Admin koennte einen Fan ueber die
   Tabellenregel direkt eintragen. Dieselbe Sperre wie oben, damit ein
   gleichzeitiger Stufenwechsel nicht dazwischenrutscht. */
create or replace function public.fan_ohne_mannschaft()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform 1 from public.club_memberships where id = new.membership_id for update;
  if exists (select 1 from public.membership_roles r
              where r.membership_id = new.membership_id and r.role = 'fan') then
    raise exception 'fan_keine_mannschaft'
      using errcode = 'check_violation',
            detail = 'Ein Fan gehoert keiner Mannschaft an.',
            hint = 'Erst die Stufe auf Mitglied wechseln.';
  end if;
  return new;
end;
$$;

drop trigger if exists team_members_kein_fan on public.team_members;
create trigger team_members_kein_fan
  before insert or update of membership_id on public.team_members
  for each row execute function public.fan_ohne_mannschaft();

revoke all on function public.fan_exklusiv_pruefen() from public, anon, authenticated;
revoke all on function public.fan_ohne_mannschaft() from public, anon, authenticated;

-- ====================================================================
-- 3) Zwei Bausteine fuer die Rollen-RPCs
-- ====================================================================
/* Aus Stufe und Zusatzrollen den vollstaendigen Rollensatz bilden - und
   dabei alles pruefen, was keine Oberflaeche garantieren kann:
     - Stufe ist 'mitglied' oder 'fan'
     - ein Fan bekommt keine Zusatzrolle (Ausnahme statt Verwerfen)
     - nur Rollen, die es noch gibt (die abgeschafften fallen hier durch)
     - vereinsadmin und sysadmin aendert nur, wer selbst eine davon hat.
       Verglichen wird mit dem bisherigen Satz: Ein Organisator darf einem
       Admin also andere Rollen geben, ihm die Leitung aber weder nehmen noch
       jemand anderem geben. */
create or replace function public.rollensatz_bilden(
  target_club uuid,
  stufe public.club_role,
  zusatzrollen public.club_role[],
  bisher public.club_role[] default '{}'
)
returns public.club_role[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_zusatz public.club_role[];
  v_erlaubt constant public.club_role[] := array['spieler', 'trainer', 'kapitaen', 'teammanager',
    'redakteur', 'sponsorenmanager', 'organisator', 'vereinsadmin', 'sysadmin']::public.club_role[];
  v_leitung constant public.club_role[] := array['vereinsadmin', 'sysadmin']::public.club_role[];
  v_neu public.club_role[];
begin
  if stufe is null or stufe not in ('mitglied', 'fan') then
    raise exception 'stufe_ungueltig' using errcode = 'check_violation',
      detail = 'Stufe 1 ist entweder mitglied oder fan.';
  end if;

  select coalesce(array_agg(distinct z), '{}') into v_zusatz
    from unnest(coalesce(zusatzrollen, '{}'::public.club_role[])) z
   where z is not null and z not in ('mitglied', 'fan');

  if stufe = 'fan' and cardinality(v_zusatz) > 0 then
    raise exception 'fan_exklusiv' using errcode = 'check_violation',
      detail = 'Ein Fan hat keine weiteren Rollen.';
  end if;
  if not (v_zusatz <@ v_erlaubt) then
    raise exception 'rolle_nicht_erlaubt' using errcode = 'check_violation',
      detail = 'Unbekannte oder abgeschaffte Rolle.';
  end if;

  v_neu := array[stufe] || v_zusatz;

  if not public.has_club_role(target_club, v_leitung)
     and exists (select 1 from unnest(v_leitung) l
                  where (l = any(v_neu)) <> (l = any(coalesce(bisher, '{}'::public.club_role[])))) then
    raise exception 'rolle_nicht_erlaubt' using errcode = 'insufficient_privilege',
      detail = 'Vereins-Administrator und Sys-Admin vergibt und entzieht nur, wer selbst eine dieser Rollen hat.';
  end if;

  return v_neu;
end;
$$;

/* Den Rollensatz einer Mitgliedschaft auf genau "neu" bringen.
   Die Reihenfolge ist Absicht:
     1. zuerst LOESCHEN, was wegfaellt. Andersherum lehnte der Fan-Waechter
        das Einfuegen ab ("fan_exklusiv"), bevor der Waechter
        letzter_vereinsadmin ueberhaupt gefragt wird - wer den letzten Admin
        zum Fan machen will, laese dann den falschen Grund.
     2. Mannschaftszeilen der weggefallenen Funktionen. Beim Fan alle.
        Frueher blieben die Zeilen einer entzogenen Athletenrolle stehen: Die
        Person sah weiter Chat und Termine der Mannschaft.
     3. dann EINFUEGEN, was neu ist.
   Alles in der Transaktion des Aufrufers - scheitert ein Schritt, bleibt der
   alte Stand vollstaendig erhalten, statt halb geschrieben. */
create or replace function public.rollensatz_anwenden(target_membership uuid, neu public.club_role[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bisher public.club_role[];
begin
  select coalesce(array_agg(r.role), '{}') into v_bisher
    from public.membership_roles r where r.membership_id = target_membership;

  delete from public.membership_roles r
   where r.membership_id = target_membership and r.role <> all(neu);

  if 'fan' = any(neu) then
    delete from public.team_members tm where tm.membership_id = target_membership;
  else
    delete from public.team_members tm
     where tm.membership_id = target_membership
       and tm.function = any(v_bisher) and tm.function <> all(neu);
  end if;

  insert into public.membership_roles (membership_id, role, granted_by)
  select target_membership, x, auth.uid() from unnest(neu) x
  on conflict (membership_id, role) do nothing;
end;
$$;

revoke all on function public.rollensatz_bilden(uuid, public.club_role, public.club_role[], public.club_role[]) from public, anon, authenticated;
revoke all on function public.rollensatz_anwenden(uuid, public.club_role[]) from public, anon, authenticated;

-- ====================================================================
-- 4) Beitrittsanfrage entscheiden - der eine Weg fuer beide Richtungen
-- ====================================================================
/* Ersetzt zwei auseinanderlaufende Wege: MembershipApprovalsPanel schrieb den
   Status direkt in die Tabelle und liess die Rollen, wie sie waren;
   JoinRequestsManager rief respond_to_join_request. Jetzt gibt es eine
   Funktion, und Status und Rollen aendern sich zusammen oder gar nicht.

   Rollen werden VOR dem Status geschrieben: Die AFTER-Ausloeser auf
   club_memberships (Aufnahme-Meldung, Willkommensgruss) feuern beim
   Status-UPDATE und sollen den endgueltigen Rollensatz sehen.
   Die Zugangsgrenze (club_account_limit_reached) wirft beim Status-UPDATE -
   dann rollt auch der Rollenwechsel zurueck.

   Ablehnen heisst 'inactive', wie im Panel seit 20260901030000: "diesmal
   nicht", keine Sperre. Wer abgelehnt wurde, darf sofort neu anfragen. */
create or replace function public.beitritt_entscheiden(
  target_membership uuid,
  approve boolean,
  stufe public.club_role default 'mitglied',
  zusatzrollen public.club_role[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
  v_status public.membership_status;
  v_team text;
  v_bisher public.club_role[];
  v_neu public.club_role[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select m.club_id, m.status, m.requested_team into v_club, v_status, v_team
    from public.club_memberships m where m.id = target_membership
     for update;
  if v_club is null then raise exception 'Membership request not found'; end if;
  if not public.has_club_role(v_club, array['sysadmin', 'vereinsadmin', 'organisator']::public.club_role[]) then
    raise exception 'Not authorized to review join requests' using errcode = 'insufficient_privilege';
  end if;
  if v_status <> 'pending' then raise exception 'This request has already been handled'; end if;

  if not coalesce(approve, false) then
    update public.club_memberships m
       set status = 'inactive',
           rejection_count = coalesce(m.rejection_count, 0) + 1,
           blocked_until = null,
           updated_at = now()
     where m.id = target_membership;
    return;
  end if;

  select coalesce(array_agg(r.role), '{}') into v_bisher
    from public.membership_roles r where r.membership_id = target_membership;
  v_neu := public.rollensatz_bilden(v_club, stufe, zusatzrollen, v_bisher);
  perform public.rollensatz_anwenden(target_membership, v_neu);

  /* Die Mannschaftszuordnung aus der Anfrage - bisher ein zweiter, nicht
     atomarer Aufruf der App nach dem Freigeben. */
  if 'spieler' = any(v_neu) and nullif(trim(v_team), '') is not null then
    insert into public.team_members (team_id, membership_id, function)
    select t.id, target_membership, 'spieler'
      from public.teams t
     where t.club_id = v_club and t.active and t.name = trim(v_team)
    on conflict do nothing;
  end if;

  update public.club_memberships m
     set status = 'active', blocked_until = null, updated_at = now()
   where m.id = target_membership;
end;
$$;

revoke all on function public.beitritt_entscheiden(uuid, boolean, public.club_role, public.club_role[]) from public, anon;
grant execute on function public.beitritt_entscheiden(uuid, boolean, public.club_role, public.club_role[]) to authenticated;

-- ====================================================================
-- 5) respond_to_join_request - alte Signatur, neuer sicherer Weg
-- ====================================================================
/* Aeltere App-Staende rufen diese Funktion noch mit EINER Rolle. Sie bleibt
   deshalb mit derselben Signatur bestehen, entscheidet aber nicht mehr
   selbst:
     - Ablehnen    -> beitritt_entscheiden(..., false): Status 'inactive'.
                      Vorher brach jedes Ablehnen ab, weil der geschriebene
                      Status im Enum nicht vorkommt.
     - 'fan'       -> Fan, ohne Zusatzrollen
     - 'mitglied' oder keine Rolle -> die Stufe, die der Bewerber selbst
                      angegeben hat. Die alte Oberflaeche schickte 'mitglied',
                      wenn niemand etwas auswaehlte; ein Fan waere so
                      stillschweigend Mitglied geworden.
     - jede andere -> Mitglied mit dieser Rolle zusaetzlich zu den bereits
                      angefragten. Pruefung und Leitungsschutz wie ueberall:
                      Ein Organisator vergibt kein vereinsadmin/sysadmin mehr.
                      Das war bisher moeglich - auch an ein zweites eigenes
                      Konto. */
create or replace function public.respond_to_join_request(
  target_membership uuid,
  approve boolean,
  granted_role public.club_role default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bisher public.club_role[];
  v_zusatz public.club_role[];
begin
  if not coalesce(approve, false) then
    perform public.beitritt_entscheiden(target_membership, false);
    return;
  end if;

  select coalesce(array_agg(r.role), '{}') into v_bisher
    from public.membership_roles r where r.membership_id = target_membership;

  if granted_role = 'fan'
     or (coalesce(granted_role, 'mitglied') = 'mitglied' and 'fan' = any(v_bisher)) then
    perform public.beitritt_entscheiden(target_membership, true, 'fan', '{}');
    return;
  end if;

  select coalesce(array_agg(distinct x), '{}') into v_zusatz
    from unnest(v_bisher || granted_role) x
   where x is not null and x not in ('mitglied', 'fan');
  perform public.beitritt_entscheiden(target_membership, true, 'mitglied', v_zusatz);
end;
$$;

revoke all on function public.respond_to_join_request(uuid, boolean, public.club_role) from public, anon;
grant execute on function public.respond_to_join_request(uuid, boolean, public.club_role) to authenticated;

-- ====================================================================
-- 6) Rollen einer Mitgliedschaft setzen
-- ====================================================================
/* Die App schrieb Rollen bisher Zeile fuer Zeile direkt in die Tabelle:
   erst alle neuen einfuegen, dann alle alten loeschen. Mit dem Fan-Waechter
   scheitert genau diese Reihenfolge an jedem Stufenwechsel, und ohne
   Transaktion blieb nach einem Fehler in der Mitte ein halber Stand stehen -
   zum Beispiel, wenn letzter_vereinsadmin das Entfernen des letzten Admins
   verweigerte, nachdem die neuen Rollen schon eingefuegt waren.
   Hier wird der Satz als Ganzes gesetzt. Ausserdem darf jetzt auch der
   Organisator Rollen vergeben - die Tabellenregel liess ihn nie, obwohl die
   Oberflaeche ihm die Benutzerverwaltung zeigt. */
create or replace function public.mitgliedsrollen_setzen(
  target_membership uuid,
  stufe public.club_role,
  zusatzrollen public.club_role[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club uuid;
  v_bisher public.club_role[];
  v_neu public.club_role[];
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select m.club_id into v_club from public.club_memberships m where m.id = target_membership for update;
  if v_club is null then raise exception 'Membership not found'; end if;
  if not public.has_club_role(v_club, array['sysadmin', 'vereinsadmin', 'organisator']::public.club_role[]) then
    raise exception 'Not authorized to manage roles' using errcode = 'insufficient_privilege';
  end if;

  select coalesce(array_agg(r.role), '{}') into v_bisher
    from public.membership_roles r where r.membership_id = target_membership;
  v_neu := public.rollensatz_bilden(v_club, stufe, zusatzrollen, v_bisher);
  perform public.rollensatz_anwenden(target_membership, v_neu);
end;
$$;

revoke all on function public.mitgliedsrollen_setzen(uuid, public.club_role, public.club_role[]) from public, anon;
grant execute on function public.mitgliedsrollen_setzen(uuid, public.club_role, public.club_role[]) to authenticated;

-- ====================================================================
-- 7) register_for_club - Signatur unveraendert, drei Stellen im Rumpf
-- ====================================================================
/* Der Rumpf ist woertlich der aus 20260906200000 (siehe dort, warum diese
   Funktion nicht aus dem Gedaechtnis neu geschrieben wird). Geaendert:
     A. Erneute Anfrage einer nicht aktiven Mitgliedschaft: Die alten
        Rollenzeilen fallen zuerst weg. Vorher haeuften sie sich - wer einmal
        als Athlet angefragt hatte und spaeter als Fan, stand mit mitglied,
        spieler UND fan da. Mit dem Fan-Waechter wuerde dieselbe Anfrage jetzt
        abbrechen.
        Der Waechter letzter_vereinsadmin kann das Loeschen einer alten
        Admin-Zeile verweigern (Verein ohne weiteren aktiven Admin). Dann
        bleiben vereinsadmin/sysadmin stehen, und die Anfrage laeuft als
        Mitglied weiter (siehe B) - statt mit einer unverstaendlichen Meldung
        abzubrechen.
     B. Fan nur, wenn daneben nichts steht: Das erste Mitglied eines Vereins
        bekommt vereinsadmin und sysadmin und ist deshalb Mitglied, auch wenn
        es "Fan" gewaehlt hat. Ein Verein, dessen einziger Admin Fan waere,
        haette niemanden, der ihn fuehren darf.
     C. 'spieler' wird weiter angenommen - aeltere App-Staende und die bei der
        Registrierung gespeicherten Kontodaten (account_role) schicken es
        noch. Es bedeutet Stufe Mitglied plus Athlet/in, wie bisher. Die
        neuen Auswahlen bieten nur noch Mitglied und Fan an; weitere Rollen
        vergibt die Vereinsleitung bei der Freigabe. */
create or replace function public.register_for_club(
  target_club uuid,
  member_name text,
  account_role public.club_role default 'mitglied',
  member_birthdate date default null,
  member_team text default null
)
returns table (membership_id uuid, membership_status public.membership_status)
language plpgsql security definer set search_path = '' as $$
declare
  new_membership_id uuid;
  new_status public.membership_status;
  first_member boolean;
  bisher public.membership_status;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if account_role not in ('mitglied', 'spieler', 'fan') then raise exception 'Invalid self-service role'; end if;
  if nullif(trim(member_name), '') is null then raise exception 'Name required'; end if;

  perform set_config('app.mitgliedschaft_pflege', 'ja', true);

  perform 1 from public.clubs where id = target_club for update;
  if not found then raise exception 'Club not found'; end if;

  select m.status into bisher
    from public.club_memberships m
   where m.club_id = target_club and m.profile_id = auth.uid();

  if bisher = 'blocked' then
    raise exception 'Blocked from this club' using errcode = 'P0001';
  end if;
  if bisher = 'active' then
    return query
      select m.id, m.status from public.club_memberships m
       where m.club_id = target_club and m.profile_id = auth.uid();
    return;
  end if;

  /* Der entscheidende Unterschied: Nicht "gerade niemand aktiv", sondern
     "noch nie jemand da gewesen". Ein verwaister Verein bleibt verwaist,
     bis der Betreiber ihn uebergibt - das ist eine Absprache, keine
     Selbstbedienung. */
  select c.uebergabe_offen into first_member from public.clubs c where c.id = target_club;
  first_member := coalesce(first_member, false)
                  and not exists (select 1 from public.club_memberships m where m.club_id = target_club);

  new_status := case when first_member then 'active'::public.membership_status else 'pending'::public.membership_status end;

  update public.profiles
     set full_name = trim(member_name),
         birthdate = coalesce(member_birthdate, birthdate)
   where id = auth.uid();

  insert into public.club_memberships (
    club_id, profile_id, display_name, email, member_since, status, requested_team, created_by
  )
  select target_club, auth.uid(), trim(member_name), u.email, extract(year from now())::integer,
    new_status, nullif(trim(member_team), ''), auth.uid()
  from auth.users u where u.id = auth.uid()
  on conflict (club_id, profile_id) do update
    set display_name = excluded.display_name,
        email = excluded.email,
        requested_team = excluded.requested_team,
        status = excluded.status,
        updated_at = now()
  returning id into new_membership_id;

  /* A: Erneute Anfrage - alte Rollen weg, bevor die neue Angabe gilt. */
  if bisher is not null then
    begin
      delete from public.membership_roles r where r.membership_id = new_membership_id;
    exception when raise_exception then
      if sqlerrm <> 'letzter_vereinsadmin' then raise; end if;
      delete from public.membership_roles r
       where r.membership_id = new_membership_id and r.role not in ('vereinsadmin', 'sysadmin');
    end;
  end if;

  /* Ein Fan bekommt NUR die Fan-Rolle - kein "mitglied" daneben. Sonst zaehlte
     er als formales Mitglied, und der Verein wuerde ihm Beitraege berechnen.
     B: ... und nur, wenn er nicht zugleich den Verein fuehrt. */
  if account_role = 'fan' and not first_member
     and not exists (select 1 from public.membership_roles r
                      where r.membership_id = new_membership_id and r.role <> 'fan') then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'fan', auth.uid()) on conflict do nothing;
  else
  insert into public.membership_roles (membership_id, role, granted_by)
  values (new_membership_id, 'mitglied', auth.uid()) on conflict do nothing;
  /* C: nur noch 'spieler' landet hier - 'fan' darf im Mitglied-Zweig nie
     dazukommen. */
  if account_role not in ('mitglied', 'fan') then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, account_role, auth.uid()) on conflict do nothing;
  end if;
  end if;
  if first_member then
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'vereinsadmin', auth.uid()), (new_membership_id, 'sysadmin', auth.uid())
    on conflict do nothing;
    -- Ab jetzt ist der Verein vergeben.
    update public.clubs set uebergabe_offen = false where id = target_club;
  end if;

  return query select new_membership_id, new_status;
end;
$$;

grant execute on function public.register_for_club(uuid, text, public.club_role, date, text) to authenticated, service_role;

-- ====================================================================
-- 8) sync_club_role_entitlement - 'fan' bleibt stehen
-- ====================================================================
/* Ohne Tarif raeumt die Funktion alle bezahlten Rollen ab. Sie loeschte dabei
   auch 'fan': Ein Fan in einem Verein ohne Abo stand danach ohne jede Rolle
   da, galt fuer die App nicht mehr als Fan und sah Trainings, Aufgaben und
   den Support-Reiter. 'fan' schaltet nichts Bezahltes frei - es ist eine
   Stufe, keine Funktion. Der uebrige Rumpf bleibt woertlich
   (20260910020000). */
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
    where role not in ('mitglied', 'fan', 'vereinsadmin', 'sysadmin')
      and membership_id in (select id from public.club_memberships where club_id = target_club);
  end if;
  return v_tier;
end;
$$;

-- ====================================================================
-- 9) claim_managed_membership - ein Fan wird beim Uebernehmen Mitglied
-- ====================================================================
/* Wer ein ohne Konto angelegtes Spielerprofil uebernimmt, bekommt dessen
   Rollen (in der Regel mitglied und spieler) und Mannschaften. War das echte
   Konto Fan, scheiterte das jetzt am Fan-Waechter. Wer ein Spielerprofil
   uebernimmt, ist aber offensichtlich kein Fan mehr: 'fan' faellt zuerst,
   'mitglied' kommt dazu. Eine 'fan'-Zeile des Platzhalters wird nicht
   mitgenommen. Der uebrige Rumpf bleibt woertlich (20260808170000). */
create or replace function public.claim_managed_membership(
  target_club uuid,
  managed_membership_id uuid,
  new_membership_id uuid
)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  managed_is_managed boolean;
  managed_club uuid;
  new_profile uuid;
  new_is_managed boolean;
  new_club uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_club_role(target_club, array['sysadmin','vereinsadmin']::public.club_role[]) then
    raise exception 'Club administrator role required';
  end if;
  if managed_membership_id = new_membership_id then raise exception 'Invalid selection'; end if;

  select club_id, is_managed_profile into managed_club, managed_is_managed
  from public.club_memberships where id = managed_membership_id;
  if managed_club is null or managed_club <> target_club or not coalesce(managed_is_managed, false) then
    raise exception 'Source membership must be a managed profile without account in this club';
  end if;

  select club_id, profile_id, is_managed_profile into new_club, new_profile, new_is_managed
  from public.club_memberships where id = new_membership_id;
  if new_club is null or new_club <> target_club or new_profile is null or coalesce(new_is_managed, false) then
    raise exception 'Target membership must be a real, non-managed account in this club';
  end if;

  if exists (select 1 from public.membership_roles where membership_id = new_membership_id and role = 'fan') then
    delete from public.membership_roles where membership_id = new_membership_id and role = 'fan';
    insert into public.membership_roles (membership_id, role, granted_by)
    values (new_membership_id, 'mitglied', auth.uid())
    on conflict (membership_id, role) do nothing;
  end if;

  insert into public.membership_roles (membership_id, role, granted_by)
  select new_membership_id, role, granted_by
  from public.membership_roles where membership_id = managed_membership_id and role <> 'fan'
  on conflict (membership_id, role) do nothing;

  insert into public.team_members (team_id, membership_id, function)
  select team_id, new_membership_id, function
  from public.team_members where membership_id = managed_membership_id
  on conflict do nothing;

  update public.family_links set first_membership_id = new_membership_id
  where first_membership_id = managed_membership_id;
  update public.family_links set second_membership_id = new_membership_id
  where second_membership_id = managed_membership_id;

  update public.fee_records set membership_id = new_membership_id
  where membership_id = managed_membership_id;
  update public.fee_people set membership_id = new_membership_id
  where membership_id = managed_membership_id;
  update public.protocol_tasks set assignee_membership_id = new_membership_id
  where assignee_membership_id = managed_membership_id;
  update public.season_votes set candidate_membership_id = new_membership_id
  where candidate_membership_id = managed_membership_id;
  update public.duty_assignments set membership_id = new_membership_id
  where membership_id = managed_membership_id;

  delete from public.club_memberships where id = managed_membership_id;
end;
$$;

revoke all on function public.claim_managed_membership(uuid, uuid, uuid) from public;
grant execute on function public.claim_managed_membership(uuid, uuid, uuid) to authenticated;

-- ---------------------------------------------------------------- Nachweis
-- Erwartet: fan_mit_weiteren_rollen 0, fans_in_mannschaften 0, waechter 2,
-- alter_ablehnstatus 0, register_for_club_fassungen 1 (keine Ueberladung),
-- abgleich_behaelt_fan 1, die drei *_ausfuehrbar true, fuer_anon_offen 0.
-- ohne_stufe ist eine Zahl fuer den Product Owner: aktive Konten ohne
-- 'mitglied' und ohne 'fan' - meist Fans, denen der alte Rollenabgleich die
-- Fan-Zeile genommen hat. Ihre Stufe laesst sich aus den Daten nicht mehr
-- ablesen.
select
  (select count(*) from public.membership_roles f
     join public.membership_roles x on x.membership_id = f.membership_id and x.role <> 'fan'
    where f.role = 'fan') as fan_mit_weiteren_rollen,
  (select count(*) from public.team_members tm
    where exists (select 1 from public.membership_roles r
                   where r.membership_id = tm.membership_id and r.role = 'fan')) as fans_in_mannschaften,
  (select count(*) from pg_trigger
    where tgname in ('membership_roles_fan_exklusiv', 'team_members_kein_fan')) as waechter,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'respond_to_join_request'
      and p.prosrc like '%''rejected''%') as alter_ablehnstatus,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'register_for_club') as register_for_club_fassungen,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'sync_club_role_entitlement'
      and p.prosrc like '%''fan''%') as abgleich_behaelt_fan,
  has_function_privilege('authenticated',
    'public.register_for_club(uuid, text, public.club_role, date, text)', 'EXECUTE') as beitritt_ausfuehrbar,
  has_function_privilege('authenticated',
    'public.beitritt_entscheiden(uuid, boolean, public.club_role, public.club_role[])', 'EXECUTE') as entscheiden_ausfuehrbar,
  has_function_privilege('authenticated',
    'public.mitgliedsrollen_setzen(uuid, public.club_role, public.club_role[])', 'EXECUTE') as rollen_setzen_ausfuehrbar,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('beitritt_entscheiden', 'mitgliedsrollen_setzen', 'respond_to_join_request',
                        'rollensatz_bilden', 'rollensatz_anwenden')
      and has_function_privilege('anon', p.oid, 'EXECUTE')) as fuer_anon_offen,
  (select count(*) from public.club_memberships m
    where m.status = 'active' and m.profile_id is not null
      and coalesce(m.is_managed_profile, false) = false
      and not exists (select 1 from public.membership_roles r
                       where r.membership_id = m.id and r.role in ('mitglied', 'fan'))) as ohne_stufe;
