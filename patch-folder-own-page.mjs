// patch-folder-own-page.mjs
// Ausführen mit: node patch-folder-own-page.mjs
// Ersetzt das bisherige Inline-Umschalten (Liste wird ausgetauscht) durch
// echte eigene Seiten pro Ordner: jeder Ordner öffnet sich als
// <ProfileUnderlay> -- exakt dieselbe Komponente, die auch "Passwort ändern"
// usw. als eigene Seite mit Titel/Schließen-Button darstellt.

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-ownpage";

const src = readFileSync(FILE, "utf8");

const candidateStarts = [
  '<div key={profileFolder || "root"} className="profileFolderFade">',
  "{!profileFolder ? (",
];
let startIdx = -1;
for (const marker of candidateStarts) {
  const idx = src.indexOf(marker);
  if (idx !== -1) { startIdx = idx; break; }
}
if (startIdx === -1) {
  console.error("FEHLER: Kein bekannter Startanker gefunden. Nichts wurde geändert.");
  console.error("Lief patch-profile-folders.mjs schon erfolgreich?");
  process.exit(1);
}

const endMarker = '<div className="rounded-2xl p-4 mb-5"';
const endIdx = src.indexOf(endMarker, startIdx);
if (endIdx === -1) {
  console.error("FEHLER: Endanker nicht gefunden. Nichts wurde geändert.");
  process.exit(1);
}

copyFileSync(FILE, BACKUP);
console.log(`Backup geschrieben: ${BACKUP}`);

const before = src.slice(0, startIdx);
const after = src.slice(endIdx);

const newBlock = `<SectionTitle eyebrow="Verwalten" title="Einstellungen" />
      <div className="space-y-2 mb-6">
        <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Familie" color={C.green} onClick={() => setProfileFolder("personal")}/>
        <ProfileSettingsCard icon={KeyRound} title="Konto & Sicherheit" description="Passwort, Sicherheit, Rechtliches, Account" color="#4A4E9E" onClick={() => setProfileFolder("security")}/>
        <ProfileSettingsCard icon={Trophy} title="Verein & Mitgliedschaft" description="Spieler-, Trainer- und Vereinsrollen" color="#2D6F8E" onClick={() => setProfileFolder("club")}/>
        <ProfileSettingsCard icon={Bell} title="Benachrichtigungen & Kalender" description="Push-Einstellungen und Kalendersync" color={C.amber} onClick={() => setProfileFolder("notify")}/>
        <ProfileSettingsCard icon={Euro} title="Abo & Empfehlungen" description="Abonnement und Vereine werben Vereine" color={C.red} onClick={() => setProfileFolder("billing")}/>
        <ProfileSettingsCard icon={Star} title="Support & Feedback" description="Bewertung abgeben, Fehler melden" color={C.textDim} onClick={() => setProfileFolder("support")}/>
      </div>

      {profileFolder === "personal" && <ProfileUnderlay title="Persönliche Daten" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={User} title="Persönliche Daten" description="Stammdaten, Kontakte, Adresse und Mitgliederausweis" color={C.green} onClick={() => setProfileUnderlay("personal")}/>
          <ProfileSettingsCard icon={Users} title="Familie" description="Familienprofile ansehen und Verknüpfungen verwalten" color={C.amber} onClick={() => setProfileUnderlay("family")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "security" && <ProfileUnderlay title="Konto & Sicherheit" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={KeyRound} title="Passwort ändern" description="Passwort aktualisieren und Geräte abmelden" color="#4A4E9E" onClick={() => setProfileUnderlay("password")}/>
          <ProfileSettingsCard icon={Settings} title="Sicherheit" description="Automatischen Logout einstellen" color={C.textDim} onClick={() => setProfileUnderlay("security")}/>
          <ProfileSettingsCard icon={ShieldCheck} title="Kontoeinstellungen" description="Sicherheit, Rechtliches und Accountverwaltung" color={C.textDim} onClick={() => setProfileUnderlay("account")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "club" && <ProfileUnderlay title="Verein & Mitgliedschaft" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          {user.roles.includes("sysadmin") && <ProfileSettingsCard icon={UserPlus} title="Benutzerverwaltung" description="Alle Vereinsnutzer auswählen und deren Einstellungen verwalten" color="#4A4E9E" onClick={() => setProfileUnderlay("users")}/>}
          {user.roles.includes("spieler") && <ProfileSettingsCard icon={Star} title="Spielerprofil" description="Mannschaften und Rückennummer verwalten" color={C.green} onClick={() => setProfileUnderlay("player")}/>}
          {user.roles.includes("trainer") && <ProfileSettingsCard icon={Trophy} title="Trainer & Rollen" description="Trainer-Mannschaften auswählen und Kapitänsrolle zuweisen" color="#2D6F8E" onClick={() => setProfileUnderlay("trainer")}/>}
          {user.roles.some((role) => ["spieler", "trainer", "teammanager", "kapitaen"].includes(role)) && <ProfileSettingsCard icon={ClipboardList} title="Strafenkatalog" description="Regeln und Kosten der Mannschaften verwalten" onClick={() => setProfileUnderlay("penalties")}/>}
        </div>
      </ProfileUnderlay>}

      {profileFolder === "notify" && <ProfileUnderlay title="Benachrichtigungen & Kalender" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Bell} title="Benachrichtigungen" description="Festlegen, worüber du informiert werden möchtest" color={C.amber} onClick={() => setProfileUnderlay("notifications")}/>
          <ProfileSettingsCard icon={Smartphone} title="Kalender synchronisieren" description="Spiele und Trainings mit dem Gerätekalender verbinden" color="#176B87" onClick={() => setProfileUnderlay("calendar")}/>
        </div>
      </ProfileUnderlay>}

      {profileFolder === "billing" && <ProfileUnderlay title="Abo & Empfehlungen" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Euro} title="Meine Abonnements" description="Tarif, Status, Erwerbsdatum und nächste Abrechnung ansehen" onClick={() => setProfileUnderlay("subscription")}/>
          {(!referralAlreadyUsed || user.roles.includes("sysadmin")) && <ProfileSettingsCard icon={Building2} title="Vereine werben Vereine" description="Einen Verein werben und drei Gratismonate erhalten" color={C.red} onClick={() => setProfileUnderlay("referral")}/>}
        </div>
      </ProfileUnderlay>}

      {profileFolder === "support" && <ProfileUnderlay title="Support & Feedback" eyebrow="Einstellungen" onClose={() => setProfileFolder("")}>
        <div className="space-y-2">
          <ProfileSettingsCard icon={Star} title="App bewerten" description="CMO im App Store oder Google Play bewerten" color={C.amber} onClick={() => setProfileUnderlay("feedback")}/>
          <ProfileSettingsCard icon={Bug} title="Fehler melden" description="Eindeutiges Ticket erstellen und E-Mail-App öffnen" color={C.red} onClick={() => setProfileUnderlay("bug")}/>
        </div>
      </ProfileUnderlay>}

      `;

const out = before + newBlock + after;
writeFileSync(FILE, out, "utf8");

console.log("Fertig. Jeder Ordner öffnet jetzt als eigene Seite (ProfileUnderlay) mit eigenem Titel und Schließen-Button.");
console.log("Bei Problemen zurückspielen mit:");
console.log(`  cp ${BACKUP} ${FILE}`);
