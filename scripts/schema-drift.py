#!/usr/bin/env python3
"""Findet Tabellen und Spalten, die es in der PRODUKTION gibt, aber in keiner
Migration.

WOZU, WO ES DOCH SCHON schema-abgleich.py GIBT
Der Abgleich daneben geht vom CODE aus: Er nimmt jedes Feld, das app/page.tsx
liest oder schreibt, und sucht es in den Migrationen. Was die App nie anfasst,
sieht er nicht - und genau dort lag der Fehler. Am 14.10.2026 fanden sich so
drei Tabellen (club_task_reminders, known_devices, notification_queue) und drei
Spalten (teams.is_adult, profiles.show_birthday, duty_tasks.reminded_at), die
nur in der Datenbank standen. Von Hand angelegt, vermutlich in der Oberflaeche
von Supabase, und seit ueber einem Jahr von Migrationen BENUTZT, aber von
keiner ANGELEGT.

Dieses Skript geht umgekehrt vor: Es nimmt den Katalog der laufenden Datenbank
und sucht dort nach, was die Migrationen nicht hergeben. Damit faellt auch auf,
was allein die Datenbank benutzt.

WARUM DAS ZAEHLT
Ein Verzeichnis von Migrationen ist ein Versprechen: "Damit baust du diesen
Stand nach." Fehlt etwas, bricht der Aufbau - und zwar nicht hier, sondern
irgendwann spaeter bei jemandem, der eine zweite Umgebung aufsetzt oder nach
einem Verlust wiederherstellt. Das ist der schlechteste Zeitpunkt, es zu
erfahren.

Aufruf:  python3 scripts/schema-drift.py
         (liest PROD nur lesend, ueber dieselbe kurzlebige Anmeldung, die auch
          scripts/sicherung-vor-migration.sh benutzt)

Endet mit 1, wenn etwas fehlt - damit es sich in eine Pruefkette haengen
laesst.
"""
import os, re, subprocess, sys, pathlib

WURZEL = pathlib.Path(__file__).resolve().parent.parent
PG_BIN = os.environ.get("CMO_PG_BIN", "/opt/homebrew/opt/libpq/bin")


def prod_spalten():
    """Tabellen und Spalten aus dem Katalog der laufenden Datenbank."""
    dry = subprocess.run(["supabase", "db", "dump", "--linked", "--dry-run", "--role-only"],
                         cwd=WURZEL, capture_output=True, text=True)
    umgebung = dict(os.environ)
    for zeile in dry.stdout.splitlines():
        if zeile.startswith("export "):
            name, _, wert = zeile[len("export "):].partition("=")
            umgebung[name] = wert.strip('"')
    if "PGHOST" not in umgebung:
        print("Keine Anmeldung bekommen - ist das Projekt verknuepft (supabase link)?", file=sys.stderr)
        sys.exit(2)
    abfrage = ("set role postgres; select c.relname || '|' || a.attname "
               "from pg_class c join pg_namespace n on n.oid = c.relnamespace "
               "join pg_attribute a on a.attrelid = c.oid "
               "where n.nspname = 'public' and c.relkind = 'r' "
               "and a.attnum > 0 and not a.attisdropped;")
    lauf = subprocess.run([f"{PG_BIN}/psql", "-t", "-A", "-c", abfrage],
                          env=umgebung, capture_output=True, text=True)
    if lauf.returncode != 0:
        print(lauf.stderr.strip(), file=sys.stderr)
        sys.exit(2)
    prod = {}
    for zeile in lauf.stdout.splitlines():
        if "|" in zeile:
            tab, sp = zeile.split("|", 1)
            prod.setdefault(tab.strip(), set()).add(sp.strip())
    return prod


def schema_aus_migrationen():
    """Dieselbe Lesart wie schema-abgleich.py - absichtlich, damit beide
    Skripte nicht auseinanderlaufen: create table, add column, drop column,
    rename table, rename column."""
    schema = {}
    for datei in sorted((WURZEL / "supabase" / "migrations").glob("*.sql")):
        t = re.sub(r"--[^\n]*", "", datei.read_text())
        for m in re.finditer(r"create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\);", t, re.S):
            tab = m.group(1)
            spalten = set(schema.get(tab, set()))
            for z in m.group(2).split("\n"):
                z = z.strip().lstrip(",").strip()
                if not z or z.lower().startswith(
                        ("primary key", "foreign key", "unique", "constraint", "check", "exclude")):
                    continue
                sp = re.match(r"(\w+)\s", z)
                if sp:
                    spalten.add(sp.group(1))
            schema[tab] = spalten
        for m in re.finditer(r"alter table (?:if exists )?public\.(\w+)([^;]*);", t, re.S):
            tab, rest = m.group(1), m.group(2)
            for a in re.finditer(r"add column (?:if not exists )?(\w+)", rest):
                schema.setdefault(tab, set()).add(a.group(1))
            for d in re.finditer(r"drop column (?:if exists )?(\w+)", rest):
                schema.get(tab, set()).discard(d.group(1))
            r = re.search(r"rename to (\w+)", rest)
            if r and tab in schema:
                schema[r.group(1)] = schema.pop(tab)
            rc = re.search(r"rename column (\w+) to (\w+)", rest)
            if rc and tab in schema:
                schema[tab].discard(rc.group(1))
                schema[tab].add(rc.group(2))
    return schema


prod = prod_spalten()
schema = schema_aus_migrationen()
fehlende_tabellen = sorted(t for t in prod if t not in schema)
fehlende_spalten = sorted((t, sp) for t in prod if t in schema for sp in sorted(prod[t] - schema[t]))

print(f"{len(prod)} Tabellen in der Produktion, {len(schema)} in den Migrationen")
if fehlende_tabellen:
    print(f"\nTabellen, die keine Migration anlegt ({len(fehlende_tabellen)}):")
    for t in fehlende_tabellen:
        print(f"  {t}")
if fehlende_spalten:
    print(f"\nSpalten, die keine Migration anlegt ({len(fehlende_spalten)}):")
    for t, sp in fehlende_spalten:
        print(f"  {t}.{sp}")
if not fehlende_tabellen and not fehlende_spalten:
    print("Nichts von Hand: jede Tabelle und jede Spalte steht in einer Migration.")
    sys.exit(0)
print("\nSo etwas gehoert in eine Migration - sonst laesst sich dieser Stand nicht nachbauen.")
sys.exit(1)
