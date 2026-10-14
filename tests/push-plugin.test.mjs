/* Die Falle, die vom 28.09. bis zum 14.10.2026 den iOS-Push lahmgelegt hat.
 *
 * Ein Capacitor-Plugin ist ein Proxy: Jeder Eigenschaftszugriff liefert eine
 * Funktion, die einen nativen Aufruf DIESES NAMENS macht - auch der Zugriff
 * auf "then". Damit sieht es fuer die Promise-Maschinerie aus wie ein
 * Thenable. Gibt man es aus einem then-Rumpf oder einer async-Funktion
 * zurueck, ruft sie sein then(resolve, reject) auf, um es zu uebernehmen -
 * und Capacitor wirft "FirebaseMessaging.then() is not implemented on ios".
 * Das Versprechen wird nie erfuellt, der ganze Push-Weg haengt.
 *
 * Dieser Test braucht weder Capacitor noch ein Geraet: Er baut den Proxy
 * nach, der genau das Verhalten hat, auf das es ankommt. Geprueft wird die
 * REGEL, nicht die Fassung des Plugins - und die Regel gilt fuer jedes
 * Capacitor-Plugin, nicht nur fuer dieses.
 */
import assert from "node:assert/strict";
import test from "node:test";

/* So verhaelt sich ein Capacitor-Plugin: jeder Name ist eine Methode. */
function pluginNachbau(aufrufe) {
  return new Proxy({}, {
    get: (_ziel, name) => (...args) => {
      aufrufe.push(String(name));
      throw new Error(`"FirebaseMessaging.${String(name)}()" is not implemented on ios`);
    },
  });
}

test("nackt zurueckgegeben greift die Falle: then wird nativ aufgerufen", async () => {
  const aufrufe = [];
  const modul = { FirebaseMessaging: pluginNachbau(aufrufe) };
  const soNICHT = () => Promise.resolve(modul).then((m) => m.FirebaseMessaging);

  await assert.rejects(soNICHT(), (fehler) =>
    /is not implemented on ios/.test(fehler.message) && /\.then\(\)/.test(fehler.message));
  assert.deepEqual(aufrufe, ["then"], "die Maschinerie hat then() des Plugins gerufen");
});

test("in einer Schachtel kommt es heil an", async () => {
  const aufrufe = [];
  const modul = { FirebaseMessaging: pluginNachbau(aufrufe) };
  /* Genau die Form aus lib/firebase-push.ts. */
  const soJA = async () => {
    const m = await Promise.resolve(modul);
    return { fm: m.FirebaseMessaging };
  };

  const { fm } = await soJA();
  assert.equal(aufrufe.length, 0, "kein einziger nativer Aufruf beim blossen Durchreichen");
  assert.equal(fm, modul.FirebaseMessaging, "es ist dasselbe Plugin");
});

test("auch eine Zwischenvariable rettet nicht - nur die Schachtel", async () => {
  const aufrufe = [];
  const modul = { FirebaseMessaging: pluginNachbau(aufrufe) };
  /* Der naheliegende Reparaturversuch, der NICHT reicht: Der Rueckgabewert
     einer async-Funktion geht genauso durch die Erfuellung. */
  const immerNochFalsch = async () => {
    const m = await Promise.resolve(modul);
    const p = m.FirebaseMessaging;
    return p;
  };
  await assert.rejects(immerNochFalsch(), /is not implemented on ios/);
  assert.deepEqual(aufrufe, ["then"]);
});
