#!/usr/bin/env bash
#
# Bringt den Stand von 'weiterbauen' in die Produktion.
#
# Zwei Schritte, und die Reihenfolge ist NICHT beliebig:
#
#   1. Migrationen einspielen
#   2. nach main mergen und pushen
#
# Warum in dieser Reihenfolge: Der neue Code prueft beim Loeschen eines
# Termins, ob wirklich Zeilen getroffen wurden. Auf public.events fehlt bis
# heute die DELETE-Regel - ohne die Migration bekaeme also JEDER die Meldung,
# ihm fehle das Recht. (Kaputt war es vorher genauso, es sah nur heil aus.)
#
# Das Skript haelt vor jedem schreibenden Schritt an und fragt nach.
# Abbrechen mit Strg-C ist jederzeit gefahrlos.

set -euo pipefail
cd "$(dirname "$0")/.."

frage() {
  printf '\n%s [j/N] ' "$1"
  read -r antwort
  [[ "$antwort" == "j" || "$antwort" == "J" ]] || { echo "Abgebrochen."; exit 1; }
}

echo "== Stand =="
git status --short || true
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Es gibt uncommittete Aenderungen. Bitte zuerst committen."
  exit 1
fi
git log --oneline main..weiterbauen | cat

echo
echo "== Schritt 1 von 2: Migrationen =="
supabase db push --dry-run
frage "Diese Migrationen einspielen?"
supabase db push

echo
echo "== Schritt 2 von 2: nach main =="
git fetch origin --quiet
git checkout main
git pull --ff-only origin main
# Reines Vorspulen - main ist direkter Vorfahre von weiterbauen.
frage "weiterbauen nach main mergen und pushen?"
git merge --ff-only weiterbauen
git push origin main
git checkout weiterbauen

echo
echo "Fertig. Vercel baut jetzt automatisch."
echo "Danach in App Store Connect: 'Diese Version veroeffentlichen'."
