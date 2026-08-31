"""Prueft die App gegen das Schema, wie es sich aus den Migrationen ergibt.

Findet Tabellen, Spalten und Funktionen, die die App benutzt, die aber in
keiner Migration beschrieben sind.

Der Anlass: Am 02.09.2026 stellte sich heraus, dass sieben Tabellen, acht
Spalten und sechzehn Funktionen ausschliesslich in der Produktivdatenbank
existierten - irgendwann direkt dort angelegt, nie in eine Migration
geschrieben. Eine Migration vom 30.08. aenderte eine dieser Tabellen per ALTER
TABLE; auf einer frisch aus diesen Dateien aufgebauten Datenbank waere sie mit
"relation does not exist" abgebrochen. Drei der Funktionen gab es ueberhaupt
nicht, auch nicht in der Produktivdatenbank - die App rief sie ins Leere, und
News-Bearbeitung und Mannschaftsaenderungen scheiterten stumm.

Die Daten lagen sicher in der Datenbank. Was fehlte, war die Beschreibung, wo
sie liegen - und aus einer Sicherung zurueckspielen kann man nur in ein Schema,
das sich herstellen laesst.

Aufruf:  python3 scripts/schema-abgleich.py
Rueckgabe 1, wenn etwas fehlt.
"""
import re, glob, sys

def ohne_kommentare(t):
    return re.sub(r"--[^\n]*", "", t)

schema = {}
for f in sorted(glob.glob("supabase/migrations/*.sql")):
    t = ohne_kommentare(open(f, encoding="utf-8").read())
    for m in re.finditer(r"create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\);", t, re.S):
        tab, koerper = m.group(1), m.group(2)
        spalten = set(schema.get(tab, set()))
        for zeile in koerper.split("\n"):
            z = zeile.strip()
            if not z or z.startswith(("constraint","primary key","unique","check","foreign key")): continue
            sp = re.match(r"(\w+)\s", z)
            if sp: spalten.add(sp.group(1))
        schema[tab] = spalten
    for m in re.finditer(r"alter table (?:if exists )?public\.(\w+)([^;]*);", t, re.S):
        tab, rest = m.group(1), m.group(2)
        for a in re.finditer(r"add column (?:if not exists )?(\w+)", rest): schema.setdefault(tab, set()).add(a.group(1))
        for d in re.finditer(r"drop column (?:if exists )?(\w+)", rest): schema.get(tab, set()).discard(d.group(1))
        r = re.search(r"rename to (\w+)", rest)
        if r and tab in schema: schema[r.group(1)] = schema.pop(tab)

app = open("app/page.tsx", encoding="utf-8").read()
for f in glob.glob("app/api/**/*.ts", recursive=True) + glob.glob("lib/*.ts"):
    app += open(f, encoding="utf-8").read()

fehler = 0

# --- Funktionen ---
funktionen = set()
for f in glob.glob("supabase/migrations/*.sql"):
    t = open(f, encoding="utf-8").read()
    for m in re.finditer(r"(?i)create (?:or replace )?function public\.(\w+)", t):
        funktionen.add(m.group(1).lower())
gerufen = sorted(set(m.group(1) for m in re.finditer(r'\.rpc\(\s*"(\w+)"', app)))
fehlende_fn = [f for f in gerufen if f.lower() not in funktionen]
fehler += len(fehlende_fn)
print(f"Funktionen: {len(gerufen)} gerufen — " + (", ".join(fehlende_fn) if fehlende_fn else "alle in den Migrationen"))

for name, muster in [("Lesend", r'\.from\("(\w+)"\)\s*\n?\s*\.select\(\s*"([^"]+)"'),
                     ("Schreibend", r'\.from\("(\w+)"\)\s*\.(?:insert|update|upsert)\(\s*\{([^}]*)\}')]:
    probleme, n = [], 0
    for m in re.finditer(muster, app):
        tab, inhalt = m.group(1), m.group(2)
        if tab not in schema: probleme.append(f"{tab}: Tabelle in keiner Migration"); continue
        felder = ([c.strip() for c in re.sub(r"\w+(?:!\w+)?\([^)]*\)", "", inhalt).split(",") if c.strip() not in ("","*",")")]
                  if name == "Lesend" else [x.group(1) for x in re.finditer(r"(?:^|,)\s*(\w+)\s*:", inhalt)])
        for feld in felder:
            n += 1
            if feld not in schema[tab]: probleme.append(f"{tab}.{feld}")
    fehler += len(set(probleme))
    print(f"{name}: {n} Felder — " + ("; ".join(sorted(set(probleme))) if probleme else "alle im Schema"))
sys.exit(1 if fehler else 0)
