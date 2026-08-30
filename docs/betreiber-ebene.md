# Betreiber-Ebene und Auswertungs-Dashboard

Konzept, aufgeschrieben am 25.08.2026. Noch nicht umgesetzt.
Umsetzung erst nach der Freigabe der laufenden Einreichung.

---

## Das Problem

Das Datenmodell kennt heute nur Rollen **innerhalb** eines Vereins. Der
Betreiber der App kommt darin nicht vor.

`sysadmin` sieht auf den ersten Blick nach dieser Rolle aus, ist es aber nicht:

```sql
-- 20260802040000_membership_approvals.sql, Zeile 59
if first_member then
  insert into membership_roles values (…, 'vereinsadmin'), (…, 'sysadmin')
```

**Wer einen Verein anlegt, wird automatisch sysadmin — von seinem Verein.**
Bindet man Betreiber-Rechte an diese Rolle, bekommt sie jeder Vereinsgründer.

Deshalb braucht es eine eigene Ebene, die nicht über eine
Vereinsmitgliedschaft erreichbar ist.

---

## 1. Die Betreiber-Rolle

```sql
create table public.platform_admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);

alter table public.platform_admins enable row level security;
-- Bewusst keine Policy für authenticated: Die Tabelle wird ausschliesslich
-- ueber ist_betreiber() gelesen, und die laeuft als security definer.
-- Niemand soll abfragen koennen, wer Betreiber ist.

create or replace function public.ist_betreiber()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.platform_admins p where p.profile_id = auth.uid());
$$;

grant execute on function public.ist_betreiber() to authenticated;

-- Eintrag von Hand, ueber den SQL-Editor. Absichtlich kein Weg dafuer in der
-- App: Wer Betreiber wird, entscheidet nicht die Oberflaeche.
insert into public.platform_admins (profile_id, note)
select id, 'Betreiber' from public.profiles where email = 'DEINE-ADRESSE';
```

**Warum eine eigene Tabelle und kein Feld an profiles:** Ein Feld waere ueber
jede Profilabfrage sichtbar. So bleibt die Information hinter einer Funktion.

---

## 2. Werbeplatzierung durch den Betreiber

Die Tabellen `sponsors` und `sponsor_placements` existieren bereits und sind
brauchbar. Ihre Regeln muessen nur den Betreiber einschliessen:

```sql
drop policy if exists "sponsor managers manage sponsors" on public.sponsors;
create policy "betreiber verwaltet sponsoren" on public.sponsors for all
  using (public.ist_betreiber()) with check (public.ist_betreiber());

drop policy if exists "sponsor managers manage placements" on public.sponsor_placements;
create policy "betreiber verwaltet platzierungen" on public.sponsor_placements for all
  using (public.ist_betreiber()) with check (public.ist_betreiber());
```

Lesen bleibt bei den Mitgliedern - sie sollen die Anzeigen ja sehen.

**In der App:** Die Anzeigen kommen dann aus `sponsor_placements` statt aus
club_app_state. Vier Plaetze gibt es bereits: dashboard_top, dashboard_bottom,
events_header, profile_bottom. Einblendungen und Klicks zaehlen die Spalten
`impressions` und `clicks` - anders als heute pro Platzierung und damit
auswertbar.

---

## 3. Das Dashboard

Erreichbar nur mit `ist_betreiber()`. Es zeigt Zahlen ueber alle Vereine, nicht
ueber einen.

### Was darauf gehoert

| Kennzahl | Warum sie zaehlt |
|---|---|
| Vereine gesamt, neu im Monat | Waechst es? |
| Mitglieder je Verein | Wo liegt Gewicht |
| Aktive Abos je Stufe | Umsatz |
| Vereine ueber 80 % ihrer Zugaenge | Verkaufsgespraech faellig |
| Vereine an der Grenze der freien Zugaenge | verlorene Kundschaft |
| Werbeplaetze: belegt, Einblendungen, Klicks | Was einem Werbekunden berichtet wird |

Der letzte Punkt betrifft das Geschaeft unmittelbar: Ohne belastbare Zahlen
laesst sich keine Werbeflaeche verkaufen.

### Abfragen

```sql
-- Vereine mit Tarif, Auslastung und Abo-Status
create or replace function public.betreiber_vereinsuebersicht()
returns table(
  verein text, tarif text, belegt integer, grenze integer,
  auslastung numeric, mitglieder bigint, angelegt date
)
language sql stable security definer set search_path = '' as $$
  select c.name,
         public.club_subscription_tier(c.id),
         public.club_account_count(c.id),
         public.club_account_limit(c.id),
         round(100.0 * public.club_account_count(c.id)
               / nullif(public.club_account_limit(c.id), 0), 1),
         (select count(*) from public.club_memberships m
          where m.club_id = c.id and m.status = 'active'),
         c.created_at::date
  from public.clubs c
  where public.ist_betreiber()      -- ohne diese Zeile laege alles offen
  order by c.name;
$$;

-- Umsatz je Monat, Jahresabos anteilig
create or replace function public.betreiber_umsatz()
returns table(laufende_abos bigint, brutto_pro_monat numeric)
language sql stable security definer set search_path = '' as $$
  select count(*),
         round(sum(case p.interval
           when 'month' then p.price_cents / 100.0
           when 'year'  then p.price_cents / 1200.0 end), 2)
  from public.club_subscriptions s
  join public.subscription_plans p on p.id = s.plan_id
  where public.ist_betreiber()
    and s.status = 'active'
    and s.provider <> 'manual'
    and (s.current_period_end is null or s.current_period_end > now());
$$;
```

**Das `where public.ist_betreiber()` ist nicht schmueckend.** Die Funktionen
laufen als security definer und umgehen damit RLS - ohne diese Zeile koennte
jedes angemeldete Mitglied die Zahlen aller Vereine abrufen.

---

## 4. Reihenfolge

1. **Betreiber-Rolle** zuerst. Alles andere baut darauf auf; ohne sie muesste
   es auf `sysadmin` aufsetzen und waere damit falsch.
2. **Sponsoring auf die Tabellen umstellen**, Regeln auf den Betreiber.
3. **Dashboard** mit den Abfragen oben.

Aufwand grob: ein bis zwei Tage.

---

## 5. Was vorher noch wichtiger ist

Der Fund vom 25.08.2026: Termine, Umfragen, Tippergebnisse, Helferplaene,
Protokolle und Sponsorenbuchungen liegen gemeinsam in **einem** JSON-Feld
(`club_app_state.state`). Wer speichert, schreibt den ganzen Block - mit dem
Stand, den seine App gerade im Speicher hat.

Arbeiten zwei Personen mit Verwaltungsrechten gleichzeitig, verliert eine ihre
Aenderungen, ohne dass es auffaellt.

**Das wiegt schwerer als dieses Konzept hier**, weil es still Daten vernichtet.
Es gehoert vor das Dashboard.
