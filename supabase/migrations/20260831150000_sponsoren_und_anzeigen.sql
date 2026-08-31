-- Anzeigen: Werbung des Betreibers und Sponsoren des Vereins.
--
-- Bisher lagen die Werbeplätze als JSON im gemeinsamen Zustandsblock — ohne
-- Laufzeit, ohne Trennung, ohne Rechte. Jeder Verein sah dieselben drei
-- vorbelegten Firmen, und wer sie ändern durfte, war Auslegungssache.
--
-- Jetzt zwei Arten in einer Tabelle:
--
--   club_id IS NULL   Werbung des Betreibers. Gilt überall, hat nichts mit dem
--                     Verein zu tun, wird von uns eingebucht.
--   club_id gesetzt   Sponsor des Vereins. Trägt der Sponsorenmanager ein,
--                     sichtbar nur in diesem Verein.
--
-- Beide in einer Tabelle, weil sie um dieselben Plätze konkurrieren und die
-- Rangfolge sonst über zwei Abfragen zusammengesucht werden müsste. Die Regel
-- ist einfach: Wo der Verein einen eigenen Sponsor hat, tritt die Werbung des
-- Betreibers zurück.
--
-- Eigene Sponsoren sind kostenpflichtig — fünf Euro im Monat über dem Tarif.
-- Freigeschaltet wird das wie alles andere vom Betreiber.

alter table public.clubs
  add column if not exists sponsoring_freigeschaltet boolean not null default false;

comment on column public.clubs.sponsoring_freigeschaltet is
  'Zusatz für fünf Euro im Monat: Der Verein darf eigene Sponsoren auf den Werbeplätzen zeigen. Wird vom Betreiber gesetzt.';

create table if not exists public.anzeigen (
  id uuid primary key default gen_random_uuid(),
  -- Null bedeutet: Werbung des Betreibers, gilt in jedem Verein.
  club_id uuid references public.clubs(id) on delete cascade,
  platz text not null check (platz in ('dashboard_top', 'dashboard_bottom', 'events_header', 'profile_bottom')),

  titel text not null check (char_length(trim(titel)) between 1 and 120),
  text text check (char_length(text) <= 400),
  bild_pfad text,
  ziel_url text,

  -- Die Aktion. Sie ist der Grund, warum eine Laufzeit nötig ist: Ein
  -- Sponsorenlogo darf stehenbleiben, eine Rabattaktion nicht.
  aktion_titel text check (aktion_titel is null or char_length(trim(aktion_titel)) between 1 and 120),
  aktion_text text check (aktion_text is null or char_length(aktion_text) <= 600),
  aktion_url text,

  laeuft_von timestamptz not null default now(),
  laeuft_bis timestamptz,
  aktiv boolean not null default true,

  erstellt_von uuid references public.club_memberships(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Eine Aktion ohne Laufzeitende wäre eine Dauerwerbung, die niemand
  -- zurücknimmt. Wer eine Aktion einträgt, sagt auch bis wann.
  constraint anzeigen_aktion_hat_ende check (aktion_titel is null or laeuft_bis is not null),
  constraint anzeigen_ende_nach_beginn check (laeuft_bis is null or laeuft_bis > laeuft_von)
);

create index if not exists anzeigen_platz_idx on public.anzeigen(platz, aktiv, laeuft_von, laeuft_bis);
create index if not exists anzeigen_club_idx on public.anzeigen(club_id, platz);

create trigger anzeigen_touch before update on public.anzeigen
for each row execute function public.touch_updated_at();

alter table public.anzeigen enable row level security;

-- Lesen darf jedes Mitglied: die Werbung des Betreibers und die Sponsoren des
-- eigenen Vereins. Fremde Vereinssponsoren bleiben unsichtbar.
create policy "anzeigen lesbar" on public.anzeigen
for select to authenticated using (
  club_id is null or public.is_club_member(club_id)
);

-- Pflegen darf sie der Sponsorenmanager und die Vereinsleitung - und nur die
-- eigenen. Die Werbung des Betreibers (club_id null) ist für niemanden in der
-- App änderbar; sie wird mit dem Dienstschlüssel gesetzt.
create policy "sponsoren pflegen" on public.anzeigen
for all to authenticated
using (
  club_id is not null
  and public.has_club_role(club_id, array['sponsorenmanager','vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
)
with check (
  club_id is not null
  and public.has_club_role(club_id, array['sponsorenmanager','vereinsadmin','sysadmin','geschaeftsfuehrung','vorstand']::public.club_role[])
);

grant select on public.anzeigen to authenticated;
grant insert, update, delete on public.anzeigen to authenticated;
grant all on public.anzeigen to service_role;

/* Was auf einem Platz gerade zu sehen ist.
 *
 * Rangfolge: Hat der Verein einen eigenen, laufenden Sponsor auf diesem Platz
 * und ist Sponsoring für ihn freigeschaltet, gewinnt der. Sonst die Werbung des
 * Betreibers. Ist beides leer, bleibt der Platz frei - eine leere Werbefläche
 * ist besser als eine fremde.
 *
 * "Laufend" heißt: aktiv, begonnen, und noch nicht abgelaufen. Damit
 * verschwindet eine Aktion von selbst, wenn sie vorbei ist. */
create or replace function public.anzeige_fuer_platz(target_club uuid, ziel_platz text)
returns table (
  id uuid, herkunft text, titel text, text text, bild_pfad text, ziel_url text,
  aktion_titel text, aktion_text text, aktion_url text, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  with laufend as (
    select a.*,
           case when a.club_id is null then 'betreiber' else 'verein' end as herkunft
      from public.anzeigen a
     where a.platz = ziel_platz
       and a.aktiv
       and a.laeuft_von <= now()
       and (a.laeuft_bis is null or a.laeuft_bis > now())
       and (
         a.club_id is null
         or (a.club_id = target_club
             and exists (select 1 from public.clubs c
                          where c.id = target_club and c.sponsoring_freigeschaltet))
       )
  )
  select l.id, l.herkunft, l.titel, l.text, l.bild_pfad, l.ziel_url,
         l.aktion_titel, l.aktion_text, l.aktion_url, l.laeuft_bis
    from laufend l
   order by case when l.herkunft = 'verein' then 0 else 1 end,
            l.created_at desc
   limit 1;
$$;

grant execute on function public.anzeige_fuer_platz(uuid, text) to authenticated;

/* Alle Plätze eines Vereins auf einmal - die Oberfläche braucht sie zusammen
   und soll dafür nicht vier Abfragen schicken. */
create or replace function public.anzeigen_fuer_verein(target_club uuid)
returns table (
  platz text, id uuid, herkunft text, titel text, text text, bild_pfad text,
  ziel_url text, aktion_titel text, aktion_text text, aktion_url text, laeuft_bis timestamptz
)
language sql stable security definer set search_path = '' as $$
  select p.platz, a.id, a.herkunft, a.titel, a.text, a.bild_pfad,
         a.ziel_url, a.aktion_titel, a.aktion_text, a.aktion_url, a.laeuft_bis
    from (values ('dashboard_top'), ('dashboard_bottom'), ('events_header'), ('profile_bottom')) as p(platz)
    cross join lateral public.anzeige_fuer_platz(target_club, p.platz) a;
$$;

grant execute on function public.anzeigen_fuer_verein(uuid) to authenticated;
