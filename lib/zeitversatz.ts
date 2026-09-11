/* Ein Abruf, der den Zeitversatz bei Supabase uebersteht - fuer JEDE Abfrage.
 *
 * Supabase stellt die Token frisch aus; liegt die Uhr der ausstellenden Stelle
 * ein paar hundert Millisekunden vor der von PostgREST, lehnt PostgREST das
 * Token ab: 401, "JWT issued at future", Code PGRST303. Der naechste Aufruf
 * geht durch.
 *
 * Bisher war nur der Kalender-Feed dagegen geschuetzt. In der App traf es in
 * der Nacht zum 12.09. die eine Abfrage der Vereinsdaten beim Start - die
 * Kopfzeile zeigte bis zum Neuladen nur das CMO-Zeichen statt Vereinslogo und
 * Namen. Deshalb hier einmal an der Wurzel, als fetch fuer den Client: bei
 * genau diesem Fehler ein zweiter Versuch nach 1,5 Sekunden (400 ms reichten
 * nachweislich nicht). Alles andere geht unveraendert durch - ein falsches
 * Passwort oder eine fehlende Berechtigung wird nicht wiederholt.
 *
 * Die Anfragekoerper von supabase-js sind Zeichenketten, FormData oder Blobs;
 * die lassen sich ein zweites Mal senden.
 */
/* Ergaenzung 12.09.: Auch ein kurzer Aussetzer bei Supabase (502/503/504,
 * "Gateway Timeout") bekommt einen zweiten Versuch - aber NUR bei lesenden
 * Anfragen. Ein POST kann schon angekommen sein, bevor die Antwort ausfiel;
 * ihn zu wiederholen hiesse im Zweifel doppelt speichern. */
const VORUEBERGEHEND = new Set([502, 503, 504]);
const nurLesend = (eingabe: RequestInfo | URL, init?: RequestInit) => {
  const methode = (init?.method || (eingabe instanceof Request ? eingabe.method : "GET")).toUpperCase();
  return methode === "GET" || methode === "HEAD";
};

export const fetchMitZweitemVersuch: typeof fetch = async (eingabe, init) => {
  const antwort = await fetch(eingabe, init);
  if (VORUEBERGEHEND.has(antwort.status) && nurLesend(eingabe, init)) {
    await new Promise((weiter) => setTimeout(weiter, 1500));
    return fetch(eingabe, init);
  }
  if (antwort.status !== 401) return antwort;
  try {
    const inhalt = await antwort.clone().json();
    if (inhalt?.code !== "PGRST303") return antwort;
  } catch {
    return antwort;
  }
  await new Promise((weiter) => setTimeout(weiter, 1500));
  return fetch(eingabe, init);
};
