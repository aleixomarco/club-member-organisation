#!/usr/bin/env bash
#
# Sichert die PRODUKTIONS-Datenbank, bevor eine Migration eingespielt wird.
#
# WARUM
# Das Projekt laeuft auf Supabase Free, und dort gibt es KEINE Sicherungen
# ("supabase backups list" ist leer). Eine Migration mit einem falschen DELETE
# oder DROP, ein versehentlich gestartetes scripts/prod-leeren.sql - und die
# Vereinsdaten waeren unwiederbringlich weg. Der riskanteste Moment ist das
# Einspielen einer Migration, und das passiert hier oft. Genau davor sichert
# dieses Skript.
#
# WAS GESICHERT WIRD
#   rollen.sql   Datenbankrollen
#   schema.sql   Tabellen, Funktionen, Regeln (ohne die von Supabase
#                verwalteten Schemata wie auth - die baut die Plattform)
#   daten.sql    alle Zeilen, AUCH auth (Anmeldungen) und storage (die
#                Verwaltungsdaten der Dateien)
#   info.txt     Zeitpunkt, Git-Stand, offene Migrationen, Zeilenzahlen,
#                Pruefsummen
# NICHT gesichert: die hochgeladenen Dateien selbst (Vereinslogos, Bilder).
# Die aendert keine Migration; fuer sie braucht es einen eigenen Weg.
#
# WIE, OHNE DOCKER
# "supabase db dump" braucht normalerweise Docker. Mit --dry-run gibt die CLI
# stattdessen das Skript aus, das sie ausfuehren wuerde - samt einer
# kurzlebigen Anmeldung, die sie selbst erzeugt. Das Skript laeuft hier mit
# dem lokalen pg_dump aus Homebrew (brew install libpq). Kein Passwort muss
# irgendwo eingetragen werden.
#
# WOHIN
# ~/Projekte/cmo-sicherungen/<Zeitstempel>/ - bewusst AUSSERHALB des Repos
# (die Dateien enthalten persoenliche Daten und Passwort-Hashes, nichts davon
# darf ins Git) und AUSSERHALB von iCloud (dort wurden am 19.08. Dateien
# ausgelagert und unlesbar). Nur der Besitzer darf lesen (umask 077).
# Die neuesten 30 Sicherungen bleiben, aeltere werden entfernt.
#
# Wiederherstellen: siehe WIEDERHERSTELLEN.txt im Sicherungsordner.
#
# Scheitert irgendein Schritt, endet das Skript mit Fehler - und wer es vor
# "supabase db push" aufruft, spielt die Migration dann NICHT ein.

set -euo pipefail
cd "$(dirname "$0")/.."

ZIEL_BASIS="${CMO_SICHERUNGEN:-$HOME/Projekte/cmo-sicherungen}"
PG_BIN="${CMO_PG_BIN:-/opt/homebrew/opt/libpq/bin}"
BEHALTEN=30

if [[ ! -x "$PG_BIN/pg_dump" ]]; then
  echo "pg_dump fehlt unter $PG_BIN - einmalig: brew install libpq" >&2
  exit 1
fi

# Eine Sicherung auf eine volle Platte ist schlimmer als keine: Sie sieht aus
# wie eine und ist abgeschnitten. Unter 500 MB frei wird gar nicht erst begonnen.
frei_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
if (( frei_kb < 512000 )); then
  echo "Nur noch $((frei_kb / 1024)) MB frei - Sicherung abgebrochen. Erst Platz schaffen." >&2
  exit 1
fi

umask 077
stempel=$(date +%Y-%m-%d_%H%M%S)
ziel="$ZIEL_BASIS/$stempel"
mkdir -p "$ziel"

# Bricht das Skript mittendrin ab, bleibt kein halber Ordner stehen, der wie
# eine Sicherung aussieht.
fertig=0
aufraeumen() { (( fertig )) || rm -rf "$ziel"; }
trap aufraeumen EXIT

sichern() {
  local datei="$1"; shift
  echo "  $datei ..."
  supabase db dump --linked --dry-run "$@" 2>/dev/null \
    | PATH="$PG_BIN:$PATH" bash > "$ziel/$datei"
  if [[ ! -s "$ziel/$datei" ]]; then
    echo "$datei ist leer - Sicherung unbrauchbar." >&2
    exit 1
  fi
}

echo "== Sicherung der Produktionsdatenbank nach $ziel =="
sichern rollen.sql --role-only
sichern schema.sql
sichern daten.sql --data-only --use-copy

# Nachzaehlen: Stimmen die Zeilen in der Sicherung mit der Datenbank ueberein?
# Geprueft werden die Tabellen, ohne die ein Verein nicht mehr existiert.
# Eine Abweichung heisst: Die Sicherung ist unvollstaendig, oder jemand hat
# genau in diesem Moment etwas angelegt - in beiden Faellen lieber neu sichern.
echo "  Zeilen nachzaehlen ..."
PRUEF_TABELLEN="auth.users public.clubs public.club_memberships public.teams public.events public.profiles"
abfrage="select json_build_object($(for t in $PRUEF_TABELLEN; do printf "'%s', (select count(*) from %s)," "$t" "$t"; done | sed 's/,$//')) as z"
live_json=$(supabase db query --linked "$abfrage" 2>/dev/null)

