// patch-profile-folders.mjs
// Ausführen mit: node patch-profile-folders.mjs
// Gruppiert die 16 flachen Profil-Einstellungs-Kacheln in app/page.tsx
// zu 6 Ordnern. Ändert NICHTS an den bestehenden ProfileUnderlay-Renderern
// (profileUnderlay === "xxx" && ...) -- die Klick-Ziele bleiben identisch,
// nur die Kachel-Liste davor wird durch eine zweistufige Ordner-Navigation
// ersetzt.

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-folders";

const src = readFileSync(FILE, "utf8");

// --- 1) Sicherheits-Backup ---
copyFileSync(FILE, BACKUP);
console.log(`Backup geschrieben: ${BACKUP}`);

// --- 2) Kachel-Liste ersetzen ---
const startMarker = '<SectionTitle eyebrow="Verwalten" title="Einstellungen" />';
const endMarker = '<div className="rounded-2xl p-4 mb-5"';

const startIdx = src.indexOf(startMarker);
if (startIdx === -1) {
  console.error("FEHLER: Startanker nicht gefunden. Nichts wurde geändert. Bitte manuell prüfen.");
  process.exit(1);
}
const endIdx = src.indexOf(endMarker, startIdx);
if (endIdx === -1) {
  console.error("FEHLER: Endanker nicht gefunden. Nichts wurde geändert. Bitte manuell prüfen.");
  process.exit(1);
}

