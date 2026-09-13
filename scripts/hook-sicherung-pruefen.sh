#!/usr/bin/env bash
#
# Claude-Code-Hook (PreToolUse, Bash): Kein "supabase db push" ohne frische
# Sicherung.
#
# Eingetragen in .claude/settings.local.json. Er bekommt den geplanten
# Befehl als JSON auf stdin. Enthaelt er ein echtes "supabase db push" (ein
# --dry-run zaehlt nicht) und ist die letzte Sicherung aelter als 30 Minuten
# oder gar nicht vorhanden, wird der Befehl abgelehnt - mit dem Hinweis, erst
# scripts/sicherung-vor-migration.sh laufen zu lassen.
#
# Warum ein Hook und nicht nur eine Notiz: Eine Notiz kann man vergessen.
# Der Hook sitzt vor jedem Befehl, den Claude ausfuehrt.

set -uo pipefail

eingabe=$(cat)
befehl=$(printf '%s' "$eingabe" | jq -r '.tool_input.command // ""')
ordner=$(printf '%s' "$eingabe" | jq -r '.cwd // ""')

# Der Hook steht in den globalen Einstellungen (~/.claude/settings.json),
# damit er in jeder Sitzung greift, egal in welchem Ordner sie gestartet
# wurde. Er gilt aber nur fuer die CMO-Datenbank: Ein "db push" in einem
# anderen Projekt hat mit dieser Sicherung nichts zu tun.
cmo_repo="$HOME/Projekte/club-member-organisation"
case "$befehl|$ordner" in
  *club-member-organisation*|*kymokcqebfruhlvcyqnw*|"$cmo_repo"*) ;;
  *) exit 0 ;;
esac

# Wie oft kommt "supabase db push" vor, und wie oft davon als Probelauf?
# Ein Befehl wie "db push --dry-run && db push" enthaelt beides - der zweite
# Teil ist echt und muss geprueft werden.
alle=$(printf '%s' "$befehl" | grep -oE 'supabase db push' | wc -l | tr -d ' ')
probe=$(printf '%s' "$befehl" | grep -oE 'supabase db push[^;&|]*--dry-run' | wc -l | tr -d ' ')
(( alle > probe )) || exit 0

marker="${CMO_SICHERUNGEN:-$HOME/Projekte/cmo-sicherungen}/.letzte-sicherung"
jetzt=$(date +%s)
zuletzt=$(cat "$marker" 2>/dev/null || echo 0)
if [[ "$zuletzt" =~ ^[0-9]+$ ]] && (( jetzt - zuletzt < 1800 )); then
  exit 0
fi

if [[ "$zuletzt" =~ ^[0-9]+$ ]] && (( zuletzt > 0 )); then
  alter="Die letzte Sicherung ist $(( (jetzt - zuletzt) / 60 )) Minuten alt."
else
  alter="Es gibt noch keine Sicherung."
fi

jq -n --arg grund "Keine Migration ohne frische Sicherung: $alter Zuerst scripts/sicherung-vor-migration.sh ausfuehren (im Repo club-member-organisation), dann supabase db push erneut starten." \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $grund}}'
