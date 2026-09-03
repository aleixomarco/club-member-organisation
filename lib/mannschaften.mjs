/* Mannschaftszugehoerigkeit eines Mitglieds.
 *
 * Eigenes Modul, weil diese Funktionen ueber Rechte und Sichtbarkeit
 * entscheiden: welche Chat-Kanaele jemand sieht, wo er absagen darf, wen ein
 * Trainer zum Kapitaen machen kann. Das gehoert geprueft, nicht in eine
 * 9600-Zeilen-Ansicht vergraben - die Tests liegen in
 * tests/mannschaften.test.mjs.
 */
import { hoechsteMannschaft } from "./mannschaftsrang.mjs";

/* ------------------------------------------------------------------ */
/* Mannschaftszugehoerigkeit                                            */
/* ------------------------------------------------------------------ */
/* Ein Mitglied kann in MEHREREN Mannschaften stehen - als Spieler in
   Herren 1 und Herren 2, als Trainer der U11 und Kapitaen der Damen 2.
   Das Feld member.team traegt trotzdem nur EINEN Namen; es ist eine
   Abkuerzung fuer Ueberschriften, keine Zugehoerigkeit.
   Wo gefragt wird "gehoert diese Person zu dieser Mannschaft", muss die
   ganze Liste zaehlen. Wurde das mit member.team beantwortet, fehlte der
   Person genau die Haelfte ihres Vereins: der zweite Mannschaftskanal, das
   Absagerecht in der zweiten Mannschaft, der Platz im zweiten Kader.
   Die Listen kommen aus team_members (function je Zeile). Die Rueckfaelle
   darunter greifen im Demo-Betrieb und bei aelteren Datensaetzen, wo die
   Rolle global am Mitglied steht und die Mannschaft nur in member.team. */
export const memberPlayerTeams = (member) => {
  if (member?.playerTeams?.length) return member.playerTeams;
  if (!member?.roles?.includes("spieler")) return [];
  if (member.teams?.length) return member.teams;
  return member.team && member.team !== "Mitglied" ? [member.team] : [];
};
export const memberTrainerTeams = (member) => {
  if (member?.trainerTeams?.length) return member.trainerTeams;
  if (!member?.roles?.includes("trainer")) return [];
  return member.team && member.team !== "Mitglied" ? [member.team] : [];
};
export const memberCaptainTeams = (member) => {
  if (member?.captainTeams?.length) return member.captainTeams;
  if (!member?.roles?.includes("kapitaen")) return [];
  /* Rueckfall NUR auf die eine Abkuerzung, nicht auf alle Spielmannschaften.
     Die Rolle "kapitaen" steht bei alten Datensaetzen global am Mitglied,
     ohne zu sagen, WO. Wuerde man daraus alle Spielmannschaften ableiten,
     bekaeme der Kapitaen von Herren 1, der nebenbei in Herren 2 spielt,
     dort ebenfalls Kapitaensrechte - also das Recht, fremde Termine
     abzusagen. Das waere mehr, als er vorher hatte. */
  const einzeln = member.team && member.team !== "Mitglied" ? [member.team] : [];
  return einzeln.filter((name) => memberPlayerTeams(member).includes(name));
};
export const memberManagedTeams = (member) => {
  if (member?.managedTeams?.length) return member.managedTeams;
  return member?.managedTeam ? [member.managedTeam] : [];
};
/* Alle Mannschaften, zu denen die Person in irgendeiner Funktion gehoert. */
export const memberAllTeams = (member) => [...new Set([
  ...memberPlayerTeams(member), ...memberTrainerTeams(member),
  ...memberCaptainTeams(member), ...memberManagedTeams(member),
].filter(Boolean))];
/* Die Frage, die frueher als "member.team === name" geschrieben wurde. */
export const memberInTeam = (member, teamName) => Boolean(teamName) && memberAllTeams(member).includes(teamName);
/* Vorauswahl in Auswahlfeldern: die hoechste Mannschaft, nicht die erste der
   Liste. Die Listen kommen sortiert nach Namen aus der Datenbank - "Damen 1"
   stand dort nur deshalb vorn, weil D vor H kommt. */
export const hoechstesTeam = (liste) => {
  const name = hoechsteMannschaft((liste || []).map((eintrag) => eintrag?.name));
  return (liste || []).find((eintrag) => eintrag?.name === name) || (liste || [])[0] || null;
};