const newBlock = `<SectionTitle eyebrow="Verwalten" title="Einstellungen" />
      {!profileFolder ? (
        <div className="space-y-2 mb-6">
          <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Familie" color={C.green} onClick={() => setProfileFolder("personal")}/>
          <ProfileSettingsCard icon={KeyRound} title="Konto & Sicherheit" description="Passwort, Sicherheit, Rechtliches, Account" color="#4A4E9E" onClick={() => setProfileFolder("security")}/>
          <ProfileSettingsCard icon={Trophy} title="Verein & Mitgliedschaft" description="Spieler-, Trainer- und Vereinsrollen" color="#2D6F8E" onClick={() => setProfileFolder("club")}/>
          <ProfileSettingsCard icon={Bell} title="Benachrichtigungen & Kalender" description="Push-Einstellungen und Kalendersync" color={C.amber} onClick={() => setProfileFolder("notify")}/>
          <ProfileSettingsCard icon={Euro} title="Abo & Empfehlungen" description="Abonnement und Vereine werben Vereine" color={C.red} onClick={() => setProfileFolder("billing")}/>
          <ProfileSettingsCard icon={Star} title="Support & Feedback" description="Bewertung abgeben, Fehler melden" color={C.textDim} onClick={() => setProfileFolder("support")}/>
        </div>
      ) : (
        <div className="mb-6">
          <button onClick={() => setProfileFolder("")} className="flex items-center gap-1.5 text-xs font-bold mb-3" style={{ color: C.textDim }}><ChevronRight size={14} style={{ transform: "rotate(180deg)" }}/> Zurück zur Übersicht</button>
          <div className="space-y-2">
            {profileFolder === "personal" && <>
              <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Adresse und Mitgliederausweis" color={C.green} onClick={() => setProfileUnderlay("personal")}/>
              <ProfileSettingsCard icon={Users} title="Familie" description="Familienprofile ansehen und Verknüpfungen verwalten" color={C.amber} onClick={() => setProfileUnderlay("family")}/>
            </>}
            {profileFolder === "security" && <>
              <ProfileSettingsCard icon={KeyRound} title="Passwort ändern" description="Passwort aktualisieren und Geräte abmelden" color="#4A4E9E" onClick={() => setProfileUnderlay("password")}/>
              <ProfileSettingsCard icon={Settings} title="Sicherheit" description="Automatischen Logout einstellen" color={C.textDim} onClick={() => setProfileUnderlay("security")}/>
              <ProfileSettingsCard icon={ShieldCheck} title="Kontoeinstellungen" description="Sicherheit, Rechtliches und Accountverwaltung" color={C.textDim} onClick={() => setProfileUnderlay("account")}/>
            </>}
            {profileFolder === "club" && <>
              {user.roles.includes("sysadmin") && <ProfileSettingsCard icon={UserPlus} title="Benutzerverwaltung" description="Alle Vereinsnutzer auswählen und deren Einstellungen verwalten" color="#4A4E9E" onClick={() => setProfileUnderlay("users")}/>}
              {user.roles.includes("spieler") && <ProfileSettingsCard icon={Star} title="Spielerprofil" description="Mannschaften und Rückennummer verwalten" color={C.green} onClick={() => setProfileUnderlay("player")}/>}
              {user.roles.includes("trainer") && <ProfileSettingsCard icon={Trophy} title="Trainer & Rollen" description="Trainer-Mannschaften auswählen und Kapitänsrolle zuweisen" color="#2D6F8E" onClick={() => setProfileUnderlay("trainer")}/>}
              {user.roles.some((role) => ["spieler", "trainer", "teammanager", "kapitaen"].includes(role)) && <ProfileSettingsCard icon={ClipboardList} title="Strafenkatalog" description="Regeln und Kosten der Mannschaften verwalten" onClick={() => setProfileUnderlay("penalties")}/>}
            </>}
            {profileFolder === "notify" && <>
              <ProfileSettingsCard icon={Bell} title="Benachrichtigungen" description="Festlegen, worüber du informiert werden möchtest" color={C.amber} onClick={() => setProfileUnderlay("notifications")}/>
              <ProfileSettingsCard icon={Smartphone} title="Kalender synchronisieren" description="Spiele und Trainings mit dem Gerätekalender verbinden" color="#176B87" onClick={() => setProfileUnderlay("calendar")}/>
            </>}
            {profileFolder === "billing" && <>
              <ProfileSettingsCard icon={Euro} title="Meine Abonnements" description="Tarif, Status, Erwerbsdatum und nächste Abrechnung ansehen" onClick={() => setProfileUnderlay("subscription")}/>
              {(!referralAlreadyUsed || user.roles.includes("sysadmin")) && <ProfileSettingsCard icon={Building2} title="Vereine werben Vereine" description="Einen Verein werben und drei Gratismonate erhalten" color={C.red} onClick={() => setProfileUnderlay("referral")}/>}
            </>}
            {profileFolder === "support" && <>
              <ProfileSettingsCard icon={Star} title="App bewerten" description="CMO im App Store oder Google Play bewerten" color={C.amber} onClick={() => setProfileUnderlay("feedback")}/>
              <ProfileSettingsCard icon={Bug} title="Fehler melden" description="Eindeutiges Ticket erstellen und E-Mail-App öffnen" color={C.red} onClick={() => setProfileUnderlay("bug")}/>
            </>}
          </div>
        </div>
      )}
      `;

let out = src.slice(0, startIdx) + newBlock + src.slice(endIdx);

// --- 3) profileFolder-State ergänzen ---
const stateAnchor = /const \[profileUnderlay,\s*setProfileUnderlay\]\s*=\s*useState\((.*?)\);/;
const match = out.match(stateAnchor);
if (!match) {
  console.warn(
    "WARNUNG: Konnte die profileUnderlay-State-Zeile nicht automatisch finden.\n" +
    'Bitte manuell direkt darunter ergänzen: const [profileFolder, setProfileFolder] = useState("");'
  );
} else {
  out = out.replace(
    stateAnchor,
    `${match[0]}\n  const [profileFolder, setProfileFolder] = useState("");`
  );
  console.log("profileFolder-State ergänzt.");
}

writeFileSync(FILE, out, "utf8");
console.log("Fertig. app/page.tsx wurde aktualisiert.");
console.log("Bei Problemen zurückspielen mit:");
console.log(`  cp ${BACKUP} ${FILE}`);
