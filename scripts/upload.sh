#!/bin/bash
# Baut die iOS-App, signiert sie und laedt sie zu App Store Connect hoch.
#
# Voraussetzung: ein App-Store-Connect-API-Schluessel unter
#   ~/.appstoreconnect/private_keys/AuthKey_<SCHLUESSEL-ID>.p8
# sowie die beiden Kennungen in den Umgebungsvariablen:
#   ASC_KEY_ID     die Schluessel-ID
#   ASC_ISSUER_ID  die Issuer-ID
#
# Aufruf:  ASC_KEY_ID=... ASC_ISSUER_ID=... scripts/upload.sh
#
# Das Skript legt Zertifikat und Profil bei Bedarf selbst an
# (-allowProvisioningUpdates). Ein Apple-Distribution-Zertifikat muss also
# nicht vorher im Schluesselbund liegen.

set -euo pipefail

PROJEKT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIV="/tmp/claude-501/cmo.xcarchive"
EXPORT="/tmp/claude-501/cmo-export"
TEAM="BGDB66U66T"

: "${ASC_KEY_ID:?ASC_KEY_ID fehlt}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID fehlt}"
SCHLUESSEL="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
[ -f "$SCHLUESSEL" ] || { echo "Schluesseldatei fehlt: $SCHLUESSEL"; exit 1; }

echo "--- Web-Stand in die Huelle uebernehmen ---"
cd "$PROJEKT"
npx cap sync ios

echo "--- Archivieren ---"
rm -rf "$ARCHIV" "$EXPORT"
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -configuration Release -destination "generic/platform=iOS" \
  -archivePath "$ARCHIV" archive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$SCHLUESSEL" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  DEVELOPMENT_TEAM="$TEAM"

echo "--- Exportieren ---"
cat > /tmp/claude-501/export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>uploadSymbols</key><true/>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIV" \
  -exportOptionsPlist /tmp/claude-501/export.plist \
  -exportPath "$EXPORT" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$SCHLUESSEL" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "--- Hochladen ---"
IPA="$(ls "$EXPORT"/*.ipa | head -1)"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo
echo "Fertig. Der Build erscheint in App Store Connect unter TestFlight,"
echo "sobald Apple ihn verarbeitet hat - meist nach fuenf bis fuenfzehn Minuten."
