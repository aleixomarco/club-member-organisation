# Android: Release-Bundle für den Play Store erzeugen

Der Play Store nimmt kein Debug-APK an. Gebraucht wird ein **signiertes App
Bundle** (`.aab`). Dafür brauchst du einmalig einen Upload-Schlüssel.

---

## 1. Upload-Schlüssel anlegen (einmalig)

**Das Passwort wählst du selbst — ich lege bewusst keines für dich an.** Der
Schlüssel ist die Identität deiner App: Geht er verloren, kannst du die App im
Play Store nie wieder aktualisieren.

```bash
/opt/homebrew/opt/openjdk@21/bin/keytool -genkeypair -v \
  -keystore ~/cmo-upload-key.jks \
  -alias cmo-upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Das Programm fragt nacheinander nach:

- **Keystore-Passwort** (zweimal) — frei wählbar, gut aufbewahren
- Vor- und Nachname, Organisation, Ort, Land — hier reichen deine Firmendaten
- **Schlüssel-Passwort** — Enter drücken übernimmt das Keystore-Passwort

Lege die Datei **außerhalb** des Projektordners ab (im Beispiel im
Benutzerverzeichnis), damit sie nie versehentlich im Repository landet.

> **Sicherungskopie anlegen.** Am besten in deinen Passwort-Manager, zusammen mit
> beiden Passwörtern. Ohne diesen Schlüssel ist die App im Store eingefroren.

---

## 2. Zugangsdaten hinterlegen

Datei `android/keystore.properties` anlegen (steht bereits in `.gitignore`):

```properties
storeFile=/Users/marcoaleixo/cmo-upload-key.jks
storePassword=DEIN_KEYSTORE_PASSWORT
keyAlias=cmo-upload
keyPassword=DEIN_SCHLUESSEL_PASSWORT
```

---

## 3. Bundle bauen

```bash
cd android && JAVA_HOME=/opt/homebrew/opt/openjdk@21 ANDROID_HOME=/opt/homebrew/share/android-commandlinetools ./gradlew bundleRelease
```

Ergebnis: `android/app/build/outputs/bundle/release/app-release.aab` — genau
diese Datei lädst du in der Play Console hoch.

---

## 4. Versionsnummer bei jedem Update erhöhen

In `android/app/build.gradle`:

```gradle
versionCode 1      // muss bei JEDEM Upload um mindestens 1 steigen
versionName "1.0"  // die für Nutzer sichtbare Version
```

Google lehnt ein Bundle ab, dessen `versionCode` bereits verwendet wurde.

---

## Play App Signing

Beim ersten Upload bietet Google „Play App Signing" an — **annehmen**. Google
verwahrt dann den eigentlichen Signaturschlüssel, deiner ist nur noch der
Upload-Schlüssel. Geht der verloren, kann Google ihn zurücksetzen; ohne dieses
Verfahren wäre die App verloren.

---

## Bauumgebung auf diesem Mac

Beides wurde eingerichtet und ist einsatzbereit:

- **JDK 21** unter `/opt/homebrew/opt/openjdk@21`
- **Android SDK** unter `/opt/homebrew/share/android-commandlinetools`
  (Platform 36, Build-Tools 36, Platform-Tools)

Der Pfad zum SDK steht in `android/local.properties` — auch diese Datei ist von
der Versionsverwaltung ausgeschlossen, da sie rechnerspezifisch ist.
