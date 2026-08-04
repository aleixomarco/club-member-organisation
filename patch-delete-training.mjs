// patch-delete-training.mjs
// Ausführen mit: node patch-delete-training.mjs
// Fügt einen "Löschen"-Button neben "Absagen" bei Trainings hinzu (nur für
// Trainer/Kapitän/Teammanager der jeweiligen Mannschaft bzw. Vereinsadmin/
// Sysadmin) und ersetzt die fragile canCancelTraining-Prüfung durch die
// echte DB-Zuordnung (manageableTeams, wie beim allowedEventTeams-Fix).

import { readFileSync, writeFileSync, copyFileSync } from "fs";

const FILE = "app/page.tsx";
const BACKUP = "app/page.tsx.bak-before-delete-training";

const src = readFileSync(FILE, "utf8");
let out = src;
let changes = 0;
const total = 5;

function applyEdit(label, oldStr, newStr) {
  const count = out.split(oldStr).length - 1;
  if (count !== 1) {
    console.error(`WARNUNG (${label}): Anker ${count}x gefunden statt 1x -- übersprungen.`);
    return;
  }
  out = out.replace(oldStr, newStr);
  changes++;
  console.log(`OK: ${label}`);
}

// Edit 1: EventCard-Signatur um onDeleteTraining erweitern
applyEdit(
  "EventCard-Signatur",
  'function EventCard({ ev, carpoolOn, onCarpool, currentUser, members, isAdminUser, dutyPlan, setDutyPlan, canCancelTraining, onCancelTraining }) {',
  'function EventCard({ ev, carpoolOn, onCarpool, currentUser, members, isAdminUser, dutyPlan, setDutyPlan, canCancelTraining, onCancelTraining, onDeleteTraining }) {'
);

// Edit 2: Löschen-Button neben Absagen-Button
applyEdit(
  "Loeschen-Button im EventCard",
  '{canCancelTraining&&!ev.cancelled&&<button onClick={()=>onCancelTraining(ev.id)} className="w-full py-2.5 rounded-xltext-xs font-bold mb-3" style={{background:"#FCEBEE",color:C.red,border:"1px solid #F3B9B9"}}>Training für {ev.team} absagen</button>}',
  '{canCancelTraining&&!ev.cancelled&&<button onClick={()=>onCancelTraining(ev.id)} className="w-full py-2.5 rounded-xltext-xs font-bold mb-2" style={{background:"#FCEBEE",color:C.red,border:"1px solid #F3B9B9"}}>Training für {ev.team} absagen</button>}{canCancelTraining&&<button onClick={()=>onDeleteTraining(ev.id, ev.team)} className="w-full py-2.5 rounded-xl text-xs font-bold mb-3" style={{background:C.paperDim,color:C.red}}>Training endgültig löschen</button>}'
);

// Edit 3: canCancelTraining aus echter DB-Zuordnung (manageableTeams) ableiten
applyEdit(
  "canCancelTraining aus DB-Zuordnung",
  'const trainerTeams = currentUser.trainerTeams?.length ?currentUser.trainerTeams : [currentUser.team];\n          const canCancelTraining = ev.type === "training" && ((currentUser.roles.includes("trainer") && trainerTeams.includes(ev.team)) || (currentUser.roles.includes("kapitaen") && currentUser.team === ev.team) || (currentUser.roles.includes("teammanager") && currentUser.managedTeam === ev.team));',
  'const trainerTeams = currentUser.trainerTeams?.length ?currentUser.trainerTeams : [currentUser.team];\n          const legacyCanCancel = (currentUser.roles.includes("trainer") && trainerTeams.includes(ev.team)) || (currentUser.roles.includes("kapitaen") && currentUser.team === ev.team) || (currentUser.roles.includes("teammanager") && currentUser.managedTeam === ev.team);\n          const canCancelTraining = ev.type === "training" && (isSysAdmin(currentUser) || (manageableTeams !== null ? manageableTeams.includes(ev.team) : legacyCanCancel));'
);

// Edit 4: deleteTraining-Funktion nach cancelTraining einfügen
applyEdit(
  "deleteTraining-Funktion",
  'const cancelTraining = async (eventId) => { if(supabase&&typeof eventId==="string") await supabase.from("events").update({status:"cancelled",cancelled_at:new Date().toISOString(),cancelled_by:currentUser.authProfileId||null}).eq("id",eventId); setEvents((all)=> all.map((item) => item.id === eventId ? { ...item, cancelled: true, cancelledBy: currentUser.id } : item)); };',
  'const cancelTraining = async (eventId) => { if(supabase&&typeof eventId==="string") await supabase.from("events").update({status:"cancelled",cancelled_at:new Date().toISOString(),cancelled_by:currentUser.authProfileId||null}).eq("id",eventId); setEvents((all)=> all.map((item) => item.id === eventId ? { ...item, cancelled: true, cancelledBy: currentUser.id } : item)); };\n  const deleteTraining = async (eventId, teamName) => {\n    if (!window.confirm(`Training für ${teamName} wirklich endgültig löschen?`)) return;\n    if (supabase && typeof eventId === "string") {\n      const { error } = await supabase.from("events").delete().eq("id", eventId);\n      if (error) return;\n    }\n    setEvents((all) => all.filter((item) => item.id !== eventId));\n  };'
);

// Edit 5: onDeleteTraining an EventCard übergeben
applyEdit(
  "onDeleteTraining-Prop uebergeben",
  'canCancelTraining={canCancelTraining} onCancelTraining={cancelTraining}',
  'canCancelTraining={canCancelTraining} onCancelTraining={cancelTraining} onDeleteTraining={deleteTraining}'
);

if (changes === 0) {
  console.error('\nKEINE Änderung konnte angewendet werden. Datei bleibt unverändert.');
  process.exit(1);
}

copyFileSync(FILE, BACKUP);
console.log(`\nBackup geschrieben: ${BACKUP}`);
writeFileSync(FILE, out, 'utf8');

console.log(`\nFertig. ${changes}/${total} Teilschritte angewendet.`);
if (changes < total) console.warn('Nicht alle Schritte konnten automatisch angewendet werden -- bitte WARNUNG-Zeilen prüfen.');
console.log('Bei Problemen zurückspielen mit:');
console.log(`  cp ${BACKUP} ${FILE}`);
