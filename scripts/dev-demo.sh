#!/usr/bin/env bash
#
# Startet die App im Demo-Betrieb: ohne Datenbank, ohne Anmeldung.
#
# WOZU
# Die App prueft mit isSupabaseConfigured, ob eine Datenbank da ist. Fehlen
# die beiden Umgebungsvariablen, laeuft sie auf den erfundenen Demodaten -
# man kommt ohne Konto hinein und kann jeden Bildschirm oeffnen.
#
# Genau das fehlte bisher beim Pruefen. Typen, Uebersetzungen und Bau lassen
# sich automatisch kontrollieren; ob eine Ansicht beim Oeffnen abstuerzt,
# sieht man erst, wenn man sie oeffnet. Der Absturz in Profil >
# Benachrichtigungen waere hier in zehn Sekunden aufgefallen - er brauchte
# stattdessen einen Fehlerbericht aus dem echten Betrieb.
#
# WICHTIG
# Das ersetzt keinen Test mit echten Daten. Alles, was an der Datenbank
# haengt - Rechte, Zeilenregeln, Auslöser -, laeuft hier gar nicht. Dafuer
# bleibt die Pruefung direkt auf der Datenbank.
#
# Aufruf ueber .claude/launch.json (Eintrag "cmo-demo") oder von Hand:
#   scripts/dev-demo.sh
set -euo pipefail
cd "$(dirname "$0")/.."

export NEXT_PUBLIC_SUPABASE_URL=""
export NEXT_PUBLIC_SUPABASE_ANON_KEY=""
export NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=""

exec npx next dev --port 3100
