/* Screenshots der App über das Chrome DevTools Protocol.
 *
 * Kein Puppeteer: Node bringt seit v22 einen WebSocket-Client mit, und Chrome
 * liegt ohnehin auf dem Rechner. Ein Paket weniger, das man pflegen muss.
 */
import { writeFileSync } from "node:fs";

const PORT = process.env.CDP_PORT || "9333";
const ZIEL = process.env.APP_URL || "http://localhost:3100";
const ORDNER = process.env.BILD_ORDNER;

const schlaf = (ms) => new Promise((r) => setTimeout(r, ms));

async function seiteFinden() {
  for (let i = 0; i < 40; i++) {
    try {
      const liste = await fetch(`http://127.0.0.1:${PORT}/json/list`).then((r) => r.json());
      const seite = liste.find((z) => z.type === "page");
      if (seite?.webSocketDebuggerUrl) return seite.webSocketDebuggerUrl;
    } catch { /* Chrome startet noch */ }
    await schlaf(250);
  }
  throw new Error("Kein Chrome-Ziel gefunden");
}

const ws = new WebSocket(await seiteFinden());
await new Promise((r) => (ws.onopen = r));

let nr = 0;
const offen = new Map();
ws.onmessage = (e) => {
  const n = JSON.parse(e.data);
  if (n.id && offen.has(n.id)) {
    const { ja, nein } = offen.get(n.id);
    offen.delete(n.id);
    n.error ? nein(new Error(JSON.stringify(n.error))) : ja(n.result);
  }
};
const senden = (method, params = {}) =>
  new Promise((ja, nein) => { const id = ++nr; offen.set(id, { ja, nein }); ws.send(JSON.stringify({ id, method, params })); });

const js = async (ausdruck) => {
  const r = await senden("Runtime.evaluate", { expression: `(async () => { ${ausdruck} })()`, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || "JS-Fehler");
  return r.result?.value;
};

/* Das Entwickler-Abzeichen von Next.js sitzt unten links über der App. In
   einer Anleitung hat es nichts verloren. */
const abzeichenWeg = () => js(`
  if (!document.getElementById("anleitung-still")) {
    const s = document.createElement("style");
    s.id = "anleitung-still";
    s.textContent = "nextjs-portal, [data-nextjs-toast], #__next-build-watcher, nextjs-router-announcer { display: none !important; }";
    document.head.appendChild(s);
  }
  return true;
`);

const bild = async (name) => {
  await abzeichenWeg();
  const { data } = await senden("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  writeFileSync(`${ORDNER}/${name}.png`, Buffer.from(data, "base64"));
  console.log(`  ✓ ${name}.png`);
};

await senden("Page.enable");
await senden("Runtime.enable");
/* Ein Telefon, doppelte Auflösung: In einem PDF sieht ein 1x-Screenshot
   ausgefranst aus, sobald er über eine halbe Seite geht. */
await senden("Emulation.setDeviceMetricsOverride", {
  width: 390, height: 844, deviceScaleFactor: 2, mobile: true,
});

/* Die Schriften kommen per @import von Google Fonts. Ohne dieses Warten faellt
   der erste Screenshot auf eine Serifenschrift zurueck - im PDF sofort
   sichtbar, weil die App sonst nirgends Serifen benutzt. */
const warteAufSchriften = () => js(`
  await document.fonts.ready;
  await new Promise(r => setTimeout(r, 600));
  return document.fonts.size;
`);

/* Beim ersten Oeffnen fragt die App nach der Sprache. Ohne diesen Schritt
   landet jeder Screenshot auf dem Sprachbildschirm. */
const spracheDurch = () => js(`
  const w = (ms) => new Promise(r => setTimeout(r, ms));
  const weiter = [...document.querySelectorAll("button")].find(b => (b.textContent || "").trim() === "Weiter");
  if (weiter) { weiter.click(); await w(1200); return "durch"; }
  return "keine Sprachwahl";
`);

const anmelden = async (konto) => {
  await senden("Page.navigate", { url: ZIEL });
  await schlaf(3000);
  await spracheDurch();
  await warteAufSchriften();
  if (konto === null) return;
  const stand = await js(`
    const w = (ms) => new Promise(r => setTimeout(r, ms));
    const setzen = (el, v) => { const s = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set; s.call(el, v); el.dispatchEvent(new Event("input", { bubbles: true })); };
    for (let i = 0; i < 20; i++) {
      const f = [...document.querySelectorAll("input")];
      const mail = f.find(i2 => i2.type === "email" || /mail/i.test(i2.placeholder || ""));
      const pw = f.find(i2 => i2.type === "password");
      if (mail && pw) {
        setzen(mail, ${JSON.stringify(konto)}); setzen(pw, "demo");
        await w(250);
        [...document.querySelectorAll("button")].find(b => /Anmelden/.test(b.textContent))?.click();
        await w(4000);
        return "angemeldet";
      }
      await w(300);
    }
    return "kein Anmeldeformular";
  `);
  if (stand !== "angemeldet") console.log(`  ! ${stand}`);
  await warteAufSchriften();
};

const tippen = async (text, warten = 1600) => {
  await js(`
    const w = (ms) => new Promise(r => setTimeout(r, ms));
    const t = ${JSON.stringify(text)};
    const kandidaten = [...document.querySelectorAll("button, a, [role=button]")];
    const treffer = kandidaten.find(b => (b.textContent || "").trim() === t)
      || kandidaten.find(b => (b.textContent || "").trim().startsWith(t))
      || kandidaten.find(b => (b.getAttribute("aria-label") || "") === t);
    if (!treffer) return "nicht gefunden: " + t;
    treffer.click();
    await w(${warten});
    return "ok";
  `).then((r) => { if (r !== "ok") console.log(`  ! ${r}`); });
};

const hochScrollen = () => js(`window.scrollTo(0,0); document.querySelectorAll("*").forEach(e => { if (e.scrollTop) e.scrollTop = 0; }); return true;`);

export { anmelden, tippen, bild, abzeichenWeg, js, schlaf, hochScrollen, warteAufSchriften, spracheDurch, senden, ws };