zeilen_in_sicherung() {
  local schema="${1%%.*}" tabelle="${1#*.}"
  awk -v kopf="COPY \"$schema\".\"$tabelle\" " '
    index($0, kopf) == 1 { drin = 1; next }
    drin && $0 == "\\." { drin = 0; next }
    drin { n++ }
    END { print n + 0 }' "$ziel/daten.sql"
}

abweichung=0
zaehlung=""
for t in $PRUEF_TABELLEN; do
  live=$(printf '%s' "$live_json" | python3 -c "
import sys, json
roh = sys.stdin.read()
zeilen = json.loads(roh[roh.index('{'):])['rows'][0]['z']
zeilen = json.loads(zeilen) if isinstance(zeilen, str) else zeilen
print(zeilen['$t'])")
  gesichert=$(zeilen_in_sicherung "$t")
  zaehlung+="  $t: live $live, gesichert $gesichert"$'\n'
  if [[ "$live" != "$gesichert" ]]; then abweichung=1; fi
done
printf '%s' "$zaehlung"
if (( abweichung )); then
  echo "Zeilenzahlen weichen ab - Sicherung verworfen. Bitte erneut starten." >&2
  exit 1
fi

{
  echo "Sicherung der Produktionsdatenbank (Supabase kymokcqebfruhlvcyqnw)"
  echo "Zeitpunkt: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Git-Stand: $(git rev-parse --short HEAD) ($(git branch --show-current))"
  echo
  echo "Noch nicht eingespielte Migrationen (lokal vorhanden, in PROD fehlend):"
  supabase migration list --linked 2>/dev/null | python3 -c "
import sys, json
roh = sys.stdin.read()
try:
    liste = json.loads(roh[roh.index('{'):])['migrations']
    offen = [m['local'] for m in liste if m.get('local') and not m.get('remote')]
    print('\n'.join('  ' + v for v in offen) or '  keine')
except Exception:
    print('  (nicht ermittelbar)')"
  echo
  echo "Zeilen nachgezaehlt:"
  printf '%s' "$zaehlung"
  echo
  echo "Dateien:"
  (cd "$ziel" && for f in rollen.sql schema.sql daten.sql; do
    printf '  %-12s %8s  sha256 %s\n' "$f" "$(du -h "$f" | cut -f1)" "$(shasum -a 256 "$f" | cut -c1-16)"
  done)
} > "$ziel/info.txt"

# Die Anleitung liegt einmal im Sicherungsordner, nicht in jeder Sicherung.
if [[ ! -f "$ZIEL_BASIS/WIEDERHERSTELLEN.txt" ]]; then
  cat > "$ZIEL_BASIS/WIEDERHERSTELLEN.txt" <<'TEXT'
Wiederherstellen einer CMO-Sicherung
====================================

NIE direkt in die Produktion zurueckspielen, ohne es vorher in einem leeren
Supabase-Projekt ausprobiert zu haben.

1. Ein neues, leeres Supabase-Projekt anlegen (oder das Ziel bewusst leeren).
2. Die Verbindungszeichenkette des Ziels aus dem Dashboard holen
   (Project Settings > Database > Connection string, Session pooler).
3. Aus dem Ordner der gewuenschten Sicherung:

   /opt/homebrew/opt/libpq/bin/psql \
     --single-transaction --variable ON_ERROR_STOP=1 \
     --file rollen.sql --file schema.sql \
     --command 'SET session_replication_role = replica' \
     --file daten.sql \
     --dbname "<Verbindungszeichenkette>"

   "session_replication_role = replica" ist PFLICHT: Es schaltet die Trigger
   beim Einspielen ab. Ohne das wuerde jede zurueckgespielte Benachrichtigung
   eine echte Push-Mitteilung an echte Mitglieder ausloesen.

4. Danach: Edge Function push-versenden und die Supabase-Geheimnisse im
   neuen Projekt einrichten, Storage-Dateien (Logos, Bilder) gesondert
   hochladen - sie sind in dieser Sicherung nicht enthalten.

Quelle des Verfahrens: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore
TEXT
fi

fertig=1
date +%s > "$ZIEL_BASIS/.letzte-sicherung"

# Alte Sicherungen entfernen - nur Ordner mit Zeitstempel-Namen, nichts anderes.
ls -1d "$ZIEL_BASIS"/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9]* 2>/dev/null \
  | sort -r | tail -n +$((BEHALTEN + 1)) | while read -r alt; do rm -rf "$alt"; done

echo "== Sicherung fertig: $ziel ($(du -sh "$ziel" | cut -f1)) =="
