/* Verzeichnis der Handbuch-Kapitel - ERZEUGT von scripts/handbuch-bauen.mjs.
 *
 * Hier stehen nur Titel, Einleitung und Umfang. WER welches Kapitel sehen
 * darf, entscheidet die App (HANDBUCH_KAPITEL in app/page.tsx) - das haengt
 * an den Rollen des angemeldeten Nutzers und hat in einer erzeugten Datei
 * nichts zu suchen. */
export type HandbuchAbschnitt = {
  titel: string; wo: string; punkte: readonly string[]; hinweis: string;
  sprung?: { tab: string };
};

export const KAPITEL = [
 {
  "key": "mitglied",
  "rolle": "Mitglied (und was als Athlet/in dazukommt)",
  "einleitung": "Jede Mitgliedschaft ist entweder Mitglied oder Fan. Als Mitglied siehst du Termine, sagst zu oder ab, hilfst bei Aufgaben und Diensten mit, schreibst im Chat und pflegst dein Profil; weitere Rollen wie Athlet/in vergibt die Vereinsleitung. Als Fan folgst du dem Verein, ohne weitere Rollen.",
  "anzahl": 16
 },
 {
  "key": "trainer",
  "rolle": "Trainerin und Trainer",
  "einleitung": "Du führst eine Mannschaft: Du setzt Trainings und Spiele an, sagst sie ab und siehst, wer dabei ist. Du entscheidest auch, was deine Mannschaft in der App sieht.",
  "anzahl": 9
 },
 {
  "key": "vereinsadmin",
  "rolle": "Vereinsadministration (Vereins-Administrator)",
  "einleitung": "Die Vereinsadministration ist die höchste Rolle im Verein. Du nimmst Mitglieder auf, vergibst Rollen, legst Mannschaften an, pflegst Logo und Farben und schaltest Funktionen für alle ein oder aus.",
  "anzahl": 12
 },
 {
  "key": "organisator",
  "rolle": "Organisator/in",
  "einleitung": "Als Organisator/in planst du für den ganzen Verein: Termine aller Mannschaften, die Helferdienste dazu, Aufgaben und Fahrzeuge. Du bist kein Vereinsadmin, darfst aber deutlich mehr als ein einfaches Mitglied.",
  "anzahl": 10
 },
 {
  "key": "sponsoren",
  "rolle": "Sponsorenbetreuung",
  "einleitung": "Du betreust die Sponsoren deines Vereins in der App. Du trägst sie auf den vier Werbeplätzen ein, hinterlegst Aktionen und siehst, wie oft sie gesehen und angetippt wurden.",
  "anzahl": 7
 },
 {
  "key": "redaktion",
  "rolle": "Redakteur",
  "einleitung": "Als Redakteur schreibst du die Vereins-News und sprichst im Chat für den ganzen Verein. Dafür hast du den Reiter „Redaktion“ und darfst im Kanal „Vereins-News“ schreiben.",
  "anzahl": 5
 },
 {
  "key": "eltern",
  "rolle": "Familie & Kinderkonten",
  "einleitung": "Es gibt im Verein KEINE Rolle „Eltern“ — niemand teilt sie dir zu, und in der Rollenliste deines Vereins kommt sie nicht vor. Was zählt, ist allein die Verknüpfung: Du trägst sie selbst in deinem Profil ein, sie verbindet dein Konto mit dem deines Kindes und bringt dir dessen Mannschaftskanal und dessen Termine.",
  "anzahl": 6
 },
 {
  "key": "betreiber",
  "rolle": "Betreiber (Vereinsverwaltung)",
  "einleitung": "Du betreibst die App und betreust alle Vereine, die sie nutzen. Deine Oberfläche heißt „Vereinsverwaltung“, hat einen eigenen Zugang und gehört nicht zur Vereins-App: kein Verein und kein Vereinsadmin kommt hinein.",
  "anzahl": 7
 },
 {
  "key": "fan",
  "rolle": "Fan",
  "einleitung": "Als Fan folgst du dem Verein, ohne Mitglied zu sein. Du siehst, wann gespielt wird, liest die Vereins-News und feuerst an – aber alles, was mit Pflichten zu tun hat, bleibt außen vor. Dieses Heft sagt dir, was du hast und was dir bewusst fehlt.",
  "anzahl": 4
 },
 {
  "key": "kapitaen",
  "rolle": "Kapitän/in",
  "einleitung": "Als Kapitän oder Kapitänin führst du die Mannschaft auf dem Feld – und in der App fast alles, was auch die Trainer/innen dürfen. Dieses Heft sagt dir, was das ist und wo die Grenze verläuft.",
  "anzahl": 3
 },
 {
  "key": "teammanager",
  "rolle": "Teammanager/in",
  "einleitung": "Als Teammanager/in führst du den Kader. Du darfst bei deiner Mannschaft dasselbe wie die Trainer/innen – und eine Sache mehr, die sonst niemand außerhalb der Vereinsleitung darf.",
  "anzahl": 3
 },
 {
  "key": "athlet",
  "rolle": "Athlet/in",
  "einleitung": "„Athlet/in“ ist keine dritte Wahl neben Mitglied und Fan, sondern kommt als Zusatzrolle obendrauf – vergeben von der Vereinsleitung, nie von dir selbst. Dieses Heft beschreibt nur, was dadurch dazukommt. Alles Übrige steht im Handbuch für Mitglieder.",
  "anzahl": 3
 }
] as const;

const LADER: Record<string, () => Promise<{ default: readonly HandbuchAbschnitt[] }>> = {
  mitglied: () => import("./mitglied"),
  trainer: () => import("./trainer"),
  vereinsadmin: () => import("./vereinsadmin"),
  organisator: () => import("./organisator"),
  sponsoren: () => import("./sponsoren"),
  redaktion: () => import("./redaktion"),
  eltern: () => import("./eltern"),
  betreiber: () => import("./betreiber"),
  fan: () => import("./fan"),
  kapitaen: () => import("./kapitaen"),
  teammanager: () => import("./teammanager"),
  athlet: () => import("./athlet"),
};

const GELADEN: Record<string, readonly HandbuchAbschnitt[]> = {};

/* Laedt ein Kapitel nach. Gibt null zurueck, wenn es das Kapitel nicht gibt
   oder das Laden scheitert - dann zeigt die App den Abschnitt eben nicht,
   statt abzustuerzen. */
export async function kapitelLaden(key: string): Promise<readonly HandbuchAbschnitt[] | null> {
  if (GELADEN[key]) return GELADEN[key];
  const lader = LADER[key];
  if (!lader) return null;
  try {
    GELADEN[key] = (await lader()).default as readonly HandbuchAbschnitt[];
    return GELADEN[key];
  } catch {
    return null;
  }
}
