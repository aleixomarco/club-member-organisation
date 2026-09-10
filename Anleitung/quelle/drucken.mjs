/* Drucken ueber das DevTools-Protokoll statt ueber --print-to-pdf.
 * Nur so laesst sich generateDocumentOutline setzen - das erzeugt aus den
 * Ueberschriften ein echtes Lesezeichen-Verzeichnis im PDF. Ueber die
 * Befehlszeile gibt es diesen Schalter nicht. */
import { js, schlaf, senden, ws } from "./schuss.mjs";
import { writeFileSync } from "node:fs";

const AUSGABEN = process.env.AUSGABEN.split(",");
const ORDNER = process.env.ORDNER;

await senden("Emulation.setDeviceMetricsOverride", { width: 1123, height: 794, deviceScaleFactor: 1, mobile: false });

for (const name of AUSGABEN) {
  await senden("Page.navigate", { url: `file://${ORDNER}/${name}.html` });
  await schlaf(3500);
  await js(`await document.fonts.ready; await new Promise(r => setTimeout(r, 800)); return true;`);
  /* Warten, bis wirklich jedes Bild da ist - ein halb geladenes Bild druckt
     als leere Flaeche, und das faellt erst im fertigen PDF auf. */
  const bilder = await js(`
    const alle = [...document.images];
    await Promise.all(alle.map(b => b.complete ? null : new Promise(r => { b.onload = r; b.onerror = r; })));
    return { gesamt: alle.length, fehlend: alle.filter(b => !b.naturalWidth).length };
  `);
  if (bilder.fehlend) console.log(`  ! ${name}: ${bilder.fehlend} Bild(er) fehlen`);

  const { stream } = await senden("Page.printToPDF", {
    landscape: true, printBackground: true, preferCSSPageSize: true,
    marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0,
    generateDocumentOutline: true, transferMode: "ReturnAsStream",
  });
  const teile = [];
  for (;;) {
    const { data, base64Encoded, eof } = await senden("IO.read", { handle: stream, size: 2_000_000 });
    if (data) teile.push(Buffer.from(data, base64Encoded ? "base64" : "utf8"));
    if (eof) break;
  }
  await senden("IO.close", { handle: stream });
  const roh = Buffer.concat(teile);
  writeFileSync(`${ORDNER}/${name}.pdf`, roh);
  const seiten = (roh.toString("latin1").match(/\/Type\s*\/Page[^s]/g) || []).length;
  const marken = /\/Outlines/.test(roh.toString("latin1"));
  const spruenge = (roh.toString("latin1").match(/\/Subtype\s*\/Link/g) || []).length;
  console.log(`  ✓ ${name.padEnd(30)} ${String(seiten).padStart(3)} S · ${(roh.length/1024/1024).toFixed(1)} MB · ${spruenge} Sprungziele · Lesezeichen: ${marken ? "ja" : "NEIN"}`);
}
ws.close();
