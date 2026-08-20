#!/bin/bash
# Schritt 4 der Einreichung: mergen, bauen, hochladen.
#
# Voraussetzungen, die dieses Skript NICHT pruefen kann:
#   - Die laufende Apple-Pruefung ist abgeschlossen
#   - Die sechs Produkte stehen in App Store Connect
#   - RevenueCat kennt Entitlement und die drei Offerings
#   - Das PROD-SQL ist eingespielt
#
# Aufruf:
#   scripts/release.sh            mergen, bauen, archivieren
#   scripts/release.sh --upload   zusaetzlich hochladen
#
# Zum Hochladen braucht es einen App-Store-Connect-API-Schluessel:
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   AuthKey_<KEY_ID>.p8 nach ~/.appstoreconnect/private_keys/

set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIV=/tmp/claude-501/cmo-build2.xcarchive
EXPORT=/tmp/claude-501/cmo-build2-export

echo "-- 1/5  Arbeitsverzeichnis pruefen"
test -z "$(git status --porcelain)" || { echo "FEHLER: nicht festgeschriebene Aenderungen"; exit 1; }

echo "-- 2/5  tarifmodell nach main"
git checkout main
git merge --no-ff tarifmodell -m "Neues Tarifmodell auf main: drei Stufen nach Zahl der Zugaenge"
git push origin main
echo "   Vercel baut jetzt neu, ein bis zwei Minuten."

echo "-- 3/5  iOS synchronisieren"
npm run build
npx cap sync ios
pod install --project-directory=ios/App

echo "-- 4/5  archivieren"
rm -rf "$ARCHIV"
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$ARCHIV" archive -allowProvisioningUpdates

if [ "${1:-}" != "--upload" ]; then
  echo "-- 5/5  uebersprungen (kein --upload)"
  echo "Archiv: $ARCHIV"
  echo "In Xcode hochladen: Window > Organizer > Distribute App"
  exit 0
fi

echo "-- 5/5  exportieren und hochladen"
cat > /tmp/claude-501/ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>BGDB66U66T</string>
  <key>uploadSymbols</key><true/>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

rm -rf "$EXPORT"
xcodebuild -exportArchive -archivePath "$ARCHIV" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist /tmp/claude-501/ExportOptions.plist \
  -allowProvisioningUpdates

xcrun altool --upload-app -f "$EXPORT"/*.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo "Fertig. Der Build erscheint nach etwa zehn Minuten in App Store Connect."
